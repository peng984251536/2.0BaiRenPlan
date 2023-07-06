Shader "MyBRDF/MyBRDFByBuiltin"
{
    // Keep properties of StandardSpecular shader for upgrade reasons.
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Glossiness("Smoothness (平滑度)", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic (金属度、反射度)", Range(0.0, 1.0)) = 0.0
        _MetallicMapScale("Metallic Scale", Range(0.0, 1.0)) = 1.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        _LUT("LUT信息图", 2D) = "white" {}
        //
        //        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        //        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0
        //
        //        _BumpScale("Scale", Float) = 1.0
        //        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}
        //
        //        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        //        _ParallaxMap ("Height Map", 2D) = "black" {}
        //
        //        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        //        _OcclusionMap("Occlusion", 2D) = "white" {}
        //
        //        _EmissionColor("Color", Color) = (0,0,0)
        //        _EmissionMap("Emission", 2D) = "white" {}
        //
        //        _DetailMask("Detail Mask", 2D) = "white" {}
        //
        //        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        //        _DetailNormalMapScale("Scale", Float) = 1.0
        //        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}
        //
        //        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0

        [Toggle(_On_Test)] _On_Test("测试",Float)=0


        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0

    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "SimpleLit"
            "IgnoreProjector" = "True"
            "ShaderModel"="4.5"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Specular.hlsl"
            #include "Fresnel.hlsl"

            float3 GetAddLight(float3 baseColor, float3 posWS, float3 viewDir, float3 normalWS,
                               float roughness, float oneMinusReflectivity)
            {
                float3 lightColor = float3(0.04, 0.04, 0.04);
                //baseColor = lerp(baseColor, 0.04, oneMinusReflectivity);
                uint pixelLightCount = GetAdditionalLightsCount();
                if (pixelLightCount == 0)
                    return float3(0, 0, 0);
                for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, posWS);
                    half lightAtten = light.distanceAttenuation * light.shadowAttenuation;
                    half3 halfDir = normalize(light.direction + normalWS);
                    half NdotL = saturate(dot(light.direction, normalWS));
                    half NdotH = saturate(dot(normalWS, halfDir));
                    half NdotV = saturate(dot(normalWS, viewDir));
                    half HdotL = saturate(dot(halfDir, light.direction));

                    //NDF,法线分布函数
                    float NDF = ggx_term_byTR(NdotH, roughness);
                    // NDF = NDFTerm(NdotH,roughness);
                    //-----GGX,几何遮蔽函数
                    float GGX = SmithJointGGXVisibilityTerm(NdotL, NdotV, roughness);
                    //-----菲尼尔函数
                    float3 fresnel = FresnelTerm(baseColor, HdotL);
                    //return float4(fresnel,1);
                    //-----反射光
                    float specularTerm = NDF * GGX * PI;
                    specularTerm = max(0.02, specularTerm * NdotL);
                    lightColor += specularTerm * fresnel * light.color * lightAtten;
                    //specularFinalColor /= pixelLightCount;
                }
                return lightColor;
            }
            ENDHLSL

            // Use same blending / depth states as Standard shader
            //            Blend[_SrcBlend][_DstBlend]
            //            ZWrite[_ZWrite]
            //            Cull[_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "DisneyDiffuse.hlsl"
            //#include "Specular.hlsl"
            //#include "Fresnel.hlsl"
            #pragma shader_feature _On_Test
            // #pragma vertex LitPassVertexSimple
            // #pragma fragment LitPassFragmentSimple
            //
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitForwardPass.hlsl"
            //
            // #pragma vertex LitPassVertex
            // #pragma fragment LitPassFragment
            //
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"

            #pragma vertex vertex
            #pragma fragment fragment

            half4 _Color;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            float _Cutoff; //透明度

            float _Glossiness;

            float _Metallic;
            TEXTURE2D(_MetallicGlossMap);
            SAMPLER(sampler_MetallicGlossMap);

            float _BumpScale;
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);

            half4 _EmissionColor;
            TEXTURE2D(_EmissionMap);
            SAMPLER(sampler_EmissionMap);

            TEXTURE2D(_LUT);
            SAMPLER(sampler_LUT);

            struct appdata
            {
                float4 pos : POSITION;
                float4 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
                float4 color :COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 halfRef : TEXCOORD2;
                float3 viewDir:TEXCOORD3;
                float3 posWS:TEXCOORD4;
                float3 normalOS:TEXCOORD5;
            };

            v2f vertex(appdata v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.pos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normalWS = TransformObjectToWorldNormal(v.normal);

                float3 posWS = TransformObjectToWorld(v.pos);
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - posWS);
                o.halfRef = normalize(viewDir + _MainLightPosition.xyz);
                o.viewDir = viewDir;
                o.posWS = posWS;
                o.normalOS = v.normal;
                return o;
            }

            float4 fragment(v2f i):SV_Target
            {
                float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                float4 metallic = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, i.uv);
                Light light = GetMainLight();

                float3 normalWS = TransformObjectToWorldNormal(i.normalOS);
                float NdotL = saturate(dot(normalWS, light.direction));
                float halfNdotL = dot(normalWS, light.direction) * 0.5 + 0.5;
                NdotL = saturate(NdotL);
                //float NdotH = saturate(dot(i.halfRef, i.normalWS));
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS);
                float3 h = normalize(viewDir + light.direction.xyz);
                float NdotH = saturate(dot(normalWS, h));
                float HdotL = saturate(dot(h, light.direction));
                float NdotV = saturate(dot(normalWS, viewDir));

                //------金属度和光滑度
                float perceptualRoughness = 0.96 - lerp(0, metallic.a, _Glossiness); //光滑度
                float oneMinusReflectivity = 1 - lerp(0, metallic.r, _Metallic); //1-金属度
                float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);


                //---------DisneyDiffuse 部分--------//
                float diffuseLight = DisneyDiffuseLight(NdotL, HdotL, perceptualRoughness);
                float diffuseView = DisneyDiffuseView(NdotV, HdotL, perceptualRoughness);
                float diffuseTerm = MyDisneyDiffuse(NdotV, NdotL, HdotL, perceptualRoughness);
                //return float4(baseColor.rgb*(light.color*diffuseTerm),1);


                //------多光源
                float3 addLightColor = GetAddLight(baseColor, i.posWS, viewDir, normalWS,
                                                   roughness, oneMinusReflectivity);
                //return float4(addLightColor,1);

                //---------Specular(反射部分)--------//
                float3 specularColor = lerp(baseColor, 0.04, oneMinusReflectivity);
                //NDF,法线分布函数
                float NDF = ggx_term_byTR(NdotH, roughness);
                // NDF = NDFTerm(NdotH,roughness);
                //-----GGX,几何遮蔽函数
                float GGX = SmithJointGGXVisibilityTerm(NdotL, NdotV, roughness);
                //-----菲尼尔函数
                float3 fresnel = FresnelTerm(specularColor.rgb, HdotL);
                //return float4(fresnel,1);
                //-----反射光
                float specularTerm = NDF * GGX * PI;
                specularTerm = max(0.02, specularTerm * NdotL);
                float3 specularFinalColor = specularTerm * fresnel * light.color;

                //-------IBL(间接光)------//
                half3 ambient_GI = SampleSH(normalWS); //环境光
                //-----间接光镜面反射
                float mip_roughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);
                float3 refDirWS = reflect(-viewDir, normalWS);
                half mip = mip_roughness * UNITY_SPECCUBE_LOD_STEPS;
                half4 encodedIrradiance =
                    SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, refDirWS, mip);
                float3 iblSpecular = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
                float grazingTerm = saturate(2 - oneMinusReflectivity - perceptualRoughness);
                float3 ibl = iblSpecular * FresnelLerp(specularColor, grazingTerm, NdotV);
                //return float4(FresnelLerp(specularColor,grazingTerm , NdotV),1);
                //return float4(ibl,1);


                //
                // half3 color =   diffColor * (gi.diffuse + light.color * diffuseTerm)
                // + specularTerm * light.color * FresnelTerm (specColor, lh)
                // + surfaceReduction * gi.specular * FresnelLerp (specColor, grazingTerm, nv);

                float3 finalColor = (light.color * diffuseTerm + ambient_GI) * baseColor * addLightColor
                    + specularFinalColor + ibl;
                //return float4(baseColor * addLightColor,1) ;

                #if _On_Test
                float3 Flast = fresnelSchlickRoughness(NdotV, float3(0.04, 0.04, 0.04), perceptualRoughness);
                half2 envBDRF = SAMPLE_TEXTURE2D(_LUT, sampler_LUT,
                    float2(lerp(0.01,0.99,NdotV),lerp(0.01,0.99,perceptualRoughness))).rg;
                float3 lut = Flast * envBDRF.r + envBDRF.g;
                //return float4(Flast, 1);
                return float4(lut, 1);
                #endif
                
                return float4(FresnelLerp(specularColor, grazingTerm, NdotV)*iblSpecular, 1);

                //漫反射测试
                //return diffuseTerm * NdotL;

                return float4(finalColor, 1);
            }
            ENDHLSL
        }
    }

    Fallback "Hidden/Universal Render Pipeline/FallbackError"
    //CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.SimpleLitShader"
}