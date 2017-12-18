#version 330

uniform vec2 iResolution;
uniform float iGlobalTime;
uniform vec3 iMouse;
uniform sampler2D texLastFrame;
uniform sampler2D tex0;

uniform float iThicknessRadius = 0.01;
uniform float iSoftness = 0.01;
uniform vec4 iDrawColor = vec4(0.3, 0.6, 0.4, 1.0);

in vec2 uv;

vec4 oldColor() {
	return texture2D(texLastFrame, uv);
}

float drawValue()
{
	// here pixels of a circle
	float aspect = iResolution.x / iResolution.y;
	vec2 pos = uv;
	pos.x *= aspect;
	vec2 pmouse = iMouse.xy / iResolution;
	pmouse.x *= aspect;
	float leftDown = clamp(iMouse.z, 0.0, 1.0);
	float circle = 1.0 - smoothstep(iThicknessRadius, iThicknessRadius + iSoftness, distance(pmouse, pos));
	return leftDown * circle;
}

vec4 textureValue() 
{
	float aspect = iResolution.x / iResolution.y;
	vec2 pos = uv;
	pos.x *= aspect;
	vec2 pmouse = iMouse.xy / iResolution;
	pmouse.x *= aspect;
	float leftDown = clamp(iMouse.z, 0.0, 1.0);
	float xCircle = 0.5 - smoothstep(iThicknessRadius/2, -iThicknessRadius/2, pmouse.x - pos.x);
	float yCircle = 0.5 - smoothstep(iThicknessRadius/2, -iThicknessRadius/2, pmouse.y - pos.y);
	
	float inXBounds = 1 - step(iThicknessRadius/2, abs(pmouse.x - pos.x));
	float inYBounds = 1 - step(iThicknessRadius/2, abs(pmouse.y - pos.y));

	return texture(tex0, vec2(.5) - vec2(xCircle, yCircle)) * leftDown * inXBounds * inYBounds;
}

vec4 waterColor() 
{	
	float aspect = iResolution.x / iResolution.y;
	vec2 pos = uv;
	pos.x *= aspect;
	vec2 pmouse = iMouse.xy / iResolution;
	pmouse.x *= aspect;

	float leftDown = clamp(iMouse.z, 0, 1);

	if(distance(pmouse, pos) > iThicknessRadius + iSoftness) 
	{
		return oldColor();
	}
	else if(leftDown > 0 && distance(pmouse, pos) > iThicknessRadius)
	{
		return mix(iDrawColor * drawValue(), oldColor(), distance(pmouse, pos));
	}
	else if(leftDown > 0)
	{
		return iDrawColor * leftDown + oldColor();
	}
	else
	{
		return oldColor();
	}
}

vec4 seedFloodFill() 
{
	vec2 pos = gl_FragCoord.xy / iResolution;
	vec2 pmouse = iMouse.xy / iResolution;
	
	if(distance(pos, pmouse) < 0.002) 
	{
		return vec4(iDrawColor.xyz, 2.0);
	}
	

	return oldColor();
}

vec4 floodFill(vec4 color)
{
	vec2 pixelDist = vec2(1) / iResolution;
	float maxAlpha = color.a;

	
	for(int x = -1; x <= 1; x++)
	{
		for(int y = -1; y <= 1; y++)
		{
			maxAlpha = max(maxAlpha, texture(texLastFrame, uv + vec2(pixelDist.x * x, pixelDist.y * y)).a);
		}
	}
	

	float isAtSeed = step(1.5, maxAlpha);


	return isAtSeed * vec4(iDrawColor.xyz, 2.0) + (1 - isAtSeed) * color;
}

vec4 floodFillCircle(vec4 color)
{
	vec2 pixelDist = vec2(1) / iResolution;
	
	float lT = texture(texLastFrame, uv + vec2(pixelDist.x * -1, pixelDist.y *  1)).a;
	float mT = texture(texLastFrame, uv + vec2(pixelDist.x *  0, pixelDist.y *  1)).a;
	float rT = texture(texLastFrame, uv + vec2(pixelDist.x *  1, pixelDist.y *  1)).a;
	
	float lM = texture(texLastFrame, uv + vec2(pixelDist.x * -1, pixelDist.y *  0)).a;
	float rM = texture(texLastFrame, uv + vec2(pixelDist.x *  1, pixelDist.y *  0)).a;
	
	float lB = texture(texLastFrame, uv + vec2(pixelDist.x * -1, pixelDist.y * -1)).a;
	float mB = texture(texLastFrame, uv + vec2(pixelDist.x *  0, pixelDist.y * -1)).a;
	float rB = texture(texLastFrame, uv + vec2(pixelDist.x *  1, pixelDist.y * -1)).a;
	
	
	float bottomThirdAlpha = max( lB, max( mB, rB ));
	float leftThirdAlpha = max( lT, max( lM, lB ));
	float topThirdAlpha = max( lT, max( mT, rT ));
	float rightThirdAlpha = max( rT, max( rM, rB ));
	float leftBotTriangle = max( lM, max( lB, mB ));
	float leftTopTriangle = max( lM, max( lT, mT ));
	float rightBotTriangle = max( rM, max( rB, mB ));
	float rightTopTriangle = max( rM, max( rT, mT ));

	float maxAlpha = max( bottomThirdAlpha, max( leftThirdAlpha, max( topThirdAlpha, max( rightThirdAlpha, max( leftBotTriangle, max( leftTopTriangle, max( rightBotTriangle, rightTopTriangle)))))));

	float isAtSeed = step(1.5, maxAlpha);


	return isAtSeed * vec4(iDrawColor.xyz, 2.0) + (1 - isAtSeed) * color;
}

void main() 
{
	vec4 color = iDrawColor * drawValue() + oldColor();
	//vec4 color = textureValue() * .2f + oldColor();
	//vec4 color = waterColor();  //Not working
	float rightDown = step(2.5, iMouse.z) * step(iMouse.z, 3.5);

	color = rightDown * seedFloodFill() + (1 - rightDown) * color;
	color = color.a > 0 ? color : floodFillCircle(color);
	//color = clamp(color, vec4(0), vec4(2.0 - iMouse.z)); //reset with all other mouse buttons
	gl_FragColor = color;
}
