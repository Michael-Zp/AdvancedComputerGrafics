#version 330

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]
	
uniform float colorRed;

#include "libs/camera.glsl"

#define PI 3.1415
#define EPSILON 1e-5
#define STEPS 700

const float BIG_FLT = 1e20;

struct Ray 
{
	vec3 origin;
	vec3 direction;
};


struct LightSource 
{
	vec3 position;
	vec3 color;
};

float sdBox( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float distanceCross(in vec3 position)
{
	float xDirBox = sdBox(position, vec3(BIG_FLT, 1.0, 1.0));
	float yDirBox = sdBox(position, vec3(1.0, BIG_FLT, 1.0));
	float zDirBox = sdBox(position, vec3(1.0, 1.0, BIG_FLT));

	return min(xDirBox, min(yDirBox, zDirBox));
}

float map(in vec3 position) 
{
	float d = sdBox(position, vec3(1.0));

	float scale = 1.0;
	for( int m=0; m<3; m++ )
	{
		vec3 a = mod( position * scale, 2.0 ) - 1.0;
		scale *= 3.0;
		vec3 r = 1.0 - 3.0 * abs(a);
				
		float c = distanceCross(r)/scale;
		d = max(d,c);
	}

	return d;
}



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


void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(uv, 0, 1);

	
	struct LightSource light;
	light.position = vec3(3, 10, -3);
	light.color = vec3(1, 1, 1);

	
	vec3 camP = calcCameraPos();
	camP.z -= 3;
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);

	
	struct Ray ray;
	ray.origin = camP;
	ray.direction = camDir;

	const float delta = 0.008f;

	vec3 currPos = ray.origin;

	for(int i = 0; i < STEPS; i++)
	{
		float dist = map(currPos);

		if(dist < EPSILON) 
		{
			//color.rgb = 1 - (vec3(1) * i) / STEPS;
			//color.rgb = getNormal(currPos, 1e-2);
			vec3 normal = getNormal(currPos, 1e-2);
			color.rgb = GetColor(light, vec3(.1f), currPos, normal, camDir, vec3(colorRed, .1, .1), 1f);
			break;
		}

		currPos = currPos + ray.direction * dist;
	}

	gl_FragColor = color;

}