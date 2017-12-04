#version 330

#include "libs/camera.glsl"


uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

struct LightSource 
{
	vec3 position;
	vec3 color;
};



float distanceToSphere(vec3 vecToCenter, float radius)
{
	return length(vecToCenter) - radius;
}


vec3 GetColorOfSphere(struct LightSource source, vec3 ambientLight, vec3 hitPoint, vec3 normal, vec3 camDir, vec3 color, float shininess)
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

vec3 getNormal(vec3 hitPoint, vec3 sphereOrigin1, vec3 sphereOrigin2, float sphereRadius1, float sphereRadius2)
{
	float vecToCenter1 = distanceToSphere(sphereOrigin1 - hitPoint, sphereRadius1);
	float vecToCenter2 = distanceToSphere(sphereOrigin2 - hitPoint, sphereRadius2);
			
	return normalize(hitPoint - (length(vecToCenter1) < length(vecToCenter2) ? sphereOrigin1 : sphereOrigin2));
}



vec3 drawScene(vec3 camPos, vec3 camDir)
{
	struct LightSource light;
	light.position = vec3(0, 10, 1);
	light.color = vec3(1, 1, 1);

	const float EPSILON = 1e-5;
	const int Steps = 128;
	const float maxDist = 40;

	vec3 color = vec3(0);
	vec3 sphereOrigin1 = vec3(0, 2, 5);
	vec3 sphereOrigin2 = vec3(2, 2, 5);
	float sphereRadius1 = 2f;
	float sphereRadius2 = 2f;
	
	vec3 rayPos = camPos;
	float dist = 0;
	for(int t = 0; t < Steps; t++)
	{
		float distanceToObj = min(distanceToSphere(sphereOrigin1 - rayPos, sphereRadius1), distanceToSphere(sphereOrigin2 - rayPos, sphereRadius2));
		if(distanceToObj < EPSILON)
		{
			rayPos += distanceToObj * camDir;
			
			float vecToCenter1 = distanceToSphere(sphereOrigin1 - rayPos, sphereRadius1);
			float vecToCenter2 = distanceToSphere(sphereOrigin2 - rayPos, sphereRadius2);
			
			vec3 normal = getNormal(rayPos, sphereOrigin1, sphereOrigin2, sphereRadius1, sphereRadius2);
			vec3 matColor = length(vecToCenter1) < length(vecToCenter2) ? vec3(1, 0, 0) : vec3(1, 1, 1);

			color.rgb = GetColorOfSphere(light, vec3(.1f), rayPos, normal, camDir, matColor, 16);
			break;
		}
		if(dist > maxDist) 
			break;

		rayPos += distanceToObj * camDir;
		dist += distanceToObj;
	}

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