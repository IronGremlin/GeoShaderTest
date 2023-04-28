using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(TerrainGen))]
public class TerrainGenEditor : Editor
{
    public override void OnInspectorGUI()
    {
        //base.OnInspectorGUI();
        TerrainGen terrainGen = (TerrainGen)target;
        if (DrawDefaultInspector())
        {
            //if (mapGen.autoUpdate)
            //    mapGen.GenerateMap();
        }
        if (GUILayout.Button("Make Flat"))
        {
            terrainGen.MakeFlat();
        }
        if (GUILayout.Button("Make Interesting")) {
            terrainGen.MakeInteresting();
        }
    }
}
