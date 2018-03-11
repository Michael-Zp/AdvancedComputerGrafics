#version 330

#include "../libs/camera.glsl" 
#include "../libs/rayIntersections.glsl" 
#include "../libs/Noise.glsl"
#include "../libs/noise3D.glsl"

uniform float iGlobalTime;
uniform vec2 iResolution;
uniform sampler2D texLastFrame0;
uniform sampler2D texLastFrame1;
uniform sampler2D texLastFrame2;
uniform sampler2D texLastFrame3;
uniform sampler2D texLastFrame4;
uniform sampler2D tex0;
uniform sampler2D tex1;

out vec4 color; 		//Really the color
out vec4 sphereData; 	//vec3 center; float radius
out vec4 physicsData; 	//vec3 velocity; float mass
out vec4 miscData; 		//float hitSun; null; null; LastTime/PixelIsInitialized
out vec4 unstuckData; 	//float SphereIsUnstuck

vec2 uv;

const float EPSILON = 1e-5;
const int sphereCount = 30;
vec2 lastTimeXY = vec2(1);

struct PhysicsSphere
{
	vec3 center;
	float radius;
	vec3 velocity;
	float mass;
	float hitSun;
};

struct GravityCenter
{
	vec3 center;
	float mass;
};

//Working but fast
//const GravityCenter gravityCenter = GravityCenter(vec3(0, 0, 500), 100000000000000000.0);


const GravityCenter gravityCenter = GravityCenter(vec3(0, 0, 500), 10000000000000000.0);

//Bind out variables to textures. tex0 will be displayed
//Has to be called in every function, that will set these parameters!! -> Can not be in a function thus macro
#define BINDOUTPUTS color = color; sphereData = sphereData; physicsData = physicsData; miscData = miscData; unstuckData = unstuckData;


vec2 getIdOfSphere(int i)
{
	float size = 200;
	float row = floor(i / size);
	float column = mod(i, size);

	return vec2(row, column) + vec2(10);
}

void cleanLastTexts() 
{
	BINDOUTPUTS

	color = vec4(0);
	sphereData = vec4(1);
	physicsData = vec4(0);
	miscData = vec4(-1, 0, -1, -1);
	unstuckData = vec4(-1);
}

vec2 coordsOfSave(vec2 pos)
{
	return (pos + fract(gl_FragCoord.xy)) / iResolution;
}

float pSphere(PhysicsSphere currSphere, Ray ray)
{
	return sphere(currSphere.center, currSphere.radius, ray, EPSILON);
}

void saveSphere(PhysicsSphere currSphere)
{
	BINDOUTPUTS

	sphereData.xyz = currSphere.center;
	sphereData.w = currSphere.radius;
	physicsData.xyz = currSphere.velocity;
	physicsData.w = currSphere.mass;
	miscData.x = currSphere.hitSun;
}

float getGravityForceOnSphere(PhysicsSphere currSphere, float distanceSphereCenter)
{
	const float gravitationalConstant = 6.674e-11;

	float forceBetweenObjects = gravitationalConstant * ((currSphere.mass * gravityCenter.mass) / (pow(distanceSphereCenter, 2)));
	return forceBetweenObjects / currSphere.mass; //F = m * a -> a = F / m
}

bool areSpheresUnstuck()
{
	if(texture2D(texLastFrame4, uv).x == -1)
	{
		return false;
	}
	
	return true;
}

PhysicsSphere unstuckSpheres(PhysicsSphere currSphere, PhysicsSphere[sphereCount] others, int currSphereIndex)
{
	BINDOUTPUTS

	bool sphereIsStuck = true;

	while(sphereIsStuck)
	{
		for(int i = 0; i < sphereCount; i++)
		{
			if(i == currSphereIndex)
				continue;

			PhysicsSphere other = others[i];

			//Colliders are bigger then the spheres to create more collisions
			if(distance(currSphere.center, other.center) < (currSphere.radius + other.radius) * 1.25) 
			{
				//Move spheres that are entangled into each other (especially at spawn)
				vec3 moveVector;
				if(other.center - currSphere.center == vec3(0))
				{
					moveVector = vec3(rand(iGlobalTime * currSphereIndex + i * 123), rand(iGlobalTime * i + currSphereIndex * 321), 0);
				}
				else
				{
					moveVector = other.center - currSphere.center;
				}

				currSphere.center = other.center + normalize(moveVector) * (currSphere.radius + other.radius) * 1.5;
			}
		}

		sphereIsStuck = false;

		for(int i = 0; i < sphereCount; i++)
		{
			if(i == currSphereIndex)
				continue;

			PhysicsSphere other = others[i];

			if(distance(currSphere.center, other.center) < (currSphere.radius + other.radius) * 1.25) 
			{
				sphereIsStuck = true;
				break;
			}
		}
	}

	return currSphere;
}

const float maxFramesAfterSunCollision = 15;

PhysicsSphere updateSphere(PhysicsSphere currSphere, PhysicsSphere[sphereCount] others, int currSphereIndex)
{
	BINDOUTPUTS

	float lastTime = texture2D(texLastFrame3, coordsOfSave(lastTimeXY)).a;
	float difTime = iGlobalTime - lastTime;


	//Collision
	for(int i = 0; i < sphereCount; i++)
	{
		if(i == currSphereIndex)
			continue;

		PhysicsSphere other = others[i];

		//Colliders are bigger then the spheres to create more collisions
		if(distance(currSphere.center, other.center) < (currSphere.radius + other.radius) * 1.25) 
		{
			float averageVelocityLength = (length(currSphere.velocity) + length(other.velocity)) / 2;

			vec3 reflectedVelocity = vec3(0);

			if(currSphere.velocity != vec3(0))
			{
				reflectedVelocity = reflect(currSphere.velocity, normalize(currSphere.center - other.center));
				reflectedVelocity = normalize(reflectedVelocity);
			}
			else if (other.velocity != vec3(0))
			{
				reflectedVelocity = -reflect(other.velocity, normalize(other.center - currSphere.center));
				reflectedVelocity = normalize(reflectedVelocity);
			}

			currSphere.velocity += reflectedVelocity * averageVelocityLength * 0.01;

			//Move spheres that are entangled into each other (especially at spawn)
			vec3 moveVector;
			if(other.center - currSphere.center == vec3(0))
			{
				moveVector = vec3(rand(iGlobalTime * currSphereIndex + i * 123), rand(iGlobalTime * i + currSphereIndex * 321), 0);
			}
			else
			{
				moveVector = other.center - currSphere.center;
			}

			currSphere.center = other.center + normalize(moveVector) * (currSphere.radius + other.radius) * 1.25;
		}
	}


	//Drag

	currSphere.velocity += (-currSphere.velocity * difTime * 0.01);


	//Gravity
	float distanceSphereCenter = distance(currSphere.center, gravityCenter.center);

	if(distanceSphereCenter > 55)
	{
		float acceleration = getGravityForceOnSphere(currSphere, distanceSphereCenter);

		vec3 accelDir = normalize(gravityCenter.center - currSphere.center) * acceleration;

		currSphere.velocity += (accelDir * difTime);
	}
	else
	{
		currSphere.radius = 0;

		currSphere.hitSun = clamp(currSphere.hitSun + 1, 0, maxFramesAfterSunCollision);

		float speed = length(currSphere.velocity);

		speed /= 1.3;

		speed = clamp(speed, 100, 400);

		currSphere.velocity = normalize(currSphere.velocity) * speed;
	}

	currSphere.center += currSphere.velocity * difTime;
	
	return currSphere;
}

PhysicsSphere loadSphere(vec2 pos)
{
	vec2 coords = coordsOfSave(pos);

	PhysicsSphere currSphere;
	vec4 sData = texture2D(texLastFrame1, coords);
	vec4 pData = texture2D(texLastFrame2, coords);
	vec4 mData = texture2D(texLastFrame3, coords);

	currSphere.center = sData.xyz;
	currSphere.radius = sData.w;
	currSphere.velocity = pData.xyz;
	currSphere.mass = pData.w;
	currSphere.hitSun = mData.x;

	return currSphere;
}

bool initalize()
{
	if(texture2D(texLastFrame3, uv).a == -1)
	{
		BINDOUTPUTS

		for(int i = 0; i < sphereCount; i++)
		{
			vec2 id = getIdOfSphere(i);
			if(uv == coordsOfSave(id))
			{
				//Position in spiral
				const float PI = 3.1415;
				const float TAU = 2 * PI;

				float distRatio = rand(i);
				float dist = distRatio * 200 + 100;
				float circlePos = distRatio * 2 * TAU;
				vec2 position = vec2(sin(circlePos), cos(circlePos)) * dist;
				
				float xPos = position.x;
				float yPos = position.y;
				float zPos = 300;
				float radius = 6.5 - rand(i * 113);
				float mass = 1;


				//Counter gravity
				PhysicsSphere currSphere = PhysicsSphere(vec3(xPos, yPos, zPos), radius, vec3(0, 0, 0), mass, 0);

				float gravity = getGravityForceOnSphere(currSphere, distance(currSphere.center, gravityCenter.center));

				float s = sin(PI / 2);
				float c = cos(PI / 2);

				mat2 rotation = mat2(c, s, -s, c);

				float gravityRatio = 3 - 3 * distRatio;
				gravityRatio = clamp(gravityRatio, 1, 3);
				vec2 perpendicularVelocityToGravity = normalize(rotation * position) * gravity / gravityRatio;

				perpendicularVelocityToGravity = normalize(rotation * position) * gravity;


				currSphere.velocity += vec3(perpendicularVelocityToGravity * 2, 0);

				saveSphere(currSphere);
			}
		}
		
		if(uv == coordsOfSave(lastTimeXY))
		{
			miscData.a = iGlobalTime;
		}
		else 
		{
			miscData.a = 0;
		}

		return true;
	}

	return false;
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

	freqs[0] = texture2D( tex1, vec2( 0.01, 0.25 ) ).x;
	freqs[1] = texture2D( tex1, vec2( 0.07, 0.25 ) ).x;
	freqs[2] = texture2D( tex1, vec2( 0.15, 0.25 ) ).x;
	freqs[3] = texture2D( tex1, vec2( 0.30, 0.25 ) ).x;

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
		vec3 texSample 	= texture2D( tex0, newUv ).rgb; 

        //Random offset on texture call, based on time
		float uOff		= ( texSample.g * brightness * 4.5 + time );

        //Uv coords on the start, offset by the random coords from uOff
		vec2 starUV		= newUv + vec2( uOff, 0.0 );

        //Simple texture call with offset randomy texture coords
		starSphere		= texture2D( tex1, starUV ).rgb;

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


const float DELTA = 0.01;
const float STEPS = 100;

vec4 render(PhysicsSphere[sphereCount] spheres, Ray ray) 
{
	//Calculate color of the image
	float t = -1;
	int currIndex = -1;
	vec3 currentCol = vec3(0);
	for(int i = 0; i < sphereCount; i++)
	{
		float tempT = pSphere(spheres[i], ray);
		if(tempT != -1)
		{
			if(t == -1)
			{
				t = tempT;
			}
			else
			{
				t = min(t, tempT);
			}

			currIndex = i;
		}
	}

	if(t == -1)
	{
		return vec4(0);
	}

	PhysicsSphere sphere = spheres[currIndex];

	vec3 rayMarchStartPoint = ray.origin + ray.dir * t;
	
	if(t != -1)
	{
		vec3 pos = rayMarchStartPoint;
		float value = 0;
		float endHeight = sphere.radius;
		float delta = DELTA;

		float endHeightRatio = 2;
		float minHeight = sphere.radius * .85;
		float minToMaxHeight = sphere.radius - minHeight;

		for(int i = 0; i < STEPS; i++)
		{
			pos = pos + ray.dir * delta;

			vec3 centerToPos = normalize(pos - sphere.center);
			vec3 posOnSphereEdge = centerToPos * sphere.radius; //Position is relative. The real position in the room would be this + sphere.center;
			float heightRatio = snoise(posOnSphereEdge / 3.5 + vec3(currIndex));
			float heightAtPos = heightRatio * minToMaxHeight + minHeight;
			float currentHeight = length(pos - sphere.center);

			if(currentHeight < heightAtPos)
			{
				endHeightRatio = heightRatio;
				break;
			}

			delta *= 1.05;
		}

		currentCol = mix(vec3(.25, .15, .05) / 2.5, vec3(.25, .15, .05) / 1.5, endHeightRatio);

		float didNotHit = step(endHeightRatio, 1);

		currentCol *= didNotHit;
	}
	else 
	{
		currentCol = vec3(0);
	}


	return currentCol;
}



void main()
{
	uv = gl_FragCoord.xy / iResolution;

	BINDOUTPUTS

	//cleanLastTexts(); return;

	//DEBUG
	//color = texture2D(texLastFrame0, uv);

	//Recover old state 
	color = vec4(0); //Reset color state each frame -> Will be done in the background either way but it wont cost any performance and is better for readability
	sphereData = texture2D(texLastFrame1, uv);
	physicsData = texture2D(texLastFrame2, uv);
	miscData = texture2D(texLastFrame3, uv);
	unstuckData = texture2D(texLastFrame4, uv);

	const float fov = 80.0;
	vec3 camP = calcCameraPos();
	vec3 camDir = calcCameraRayDir(fov, gl_FragCoord.xy, iResolution);

	//Initialisierung and loading of all spheres
	if(initalize())
	{
		return;
	}

	//Load spheres
	PhysicsSphere[sphereCount] spheres;

	for(int i = 0; i < sphereCount; i++)
	{
		vec2 id = getIdOfSphere(i);
		spheres[i] = loadSphere(id);
	}

	//Unstuck spheres
	if(!areSpheresUnstuck())
	{
		unstuckData.x = 0.0;
		for(int i = 0; i < sphereCount; i++)
		{
			if(uv == coordsOfSave(getIdOfSphere(i)))
			{
				PhysicsSphere newSphere = unstuckSpheres(spheres[i], spheres, i);
				saveSphere(newSphere);
				spheres[i] = newSphere;
			}
		}
		return;
	}


	float currentFrameInSunCollisionMixFactor = 0;
	vec4 sunCollisionColor = vec4(0);
	vec2 closestCollidedWithSunUv = vec2(0);
	bool somethingColided = false;
	float sunHitCount = 0;
	
	for(int i = 0; i < sphereCount; i++)
	{
		if(spheres[i].hitSun < maxFramesAfterSunCollision && spheres[i].hitSun > 0)
		{
			//Reverse the camera direction from the center to get the uv pos at the point

			vec3 camDirToCenter = normalize(camP - spheres[i].center);
			
			float fx = tan(radians(fov) / 2.0) / iResolution.x;
			vec2 fc = camDirToCenter.xy / (2 * fx) + iResolution.xy;
			vec2 centerUv = iResolution.xy / fc.xy;
			centerUv -= vec2(.5);

			/*
			float fx = tan(radians(fov) / 2.0) / resolution.x;
			vec2 d = fx * (fragCoord * 2.0 - resolution);
			vec3 rayDir = normalize(vec3(d, 1.0));

			d = fx * (fc * 2.0 - resolution);
			d = fx * fc * 2.0 - fx * resolution
			d + fx * resolution = fx * fc * 2.0
			d / (2 * fx) + (2 * fx * resolution) / (2 * fx)
			d / (2 * fx) + resolution = fc
			*/

			if(!somethingColided)
			{
				somethingColided = true;
				closestCollidedWithSunUv = centerUv;

				currentFrameInSunCollisionMixFactor = max(currentFrameInSunCollisionMixFactor, spheres[i].hitSun / maxFramesAfterSunCollision);
			}
			else
			{
				if(distance(uv, centerUv) < distance(uv, closestCollidedWithSunUv))
				{
					closestCollidedWithSunUv = centerUv;
					currentFrameInSunCollisionMixFactor = max(currentFrameInSunCollisionMixFactor, spheres[i].hitSun / maxFramesAfterSunCollision);
				}
			}
		}

		sunHitCount += step(14.5, spheres[i].hitSun);
	}

	if(somethingColided)
	{
		float invertedMixFactor = 1 / currentFrameInSunCollisionMixFactor;
		invertedMixFactor /= maxFramesAfterSunCollision;
		invertedMixFactor = min(invertedMixFactor * 4, 1);

		float defaultRadius = 0.01;
		float collisionRadius = defaultRadius * invertedMixFactor;

		if(distance(uv, closestCollidedWithSunUv) < collisionRadius)
		{
			sunCollisionColor = clamp(renderSun(true, closestCollidedWithSunUv, collisionRadius) * 8, vec4(0), vec4(1));
		}
		else
		{
			currentFrameInSunCollisionMixFactor = 0;
		}
	}


/*
	vec3 colors[3] = vec3[3]( 
		vec3(1, 0, 0),
		vec3(0, 1, 0),
		vec3(0, 0, 1)
	);

	//Calculate color of the image
	float t = -1;
	vec3 currentCol = vec3(0);
	for(int i = 0; i < sphereCount; i++)
	{
		float tempT = pSphere(spheres[i], Ray(camP, camDir));
		if(t < tempT)
		{
			t = tempT;
			currentCol = colors[i % 3];
		}
	}

	color = vec4(currentCol, 1);
	//color += texture2D(texLastFrame0, uv);
	//color = abs(texture2D(texLastFrame1, uv));

*/
	color += render(spheres, Ray(camP, camDir));
	
	vec4 ignitedColor = renderSun(true, vec2(.5), .1);
	vec4 notIgnitedColor = renderSun(false, vec2(.5), .1);
	vec4 sunColor = mix(notIgnitedColor, ignitedColor, sunHitCount / sphereCount);

	color += sunColor;

	color = mix(color, sunCollisionColor, pow(currentFrameInSunCollisionMixFactor, 2));

	//Update and save the state
	for(int i = 0; i < sphereCount; i++)
	{
		if(uv == coordsOfSave(getIdOfSphere(i)))
		{
			PhysicsSphere newSphere = updateSphere(spheres[i], spheres, i);
			saveSphere(newSphere);
			spheres[i] = newSphere;

			//saveSphere(spheres[i]);
		}
	}

	if(uv == coordsOfSave(lastTimeXY))
	{
		miscData.a = iGlobalTime;
	}
}