using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TerrainGen : MonoBehaviour
{
    [Header("Target Terrain")]
    public Material groundMaterial;
    public bool makeInteresting;
    [Range(10,255)]
    public int Size;
    [Range(0, 50)]
    public float HeightMultiplier;
    public int Seed;
    public float NoiseScale;
    [Range(0, 1)]
    public float Persistance;
    public float Lacunarity;
    public int Octaves;
    private GameObject ground;
    private Mesh terrainMesh;

    public Vector3[] terrainVertices { get; private set; }

    [Header("Rendering Properties")]

    [Tooltip("Compute shader for generating transformation matrices.")]
    public ComputeShader computeShader;
    public ComputeShader rayCastComputer;




    [Tooltip("Mesh for individual grass blades.")]
    public Mesh grassMesh;
    [Tooltip("Material for rendering each grass blade.")]
    public Material grassMaterial;

    //[Space(10)]

    //[Header("Lighting and Shadows")]

    //[Tooltip("Should the procedural grass cast shadows?")]
    //public ShadowCastingMode castShadows = ShadowCastingMode.On;
    //[Tooltip("Should the procedural grass receive shadows from other objects?")]
    //public bool receiveShadows = true;

    [Space(10)]

    [Header("Grass Blade Properties")]

    [Range(0.0f, 100.0f)]
    [Tooltip("Base size of grass blades in all three axes.")]
    public float scale = 0.1f;
    [Range(0.0f, 5.0f)]
    [Tooltip("Minimum height multiplier.")]
    public float minBladeHeight = 0.5f;
    [Range(0.0f, 5.0f)]
    [Tooltip("Maximum height multiplier.")]
    public float maxBladeHeight = 1.5f;

    [Range(-1.0f, 1.0f)]
    [Tooltip("Minimum random offset in the x- and z-directions.")]
    public float minOffset = -0.1f;
    [Range(-1.0f, 1.0f)]
    [Tooltip("Maximum random offset in the x- and z-directions.")]
    public float maxOffset = 0.1f;

    [Space(10)]

    [Header("Scatter Placement Parameters")]
    public float Radius;
    public Transform RayTarget;
    

    public Vector3 lastSplat { get; private set; }

    private bool buffersReady;


    private GraphicsBuffer terrainTriangleBuffer;
    private GraphicsBuffer terrainVertexBuffer;

    private GraphicsBuffer transformMatrixBuffer;

    private GraphicsBuffer grassTriangleBuffer;
    private GraphicsBuffer grassVertexBuffer;
    private GraphicsBuffer grassUVBuffer;

    private Bounds bounds;
    private MaterialPropertyBlock properties;

    private int kernel;
    private uint threadGroupSize;
    private int terrainTriangleCount = 0;

    public void MakeFlat()
    {
        if (ground != null) {
            if (Application.isEditor) {
                DestroyImmediate(ground);
            }
            else
            {
                Destroy(ground);
            }
        }
        float[,] heights = new float[Size, Size];
        
        for (int x = 0; x < Size; x++)
        {
            for (int y = 0; y < Size; y++)
            {
                heights[x, y] = 0f;
        
            }

        }
        MeshData mesh = MeshGenerator.GenerateTerrainMesh(heights);
        ground = new GameObject();
        ground.transform.position = transform.position;
        ground.transform.rotation = transform.rotation;
        ground.transform.localScale = transform.localScale;
        MeshFilter filter = ground.AddComponent<MeshFilter>();
        MeshRenderer renderer = ground.AddComponent<MeshRenderer>();
        filter.sharedMesh = mesh.CreateMesh();
        ground.AddComponent<MeshCollider>();
        renderer.material = new Material(groundMaterial);
    }
    public void MakeInteresting() {
        if (ground != null)
        {
            if (Application.isEditor)
            {
                DestroyImmediate(ground);
            }
            else
            {
                Destroy(ground);
            }
        }
        float[,] heights = Noise.GenerateNoiseMap(Size, Seed, NoiseScale, Octaves, Persistance, Lacunarity, Vector2.zero);
        
        for (int x = 0; x < Size; x++)
        {
            for (int y = 0; y < Size; y++)
            {
                heights[x, y] *= HeightMultiplier;
            }

        }
        MeshData mesh = MeshGenerator.GenerateTerrainMesh(heights);
        ground = new GameObject();
        ground.transform.position = transform.position;
        ground.transform.rotation = transform.rotation;
        ground.transform.localScale = transform.localScale;
        MeshFilter filter = ground.AddComponent<MeshFilter>();
        MeshRenderer renderer = ground.AddComponent<MeshRenderer>();
        filter.sharedMesh = mesh.CreateMesh();
        ground.AddComponent<MeshCollider>();
        
        renderer.material = new Material(groundMaterial);

    }

    private void Start()
    {
        if (ground == null)
        {
            if (!makeInteresting)
            {
                MakeFlat();
            }
            else
            {
                MakeInteresting();
            }

        }
   
            kernel = computeShader.FindKernel("CalculateBladePositions");


            MeshFilter meshFilter = ground.GetComponent<MeshFilter>();
            terrainMesh = meshFilter.sharedMesh;

            // Terrain data for the compute shader.

            terrainVertices = terrainMesh.vertices;
            terrainVertexBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, terrainVertices.Length, sizeof(float) * 3);
            terrainVertexBuffer.SetData(terrainVertices);
            //We don't use this for raycast but unity bitches about not disposing buffers that don't exist.
            int[] terrainTriangles = terrainMesh.triangles;
            terrainTriangleBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, terrainTriangles.Length, sizeof(int));


            terrainTriangleBuffer.SetData(terrainTriangles);
            computeShader.SetBuffer(kernel, "_TerrainTriangles", terrainTriangleBuffer);
            terrainTriangleCount = terrainTriangles.Length / 3;

            computeShader.SetBuffer(kernel, "_TerrainPositions", terrainVertexBuffer);


            // Grass data for RenderPrimitives.
            Vector3[] grassVertices = grassMesh.vertices;
            grassVertexBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, grassVertices.Length, sizeof(float) * 3);
            grassVertexBuffer.SetData(grassVertices);

            int[] grassTriangles = grassMesh.triangles;
            grassTriangleBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, grassTriangles.Length, sizeof(int));
            grassTriangleBuffer.SetData(grassTriangles);

            Vector2[] grassUVs = grassMesh.uv;
            grassUVBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, grassUVs.Length, sizeof(float) * 2);
            grassUVBuffer.SetData(grassUVs);

            // Set up buffer for the grass blade transformation matrices.
            transformMatrixBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append, terrainTriangleCount, sizeof(float) * 16);
            computeShader.SetBuffer(kernel, "_TransformMatrices", transformMatrixBuffer);

            // Set bounds.
            MeshRenderer meshRenderer = ground.GetComponent<MeshRenderer>();

            bounds = new Bounds(Vector3.zero, meshRenderer.bounds.size * 2);
            bounds.Expand(maxBladeHeight * 3f);
            bounds.center = meshRenderer.bounds.center;



            // Bind buffers to a MaterialPropertyBlock which will get used for the draw call.
            properties = new MaterialPropertyBlock();
            properties.SetBuffer("_TransformMatrices", transformMatrixBuffer);
            properties.SetBuffer("_Positions", grassVertexBuffer);
            properties.SetBuffer("_UVs", grassUVBuffer);
            computeShader.SetFloat("_Radius", Radius);
            computeShader.SetVector("_Origin", RayTarget.position);
            lastSplat = RayTarget.position;

            RunComputeShader();
        
        
    }

    private void RunComputeShader()
    {
        // Bind variables to the compute shader.
        computeShader.SetMatrix("_TerrainObjectToWorld", transform.localToWorldMatrix);
        computeShader.SetInt("_TerrainTriangleCount", terrainTriangleCount);
        computeShader.SetFloat("_MinBladeHeight", minBladeHeight);
        computeShader.SetFloat("_MaxBladeHeight", maxBladeHeight);
        computeShader.SetFloat("_MinOffset", minOffset);
        computeShader.SetFloat("_MaxOffset", maxOffset);
        computeShader.SetFloat("_Scale", 1f);

        // Run the compute shader's kernel function.
        computeShader.GetKernelThreadGroupSizes(kernel, out threadGroupSize, out _, out _);
        int threadGroups = Mathf.CeilToInt(terrainTriangleCount / threadGroupSize);
        computeShader.Dispatch(kernel, threadGroups, 1, 1);
    }

    // Run a single draw call to render all the grass blade meshes each frame.
    private void Update()
    {
        Vector2 last = new Vector2(lastSplat.x, lastSplat.z);
        Vector2 current = new Vector2(RayTarget.position.x, RayTarget.position.z);
        if (Vector2.Distance(last, current) >= (.125 * Radius)) {
            properties.Clear();
            // Grass data for RenderPrimitives.
            Vector3[] grassVertices = grassMesh.vertices;
            grassVertexBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, grassVertices.Length, sizeof(float) * 3);
            grassVertexBuffer.SetData(grassVertices);

            int[] grassTriangles = grassMesh.triangles;
            grassTriangleBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, grassTriangles.Length, sizeof(int));
            grassTriangleBuffer.SetData(grassTriangles);

            Vector2[] grassUVs = grassMesh.uv;
            grassUVBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, grassUVs.Length, sizeof(float) * 2);
            grassUVBuffer.SetData(grassUVs);

            // Set up buffer for the grass blade transformation matrices.
            transformMatrixBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Append, terrainTriangleCount, sizeof(float) * 16);
            computeShader.SetBuffer(kernel, "_TransformMatrices", transformMatrixBuffer);
            properties.SetBuffer("_TransformMatrices", transformMatrixBuffer);
            properties.SetBuffer("_Positions", grassVertexBuffer);
            properties.SetBuffer("_UVs", grassUVBuffer);
            computeShader.SetVector("_Origin", RayTarget.position);
            lastSplat = RayTarget.position;
            RunComputeShader();
        }

        /*
        RenderParams rp = new RenderParams(material);
        rp.worldBounds = bounds;
        rp.matProps = new MaterialPropertyBlock();
        rp.matProps.SetBuffer("_TransformMatrices", transformMatrixBuffer);
        rp.matProps.SetBuffer("_Positions", grassVertexBuffer);
        rp.matProps.SetBuffer("_UVs", grassUVBuffer);
        */

        //Graphics.RenderPrimitivesIndexed(rp, MeshTopology.Triangles, grassTriangleBuffer, grassTriangleBuffer.count, instanceCount: terrainTriangleCount);
            Graphics.DrawProcedural(grassMaterial, bounds, MeshTopology.Triangles, grassTriangleBuffer, grassTriangleBuffer.count,
            instanceCount: terrainTriangleCount,
            properties: properties,
            castShadows: UnityEngine.Rendering.ShadowCastingMode.Off,
            receiveShadows: false);

    }
    private void FixedUpdate()
    {
    }
    

    private void OnDestroy()
    {
        if (terrainTriangleBuffer != null)
            terrainTriangleBuffer.Dispose();
        terrainVertexBuffer.Dispose();
        transformMatrixBuffer.Dispose();

        grassTriangleBuffer.Dispose();
        grassVertexBuffer.Dispose();
        grassUVBuffer.Dispose();
    }
    private void OnValidate()
    {
        
        if (Lacunarity < 1)
            Lacunarity = 1;
        if (Octaves < 0)
            Octaves = 0;

    }
}
