#version 330

#include "../libs/camera.glsl" 
#include "../libs/rayIntersections.glsl" 
#include "../libs/Noise.glsl"
#include "../libs/noise3D.glsl"

uniform float iGlobalTime;
uniform vec2 iResolution;
uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform float growth;
uniform float sunStrength;


float localTime = iGlobalTime - 62.0;


vec2 uv;


const float PI = 3.1415;
const float TAU = PI * 2.0;
const float EPSILON = 1e-2; //Many waves -> big epsilon == less artifacts
const int STEPS = 300;
const float DELTA = 0.01;
const float MAX_DIST = 25.0;

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
	x *= 2.0;
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

float sdSphere( vec3 vecToCenter, float radius )
{
  return length(vecToCenter) - radius;
}

float udBox(vec3 vecToCenter, vec3 box)
{
	return length(max(abs(vecToCenter) - box, 0.0));
}

float sdCylinder( vec3 point, vec3 cylinder )
{
  	return length(point.xz - cylinder.xy) - cylinder.z;
}

float opUnify(float a, float b)
{
	return min(a, b);
}

struct HitInfo
{
	float distance;
	float hitId;
};

const float sandId = 0.0;
const float waterId = 1.0;
const float seaGrassId = 2.0;
const float seaGrassInnerId = 3.0;

const vec3 baseColor = vec3(.4, .4, .2);
const vec3 waterColor = vec3(0, .6, .9);
const vec3 seaGrassColor = vec3(.3, 1, .3);
const vec3 seaGrassInnerColor = vec3(0, .7, 0);

const vec3[4] hitIdToColor = vec3[4] (
	baseColor,
	waterColor,
	seaGrassColor,
	seaGrassInnerColor
);


const vec3 skyColor = vec3(.1, .6, 1);
const vec3 miscColor = vec3(.8, .8, .8);

const float waterLevel = 2.0;

HitInfo distanceWater(vec3 hitPoint)
{
	float waves = fbm(hitPoint + vec3(localTime / 10.0), 3) * 0.2;

	float waterHeight = (waterLevel + waves);
	return HitInfo(hitPoint.y - waterHeight, waterId);
}

vec3 scaleDownVector(vec3 vec, float decimalDownScaleFactor)
{
	float factor = pow(10, decimalDownScaleFactor);
	vec.x = int(floor(vec.x * factor)) / factor;
	vec.y = int(floor(vec.x * factor)) / factor;
	vec.z = int(floor(vec.x * factor)) / factor;
	return vec;
}

void seaGrass(out float seaGrassDist, out float seaGrassInnerDist, vec3 hitPoint, float seed, float gridSize, float gridArea)
{
	float seaGrassHeight = 0.5 + rand(seed) * 0.5;
	seaGrassHeight *= clamp(growth, 0.01, 1.0);

	vec3 seaGrassWave = vec3(sin(hitPoint.y * (8 + rand(seed * 123) * 4.0) + hitPoint.z * (8 + rand(seed * 234) * 4.0) + localTime) * hitPoint.y * 0.05, 
							 0.0, 
							 cos(hitPoint.y * (17.5 + rand(seed * 345) * 5.0) + localTime * (3.0 + rand(seed * 456))) * 0.01);

	vec3 seaGrassSize = vec3(.005 + noise(hitPoint.y * 5.0) * 0.015 + 0.015, seaGrassHeight, .001);
	float maxThickHeight = seaGrassHeight * (0.7 + rand(seed * 567) * 0.2);
	float currentHeight = clamp(hitPoint.y, maxThickHeight, seaGrassHeight);
	float diminshZone = seaGrassHeight - maxThickHeight;
	float thicknessFactor = 1 - ((currentHeight - maxThickHeight) / diminshZone);
	seaGrassSize.x *= thicknessFactor;


	//Group the seaGrass into grid cells otherwise the random distribution is shit
	float gridCellSize = gridArea / gridSize;
	float xQuadrant = floor(seed / gridSize);
	float zQuadrant = mod(seed, gridSize);
	vec3 position = vec3(texture2D(tex1, vec2(rand(seed * 789.0 * (zQuadrant + 1.0)))).r, 0.0, texture2D(tex1, vec2(rand(seed * 987.0 * (xQuadrant + 1.0)))).r);
	position.x = (xQuadrant * gridCellSize) + (position.x * gridCellSize) - gridArea / 2.0;
	position.z = (zQuadrant * gridCellSize) + (position.z * gridCellSize) - gridArea / 2.0;

	seaGrassDist = udBox(position - hitPoint + seaGrassWave, seaGrassSize);
	seaGrassInnerDist = sdCylinder(position - hitPoint, vec3(-seaGrassWave.x, -seaGrassWave.z, seaGrassSize.x / (3.5 + rand(678.0)) - step(thicknessFactor, 0.001)));
}

HitInfo distanceRest(vec3 hitPoint)
{
	vec3 fbmVec = scaleDownVector((hitPoint + sin(hitPoint.z)) / 2.0, 3); //Noise reduction 
	float noise = fbm(fbmVec, 3) * 0.15 + length(texture2D(tex2, hitPoint.xz / 10.0).rgb) * 0.05;
	float waves = sin(hitPoint.x / 2.0 + hitPoint.z) * 0.1 + sin((hitPoint.x / 2.0 + hitPoint.z) * 10.0) * 0.06;

	float sandHeight = (noise + waves + 0.0);
	float sandDistance = hitPoint.y - sandHeight;

	float seaGrassDist, seaGrassInnerDist;
	float tempSeaGrassDist, tempSeaGrassInnerDist;

	const float gridArea = 3.0;
	const float seaGrassGridSize = 6.0;
	const float seaGrassCount = seaGrassGridSize * seaGrassGridSize;

	vec3 seaGrassRepeatPoint = vec3(mod(hitPoint.x, gridArea) - gridArea / 2.0, hitPoint.y, mod(hitPoint.z, gridArea) - gridArea / 2.0);

	seaGrass(seaGrassDist, seaGrassInnerDist, seaGrassRepeatPoint, 0.0, seaGrassGridSize, gridArea);

	for(int i = 1; i < seaGrassCount; i++)
	{
		seaGrass(tempSeaGrassDist, tempSeaGrassInnerDist, seaGrassRepeatPoint, i, seaGrassGridSize, gridArea);
		seaGrassDist = min(seaGrassDist, tempSeaGrassDist);
		seaGrassInnerDist = min(seaGrassInnerDist, tempSeaGrassInnerDist);
	}

	float returnId = step(sandDistance, seaGrassDist) * sandId +
					 step(seaGrassDist, sandDistance) * step(seaGrassDist, seaGrassInnerDist) * seaGrassId + 
					 step(seaGrassInnerDist, seaGrassDist) * step(seaGrassInnerDist, sandDistance) * seaGrassInnerId;

	float dist = opUnify(sandDistance, seaGrassDist);
	dist = opUnify(dist, seaGrassInnerDist);

	return HitInfo(dist, returnId);
}

HitInfo map(vec3 hitPoint)
{
	HitInfo restDistance;
	HitInfo waterDistance;
	

	restDistance = distanceRest(hitPoint);
	waterDistance = distanceWater(hitPoint);

	float hitWater = step(abs(waterDistance.distance), abs(restDistance.distance));
	float notHitWater = 1.0 - hitWater;

	float hitId = hitWater * waterDistance.hitId + notHitWater * restDistance.hitId;


	//Dont return the abs distance -> will fuck up the lighting somehow
	return HitInfo(step(abs(restDistance.distance), abs(waterDistance.distance)) * restDistance.distance + step(abs(waterDistance.distance), abs(restDistance.distance)) * waterDistance.distance, 
				   hitId);
}

HitInfo mapWithoutWater(vec3 hitPoint)
{
	return distanceRest(hitPoint);
}

vec3 getNormal(vec3 hitPoint)
{
	vec2 deltaVec = vec2(DELTA, 0);

	float nextX = map(hitPoint + deltaVec.xyy).distance;
	float nextY = map(hitPoint + deltaVec.yxy).distance;
	float nextZ = map(hitPoint + deltaVec.yyx).distance;

	float previousX = map(hitPoint - deltaVec.xyy).distance;
	float previousY = map(hitPoint - deltaVec.yxy).distance;
	float previousZ = map(hitPoint - deltaVec.yyx).distance;

	vec3 unnormalizedGradient = vec3(nextX - previousX, nextY - previousY, nextZ - previousZ);

	return normalize(unnormalizedGradient);
}

vec3 getNormalWithoutWater(vec3 hitPoint)
{
	vec2 deltaVec = vec2(DELTA, 0);

	float nextX = mapWithoutWater(hitPoint + deltaVec.xyy).distance;
	float nextY = mapWithoutWater(hitPoint + deltaVec.yxy).distance;
	float nextZ = mapWithoutWater(hitPoint + deltaVec.yyx).distance;

	float previousX = mapWithoutWater(hitPoint - deltaVec.xyy).distance;
	float previousY = mapWithoutWater(hitPoint - deltaVec.yxy).distance;
	float previousZ = mapWithoutWater(hitPoint - deltaVec.yyx).distance;

	vec3 unnormalizedGradient = vec3(nextX - previousX, nextY - previousY, nextZ - previousZ);

	return normalize(unnormalizedGradient);
}



float densityFunc(const vec3 p)
{
	vec3 q = p;// + vec3(0.0, 0.10, 1.0) * time; //clouds move
	float f = fbm(q / 40.0, 3);
	return clamp( 2 * f - p.y + 200, 0.0, 1.0 );
}


vec3 lighting(const vec3 pos, const float cloudDensity
			, const vec3 backgroundColor, const float pathLength, const vec3 sundir )
{
	float densityLightDir = densityFunc(pos + 0.3 * sundir); // sample in light dir
	float gradientLightDir = clamp(cloudDensity - densityLightDir, 0.0, 1.0);
			
    vec3 litColor = vec3(0.91, 0.98, 1.0) + vec3(1.0, 0.6, 0.3) * 2.0 * gradientLightDir;        
	vec3 cloudAlbedo = mix( vec3(1.0, 0.95, 0.8), vec3(0.25, 0.3, 0.35), cloudDensity );

	const float extinction = 0.0003;
	float transmittance = exp( -extinction * pathLength );
    return mix(backgroundColor, cloudAlbedo * litColor, transmittance );
}


vec4 raymarchClouds(const Ray ray, const vec3 backgroundColor, const vec3 sunDir )
{
	vec4 sum = vec4(0.0);
	float t = 0.0;
	for(int i = 0; i < 200; ++i)
	{
		vec3 pos = ray.origin + t * ray.dir;
		if( 0.99 < sum.a ) break; //break if opaque
		float cloudDensity = densityFunc( pos );
		if( 0.01 < cloudDensity ) // if not empty -> light and accumulate 
		{
			vec3 colorRGB = lighting( pos, cloudDensity, backgroundColor, t, sunDir );
			float alpha = cloudDensity * 0.4;
			vec4 color = vec4(colorRGB * alpha, alpha);
			sum += color * ( 1.0 - sum.a ); //blend-in new color contribution
		}
		t += max( 0.05, 0.02 * t ); //step size at least 0.05, increase t with each step
	}
    return clamp( sum, 0.0, 1.0 );
}


vec3 cloud(Ray ray, LightSource source)
{
	float hitsClouds = plane(vec3(0, 1, 0), -200.0, ray, 1e-5);

	if(hitsClouds <= -1) 
	{
		return vec3(0);
	}
	else
	{
		ray.origin = ray.origin + ray.dir * hitsClouds;
	}

	vec3 sunDir = normalize(ray.origin - source.position);

    // background sky     
	float sun = clamp( dot( sunDir, ray.dir ), 0.0, 1.0 );
	vec3 backgroundSky = vec3( 0.7, 0.79, 0.83 )
		- ray.dir.y * 0.2 * vec3( 1.0, 0.5, 1.0 )
		+ 0.2 * vec3( 1.0, 0.6, 0.1 ) * pow( sun, 8.0 );

    // clouds    
    vec4 res = raymarchClouds( ray, backgroundSky, sunDir);
    vec3 col = backgroundSky * ( 1.0 - res.a ) + res.rgb; // blend clouds with sky

	
	float rate = smoothstep(-0.1, 1.0, snoise(vec3(ray.origin.xz / 100.0, 0.0)));

	float sunIntensity = pow(dot(ray.dir, normalize(source.position - ray.origin)), 1);

	//The dot product will produce artifacts on the wrong side of the planet. Will reduce or erradicate these artifacts
	sunIntensity = sunIntensity * (1.0 - clamp(distance(ray.dir, normalize(source.position - ray.origin)), 0.0, 1.0));


	col = mix(vec3(0), col, rate);

	return col + vec3(sunIntensity + sunStrength);
}


vec4 render(vec3 camP, vec3 camDir)
{
	
	LightSource source = LightSource(vec3(0, 300, 0), vec3(1));

	vec4 color = vec4(0);
	
	vec3 rayPos = camP;
	float dist = 0;

	int t;
	float afterWaterSurfaceDist = 0.0;

	vec4 hitColor = vec4(0);
	bool isInWater = step(camP.y, waterLevel) == 1.0;

	for(t = 0; t < STEPS; t++)
	{
		HitInfo currentHit = map(rayPos);
		currentHit.distance = abs(currentHit.distance);
		dist += currentHit.distance;

		if(dist > MAX_DIST) 
		{
			break;
		}

		if(currentHit.distance < EPSILON)
		{
			rayPos += currentHit.distance * camDir;
			
			vec3 normal = getNormal(rayPos);
			
			if(currentHit.hitId != waterId)
			{
				hitColor.rgb = GetColor(source, vec3(.4), rayPos, normal, camDir, hitIdToColor[int(currentHit.hitId)], 16.0, 0.0);
			}
			else
			{
				hitColor.rgb = waterColor / 1.1;
				hitColor.a = 0.5;
				
				const float factorWater = 1.33; //1.333; //1.333 is physically correct. Looks not good tho
				const float factorAir = 1.0;
				const float factorWaterToAir = factorWater / factorAir;
				const float factorAirToWater = factorAir / factorWater;

				float refractedFactor;

				if(isInWater)
				{
					refractedFactor = factorWaterToAir;
				}
				else
				{
					refractedFactor = factorAirToWater;
				}

				vec3 waterNormal = step(camP.y, waterLevel) * -normal +
								   step(waterLevel, camP.y) * normal;

				vec3 refractedRay = refract(camDir, waterNormal, refractedFactor);
				vec3 reflectedRay = reflect(camDir, waterNormal);


				vec3 reflectedPos, refractedPos;
				reflectedPos = refractedPos = rayPos;

				vec3 reflectedColor, refractedColor;

				int t2 = 0;
				float wholeReflectedDist = 0.0;

				vec3 lightingOnWater = GetColor(source, vec3(0), reflectedRay, waterNormal, camDir, vec3(0), 16, 1.0) * 2.0;

				for(t2 = 0; t2 < STEPS/* && run*/; t2++)
				{
					HitInfo reflectedDist = mapWithoutWater(reflectedPos);
					
					reflectedDist.distance = abs(reflectedDist.distance);

					wholeReflectedDist += reflectedDist.distance;

					if(wholeReflectedDist > MAX_DIST) 
					{
						break;
						/*
						break produced artifacts. now not. i have no clue...
						//Break will produce artifacts. No idea why
						run = false;
						continue;
						*/
					}

					if(reflectedDist.distance < EPSILON)
					{
						reflectedPos += reflectedDist.distance * reflectedRay;

						normal = getNormalWithoutWater(reflectedPos);
						reflectedColor = GetColor(source, vec3(.2), reflectedRay, normal, camDir, hitIdToColor[int(reflectedDist.hitId)], 16, 0.0);

						break;
						
						/*
						break produced artifacts. now not. i have no clue...
						//Break will produce artifacts. No idea why
						run = false;
						continue;
						*/
					}

					reflectedPos += (reflectedDist.distance * 0.75) * reflectedRay;
				}

				if(t2 == STEPS || wholeReflectedDist > MAX_DIST)
				{
					reflectedColor = waterColor / 2.0;
				}

				if(length(refractedRay) > 0.5)
				{
					int t2 = 0;
					float wholeRefractedDist = 0.0;
					for(t2 = 0; t2 < STEPS/* && run*/; t2++)
					{
						HitInfo refractedDist = mapWithoutWater(refractedPos);
						
						refractedDist.distance = abs(refractedDist.distance);

						wholeRefractedDist += refractedDist.distance;

						if(wholeRefractedDist > MAX_DIST) 
						{
							break;
							/*
							break produced artifacts. now not. i have no clue...
							//Break will produce artifacts. No idea why
							run = false;
							continue;
							*/
						}

						if(refractedDist.distance < EPSILON)
						{
							refractedPos += refractedDist.distance * refractedRay;

							normal = getNormalWithoutWater(refractedPos);
							refractedColor = GetColor(source, vec3(.2f), refractedRay, normal, camDir, hitIdToColor[int(refractedDist.hitId)], 16, 0.0);
							break;
							
							/*
							break produced artifacts. now not. i have no clue...
							//Break will produce artifacts. No idea why
							run = false;
							continue;
							*/
						}

						refractedPos += (refractedDist.distance * 0.75) * refractedRay;
					}

					if(t2 == STEPS || wholeRefractedDist > MAX_DIST)
					{
						refractedColor = waterColor / 3.0;
					}
				}
				else 
				{
					refractedColor = reflectedColor;
				}

				
				//Total reflection due to refraction results in a refractedRay of length 0.0
				vec3 afterWaterRay = step(0.5, length(refractedRay)) * refractedRay +
									 step(length(refractedRay), 0.5) * reflectedRay;
				

				//bool run = true;
				
				float angleIncoming = acos(dot(camDir, -normal));
				float angleOutgoing = acos(dot(afterWaterRay, -normal));

				//acos and cos could be simplified, but for the sake of the equation and understanding it, leave it like that
				float fresnel = pow((factorWater * cos(angleOutgoing) - factorAir * cos(angleIncoming)) / (factorWater * cos(angleOutgoing) + factorAir * cos(angleIncoming)), 2);
				
				fresnel = clamp(fresnel, 0.0, 1.0);

				hitColor.rgb = mix(refractedColor, reflectedColor, fresnel);

				hitColor.rgb += lightingOnWater;
			}

			break;
		}

		rayPos += (currentHit.distance * 0.75) * camDir;
	}

	if(dist > MAX_DIST || t == STEPS)
	{
		color.rgb = miscColor;
	}
	

	if(isInWater)
	{
		if(dist > MAX_DIST)
		{
			color.rgb = waterColor;
		}
		else
		{
			const float waterRatioMin = 0.2;
			const float waterRatioMinInverted = 1.0 - waterRatioMin;
			float waterRatio = (dist / MAX_DIST) * waterRatioMinInverted + waterRatioMin;

			color.rgb = mix(hitColor.rgb, waterColor, waterRatio);
		}
	}
	else
	{
		float miscRatio = 0.0;
		if(dist > MAX_DIST)
		{
			miscRatio = 1.0 - clamp((rayPos.y - waterLevel) / 8.0, 0.0, 1.0);
			hitColor.rgb = skyColor;
		}
		else
		{
			const float miscRatioStart = 0.5;
			const float miscRatioStartInverted = 1.0 / miscRatioStart;
			miscRatio = dist / MAX_DIST;
			miscRatio = clamp(miscRatio - miscRatioStart, 0.0, 1.0) * miscRatioStartInverted;
		}
		
		color.rgb = mix(hitColor.rgb, miscColor, miscRatio);
		
		//No clouds under water, will cost a shit ton of performance for nearly nothing if the right perspective is chosen
		vec3 cloudColor = cloud(Ray(camP, camDir), source);

		color.rgb += clamp((0.7 - miscRatio), 0.0, 1.0) * cloudColor;
	}

	return vec4(color.rgb, 1.0);
}


void main()
{
	uv = gl_FragCoord.xy / iResolution;

	const float fov = 80.0;

	vec3 camP = calcCameraPos();


	vec4 color;

	const vec2 pixelResolution = vec2(2);
	for(int x = 0; x < pixelResolution.x; x++) 
	{
		for(int y = 0; y < pixelResolution.y; y++)
		{
			vec2 coordPos = vec2(gl_FragCoord.x + x * (1 / pixelResolution.x), gl_FragCoord.y + y * (1 / pixelResolution.y));
			vec3 camDir = calcCameraRayDir(fov, coordPos, iResolution);
			color += render(camP, camDir);
		}
	}
	color.rgb /= (pixelResolution.x * pixelResolution.y);
	

	gl_FragColor = color;
}