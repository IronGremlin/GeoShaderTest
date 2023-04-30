Shader "Hidden/VolumetricLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Scattering("Scattering",Float) = -0.2
        _Steps("Ray Steps", Integer) = 36
        _MaxDistance("Max Ray Distance", Float) = 72
        _RayJitter("Ray Jitter", Float) = 12
        _RayBrightness("Ray Brightness", Float) = 1
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
                HLSLPROGRAM

            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            //#pragma multi_compile _ _SHADOWS_HARD

            #pragma multi_compile _  _MAIN_LIGHT_SHADOWS_CASCADE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            //Boilerplate code, we aren't doind anything with our vertices or any other input info,
            // because technically we are working on a quad taking up the butt screen
            struct appdata
            {
                real4 vertex : POSITION;
                real2 uv : TEXCOORD0;
            };

            struct v2f
            {
                real2 uv : TEXCOORD0;
                real4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformWorldToHClip(float3(v.vertex.xyz));
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            float3 _SceneLightDirection;
            float4 _SceneLightColor;
            float _Scattering;
            float _Steps;
            float _MaxDistance;
            float _RayJitter;
     
            //We will set up these uniforms from the ScriptableRendererFeature in the future
            
            #define FourPi 12.566370614359172

            //This function will tell us if a certain point in world space coordinates is in light or shadow of the main light
            float ShadowAtten(real3 worldPosition)
            {
                return MainLightRealtimeShadow(float4(TransformWorldToShadowCoord(worldPosition).xyz,1));
            }

            //Unity already has a function that can reconstruct world space position from depth
            float3 GetWorldPos(float2 uv){
                #if UNITY_REVERSED_Z
                    float depth = SampleSceneDepth(uv);
                #else
                    // Adjust z to match NDC for OpenGL
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
                #endif
                return ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
            }

            // Mie scaterring approximated with Henyey-Greenstein phase function.
            float ComputeScattering(float lightDotView)
            {
                
                float result = 1.0f - _Scattering * _Scattering;
                result /= (FourPi * pow(1.0f + _Scattering * _Scattering - (2.0f * _Scattering) * lightDotView, 1.5f));
                return result;
            }

            //standart hash
            real random( real2 p ){
                return frac(sin(dot(p, real2(41, 289)))*45758.5453 )-0.5; 
            }
            real random01( real2 p ){
                return frac(sin(dot(p, real2(41, 289)))*45758.5453 ); 
            }
            
            //from Ronja https://www.ronja-tutorials.com/post/047-invlerp_remap/
            float invLerp(float from, float to, float value){
                return (value - from) / (to - from);
            }
            float remap(float origFrom, float origTo, float targetFrom, float targetTo, float value){
                float rel = invLerp(origFrom, origTo, value);
                return lerp(targetFrom, targetTo, rel);
            }

            //this implementation is loosely based on http://www.alexandre-pestana.com/volumetric-lights/ 
            //and https://fr.slideshare.net/BenjaminGlatzel/volumetric-lighting-for-many-lights-in-lords-of-the-fallen

            // #define MIN_STEPS 25

            float4 frag (v2f i) : SV_Target
            {
                //Shader seems to get mad if we don't set this prior to the loop.
                 int iterations = _Steps -1;

                float4 col = tex2D(_MainTex, i.uv);
                
                
                //first we get the world space position of every pixel on screen
                float3 worldPos = GetWorldPos(i.uv);             
                //return col + (frac(MainLightRealtimeShadow(TransformWorldToShadowCoord(worldPos))));
                float shadowMapValue = saturate(ShadowAtten(worldPos));
                
               
                //we find out our ray info, that depends on the distance to the camera
                float3 startPosition = _WorldSpaceCameraPos;
                float3 rayVector = worldPos- startPosition;
                float3 rayDirection =  normalize(rayVector);
                float rayLength = length(rayVector);


                if(rayLength>_MaxDistance){
                    rayLength=_MaxDistance;
                
                    worldPos= startPosition+rayDirection*rayLength;
                }
               
                
                

                //We can limit the amount of steps for close objects
                // steps= remap(0,_MaxDistance,MIN_STEPS,_Steps,rayLength);  
                //or
                // steps= remap(0,_MaxDistance,0,_Steps,rayLength);   
                // steps = max(steps,MIN_STEPS);
                

                float stepLength = rayLength / _Steps;
                float rayStartOffset = random( i.uv) * (_RayJitter * 0.001);
                float3 step = rayDirection *  (stepLength + rayStartOffset);
                float3 currentPosition = startPosition;
                float accumFog = 0;
                
                
                 //we ask for the shadow map value at different depths, if the sample is in light we compute the contribution at that point and add it
                for (int j = 0; j < iterations; j++)
                {
                    float shadowMapValue = saturate(ShadowAtten(currentPosition));
                    
                    //if it is in light
                    if (shadowMapValue > 0.0000000000001) {
                        float kernelColor = ComputeScattering(dot(rayDirection, _SceneLightDirection)).xxx ;
                        saturate(kernelColor);
                        
                        accumFog += kernelColor; 
                    }
                        
                     
                    currentPosition += step;
                }
                //we need the average value, so we divide between the amount of samples 
                accumFog /= _Steps;
                
                
                
                return _SceneLightColor * accumFog;
            }
            ENDHLSL
        }
          Pass
        {
            Name "PassThrough"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            sampler2D _MainTex;
            sampler2D _VolumetricTexture;
            sampler2D _LowResDepth;
            float4 _SceneLightColor;
            struct appdata
            {
                real4 vertex : POSITION;
                real2 uv : TEXCOORD0;
            };

            struct v2f
            {
                real2 uv : TEXCOORD0;
                real4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformWorldToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 cola = tex2D(_MainTex, i.uv);
                float4 colb = tex2D(_VolumetricTexture, i.uv);
                float4 colc = tex2D(_LowResDepth, i.uv);
                return colb.x * _SceneLightColor + cola;
                
            }
            ENDHLSL
        }
                Pass
        {
            Name "Gaussian Blur"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local __ _COLORED_ON
            #pragma multi_Compile_local _ _Vertical
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"


            struct appdata {
                real4 vertex : POSITION;
                real2 uv : TEXCOORD0;
            };

            struct v2f {
                real2 uv : TEXCOORD0;
                real4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformWorldToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            // sampler2D _MainTex;
            int _GaussSamples;
            real _GaussAmount;
            static const real gauss_filter_weights[] = {0.14446445, 0.13543542, 0.11153505, 0.08055309, 0.05087564, 0.02798160, 0.01332457, 0.00545096, 0, 0, 0, 0, 0, 0, 0, 0, 0};


            #define BLUR_DEPTH_FALLOFF 100.0


            #define BILATERAL_BLUR


            #ifdef _COLORED_ON
                #define REAL real3
            #else
                #define REAL real
            #endif


            REAL frag(v2f i) : SV_Target
            {
                REAL col = 0;
                REAL accumResult = 0;
                real accumWeights = 0;

              
                const int2 _Axis = int2(1, 0);
            
                #if UNITY_REVERSED_Z
                real depthCenter = SampleSceneDepth(i.uv);
                #else
                   real depthCenter = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
                #endif
                
                const int number = 5;
                UNITY_FLATTEN
                for (real index = -number; index <= number; index++)
                {
                    //we offset our uvs by a tiny amount 
                    // real2 uv = i.uv + _Axis * (index * _GaussAmount / 1000.);

                    //sample the color at that location
                    // REAL kernelSample = tex2Dlod(_MainTex, uv,);

                    REAL kernelSample = _MainTex.SampleLevel(sampler_MainTex, i.uv, 0, _Axis * index);
                    //depth at the sampled pixel
                    #ifdef BILATERAL_BLUR
                        real depthKernel;
                        #if UNITY_REVERSED_Z
                          depthKernel =_CameraDepthTexture.SampleLevel(sampler_MainTex, i.uv, 0, _Axis * index);
                        #else
                            depthKernel = lerp(UNITY_NEAR_CLIP_VALUE, 1, _CameraDepthTexture.SampleLevel(sampler_MainTex, i.uv, 0, _Axis * index));
                        #endif
                        //weight calculation depending on distance and depth difference
                        real depthDiff = abs(depthKernel - depthCenter);
                        real r2 = depthDiff * BLUR_DEPTH_FALLOFF;
                        real g = exp(-r2 * r2);
                        real weight = g * gauss_filter_weights[abs(index)];
                        //sum for every iteration of the color and weight of this sample 
                        accumResult += weight * kernelSample;
                       
                    #else

                    // real weight = gauss_filter_weights[abs(index)];
                    real weight = 1;
                    accumResult += kernelSample * weight;

                    #endif

                    accumWeights += weight;
                }
                //final color
                col = accumResult / accumWeights;

                return col;
            }
            ENDHLSL
        }

  Pass
        {
            Name "Gaussian Blur 2"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local __ _COLORED_ON
            #pragma multi_Compile_local _ _Vertical
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"


            struct appdata {
                real4 vertex : POSITION;
                real2 uv : TEXCOORD0;
            };

            struct v2f {
                real2 uv : TEXCOORD0;
                real4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformWorldToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            // sampler2D _MainTex;
            int _GaussSamples;
            real _GaussAmount;
            static const real gauss_filter_weights[] = {0.14446445, 0.13543542, 0.11153505, 0.08055309, 0.05087564, 0.02798160, 0.01332457, 0.00545096, 0, 0, 0, 0, 0, 0, 0, 0, 0};


            #define BLUR_DEPTH_FALLOFF 100.0


            #define BILATERAL_BLUR


            #ifdef _COLORED_ON
                #define REAL real3
            #else
                #define REAL real
            #endif


            REAL frag(v2f i) : SV_Target
            {
                REAL col = 0;
                REAL accumResult = 0;
                real accumWeights = 0;

             
                  const int2 _Axis = int2(0,1);
             

                #if UNITY_REVERSED_Z
                real depthCenter = SampleSceneDepth(i.uv);
                #else
                   real depthCenter = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
                #endif
                
                const int number = 5;
                UNITY_FLATTEN
                for (real index = -number; index <= number; index++)
                {
                    //we offset our uvs by a tiny amount 
                    // real2 uv = i.uv + _Axis * (index * _GaussAmount / 1000.);

                    //sample the color at that location
                    // REAL kernelSample = tex2Dlod(_MainTex, uv,);

                    REAL kernelSample = _MainTex.SampleLevel(sampler_MainTex, i.uv, 0, _Axis * index);
                    //depth at the sampled pixel
                    #ifdef BILATERAL_BLUR
                        real depthKernel;
                        #if UNITY_REVERSED_Z
                          depthKernel =_CameraDepthTexture.SampleLevel(sampler_MainTex, i.uv, 0, _Axis * index);
                        #else
                            depthKernel = lerp(UNITY_NEAR_CLIP_VALUE, 1, _CameraDepthTexture.SampleLevel(sampler_MainTex, i.uv, 0, _Axis * index));
                        #endif
                        //weight calculation depending on distance and depth difference
                        real depthDiff = abs(depthKernel - depthCenter);
                        real r2 = depthDiff * BLUR_DEPTH_FALLOFF;
                        real g = exp(-r2 * r2);
                        real weight = g * gauss_filter_weights[abs(index)];
                        //sum for every iteration of the color and weight of this sample 
                        accumResult += weight * kernelSample;
                       
                    #else

                    real weight = gauss_filter_weights[abs(index)];
                    // real weight = 1;
                    accumResult += kernelSample * weight;

                    #endif

                    accumWeights += weight;
                }
                //final color
                col = accumResult / accumWeights;

                return col;
            }
            ENDHLSL
        }


        Pass
        {
            Name "Compositing"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local __ _COLORED_ON
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct appdata {
                real4 vertex : POSITION;
                real2 uv : TEXCOORD0;
            };

            struct v2f {
                real2 uv : TEXCOORD0;
                real4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformWorldToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }
            float4 _SceneLightColor;
            sampler2D _MainTex;
            TEXTURE2D(_VolumetricTexture);
            SAMPLER(sampler_VolumetricTexture);
            TEXTURE2D(_LowResDepth);
            SAMPLER(sampler_LowResDepth);
            
            float _RayBrightness;
            real _Downsample;



            #ifdef _COLORED_ON
                #define REAL real3
            #else
                #define REAL real
            #endif

            float3 frag(v2f i) : SV_Target
            {
             
                REAL col = 1;
                //based on https://eleni.mutantstargoat.com/hikiko/on-depth-aware-upsampling/ 
  
                int offset = 0;
                real d0 = SampleSceneDepth(i.uv);

                /* calculating the distances between the depths of the pixels
                * in the lowres neighborhood and the full res depth value
                * (texture offset must be compile time constant and so we
                * can't use a loop)
                */
                real d1 = _LowResDepth.Sample(sampler_LowResDepth, i.uv, int2(0, 1)).x;
                real d2 = _LowResDepth.Sample(sampler_LowResDepth, i.uv, int2(0, -1)).x;
                real d3 = _LowResDepth.Sample(sampler_LowResDepth, i.uv, int2(1, 0)).x;
                real d4 = _LowResDepth.Sample(sampler_LowResDepth, i.uv, int2(-1, 0)).x;
                //return tex2D(_LowResDepth, i.uv);

                d1 = abs(d0 - d1);
                d2 = abs(d0 - d2);
                d3 = abs(d0 - d3);
                d4 = abs(d0 - d4);

                real dmin =min(min(d1, d2), min(d3, d4));

                if (dmin == d1)
                    offset = 0;

                else if (dmin == d2)
                    offset = 1;

                else if (dmin == d3)
                    offset = 2;

                else if (dmin == d4)
                    offset = 3;

                switch (offset)
                {
                    case 0:
                        col = _VolumetricTexture.Sample(sampler_VolumetricTexture, i.uv, int2(0, 1));
                        break;
                    case 1:
                        col = _VolumetricTexture.Sample(sampler_VolumetricTexture, i.uv, int2(0, -1));
                        break;
                    case 2:
                        col = _VolumetricTexture.Sample(sampler_VolumetricTexture, i.uv, int2(1, 0));
                        break;
                    case 3:
                        col = _VolumetricTexture.Sample(sampler_VolumetricTexture, i.uv, int2(-1, 0));
                        break;
                    default: 
                        col =_VolumetricTexture.Sample(sampler_VolumetricTexture, i.uv);
                        break;
                }

                 // col = _volumetricTexture.Sample(sampler_volumetricTexture, i.uv);
          
                real3 finalShaft = col  * _SceneLightColor * _RayBrightness; //_Intensity*_SunMoonColor;
  
                real3 screen = tex2D(_MainTex, i.uv);
                return screen+ finalShaft;
            }
            ENDHLSL
        }
        Pass
        {
            Name "SampleDepth"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct appdata {
                real4 vertex : POSITION;
                real2 uv : TEXCOORD0;
            };

            struct v2f {
                real2 uv : TEXCOORD0;
                real4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = TransformWorldToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }


            real frag(v2f i) : SV_Target
            {
                #if UNITY_REVERSED_Z
                real depth = SampleSceneDepth(i.uv);
                #else
                    // Adjust z to match NDC for OpenGL
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(i.uv));
                #endif
                return depth;
            }
            ENDHLSL
        }
    }
}
