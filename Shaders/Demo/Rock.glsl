#version 330

#include "../libs/camera.glsl" 
#include "../libs/rayIntersections.glsl" 
#include "../libs/Noise.glsl"
#include "../libs/noise3D.glsl"

uniform float iGlobalTime;
uniform vec2 iResolution;
vec2 uv;

const float EPSILON = 1e-5;

struct PhysicsSphere
{
	vec3 center;
	float radius;
	vec3 velocity;
	float mass;
};

float pSphere(PhysicsSphere currSphere, Ray ray)
{
	return sphere(currSphere.center, currSphere.radius, ray, EPSILON);
}

const int STEPS = 100;
const float DELTA = 0.01;

void main()
{
	uv = gl_FragCoord.xy / iResolution;


	vec3 camP = calcCameraPos();
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);

	//Load spheres
	PhysicsSphere sphere = PhysicsSphere(vec3(0, 0, 20), 7.0, vec3(0), 1.0);



	//Calculate color of the image
	float t = pSphere(sphere, Ray(camP, camDir));
	vec3 currentCol = vec3(1, 0, 0) * t;

	vec3 rayMarchStartPoint = camP + camDir * t;
	
	if(t != -1)
	{
		vec3 pos = rayMarchStartPoint;
		float value = 0;
		float endHeight = sphere.radius;
		float delta = DELTA;

		float endHeightRatio = 2;
		float minHeight = sphere.radius * .85;
		float minToMaxHeight = sphere.radius - minHeight;

		float id = 0;

		for(int i = 0; i < STEPS; i++)
		{
			pos = pos + (camDir) * delta;

			vec3 centerToPos = normalize(pos - sphere.center);
			vec3 posOnSphereEdge = centerToPos * sphere.radius; //Position is relative. The real position in the room would be this + sphere.center;
			float heightRatio = snoise(posOnSphereEdge / 3.5 + vec3(id));
			float heightAtPos = heightRatio * minToMaxHeight + minHeight;
			float currentHeight = length(pos - sphere.center);

			if(currentHeight < heightAtPos)
			{
				endHeightRatio = heightRatio;
				break;
			}

			delta *= 1.05;
		}

		currentCol = mix(vec3(1), vec3(0), endHeightRatio);
		currentCol = mix(vec3(.25, .15, .05) / 3, vec3(.25, .15, .05) / 1.5, endHeightRatio);

		float missedHeight = step(endHeightRatio, 1);

		currentCol *= missedHeight;

		//currentCol = vec3(1 - (endHeight / sphere.radius), 0, 0);

	}
	else 
	{
		currentCol = vec3(0);
	}

	gl_FragColor = vec4(currentCol, 1);
}




