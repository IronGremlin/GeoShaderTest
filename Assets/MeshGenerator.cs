using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class MeshGenerator { 
    public static MeshData GenerateTerrainMesh(float[,] heightMap)
    {
        int width = heightMap.GetLength(0);
        float topLeftX = (width - 1) / -2f;
        float topLeftZ = (width - 1) / 2f;

        MeshData meshData = new MeshData(width);
        for (int vertexIndex =0, y = 0; y < width; y++)
        {
            for (int x = 0; x < width; x++)
            {
                //meshData.vertices[vertexIndex] = new Vector3(topLeftX + x, meshHeightCurve.Evaluate(heightMap[x, y]) * heightMultiplier, topLeftZ - y);
                meshData.vertices[vertexIndex] = new Vector3(topLeftX + x, heightMap[x, y], topLeftZ - y);
                meshData.uvs[vertexIndex] = new Vector2(x / (float)width, y / (float)width);
                if (x < width - 1 && y < width - 1)
                {
                    meshData.AddTriangle(vertexIndex, vertexIndex + width + 1, vertexIndex + width);
                    meshData.AddTriangle(vertexIndex + width + 1, vertexIndex, vertexIndex+ 1);
                }
                vertexIndex++;

            }

        }
        return meshData;
    }
}
public class MeshData
{
    public Vector3[] vertices;
    public int[] triangles;
    public Vector2[] uvs;

    int triangleIndex;
    public int width {get; private set;}

    public MeshData(int meshWidth)
    {
        width = meshWidth;
        vertices = new Vector3[meshWidth * meshWidth];
        uvs = new Vector2[meshWidth * meshWidth];
        triangles = new int[(meshWidth - 1) * (meshWidth - 1) * 6];
    }

    public void AddTriangle(int a, int b, int c) {
        triangles[triangleIndex] = a;
        triangles[triangleIndex+1] = b;
        triangles[triangleIndex+2] = c;
        triangleIndex += 3;
    }

    public Mesh CreateMesh()
    {
        Mesh mesh = new Mesh();
        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.uv = uvs;
        mesh.RecalculateNormals();
        return mesh;

    }
}