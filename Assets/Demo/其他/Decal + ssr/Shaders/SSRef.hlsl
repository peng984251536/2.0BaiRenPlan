#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#pragma multi_compile_local _ _MULIT_SAMPLING
#pragma multi_compile_local _ _PATIO_FILTER


// TEXTURE2D (_MyBaseMap);
// SAMPLER (sampler_MyBaseMap);
TEXTURE2D(_CameraTexture);
SAMPLER(sampler_CameraTexture);
TEXTURE2D (_NoiseTex);
SAMPLER (sampler_NoiseTex);
TEXTURE2D_X(_SSRayCast);
SAMPLER (sampler_SSRayCast);
TEXTURE2D_X(_SSRayCastMask);
SAMPLER (sampler_SSRayCastMask);


float4 _NoiseTex_TexelSize;
float4 _CameraDepthTexture_TexelSize;
float4 _SSRayCast_TexelSize;
float4 _CameraDepthTexture_ST;
float4x4 _VPMatrix;


float _downsampleDivider;

//rayMarch Params
float4 _rayParams;
#define RayStepNum _rayParams.x;
#define RayStepScale _rayParams.y;
#define _thickness _rayParams.z;
//rougness
float _BRDFBias;
float _EdgeFactor;
//_jitter Params
float2 _Jitter;
float4 _JitterSizeAndOffset;

inline float SmithJointGGXVisibilityTerm (float NdotL, float NdotV, float roughness)
{
    #if 0
    // Original formulation:
    //  lambda_v    = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5f;
    //  lambda_l    = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5f;
    //  G           = 1 / (1 + lambda_v + lambda_l);

    // Reorder code to be more optimal
    half a          = roughness;
    half a2         = a * a;

    half lambdaV    = NdotL * sqrt((-NdotV * a2 + NdotV) * NdotV + a2);
    half lambdaL    = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);

    // Simplify visibility term: (2.0f * NdotL * NdotV) /  ((4.0f * NdotL * NdotV) * (lambda_v + lambda_l + 1e-5f));
    return 0.5f / (lambdaV + lambdaL + 1e-5f);  // This function is not intended to be running on Mobile,
    // therefore epsilon is smaller than can be represented by half
    #else
    // Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
    float a = roughness;
    float lambdaV = NdotL * (NdotV * (1 - a) + a);
    float lambdaL = NdotV * (NdotL * (1 - a) + a);

    #if defined(SHADER_API_SWITCH)
    return 0.5f / (lambdaV + lambdaL + UNITY_HALF_MIN);
    #else
    return 0.5f / (lambdaV + lambdaL + 1e-5f);
    #endif

    #endif
}

inline float GGXTerm (float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
    return INV_PI * a2 / (d * d + 1e-7f); // This function is not intended to be running on Mobile,
    // therefore epsilon is smaller than what can be represented by half
}

float RayAttenBorder (float2 pos, float value)
{
    float borderDist = min(1.0 - max(pos.x, pos.y), min(pos.x, pos.y));
    return saturate(borderDist > value ? 1.0 : borderDist / value);
}

//计算BRDF的ND项目
float BRDF_Unity_Weight(float3 V, float3 L, float3 N, float Roughness)
{
    float3 H = normalize(L + V);

    float NdotH = saturate(dot(N,H));
    float NdotL = saturate(dot(N,L));
    float NdotV = saturate(dot(N,V));

    half G = SmithJointGGXVisibilityTerm (NdotL, NdotV, Roughness);
    half D = GGXTerm (NdotH, Roughness);

    return (D * G) * (PI / 4.0);
}



float4 resolve(v2f i) : SV_Target
{
    float2 uv = i.uv;
    int2 pos = uv * _ScreenSize.xy;

    float4 NormalMap = SAMPLE_TEXTURE2D(_GBuffer2, sampler_GBuffer2, uv);
    float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
    float roughness = clamp(1-NormalMap.a,0.04f,0.96f) ;
    float3 posWS = GetWorldPos(uv,depth);
    float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-posWS.xyz);
    float3 screenPos = float3(uv, depth);

    //-----控制是否开启BRDF-----//
    float _UseNormalization = 1;
    //float _Fireflies = 1;
    

    
    //-------创建一个抖动矩阵，为了做 多重采样---------
    // Blue noise generated by https://github.com/bartwronski/BlueNoiseGenerator/
    float2 uv_jitter = (uv+_JitterSizeAndOffset.zw)*_ScreenSize.xy/_downsampleDivider * _NoiseTex_TexelSize.xy;
    float2 blueNoise = SAMPLE_TEXTURE2D_X(_NoiseTex,sampler_NoiseTex,uv_jitter).rg*2-1;
    //blueNoise*=_JitterSizeAndOffset.xy;
    // works better with [-1, 1] range
    float2x2 offsetRotationMatrix = float2x2(blueNoise.x, blueNoise.y, -blueNoise.y, blueNoise.x);
    //原来的矩阵模式，上面的是简化版本
    /*
    float2x2 offsetRotationMatrix;
    {
        float2 offsetRotation;
        sincos(2.0 * PI * InterleavedGradientNoise(pos, 0.0), offsetRotation.y, offsetRotation.x);
        offsetRotationMatrix = float2x2(offsetRotation.x, offsetRotation.y, -offsetRotation.y, offsetRotation.x);
    }
    */

    int NumResolve = 1;
    int maxMipLevel = 7;
    #if defined(_MULIT_SAMPLING)
    NumResolve = 4;
    #endif
    
    // if (_RayReuse == 1)
    //     NumResolve = 4;

    float NdotV = saturate(dot(NormalMap.xyz, viewDir));
    float coneTangent = lerp(0.0, roughness * (1.0 - _BRDFBias), NdotV * sqrt(roughness));
    //return coneTangent;
    // float hitMask = _SSRayCastMask.Sample(sampler_SSRayCastMask,uv).r;
    // hitMask = lerp(coneTangent*_DebugParams.y,hitMask,_DebugParams.x);
    // return hitMask;
    // hitMask =  RayAttenBorder(uv, _EdgeFactor) * hitMask;
    

    //--2、Multi sample,利用随机因子进行多重采样
    /*https://blog.csdn.net/qq_42999564/article/details/127631258*/
    //NumResolve = _DebugParams.x;
    float4 result = 0.0;
    float weightSum = 0.0;
    for (int i = 0; i < NumResolve; i++)
    {
        float2 offsetUV = offset[i] * _ScreenSize.zw*_downsampleDivider;
        offsetUV = mul(offsetRotationMatrix, offsetUV);

        // "uv" is the location of the current (or "local") pixel. We want to resolve the local pixel using
        // intersections spawned from neighboring pixels. The neighboring pixel is this one:
        float2 neighborUv = uv + offsetUV;

        // Now we fetch the intersection point and the PDF that the neighbor's ray hit.
        float4 hitPacked =_SSRayCast.Sample(sampler_SSRayCast,neighborUv);
        float2 hitUv = hitPacked.xy;
        float hitZ = hitPacked.z;
        float hitPDF = hitPacked.w;
        float hitMask = _SSRayCastMask.Sample(sampler_SSRayCastMask,neighborUv).r;

        float3 hitWS = GetWorldPos(hitUv,hitZ);

        // We assume that the hit point of the neighbor's ray is also visible for our ray, and we blindly pretend
        // that the current pixel shot that ray. To do that, we treat the hit point as a tiny light source. To calculate
        // a lighting contribution from it, we evaluate the BRDF. Finally, we need to account for the probability of getting
        // this specific position of the "light source", and that is approximately 1/PDF, where PDF comes from the neighbor.
        // Finally, the weight is BRDF/PDF. BRDF uses the local pixel's normal and roughness, but PDF comes from the neighbor.
        //--3、patiofilter 空间滤波
        float weight = 1.0;
        #if defined(_PATIO_FILTER)
        //计算 BRDF的双向反射函数
        //计算出这个像素对应的间接光的BRDF值,
        weight = BRDF_Unity_Weight(viewDir /*V*/, normalize(hitWS - posWS) /*L*/,
                                   NormalMap.xyz /*N*/, roughness) / max(1e-5, hitPDF);
        //return weight;
        #endif
        //return weight;
        // float intersectionCircleRadius = coneTangent * length(hitUv - uv);
        // float mip = clamp(log2(intersectionCircleRadius * max(_ResolveSize.x, _ResolveSize.y)), 0.0, maxMipLevel);

        float intersectionCircleRadius = coneTangent * length(hitUv - uv);
        float mipVal = log2(intersectionCircleRadius * max(_ScreenSize.x,_ScreenSize.y)/_downsampleDivider);
        float mip = clamp(mipVal, 0.0, maxMipLevel);
        float4 sampleColor = float4(0.0, 0.0, 0.0, 0.0);
        //采样摄像机的图像
        sampleColor.rgb = saturate(_CameraTexture.SampleLevel(sampler_CameraTexture,hitUv,mip).rgb);
        //return mip - _DebugParams.y;
        //sampleColor.rgb += _MyBaseMap.SampleLevel(sampler_MyBaseMap,hitUv,mip).rgb;
        sampleColor.a = RayAttenBorder(hitUv, _EdgeFactor) * hitMask;

        if (_Fireflies == 1)
            sampleColor.rgb /= 1 + Luminance(sampleColor.rgb);

        result += sampleColor * weight;
        weightSum += weight;
    }
    result /= weightSum;

    if (_Fireflies == 1)
        result.rgb /= 1 - Luminance(result.rgb);
    if (_Fireflies == 1)
        result.rgb = ToneMapping(result);

    return  result;
}

