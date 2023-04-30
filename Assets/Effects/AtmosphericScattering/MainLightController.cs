using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class MainLightController : MonoBehaviour
{
       

    // Update is called once per frame
    void Update()
    {
        Light myLight = GetComponent<Light>();
        Shader.SetGlobalVector("_SceneLightColor", myLight.color);
        Shader.SetGlobalVector("_SceneLightDirection", transform.forward);
        
    }
}
