﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;


namespace URPLearn
{
    public class GrassUtil2
    {
        private static Mesh _grassMesh;

        public static Mesh CreateGrassMesh()
        {
            var grassMesh = new Mesh {name = "Grass Quad"};
            float width = 1f;
            float height = 0.88f;
            float halfWidth = width / 2;
            grassMesh.SetVertices(new List<Vector3>
            {
                new Vector3(-halfWidth, 0, 0.0f),
                new Vector3(halfWidth, 0, 0.0f),
                new Vector3(-halfWidth / 2, height / 2, 0.0f),
                new Vector3(halfWidth / 2, height / 2, 0.0f),
                new Vector3(0, height, 0.0f),
            });
            grassMesh.SetUVs(0, new List<Vector2>
            {
                new Vector2(0, 0),
                new Vector2(1, 0),
                new Vector2(0.25f, 0.44f),
                new Vector2(0.75f, 0.44f),
                new Vector2(0.5f, 0.88f)
            });

            grassMesh.SetIndices(new[] {0, 2, 1, 1, 2, 3, 3, 2, 4},
                MeshTopology.Triangles, 0, false);
            grassMesh.RecalculateNormals();
            grassMesh.UploadMeshData(true);
            return grassMesh;
        }

        public static Mesh unitMesh
        {
            get
            {
                if (_grassMesh != null)
                {
                    return _grassMesh;
                }

                _grassMesh = CreateGrassMesh();
                return _grassMesh;
            }
        }


        /// <summary>
        /// 三角形内部，取平均分布的随机点
        /// </summary>
        public static Vector3 RandomPointInsideTriangle(Vector3 p1, Vector3 p2, Vector3 p3)
        {
            var x = Random.Range(0, 1f);
            var y = Random.Range(0, 1f);
            if (y > 1 - x)
            {
                //如果随机到了右上区域，那么反转到左下
                var temp = y;
                y = 1 - x;
                x = 1 - temp;
            }

            var vx = p2 - p1;
            var vy = p3 - p1;
            return p1 + x * vx + y * vy;
        }


        //计算三角形面积
        public static float GetAreaOfTriangle(Vector3 p1, Vector3 p2, Vector3 p3)
        {
            var vx = p2 - p1;
            var vy = p3 - p1;
            var dotvxy = Vector3.Dot(vx, vy);
            var sqrArea = vx.sqrMagnitude * vy.sqrMagnitude - dotvxy * dotvxy;
            return 0.5f * Mathf.Sqrt(sqrArea);
        }

        public static Vector3 GetFaceNormal(Vector3 p1, Vector3 p2, Vector3 p3)
        {
            var vx = p2 - p1;
            var vy = p3 - p1;
            return Vector3.Cross(vx, vy);
        }
    }
}