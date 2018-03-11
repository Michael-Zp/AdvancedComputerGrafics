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
uniform float sunPosition;

vec2 uv;

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
	texRotAngle * 3.1415 * 2;

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


float sunNoise(vec3 uv, float res)	// by trisomie21
{
	const vec3 s = vec3(1e0, 1e2, 1e4);
	
	uv *= res;
	
	vec3 uv0 = floor(mod(uv, res)) * s;
	vec3 uv1 = floor(mod(uv + vec3(1.), res)) * s;
	
	vec3 f = fract(uv); 
    f = f * f * (3.0 - 2.0 * f);
	
	vec4 v = vec4(uv0.x+uv0.y+uv0.z, uv1.x+uv0.y+uv0.z,
		      	  uv0.x+uv1.y+uv0.z, uv1.x+uv1.y+uv0.z);
	
	vec4 r = fract( sin( v * 1e-3) * 1e5);
	float r0 = mix( mix(r.x, r.y, f.x), mix(r.z, r.w, f.x), f.y);
	
	r = fract(sin((v + uv1.z - uv0.z) * 1e-3) * 1e5);
	float r1 = mix(mix(r.x, r.y, f.x), mix(r.z, r.w, f.x), f.y);
	
	return mix(r0, r1, f.z) * 2. - 1.;
}


vec4 renderSun(bool ignited, vec2 sunPos, float size)
{
    //UV coordinates are twisted to position and resize the sun -> make local copy
    vec2 localUV = uv;
    float freqs[4];

	freqs[0] = texture2D( tex2, vec2( 0.01, 0.25 ) ).x;
	freqs[1] = texture2D( tex2, vec2( 0.07, 0.25 ) ).x;
	freqs[2] = texture2D( tex2, vec2( 0.15, 0.25 ) ).x;
	freqs[3] = texture2D( tex2, vec2( 0.30, 0.25 ) ).x;

	float brightness	= freqs[1] * 0.25 + freqs[2] * 0.25;
	float radius		= 0.23 + brightness * 0.2;
	float invRadius 	= 1.0 / radius;
	
	vec3 orange			= vec3( 0.8, 0.65, 0.3 );
	vec3 orangeRed		= vec3( 0.8, 0.35, 0.1 );

    if(ignited == false)
    {
        orange = vec3(1.25, 1, 1) / 20.0;
        orangeRed = vec3(0.1, 0.1, 0.1) / 2.0;
    }

	float time		    = iGlobalTime * 0.002;
	float aspect	    = iResolution.x / iResolution.y;

    localUV -= sunPos;
    localUV /= size;

	vec2 posFromCenter = localUV;
	posFromCenter.x *= aspect;

	float fade		= pow( length( 2.0 * posFromCenter ), 0.5 );
	float fVal1		= 1.0 - fade;
	float fVal2		= 1.0 - fade;
	
    const float PI = 3.1415;
    const float TAU = 2.0 * PI;

	float angle		= atan(posFromCenter.x, posFromCenter.y) / TAU;
	float dist		= length(posFromCenter);
	vec3 coord		= vec3(angle, dist, time * 0.002 );
	
	float newTime1	= abs( sunNoise( coord + vec3( 0.0, -time * ( 0.35 + brightness * 0.001 ), time * 0.015 ), 15.0 ) );
	float newTime2	= abs( sunNoise( coord + vec3( 0.0, -time * ( 0.15 + brightness * 0.001 ), time * 0.015 ), 45.0 ) );

	for(int i = 2; i <= 3; i++)
    {
		float power = pow( 2.0, float(i) );
		fVal1 += ( 0.5 / power ) * sunNoise( coord + vec3( 0.0, -time, time * 0.2 ), ( power * ( 10.0 ) * ( newTime1 + 1.0 ) ) );
		fVal2 += ( 0.5 / power ) * sunNoise( coord + vec3( 0.0, -time, time * 0.2 ), ( power * ( 25.0 ) * ( newTime2 + 1.0 ) ) );
	}
	
	float corona		= pow( fVal1 * max( 1.12 - fade, 0.0 ), 2.0 ) * 50.0;
	corona				+= pow( fVal2 * max( 1.12 - fade, 0.0 ), 2.0 ) * 50.0;
	corona				*= 1.2 - newTime1;

	vec3 starSphere		= vec3( 0.0 );
	
	vec2 sphere = 2.0 * localUV;
	sphere.x *= aspect;
	sphere *= ( 2.0 - brightness );
  	float radiusLength = dot(sphere, sphere);
	float f = (1.0 - sqrt(abs(1.0 - radiusLength))) / radiusLength + brightness * 0.5;

    if(!ignited)
    {
        corona = 0.0;
    }

    //Point is in sphere
	if( dist < radius )
    {
		corona *= pow( dist * invRadius, 24.0 ); //Make corona only visible if it is barly at the edge of the star

        //f does not influence it that much. But I leave it in.
  		vec2 newUv;
 		newUv.x = sphere.x * f;
  		newUv.y = sphere.y * f;
		newUv += vec2( time, 0.0 );

        //Randomness
		vec3 texSample 	= texture2D( tex1, newUv ).rgb; 

        //Random offset on texture call, based on time
		float uOff		= ( texSample.g * brightness * 4.5 + time );

        //Uv coords on the start, offset by the random coords from uOff
		vec2 starUV		= newUv + vec2( uOff, 0.0 );

        //Simple texture call with offset randomy texture coords
		starSphere		= texture2D( tex2, starUV ).rgb;

        if(!ignited)
        {
            vec3 greyScaleWeight = vec3(0.2126, 0.7152, 0.0722); 
            float greyScaleValue = dot(starSphere, greyScaleWeight);

            starSphere = (starSphere + vec3(greyScaleValue)) / 2.0;
            starSphere /= 1.5;
        }
	}


	float starGlow	= clamp(1.0 - dist * ( 1.0 - brightness ), 0.0, 1.0) * 0.7;
	vec4 color = vec4( vec3( f * ( 0.75 + brightness * 0.3 ) * orange ) + starSphere + corona * orange + starGlow * orangeRed, 1.0);

	//The color will go up after a certain distance, cap that.
	color = color * step(dist, radius * 7);

    return color;
}

vec3 render(vec3 camP, vec3 camDir)
{
	
	LightSource source = LightSource(vec3(-sin(iGlobalTime / 2.0) * 80, 0, -cos(iGlobalTime / 2.0) * 80), vec3(1));

	
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

		vec3 colors[4] = vec3[4] (
			vec3(0.2, 0.23, 0.1),   //Core bottom
			vec3(0.35, 0.45, 0.2),	//Core top
			vec3(0.5, 0.35, 0.25),	//Land
			vec3(0.5)				//Mountain
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

		currentCol = vec3(step(rand(camDir.x) + rand(camDir.y) + rand(camDir.z), .01));

		//uniforms can not be minus for some reason -> position has to be negative -> every other positioin is + 1.0
		currentCol += renderSun(true, vec2(sunPosition - 1.0, .5), .1).rgb;
	}

	return currentCol;
}


void main()
{
	uv = gl_FragCoord.xy / iResolution;
	
	const float fov = 80.0;

	vec3 camP = calcCameraPos();


	vec3 color;

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

	gl_FragColor = vec4(color, 1);
}




