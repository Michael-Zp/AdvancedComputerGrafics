#version 330

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

float random(float seed) 
{	
	return fract(sin(seed) * 1231534.9);
}

float random2D(vec2 coord) 
{
	return random(dot(coord, vec2(21.97898, 7809.33123)));
}

//random vector with length 1
vec2 rand2(vec2 seed)
{
	const float pi = 3.1415926535897932384626433832795;
	const float twopi = 2 * pi;
	float r = random2D(seed) * twopi;
	return vec2(cos(r), sin(r));
}


float noise(float value) 
{
	float xPos = floor(value);

	float currentVal = random(xPos);
	float lastVal = random(xPos - 1);

	float weight = fract(value);
	weight = smoothstep(0, 1, weight);

	return mix(lastVal, currentVal, weight);
}

float gnoise(float axisCord) 
{
	float xPos = floor(axisCord);

	float f = fract(axisCord);
	
	float gradient0 = 2 * random(xPos) - 1;
	float gradient1 = 2 * random(xPos + 1) - 1;

	float val0 = random(gradient0) * f;
	float val1 = random(gradient1) * (f - 1);

	float weight = f;
	weight = smoothstep(0, 1, weight);

	return mix(val0, val1, weight) + .5;
}

//gradient noise: random gradient at integer positions with interpolation inbetween
float gnoise(vec2 coord)
{
	vec2 i = floor(coord); // integer position

	//random gradient at nearest integer positions
	vec2 g00 = rand2(i);
	vec2 g10 = rand2(i + vec2(1, 0));
	vec2 g01 = rand2(i + vec2(0, 1));
	vec2 g11 = rand2(i + vec2(1, 1));

	vec2 f = fract(coord);
	float v00 = dot(g00, f);
	float v10 = dot(g10, f - vec2(1, 0));
	float v01 = dot(g01, f - vec2(0, 1));
	float v11 = dot(g11, f - vec2(1, 1));

	vec2 weight = f; // linear interpolation
	weight = smoothstep(0, 1, f); // cubic interpolation

	float x1 = mix(v00, v10, weight.x);
	float x2 = mix(v01, v11, weight.x);
	return mix(x1, x2, weight.y) + 0.5;
}


const float PI = 3.1415926535897932384626433832795;

vec2 rotate2D(vec2 coord, float angle)
{
    mat2 rot =  mat2(cos(angle),-sin(angle), sin(angle),cos(angle));
    return rot * coord;
}

float lines(in vec2 pos, float b){
    float scale = 10.0;
    pos *= scale;

    return smoothstep(0.0,
                    .5+b*.5,
                    abs((sin(pos.y * PI)+b*2.0))*.5);
}

vec3 wood(vec2 coord)
{
	coord = rotate2D(coord, gnoise(coord)); // rotate the space
    float weight = lines(coord, 0.5); // draw lines
	return 	mix(vec3(0), vec3(1), weight);
}

float fBm(float xPos) 
{
	const int OCTAVES = 3;
	float value = 0;

	float lacunarity = 2;
	float gain = .5f;

	float amplitude = 1;
	float frequency = 1;
	
	for(int i = 0; i < OCTAVES; i++) 
	{
		value += amplitude * noise(frequency * xPos - iGlobalTime);

		frequency *= lacunarity;
		amplitude *= gain;
	}

	return value;
}

float fBm2D(vec2 position)
{
	const int OCTAVES = 5;
	float value = 0;

	float lacunarity = 2;
	float gain = .5f;

	float amplitude = 1;
	float frequency = 1;
	
	for(int i = 0; i < OCTAVES; i++) 
	{
		value += amplitude * gnoise(vec2(frequency * position.x - iGlobalTime, frequency * position.y - iGlobalTime));

		frequency *= lacunarity;
		amplitude *= gain;
	}

	return value;
}

float plotFBM(vec2 position, float width) 
{
	float dist = distance(fBm(position.x), position.y);

	return 1 - smoothstep(0, width, dist);
}

float plotFBM2D(vec2 position, float width) 
{
	return 1 - smoothstep(0, width, fBm2D(position));
}

void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec3 color = vec3(uv, 0);

	//color = vec3(random2D(uv));

	//color = vec3(noise(uv, 10));
	//color = vec3(random(floor(uv.x * iResolution.x)));

	//color = vec3(gnoise(uv, 10));

	//color = vec3(wood(.5 + uv.xy * vec2(3., 1)));

	uv -= .5;
	uv *= vec2(10, 5);

	//color = vec3(plotFBM(uv, 0.1));
	color = vec3(plotFBM2D(uv, 2));
	
	
	gl_FragColor = vec4(color, 1);
}