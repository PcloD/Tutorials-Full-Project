Shader "Custom/DiffuseTut"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
        _BrightColor("Light Color", Color) = (1, 1, 1, 1)
        _DarkColor("Dark Color", Color) = (1, 1, 1, 1)
        _K("Shadow Intensity", float) = 1.0
        _P("Shadow Falloff",  float) = 1.0
	}

	SubShader
	{
		// Regular color & lighting pass
		Pass
		{
            Tags
			{ 
				"LightMode" = "ForwardBase" // allows shadow rec/cast, lighting
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase // shadows
			#include "AutoLight.cginc"
			#include "UnityCG.cginc"
			
			// Properties
			sampler2D _MainTex;
            sampler2D _SpecRamp;
            float4 _Color;
			float4 _LightColor0; // provided by Unity
            float4 _BrightColor;
            float4 _DarkColor;
            float _K;
            float _P;

			struct vertexInput
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
			};

			struct vertexOutput
			{
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 texCoord : TEXCOORD0;
                float3 viewDir: TEXCOORD1;
				LIGHTING_COORDS(2,3) // shadows
			};

			vertexOutput vert(vertexInput input)
			{
				vertexOutput output;

				output.pos = UnityObjectToClipPos(input.vertex);
				float4 normal4 = float4(input.normal, 0.0);
				output.normal = normalize(mul(normal4, unity_WorldToObject).xyz);
                output.viewDir = normalize(_WorldSpaceCameraPos - mul(unity_ObjectToWorld, input.vertex).xyz);

				output.texCoord = input.texCoord;

				TRANSFER_SHADOW(output); // shadows
				return output;
			}

			float4 frag(vertexOutput input) : COLOR
			{
				// _WorldSpaceLightPos0 provided by Unity
				float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

				// get dot product between surface normal and light direction
				float lightDot = clamp(dot(input.normal, lightDir), -1, 1);
                // do some math to make lighting falloff smooth
                lightDot = exp(-pow(_K*(1 - lightDot), _P));

                // lerp lighting between light & dark value
                float3 light = lerp(_DarkColor, _BrightColor, lightDot);

				// sample texture for color
				float4 albedo = tex2D(_MainTex, input.texCoord.xy);

                // shadow value
                float attenuation = LIGHT_ATTENUATION(input); 

				// ambient light
				//albedo += ShadeSH9(half4(input.normal, 1));
                
                // multiply albedo and lighting
				float3 rgb = albedo.rgb * light * attenuation;
				return float4(rgb, 1.0);
			}

			ENDCG
		}

		// Shadow pass
		Pass
    	{
            Tags 
			{
				"LightMode" = "ShadowCaster"
			}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f { 
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
    	}
	}
    Fallback "Diffuse"
}