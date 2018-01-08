#version 330

#include "../../libs/camera.glsl"
#include "../../libs/Noise.glsl"

struct LightSource 
{
	vec3 position;
	vec3 color;
};

struct RayHit
{
	float type;
	float dist;
};


uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]



float sdSphere(vec3 rayPos, float radius)
{
	return length(rayPos) - radius;
}

float sdBox(vec3 rayPos, vec3 box)
{
	return length(max(abs(rayPos) - box, 0.0));
}

float sdTorus( vec3 rayPos, vec2 torus )
{
	vec2 q = vec2(length(rayPos.xz)-torus.x,rayPos.y);
	return length(q)-torus.y;
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

struct RayHit map(vec3);

vec3 getNormal(vec3 hitPoint, float delta)
{
	vec2 deltaVec = vec2(delta, 0);

	struct RayHit nextX = map(hitPoint + deltaVec.xyy);
	struct RayHit nextY = map(hitPoint + deltaVec.yxy);
	struct RayHit nextZ = map(hitPoint + deltaVec.yyx);

	struct RayHit previousX = map(hitPoint - deltaVec.xyy);
	struct RayHit previousY = map(hitPoint - deltaVec.yxy);
	struct RayHit previousZ = map(hitPoint - deltaVec.yyx);

	vec3 unnormalizedGradient = vec3(nextX.dist - previousX.dist, nextY.dist - previousY.dist, nextZ.dist - previousZ.dist);

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

mat3 random3DRotation(float seed) 
{
	const float PI = 3.1415;
	float a = noise(rand(seed) + iGlobalTime - seed);
	float c = cos(a);
	float s = sin(a);

	mat3 rotX = mat3(1, 0, 0, 0, c, s, 0, -s, c);
	mat3 rotY = mat3(c, 0, -s, 0, 1, 0, s, 0, c);
	mat3 rotZ = mat3(c, s, 0, -s, c, 0, 0, 0, 1);

	return (rotX * rotY * rotZ);
}
//Planet
//TODO Improve it - The shrinking of the sphere is to fast at the end
float sphereRadius = 10f - clamp(iGlobalTime, 0, 9) + clamp(sin(4 * iGlobalTime) * .4, clamp(-(10 - iGlobalTime), -10, 0), clamp((10 - iGlobalTime), 0, 10));
	

struct RayHit map(vec3 rayPos) 
{	
	struct RayHit hit;

	

	//Particles
	float particles = 100000;

	for(int i = 0; i < 150; i++) 
	{
		vec3 offset = randomDirection(i);
		particles = opUnify(particles, sdSphere(rayPos - offset * (fract(iGlobalTime / 4 + rand(i)) + sphereRadius) * mod(i, 7), .04));
		//particles = opUnify(particles, sdSphere(rayPos - offset * sphereRadius, .04));
	}

	float visiblePart = opCutOut(sdSphere(rayPos, sphereRadius), sdSphere(rayPos, sphereRadius * 10));

	particles = opIntersect(visiblePart, particles);
	hit.type = 0;
	float minDist = particles;



	//Planet
	float sphere1 = sdSphere(rayPos - vec3(0, 0, 0), sphereRadius);
	hit.type = sphere1 < minDist ? 1 : hit.type;
	minDist = min(minDist, sphere1);

	//Rings
	float torus = sphere1;
	vec3 rotatedPos = rayPos;
	for(int i = 0; i < 4; i++) 
	{
		rotatedPos = random3DRotation(i) * rotatedPos;
		torus = opUnify(torus, sdTorus(rotatedPos - vec3(0, 0, 0), vec2(sphereRadius + .3, .04)));
	}
	hit.type = torus < minDist ? 2 : hit.type;
	minDist = min(minDist, torus);
	
	hit.dist = opUnify(opUnify(sphere1, torus), particles);
	return hit;
}

vec4 drawScene(vec3 camPos, vec3 camDir)
{
	sphereRadius = 10f - clamp(iGlobalTime, 0, 9) + clamp(sin(4 * iGlobalTime) * .4, clamp(-(10 - iGlobalTime), -10, 0), clamp((10 - iGlobalTime), 0, 10));

	struct LightSource light;
	light.position = vec3(0, 10, 0);
	light.color = vec3(1, 1, 1);

	const float EPSILON = 1e-5;
	const int Steps = 128;
	const float maxDist = 100;

	vec4 color = vec4(0);
	
	
	vec3 rayPos = camPos;
	float dist = 0;
	for(int t = 0; t < Steps; t++)
	{
		struct RayHit distanceToObj = map(rayPos);
		if(distanceToObj.dist < EPSILON)
		{
			
			//vec3 normal = getNormal(rayPos, 0.01);
			//vec3 matColor = vec3(0.9, 0.9, 0.9);

			rayPos += distanceToObj.dist * camDir;
			color.rgb = vec3(1);

			float hitParticle = distanceToObj.type < 0.5 ? 1 : 0;

			color.a = hitParticle * (sphereRadius * 3 - distance(rayPos, vec3(0))) + (1 - hitParticle);

			//Fake ass alpha blending
			color.rgb = mix(vec3(0), color.rgb, color.a);

			break;
		}
		if(dist > maxDist) 
			break;

		rayPos += distanceToObj.dist * camDir;
		dist += distanceToObj.dist;
	}
	
	
	return color;
}

vec3 calcAdditionalRayDir(float fov, vec2 fragCoord, vec2 resolution) 
{
	const float PI = 3.14159;

	float fx = tan(radians(fov) / 2.0) / resolution.x;
	vec2 d = fx * (fragCoord * 2.0 - resolution);
	vec3 rayDir = normalize(vec3(d, 1.0));
	return rayDir;
}


void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(0, 0, 0, 1);
	
	float fov = 80;
	vec3 camP = calcCameraPos();
	camP += vec3(0, 0, -10);
	vec3 camDir = calcCameraRayDir(fov, gl_FragCoord.xy, iResolution);
	
	const vec2 pixelResolution = vec2(4);
	for(int x = 0; x < pixelResolution.x; x++) 
	{
		for(int y = 0; y < pixelResolution.y; y++)
		{
			vec2 coordPos = vec2(gl_FragCoord.x + x * (1 / pixelResolution.x), gl_FragCoord.y + y * (1 / pixelResolution.y));
			camDir = calcCameraRayDir(fov, coordPos, iResolution);
			color += drawScene(camP, camDir);
		}
	}
	color.rgb /= (pixelResolution.x * pixelResolution.y);



	gl_FragColor = color;
}