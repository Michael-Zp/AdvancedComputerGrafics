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


float sdTorus( vec3 point, vec2 torus )
{
	vec2 q = vec2(length(point.xz)-torus.x,point.y);
	return length(q)-torus.y;
}

float sdCylinder( vec3 point, vec3 cylinder )
{
  	return length(point.xz - cylinder.xy) - cylinder.z;
}


float opUnify(float a, float b)
{
	return min(a, b);
}

float opCutOut(float cut, float stay)
{
	return max(-cut, stay);
}

float opIntersect( float a, float b )
{
    return max(a, b);
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


float map(vec3 rayPos) 
{	
	return sdCylinder(rayPos, vec3(0, 0, 1));
}




vec3 drawScene(vec3 camPos, vec3 camDir)
{
	LightSource light;
	light.position = vec3(0, 0, -15);
	light.color = vec3(1, 1, 1);

	const float EPSILON = 1e-5;
	const int Steps = 256;
	const float maxDist = 100;

	vec3 color = vec3(0);

	vec3 rayPos = camPos;
	float dist = 0;
	float distanceToObj = 0;
	for(int t = 0; t < Steps; t++)
	{
		distanceToObj = map(rayPos);
		if(distanceToObj < EPSILON)
		{
			rayPos += distanceToObj * camDir;
			//color.rgb = GetColor(light, vec3(.1), rayPos, getNormal(rayPos, 1e-5), camDir, vec3(1), 1.0);
			color.rgb = vec3(1);
			break;
		}
		if(dist > maxDist) 
			break;

		//Not going the whole distance reduces performance, but prefents artifacts
		rayPos += (distanceToObj * .75) * camDir;
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
	//4 component color red, green, blue, alpha
	vec4 color = vec4(0, 0, 0, 1);
	
    /*
	float fov = 80;
	vec3 camP = calcCameraPos();
	camP += vec3(0, 0, -10);
	vec3 camDir = calcCameraRayDir(fov, gl_FragCoord.xy, iResolution);
	
	const vec2 pixelResolution = vec2(2);
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
    */

    const float size = 10;
    vec3 camP = vec3(uv * size - size / 2.0, -10);
    vec3 camDir = vec3(0, 0, 1);

    color.rgb += drawScene(camP, camDir);


	gl_FragColor = color;
}