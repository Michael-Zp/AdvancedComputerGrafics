#version 330

#include "../libs/camera.glsl"
#include "../libs/Noise.glsl"


uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

struct LightSource 
{
	vec3 position;
	vec3 color;
};


float sdSphere(vec3 rayPosition, float radius)
{
	return length(rayPosition) - radius;
}

float sdBox(vec3 rayPosition, vec3 box)
{
	return length(max(abs(rayPosition) - box, 0.0));
}

float sdTorus( vec3 rayPosition, vec2 thickness )
{
	vec2 q = vec2(length(rayPosition.xz)-thickness.x,rayPosition.y);
	return length(q)-thickness.y;
}


vec3 GetColor(struct LightSource source, vec3 ambientLight, vec3 hitPoint, vec3 normal, vec3 camDir, vec3 color, float shininess)
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

float map(vec3 pos);

vec3 getNormal(vec3 hitPoint, float delta)
{
	vec2 deltaVec = vec2(delta, 0);

	float nextX = map(hitPoint + deltaVec.xyy);
	float nextY = map(hitPoint + deltaVec.yxy);
	float nextZ = map(hitPoint + deltaVec.yyx);

	float previousX = map(hitPoint - deltaVec.xyy);
	float previousY = map(hitPoint - deltaVec.yxy);
	float previousZ = map(hitPoint - deltaVec.yyx);

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

float opIntersect(float a, float b)
{
	return max(a, b);
}

vec3 randomDirection(float seed)
{
	return normalize( vec3( rand2( vec2(seed, seed * 2) ) , (rand(seed * 3) - .5) * 2 ) );
}

float mapPlanet(vec3 position) 
{
	return sdSphere(position, 1.5f);
}

float mapParticles(vec3 position)
{
	float dist = 100000;

	for(int i = 0; i < 150; i++) 
	{
		vec3 offset = randomDirection(i);
		dist = opUnify(dist, sdSphere(position - offset * fract(iGlobalTime / 4 + rand(i) + 1.5) * mod(i, 7), .04));
	}

	float visiblePart = opCutOut(sdSphere(position, 1.5), sdSphere(position, 3));

	return opIntersect(visiblePart, dist);
}

float map(vec3 position) 
{
	return opUnify(mapPlanet(position), mapParticles(position));
}


vec4 drawScene(vec3 camPos, vec3 camDir)
{
	struct LightSource light;
	light.position = vec3(0, 10, 1);
	light.color = vec3(1, 1, 1);

	const float EPSILON = 1e-5;
	const int Steps = 64;
	const float maxDist = 100;

	vec4 color = vec4(0);
	
	vec3 rayPos = camPos;
	float dist = 0;
	for(int t = 0; t < Steps; t++)
	{
		float distancePlanet = mapPlanet(rayPos);
		float distanceParticles = mapParticles(rayPos);

		float distanceToObj = opUnify(distancePlanet, distanceParticles);

		if(distanceToObj < EPSILON)
		{
			rayPos += distanceToObj * camDir;
			
			vec3 normal = getNormal(rayPos, .1);

			float hitParticle = step(distanceParticles, distancePlanet);

			color.rgb = hitParticle > 0.5 ? vec3(1) : GetColor(light, vec3(.1f), rayPos, normal, camDir, vec3(1), 16);
			
			color.a = hitParticle * (3.25 - distance(rayPos, vec3(0))) + (1 - hitParticle);

			//Fake ass alpha blending
			color.rgb = mix(vec3(0), color.rgb, color.a);

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
	camP += vec3(0, 0, -4);
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);
	

	color = drawScene(camP, camDir);
	
	gl_FragColor = color;
}