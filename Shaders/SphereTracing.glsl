#version 330

#include "libs/camera.glsl"

struct LightSource 
{
	vec3 position;
	vec3 color;
};


uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]



float distanceToSphere(vec3 vecToCenter, float radius)
{
	return length(vecToCenter) - radius;
}

float distanceToBox(vec3 vecToCenter, vec3 box)
{
	return length(max(abs(vecToCenter) - box, 0.0));
}


vec3 GetColor(LightSource source, vec3 ambientLight, vec3 hitPoint, vec3 normal, vec3 camDir, vec3 color, float shininess)
{
	vec3 lightDirection = normalize(source.position - hitPoint);
	vec3 reflectDirection = normalize(reflect(lightDirection, normal));

	float lightHitsForeground = step(0, dot(normal, lightDirection));
	float specularReflectionIsAbove90Deg = step(0, dot(reflectDirection, camDir));

	//Ambient
	vec3 sphereAmbientColor = color * ambientLight;

	//Diffuse
	vec3 sphereDiffuseColor = color * source.color * dot(normal, lightDirection) * lightHitsForeground;

	//Specular
	float specularAngle = dot(reflectDirection, camDir) * specularReflectionIsAbove90Deg * lightHitsForeground;
	vec3 sphereSpecularColor = source.color * pow(specularAngle, shininess);

	return sphereAmbientColor + sphereDiffuseColor + sphereSpecularColor;
}

vec3 getNormalOfSphere(vec3 hitPoint, vec3 sphereOrigin, float sphereRadius, float delta)
{
	vec2 deltaVec = vec2(delta, 0);

	vec3 vecToCenter = hitPoint - sphereOrigin;

	float nextX = distanceToSphere(vecToCenter + deltaVec.xyy, sphereRadius);
	float nextY = distanceToSphere(vecToCenter + deltaVec.yxy, sphereRadius);
	float nextZ = distanceToSphere(vecToCenter + deltaVec.yyx, sphereRadius);

	float previousX = distanceToSphere(vecToCenter - deltaVec.xyy, sphereRadius);
	float previousY = distanceToSphere(vecToCenter - deltaVec.yxy, sphereRadius);
	float previousZ = distanceToSphere(vecToCenter - deltaVec.yyx, sphereRadius);

	vec3 unnormalizedGradient = vec3(nextX - previousX, nextY - previousY, nextZ - previousZ);

	return normalize(unnormalizedGradient);
}

float opUnify(float a, float b)
{
	return min(a, b);
}

float opCutOut(float cut, float stay)
{
	return max(-cut, stay);
}



vec3 drawScene(vec3 camPos, vec3 camDir)
{
	LightSource light;
	light.position = vec3(0, 10, 1);
	light.color = vec3(1, 1, 1);

	const float EPSILON = 1e-5;
	const int Steps = 128;
	const float maxDist = 100;

	vec3 color = vec3(0);
	vec3 sphereOrigin1 = vec3(0, 2, 5);
	vec3 sphereOrigin2 = vec3(2, 2, 5);
	float sphereRadius1 = 2;
	float sphereRadius2 = 2;
	
	vec3 rayPos = camPos;
	float dist = 0;
	for(int t = 0; t < Steps; t++)
	{
		float sphere1 = distanceToSphere(sphereOrigin1 - rayPos, sphereRadius1);
		float sphere2 = distanceToSphere(sphereOrigin2 - rayPos, sphereRadius2);
		float box1 = distanceToBox(vec3(1, 6, 5) - rayPos, vec3(1, 1, 1));
		float distanceToObj = opUnify(box1, opUnify(sphere1, sphere2));
		if(distanceToObj < EPSILON)
		{
			rayPos += distanceToObj * camDir;
			
			float vecToCenter1 = distanceToSphere(sphereOrigin1 - rayPos, sphereRadius1);
			float vecToCenter2 = distanceToSphere(sphereOrigin2 - rayPos, sphereRadius2);
			
			vec3 normal = length(vecToCenter1) < length(vecToCenter2) ? getNormalOfSphere(rayPos, sphereOrigin1, sphereRadius1, 0.01) : getNormalOfSphere(rayPos, sphereOrigin2, sphereRadius2, 0.01);
			vec3 matColor = length(vecToCenter1) < length(vecToCenter2) ? vec3(1, 0, 0) : vec3(1, 1, 1);

			color.rgb = GetColor(light, vec3(.1f), rayPos, normal, camDir, matColor, 16);
			break;
		}
		if(dist > maxDist) 
			break;

		rayPos += distanceToObj * camDir;
		dist += distanceToObj;
	}
	
	color.rgb += mix(color.rgb, vec3(1, 1, 0), dist / maxDist);

	return color;
}


void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(uv, 0, 1);
	
	vec3 camP = calcCameraPos();
	camP.y += 2;
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);
	

	color.rgb = drawScene(camP, camDir);



	gl_FragColor = color;
}