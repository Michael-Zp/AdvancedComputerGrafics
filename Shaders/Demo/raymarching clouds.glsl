#version 330

#include "../libs/camera.glsl" 
#include "../libs/rayIntersections.glsl" 
#include "../libs/noise3D.glsl" //uncomment for simplex noise: slower but more "fractal"
#include "../libs/Noise.glsl"

uniform float iGlobalTime;
uniform vec2 iResolution;

float time = iGlobalTime + 0.7;

// adapted from https://www.shadertoy.com/view/4sfGzS 

//vec3 sundir = normalize( vec3(sin(time), 0.0, cos(time)) );
//vec3 sundir = normalize( vec3(0.0, -1.0, 0.0) );

const int LightCount = 5;

struct Cloud
{
	int id;
	vec3 center;
	vec3 lightPositions[LightCount];
	vec3 baseColor;
};

vec3 sundir(const int index, const vec3 position, const Cloud currCloud) 
{
	//return vec3(0, -1, 0);
	return normalize(currCloud.lightPositions[index] - position);
}


const int STEPS = 350;
const int OCTAVES = 2;

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
	return snoise(x * 0.25); //enable: slower but more "fractal"
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

float densityFunc(const vec3 p, const Cloud currCloud)
{
	if(distance(currCloud.center, p) > 20)
	{
		return 0;
	}

	vec3 q = p;// + vec3(0.0, 0.10, 1.0) * time; //clouds move
	float f = fbm(q, OCTAVES);
	//return clamp(2 * f - p.y, 0, 1);
	//return clamp( 2 * f - p.y - 1, 0.0, 1.0 );

	//Pseudo rotation of cloud
	float xRotation = rand(currCloud.id * 123) * 64 + 20;
	float zRotation = rand(currCloud.id * 321) * 64 + 20;


	if(p.y - currCloud.center.y > -1 || p.y - currCloud.center.y < 1) {
		return clamp(2 * f - p.y - p.x / xRotation - p.z / zRotation + currCloud.center.y, 0, 1);
	}
	else {
		return 0;
	}
}

vec3 lighting(const vec3 pos, const float cloudDensity
			, const vec3 backgroundColor, const float pathLength, const Cloud currCloud )
{
	float densityLightDir = 0;
	for(int i = 0; i < LightCount; i++) 
	{
		densityLightDir += densityFunc(pos + 0.3 * sundir(i, pos, currCloud), currCloud);
	}
	densityLightDir /= LightCount;

	float gradientLightDir = clamp(cloudDensity - densityLightDir, 0.0, 1.0);
			
    vec3 litColor = currCloud.baseColor / 3 + currCloud.baseColor * 2.0 * gradientLightDir;        
	vec3 cloudAlbedo = mix( currCloud.baseColor * 3, vec3(0.25, 0.3, 0.35), cloudDensity );

	const float extinction = 0.0003;
	float transmittance = exp( -extinction * pathLength );
    return mix(backgroundColor, cloudAlbedo * litColor, transmittance );
}


vec4 raymarchClouds(const Ray ray, const vec3 backgroundColor, const Cloud currCloud )
{
	vec4 sum = vec4(0.0);
	float t = 0.0;
	float minDist = 0;
	float maxDist = 10;
	vec3 pos = vec3(0);
	for(int i = 0; i < STEPS; i++)
	{
		pos = ray.origin + t * ray.dir;
		if( 0.99 < sum.a ) break; //break if opaque
		float cloudDensity = densityFunc( pos, currCloud );


		if( .7 < cloudDensity ) // if not empty -> light and accumulate 
		{
			vec3 colorRGB = lighting( pos, cloudDensity, backgroundColor, t, currCloud );
			float alpha = cloudDensity * 0.4;
			vec4 color = vec4(colorRGB * alpha, alpha);
			sum += color * ( 1.0 - sum.a ); //blend-in new color contribution

			minDist = distance(pos, currCloud.lightPositions[0]);
			for(int k = 1; k < LightCount; k++)
			{
				minDist = min(minDist, distance(pos, currCloud.lightPositions[k]));
			}

			if(minDist + pow(noise(ray.dir.xy) * 1.5, noise(iGlobalTime) * 3) > maxDist)
			{
				//Some kind of bug which cuts of the edges of the cloud
				//sum = vec4(0);
				break;
			}
		}
		t += max( 0.05, 0.02 * t ); //step size at least 0.05, increase t with each step
	}

	sum = mix(sum, vec4(0), (minDist / maxDist) < .65 ? (minDist / maxDist) / 3 : (minDist / maxDist));

    return clamp( sum, 0.0, 1.0 );
}

vec3 render(Ray ray, const Cloud currCloud)
{
	float hitsClouds = sphere(currCloud.center, 18, ray, 1e-5);

	if(hitsClouds <= -1) 
	{
		return vec3(0);
	}
	else 
	{
		ray.origin = ray.origin + ray.dir * hitsClouds;
	}

    // background sky

	float sun = 0;
	for(int i = 0; i < LightCount; i++) 
	{
		sun = max(sun, clamp( dot( sundir(i, ray.origin, currCloud), ray.dir ), 0.0, 1.0 ));
	}

	vec3 backgroundSky =  0.05 * vec3( 1.0, 0.6, 0.1 ) * pow( sun, 40.0 );


    // clouds    
    vec4 res = raymarchClouds( ray, backgroundSky, currCloud );
    vec3 col = backgroundSky * ( 1.0 - res.a ) + res.rgb; // blend clouds with sky
    
    // add sun glare    
	col += .3 * (currCloud.baseColor * 2) * pow( sun, 200 );

	if(length(col) < 0.04f) 
	{
		return col;
	}

	//base seed should be >= 1
	int baseSeed = currCloud.id * currCloud.id + 1;
	float maxSunsT = -1;
	for(int i = 0; i < 15; i++) 
	{
		const float xDiameter = 18;
		const float zDiameter = 22;
		vec3 pos = currCloud.center;
		pos.x += rand(baseSeed * 5 + i) * xDiameter - xDiameter/2;
		pos.z += rand(baseSeed * 1785 + i) * zDiameter - zDiameter/2;

		maxSunsT = max(maxSunsT, sphere(pos, .2f + rand(i + currCloud.id) * .05f, ray, 1e-5));
	}

	
	float maxBlackHolesT = -1;
	for(int i = 0; i < 15; i++) 
	{
		const float xDiameter = 22;
		const float zDiameter = 30;
		vec3 pos = currCloud.center;
		pos.x += rand(baseSeed * 3 + i + 651816) * xDiameter - xDiameter/2;
		pos.z += rand(baseSeed * 1785 + i -8684) * zDiameter - zDiameter/2;

		maxBlackHolesT = max(maxBlackHolesT, sphere(pos, .2f + rand(i + currCloud.id) * .15f, ray, 1e-5));
	}

	if (maxSunsT > -1)
	{
		return vec3(.2f) + col;
	}
	
	if (maxBlackHolesT > -1) 
	{
		return col / 3;
	}

	return col;
}

Cloud initCloud(const int id, const vec3 center)
{
	Cloud tempCloud;
	tempCloud.id = id;
	tempCloud.center = center;

	vec3 baseColors[7] = vec3[7]( 
		vec3(0, 0, 1),
		vec3(0, 1, 0),
		vec3(0, 1, 1),
		vec3(1.5, 0, 0),
		vec3(1, 0, 1),
		vec3(1.5, 1.5, 0),
		vec3(1, 1, 1)
	);

	tempCloud.baseColor = baseColors[int(floor(rand(id) * 7))];
	

	tempCloud.lightPositions[0] = vec3(rand(123 * id + 0) * -8     , -2, rand(123 * id + 1) * -8) + center;
	tempCloud.lightPositions[1] = vec3(rand(123 * id + 2) *  8     , -2, rand(123 * id + 3) * -8) + center;
	tempCloud.lightPositions[2] = vec3(rand(123 * id + 4) *  8     , -2, rand(123 * id + 5) *  8) + center;
	tempCloud.lightPositions[3] = vec3(rand(123 * id + 6) * -8     , -2, rand(123 * id + 7) *  8) + center;
	tempCloud.lightPositions[4] = vec3(rand(123 * id + 8) *  16 - 8, -2, rand(123 * id + 9) *  16 - 8) + center;

	return tempCloud;
}

void main()
{
	vec3 camP = calcCameraPos();
	camP.y += 50;
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);

	vec3 color = vec3(0);

	for(int k = 0; k < 400; k++)
	{
		int id = k;
		float yDepth = 150 + (rand(id) * 20 - 40) + 40 * k;

		float row = floor(rand(k) * 4);
		float column = k % 4;

		vec2 xzPos = vec2(0);
		float spread = 160 + yDepth / 1.5;
		xzPos.x = -spread + column * (spread / 2) + spread / 4 + rand(id * 123) * spread / 2 - spread / 4;
		xzPos.y = -spread + row * (spread / 2) + spread / 4 + rand(id * 321) * spread / 2 - spread / 4;

		//vec2 xzPos = vec2(rand(id * 123) * 2 - 1, rand(id * 321) * 2 - 1);
		//xzPos = normalize(xzPos) * (rand(id * 222) * (160 * (i + 1)));

		color += render( Ray( camP, camDir ), initCloud(id, vec3(xzPos.x, -yDepth, xzPos.y)));
	}

	//11111111.. is just a cloud that look kinda nice
	Cloud targetCloud = initCloud(1111111111, vec3(0, -10970, 0));
	targetCloud.baseColor = vec3(0, 1, 0);

	color += render( Ray( camP, camDir ), targetCloud);


    gl_FragColor = vec4(color, 1.0 );
}



