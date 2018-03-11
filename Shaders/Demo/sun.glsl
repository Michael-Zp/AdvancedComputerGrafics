// Fork of the main sequence star by flight404: https://www.shadertoy.com/view/4dXGR4
// Without the music of course.
// based on https://www.shadertoy.com/view/lsf3RH by
// trisomie21 (THANKS!)
// My apologies for the ugly code.

uniform float iGlobalTime;
uniform vec2 iResolution;

uniform sampler2D tex0;
uniform sampler2D tex1;

in vec2 uv;

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
	vec4 color      = vec4( vec3( f * ( 0.75 + brightness * 0.3 ) * orange ) + starSphere + corona * orange + starGlow * orangeRed, 1.0);

    return color;
}


void main()
{
    gl_FragColor = renderSun(true, vec2(.5), 1);
}