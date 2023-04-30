using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class TextureBaker : MonoBehaviour
{

    public bool GenerateBlankInputTexture;
    Texture2D inputTexture;
    public Texture2D SuppliedInputTexture;
    public string FileName;
    public Material ProcessingShader;
    RenderTexture textureBuffer;

    public string MaterialPass;
    public int ImageWidth;
    public int ImageHeight;


    const TextureFormat textureFormat = TextureFormat.ARGB32;
    const RenderTextureFormat renderTextureFormat = RenderTextureFormat.ARGB32;

    public void DrawTexture()
    {
        int materialPassIndex = MaterialPass != "" ? ProcessingShader.FindPass(MaterialPass) : 0;
        Texture2D output = new Texture2D(ImageWidth, ImageHeight, textureFormat, false);
        Graphics.Blit(inputTexture, textureBuffer, ProcessingShader, materialPassIndex);
        string destinationFilePath = string.Format($"{Application.dataPath}/{FileName}");
        RenderTexture.active = textureBuffer;
        output.ReadPixels(new Rect(0, 0, ImageWidth, ImageHeight), 0, 0, false);
        System.IO.File.WriteAllBytes(destinationFilePath, output.EncodeToPNG());
        AssetDatabase.Refresh();
    }
    private void OnValidate()
    {
        if (ImageWidth < 1)
            ImageWidth = 1;
        if (ImageHeight < 1)
            ImageHeight = 1;
        if (MaterialPass == null)
            MaterialPass = "";
        if (SuppliedInputTexture == null || GenerateBlankInputTexture)
        {
            if (inputTexture == null || inputTexture.width != ImageWidth || inputTexture.height != ImageHeight) {
                Color[] whiteField = new Color[ImageHeight * ImageWidth];
                for (int i = 0; i < ImageHeight * ImageWidth; i++)
                {
                    whiteField[i] = Color.white;
                }
                inputTexture = new Texture2D(ImageWidth, ImageHeight, textureFormat, false);
                inputTexture.SetPixels(whiteField);
                inputTexture.Apply();
            }
        }
        if (textureBuffer == null || textureBuffer.width != ImageWidth || textureBuffer.height != ImageHeight)
        {
            textureBuffer = new RenderTexture(ImageWidth, ImageHeight, 0, renderTextureFormat, RenderTextureReadWrite.Linear);
        }
        

    }

}
