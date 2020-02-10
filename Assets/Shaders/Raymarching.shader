Shader "Unlit/Raymarching"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag


			#include "UnityCG.cginc"

#define MAX_STEPS 100
#define MAX_DISTANCE 100
#define SURFACE_DISTANCE 1e-3


			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float3 rayOrigin : TEXCOORD1;
				float3 hitPosition : TEXCOORD2;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);

				o.rayOrigin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
				o.hitPosition = v.vertex;

				o.rayOrigin = _WorldSpaceCameraPos;
				o.hitPosition = mul(unity_ObjectToWorld, v.vertex);

				return o;
			}

			float Sphere(float3 position)
			{
				float3 distance = length(position) - 0.2;
				return distance;
			}

			float Torus(float3 position)
			{
				float3 distance = length(float2(length(position.xz) - .4, position.y)) - 0.1;
				return distance;
			}

			float Mandelbulb(float3 position)
			{
				int iterations = 5;
				float bailout = 1.15;
				float power = 5;

				float3 distance;

				float3 z = position;
				float dr = 1.0;
				float r = 0.0;

				for (int i = 0; i < iterations; i++)
				{
					r = length(z);
					if (r > bailout) break;

					// convert to polar coordinates
					float theta = acos(z.z / r);
					float phi = atan2(z.y, z.x);
					dr = pow(r, power - 1.0)*power*dr + 1.0;

					// scale and rotate the point
					float zr = pow(r, power);
					theta = theta * power;
					phi = phi * power;

					// convert back to cartesian coordinates
					z = zr * float3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
					z += position;
				}
				distance = 0.5*log(r)*r / dr;

				return distance;
			}

			float2 DE(float3 pos) {
				float Power = 3.0 + 4.0*(sin(_Time / 10.0) + 1.0);
				float3 z = pos;
				float dr = 1.0;
				float r = 0.0;
				int steps = 64;
				float dist = 1.5;
				int iterations = 64;

				for (int i = 0; i < steps; i++) {
					r = length(z);
					if (r > dist) break;

					// convert to polar coordinates
					float theta = acos(z.z / r);
					float phi = atan2(z.y, z.x);
					dr = pow(r, Power - 1.0)*Power*dr + 1.0;

					// scale and rotate the point
					float zr = pow(r, Power);
					theta = theta * Power;
					phi = phi * Power;

					// convert back to cartesian coordinates
					z = zr * float3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
					z += pos;
				}
				return float2(0.5*log(r)*r / dr, 50.0*pow(dr, 0.128 / float(iterations)));
			}

			float GetDistance(float3 position)
			{
				float3 distance = DE(position).x;
				//float3 distance = Sphere(position);
				return distance;
			}

			float Raymarch(float3 rayOrigin, float3 rayDirection)
			{
				float distanceFromOrigin = 0;
				float distanceFromSurface;
				for (int i = 0; i < MAX_STEPS; i++)
				{
					float3 position = rayOrigin + distanceFromOrigin * rayDirection;
					distanceFromSurface = GetDistance(position);
					distanceFromOrigin += distanceFromSurface;
					if (distanceFromSurface < SURFACE_DISTANCE || distanceFromOrigin > MAX_DISTANCE) break;
				}

				return distanceFromOrigin;
			}

			float3 GetNormal(float3 pointOnSurface)
			{
				float2 epsilon = float2(1e-2, 0);

				float3 normal = GetDistance(pointOnSurface) - float3(
					GetDistance(pointOnSurface - epsilon.xyy),
					GetDistance(pointOnSurface - epsilon.yxy),
					GetDistance(pointOnSurface - epsilon.yyx)
					);
				return normalize(normal);
			}

			float GetLight(float3 p)
			{
				float SURF_DIST = 2;

				float3 lightPos = float3(0, 5, 6);
				lightPos.x += _SinTime * 5;
				lightPos.z += _CosTime * 10.0;
				float3 l = mul(unity_WorldToObject, normalize(lightPos - p));
				float3 n = GetNormal(p);

				float dif = clamp(dot(n, l), 0., 1.);
				float d = Raymarch(p + n * SURF_DIST*2., l);
				if (d < length(lightPos - p)) dif *= .1;

				return dif;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float2 uv = i.uv - 0.5;
				float3 rayOrigin = i.rayOrigin;
				float3 rayDirection = normalize(i.hitPosition - i.rayOrigin); //normalize(float3(uv.x, uv.y, 1));

				float distance = Raymarch(rayOrigin, rayDirection);

				fixed4 col = 0;

				if (distance < MAX_DISTANCE)
				{
					float3 pointOnSurface = rayOrigin + rayDirection * distance;
					float3 normal = GetNormal(pointOnSurface);
					col = GetLight(pointOnSurface);
				}
				else
					discard;

				return col;
			}
			ENDCG
		}
	}
}
