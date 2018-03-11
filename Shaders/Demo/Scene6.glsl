#version 330

#include "../libs/camera.glsl" 
#include "../libs/rayIntersections.glsl" 
#include "../libs/Noise.glsl"
#include "../libs/noise3D.glsl"

uniform sampler2D texLastFrame0;
uniform float iGlobalTime;
uniform vec2 iResolution;
uniform sampler2D tex0;
vec2 uv;


const float PI = 3.1415;
const float TAU = PI * 2.0;
const float EPSILON = 1e-5;
const int STEPS = 200;
const float DELTA = 0.01;
const vec3 sphereCenter = vec3(0, 0, 70);
const float sphereRadius = 30.0;
const float minHeight = sphereRadius * .7;
const float minToMaxHeight = sphereRadius - minHeight;

const float mountainHeightRatio = 0.5;
const float landHeightRatio = 0.2;
const float landToMaintainMixRange = 0.1;

struct LightSource 
{
	vec3 position;
	vec3 color;
};

float hash(vec3 p)
{
    p  = fract( p*0.3183099 + .1 );
	p *= 17.0;
    return fract( p.x*p.y*p.z*(p.x+p.y+p.z) );
}

float noise( in vec3 x )
{
	x *= 2;
#ifdef noise3D_glsl
	//return snoise(x * 0.25); //enable: slower but more "fractal"
#endif
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f*f*(3.0-2.0*f);
	
    return mix(mix(mix( hash(p+vec3(0,0,0)), 
                        hash(p+vec3(1,0,0)),f.x),
                   mix( hash(p+vec3(0,1,0)), 
                        hash(p+vec3(1,1,0)),f.x),f.y),
               mix(mix( hash(p+vec3(0,0,1)), 
                        hash(p+vec3(1,0,1)),f.x),
                   mix( hash(p+vec3(0,1,1)), 
                        hash(p+vec3(1,1,1)),f.x),f.y),f.z);
}

float fbm(vec3 p, const int octaves )
{
	float f = 0.0;
	float weight = 0.5;
	for(int i = 0; i < octaves; ++i)
	{
		f += weight * noise( p );
		weight *= 0.5;
		p *= 2.0;
	}
	return f;
}


float heightRatio(vec3 posOnSphereEdge)
{
	posOnSphereEdge = normalize(posOnSphereEdge);

	float core = snoise(posOnSphereEdge * 3.0) * 0.15;
	float land = snoise((posOnSphereEdge + vec3(123, 213, 321)));
	float mountain = snoise((posOnSphereEdge / 3.0 + vec3(111, 222, 222)));

	float heightRatio = core;

	land = clamp(land + 0.1, 0, 1);

	heightRatio += pow(land, 2) * .85;
	heightRatio += pow(mountain, 3) * 0.7;

	float texRotAngle = snoise(posOnSphereEdge * 2) * 0.5 + 0.5;
	texRotAngle * TAU;

	float c = cos(texRotAngle);
	float s = sin(texRotAngle);

	mat2 rotation = mat2(c, s, -s, c);

	heightRatio -= length(texture2D(tex0, rotation * posOnSphereEdge.xy)) * 0.04;
	heightRatio += length(texture2D(tex0, rotation * posOnSphereEdge.yx)) * 0.05;

	return heightRatio;
}


float heightRatioToHeight(float ratio)
{
	return ratio * minToMaxHeight + minHeight;
}

float sphereHeight(vec3 posOnSphereEdge)
{
	return heightRatioToHeight(heightRatio(posOnSphereEdge));
}


vec3 GetColor(LightSource source, vec3 ambientLight, vec3 hitPoint, vec3 normal, vec3 camDir, vec3 color, float shininess, float specularIntensity)
{
	vec3 lightDirection = normalize(source.position - hitPoint);
	vec3 reflectDirection = normalize(reflect(lightDirection, normal));

	float lightHitsForeground = step(0.0, dot(normal, lightDirection));
	float specularReflectionIsAbove90Deg = step(0.0, dot(reflectDirection, camDir));

	//Ambient
	vec3 sphereAmbientColor = color * ambientLight;

	//Diffuse
	vec3 sphereDiffuseColor = color * source.color * dot(normal, lightDirection) * lightHitsForeground;

	//Specular
	float specularAngle = dot(reflectDirection, camDir) * specularReflectionIsAbove90Deg * lightHitsForeground;
	vec3 sphereSpecularColor = source.color * pow(specularAngle, shininess);
	sphereSpecularColor *= specularIntensity;


	return sphereAmbientColor + sphereDiffuseColor + sphereSpecularColor;
}



// this calculates the water as a height of a given position
float water( vec3 p )
{
	float height = 0;

	height = fbm(p, 3);

	return height;
}

vec3 getNormalOfSphere(vec3 hitPoint, vec3 sphereOrigin, float delta)
{
	vec2 deltaVec = vec2(delta, 0);

	float nextDeltaX = sphereHeight(hitPoint + deltaVec.xyy) - distance(hitPoint + deltaVec.xyy, sphereOrigin);
	float nextDeltaY = sphereHeight(hitPoint + deltaVec.yxy) - distance(hitPoint + deltaVec.yxy, sphereOrigin);
	float nextDeltaZ = sphereHeight(hitPoint + deltaVec.yyx) - distance(hitPoint + deltaVec.yyx, sphereOrigin);
	float previousDeltaX = sphereHeight(hitPoint - deltaVec.xyy) - distance(hitPoint - deltaVec.xyy, sphereOrigin);
	float previousDeltaY = sphereHeight(hitPoint - deltaVec.yxy) - distance(hitPoint - deltaVec.yxy, sphereOrigin);
	float previousDeltaZ = sphereHeight(hitPoint - deltaVec.yyx) - distance(hitPoint - deltaVec.yyx, sphereOrigin);

	vec3 unnormalizedGradient = vec3(nextDeltaX - previousDeltaX, nextDeltaY - previousDeltaY, nextDeltaZ - previousDeltaZ);


	return normalize(unnormalizedGradient);
}


float waterHeight(vec3 hitPoint)
{
	float wave = 0;
	wave += water(hitPoint);
	return heightRatioToHeight(landHeightRatio) + wave * 0.15;
}

vec3 getNormalOfWater(vec3 hitPoint, vec3 sphereOrigin, float delta)
{
	vec2 deltaVec = vec2(delta, 0);

	float nextDeltaX = waterHeight(hitPoint + deltaVec.xyy) - distance(hitPoint + deltaVec.xyy, sphereOrigin);
	float nextDeltaY = waterHeight(hitPoint + deltaVec.yxy) - distance(hitPoint + deltaVec.yxy, sphereOrigin);
	float nextDeltaZ = waterHeight(hitPoint + deltaVec.yyx) - distance(hitPoint + deltaVec.yyx, sphereOrigin);
	float previousDeltaX = waterHeight(hitPoint - deltaVec.xyy) - distance(hitPoint - deltaVec.xyy, sphereOrigin);
	float previousDeltaY = waterHeight(hitPoint - deltaVec.yxy) - distance(hitPoint - deltaVec.yxy, sphereOrigin);
	float previousDeltaZ = waterHeight(hitPoint - deltaVec.yyx) - distance(hitPoint - deltaVec.yyx, sphereOrigin);

	vec3 unnormalizedGradient = vec3(nextDeltaX - previousDeltaX, nextDeltaY - previousDeltaY, nextDeltaZ - previousDeltaZ);


	return normalize(unnormalizedGradient);
}

vec2 calcUvOnSphere(vec3 hitPoint, vec3 sphereCenter)
{
    vec3 centerToHitPoint = normalize(hitPoint - sphereCenter);

    return vec2(centerToHitPoint.x, centerToHitPoint.y) / 2.0 + vec2(0.5);
}

int isAlive(vec2 uvOffset)
{
	return int(step(0.5, texture2D(texLastFrame0, uv + uvOffset).a ));
}

float gameOfLive()
{
	//Only play in a 100 by 100 field
	//vec2 downscaledUv = floor(uv * 100.0) / 100.0;

	float oldState = texture2D(texLastFrame0, uv).a;
	
	if(oldState == -1)
	{
		/*
		return noise(uv * 100) * 0.5;
		*/

		return step(0.9, noise(uv * 100.0));
	}

	if(oldState == 1.0)
	{
		return oldState;
	}


	int neighborsCount = 0;
	vec2 pixelSize = vec2(1.0) / iResolution;

	//Iterate over top row and bottom row
	for(int x = -1; x <= 1; x++)
	{
		neighborsCount += isAlive(pixelSize * vec2(x, -1.0));
		neighborsCount += isAlive(pixelSize * vec2(x,  1.0));
	}

	//Check middel left and right
	neighborsCount += isAlive(pixelSize * vec2(-1.0, 0.0));
	neighborsCount += isAlive(pixelSize * vec2( 1.0, 0.0));


	if(neighborsCount == 2.0)
	{
		return oldState;
	}

	if(neighborsCount == 3.0)
	{
		return step(0.3, rand(iGlobalTime * uv.x * uv.y));
	}

	return oldState;
}

void main()
{
	//Clear frame
	gl_FragColor = vec4(0, 0, 0, -1); return;

	uv = gl_FragCoord.xy / iResolution;


	vec3 camP = calcCameraPos();
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);

	float alpha = gameOfLive();


	LightSource source = LightSource(vec3(20, 40, 30), vec3(1));

	
	//LightSource source = LightSource(vec3(20, 0, 0), vec3(1));
	//source.position.xz = vec2(sin(iGlobalTime), cos(iGlobalTime)) * 90;


	//Calculate color of the image
	float t = sphere(sphereCenter, sphereRadius, Ray(camP, camDir), 1e-5);
	vec3 currentCol = vec3(1, 0, 0) * t;

	vec3 rayMarchStartPoint = camP + camDir * t;
	
	bool hitAtmos = false;

	if(t != -1.0)
	{
		vec3 pos = rayMarchStartPoint;
		float value = 0.0;
		float endHeight = sphereRadius;
		float endHeightRatio = 2.0;
		float delta = DELTA;
		bool wasInWater = false;

		for(int i = 0; i < STEPS; i++)
		{
			pos = pos + (camDir) * delta;

			vec3 centerToPos = normalize(pos - sphereCenter);
			vec3 posOnSphereEdge = centerToPos * sphereRadius; //Position is relative. The real position in the room would be this + sphereCenter;
			float heightRatio = heightRatio(posOnSphereEdge);
			float heightAtPos = heightRatioToHeight(heightRatio);

			float currentHeight = length(pos - sphereCenter);

			if(currentHeight < heightRatioToHeight(landHeightRatio))
			{
				wasInWater = true;
			}

			if(currentHeight < heightAtPos)
			{
				endHeight = heightAtPos;
				endHeightRatio = heightRatio;
				break;
			}

			delta *= 1.02;
			
		}

		vec3 woodColor = vec3(.282, .51, 0.078);
		vec3 rockColor = vec3(0.5, 0.35, 0.25);

		vec2 sphereUv = calcUvOnSphere(pos, sphereCenter);

		float state = texture2D(texLastFrame0, sphereUv).a;

		vec3 landColor = mix(rockColor, woodColor, clamp(state, 0.0, 1.0));


		vec3 colors[4] = vec3[4] (
			vec3(.2, .23, .1),
			vec3(0.35, 0.45, .2),
			landColor,
			vec3(0.5)
		);



		vec3 normal = getNormalOfSphere(pos, sphereCenter, -0.01);
		
		if(endHeightRatio > 1.0)
		{
			if(!wasInWater)
			{
				hitAtmos = true;
			}
		}
		else if(endHeightRatio >= landHeightRatio)
		{
			vec3 mountainColorHere = colors[3] - length(texture2D(tex0, uv.yx)) * vec3(0.4) + vec3(0.4);
			vec3 landColorHere = colors[2] - texture2D(tex0, uv).rgb * 0.4;
			if(endHeightRatio >= mountainHeightRatio + landToMaintainMixRange / 2.0)
			{
				//Mountains
				currentCol = mountainColorHere;
			}
			else if(endHeightRatio >= mountainHeightRatio - landToMaintainMixRange / 2.0)
			{
				float minMixRatio = mountainHeightRatio - landToMaintainMixRange / 2.0;
				float mixRatio = endHeightRatio - minMixRatio;
				mixRatio *= (1.0 / landToMaintainMixRange);
				currentCol = mix(landColorHere, mountainColorHere, mixRatio);
			}
			else
			{
				//Land
				currentCol = landColorHere;
			}
			
			currentCol = GetColor(source, vec3(.2), pos, normal, camDir, currentCol, 0.0, 0.0);
		}
		else
		{
			float depthRatio = endHeightRatio * (1.0 / landHeightRatio);

			//Core
			currentCol = mix(colors[0], colors[1], depthRatio);
			currentCol = GetColor(source, vec3(.2), pos, normal, camDir, currentCol, 0.0, 0.0);
		}

		if(wasInWater)
		{
			if(endHeightRatio > 1.0)
			{
				currentCol = vec3(0, 0, .5);
			}
			else 
			{
				float depthRatio = endHeightRatio * (1.0 / landHeightRatio);
				currentCol = mix(currentCol + vec3(0, 0, .45), currentCol + vec3(0, 0, .35), depthRatio);
			}
			

			currentCol = GetColor(source, vec3(.2), pos, getNormalOfWater(pos, sphereCenter, -0.01), camDir, currentCol, 3.0, 0.8);
		}
		else
		{
			float missedHeight = step(endHeight, sphereRadius - 0.01);

			currentCol *= missedHeight;
		}
		

	}

	const float atmosRadius = sphereRadius * 1.06;
	const float maxAtmosThickness = cos(atan(minHeight / atmosRadius)) * atmosRadius * 2;
	float tNear = sphere(sphereCenter, atmosRadius, Ray(camP, camDir), 1e-5);


	if((tNear != -1 && t == -1) || hitAtmos)
	{
		vec3 atmosEntry = camP + tNear * camDir;
		vec3 pointBehindAtmos = atmosEntry + camDir * maxAtmosThickness;
		float tFar = sphere(sphereCenter, atmosRadius, Ray(pointBehindAtmos, -camDir), 1e-5);
		vec3 atmosExit = pointBehindAtmos - camDir * tFar;
		float atmosThicknessRate = distance(atmosEntry, atmosExit) / maxAtmosThickness;

		// cheap atmospeheric scattering effect.
		vec3 baseAtmosColor = .35 * atmosThicknessRate * vec3(.4, .6, 1.);

		vec3 atmosCenter = atmosEntry + (atmosEntry - atmosExit) / 2.0;
		float sunIntensity = pow(dot(camDir, normalize(source.position - atmosCenter)), 7);

		//The dot product will produce artifacts on the wrong side of the planet. Will reduce or erradicate these artifacts
		sunIntensity = sunIntensity * (1.0 - clamp(distance(camDir, normalize(source.position - atmosCenter)), 0.0, 1.0));

		currentCol = mix(baseAtmosColor, vec3(0.6, 0.15, 0.), sunIntensity);
	}
	else if(t == -1)
	{
		currentCol = vec3(0);

		currentCol = vec3(step(rand(camDir.x) + rand(camDir.y) + rand(camDir.z), .05));
	}

	gl_FragColor = vec4(currentCol, alpha);
}




