using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(TextureBaker))]
public class TextureBakerEditor : Editor 
{
    public override void OnInspectorGUI()
    {
        TextureBaker baker = (TextureBaker)target;
        if (DrawDefaultInspector()) { 
            
        }
        if (GUILayout.Button("Draw Texture"))
        {
            baker.DrawTexture();
        }
    }
}
