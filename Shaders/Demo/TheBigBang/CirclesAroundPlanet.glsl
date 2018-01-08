#version 330

#include "../libs/camera.glsl"
#include "../libs/Noise.glsl"

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

float sdTorus( vec3 point, vec2 torus )
{
	vec2 q = vec2(length(point.xz)-torus.x,point.y);
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

float map(vec3);

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

float map(vec3 rayPos) 
{		
	//TODO Improve it - The shrinking of the sphere is to fast at the end
	float sphereRadius = 10f - clamp(iGlobalTime, 0, 9) + clamp(sin(4 * iGlobalTime) * .4, clamp(-(10 - iGlobalTime), -10, 0), clamp((10 - iGlobalTime), 0, 10));
	
	float sphere1 = distanceToSphere(rayPos - vec3(0, 0, 0), sphereRadius);

	float torus = sphere1;
	vec3 rotatedPos = rayPos;
	for(int i = 0; i < 4; i++) 
	{
		rotatedPos = random3DRotation(i) * rotatedPos;
		torus = opUnify(torus, sdTorus(rotatedPos - vec3(0, 0, 0), vec2(sphereRadius + .3, .04)));
	}
	//float torus1 = sdTorus(rotatedPos - vec3(0, 0, 0), vec2(sphereRadius + .3, .05));
	
	return opUnify(sphere1, torus);
}

vec3 drawScene(vec3 camPos, vec3 camDir)
{
	struct LightSource light;
	light.position = vec3(0, 10, 0);
	light.color = vec3(1, 1, 1);

	const float EPSILON = 1e-5;
	const int Steps = 128;
	const float maxDist = 100;

	vec3 color = vec3(0);
	
	
	vec3 rayPos = camPos;
	float dist = 0;
	for(int t = 0; t < Steps; t++)
	{
		float distanceToObj = map(rayPos);
		if(distanceToObj < EPSILON)
		{
			
			//vec3 normal = getNormal(rayPos, 0.01);
			//vec3 matColor = vec3(0.9, 0.9, 0.9);

			rayPos += distanceToObj * camDir;
			color.rgb = vec3(1, 1, 1);
			//color.rgb = GetColor(light, vec3(.1f), rayPos, normal, camDir, matColor, 16);
			break;
		}
		if(dist > maxDist) 
			break;

		rayPos += distanceToObj * camDir;
		dist += distanceToObj;
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
			color.rgb += drawScene(camP, camDir);
		}
	}
	color.rgb /= (pixelResolution.x * pixelResolution.y);



	gl_FragColor = color;
}