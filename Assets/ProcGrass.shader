Shader "Unlit/ProcGrass"
{
    Properties
	{
		_BaseColor("Base Color", Color) = (0, 0, 0, 1)
		_TipColor("Tip Color", Color) = (1, 1, 1, 1)
		_BaseTex("Base Texture", 2D) = "white" {}
	}
    SubShader
    {
        Tags { 
			"RenderType"="Opaque"
			"Queue"="Geometry" 
		}
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
			{
				uint vertexID : SV_VertexID;
				uint instanceID : SV_InstanceID;
			};

			struct v2f
			{
				float4 positionCS : SV_Position;
				float4 positionWS : TEXCOORD0;
				float2 uv : TEXCOORD1;
			};

			StructuredBuffer<float3> _Positions;
			StructuredBuffer<float3> _Normals;
			StructuredBuffer<float2> _UVs;
			StructuredBuffer<float4x4> _TransformMatrices;

			CBUFFER_START(UnityPerMaterial)
				float4 _BaseColor;
				float4 _TipColor;
				sampler2D _BaseTex;
				float4 _BaseTex_ST;

				float _Cutoff;
			CBUFFER_END


            v2f vert (appdata v)
            {
				v2f o;

				float4 positionOS = float4(_Positions[v.vertexID], 1.0f);
				float4x4 objectToWorld = _TransformMatrices[v.instanceID];

				o.positionWS = mul(objectToWorld, positionOS);
				o.positionCS = mul(UNITY_MATRIX_VP, o.positionWS);
				o.uv = _UVs[v.vertexID];

				return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 color = tex2D(_BaseTex, i.uv);


				//VertexPositionInputs vertexInput = (VertexPositionInputs)0;
				//vertexInput.positionWS = i.positionWS;

				return color * lerp(_BaseColor, _TipColor, i.uv.y);
            }
            ENDCG
        }
    }
}
