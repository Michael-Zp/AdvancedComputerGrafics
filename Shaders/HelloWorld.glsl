#version 330

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]
	
vec3 giveTriangle(vec2, float);
float random(float);
float select(float, float, float);
vec3 giveStraightLine(float, float, float, vec2);
vec3 giveGridOfRandomTriangles(float, int, int, vec2);
vec3 giveGridOfRectangles(vec2, vec3, vec2, vec2, int, int);
vec3 giveRectangleAt(vec2, vec2, vec3, vec2);
vec3 giveSmoothRectangleAt(vec2, vec2, float, float, vec3, vec2);
vec3 giveCicle(vec2, float, float, float, vec2, vec3);
vec3 sinLine(vec2, float, float, vec2);

void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(uv, 0, 1);
	// color =  vec4(vec3(1.0) - vec3(mouse.y, mouse.x, 1), 1); //line i
	// color.rgb = vec3(step(abs((sin(iGlobalTime) + 1) / 2), uv.y * uv.x)); //line ii
	// color.rgb = vec3(step(0.5, uv.x));
	// color.rgb = vec3(smoothstep(0.35, 0.65, uv.y * uv.x)); //line iii
	// color.rgb = vec3(step(0.5, uv.x) * step(0.5, uv.y)); //line iv
	// vec3 top = vec3(1) - vec3(step(0.7, uv.y));
	// vec3 right = vec3(1) - vec3(step(0.7, uv.x));
	// color.rgb *= top * right * vec3(1, 0, 0);

	/*color.rgb = giveRectangleAt(vec2(.0 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .8), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.2 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .8), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.4 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .8), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.6 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .8), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.8 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .8), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);

	color.rgb += giveRectangleAt(vec2(.1 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .6), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.3 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .6), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.5 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .6), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.7 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .6), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.9 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .6), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);

	color.rgb += giveRectangleAt(vec2(.0 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .4), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.2 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .4), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.4 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .4), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.6 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .4), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.8 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .4), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	
	color.rgb += giveRectangleAt(vec2(.1 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .2), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.3 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .2), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.5 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .2), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.7 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .2), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.9 - (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .2), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	
	color.rgb += giveRectangleAt(vec2(.0 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .0), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.2 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .0), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.4 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .0), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.6 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .0), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	color.rgb += giveRectangleAt(vec2(.8 + (abs(sin(3 * iGlobalTime) + 1) / 2) * .1, .0), vec2(.1, .2), vec3(uv.x,uv.y,uv.x * uv.y), uv);
	
	*/

	/*
	int rectsInX = 5;
	int rectsInY = 5;

	float xShift = step(0, mod(iGlobalTime, 12)) * iGlobalTime;
	float yShift = (1 - step(0, mod(iGlobalTime, 12))) * iGlobalTime;

	color.rgb = giveGridOfRectangles(vec2(.7), vec3(1, 1, 1), vec2(uv.x, uv.y), vec2(xShift, yShift), rectsInX, rectsInY);

	color.rgba *= vec4(uv, 0, 1);
	*/

	/*
	float rand = random(5) * 4;

	//color.rgb = vec3(rand);

	color.rgb = giveTriangle(uv, rand);

	//color.rgb = vec3(step(rand, uv.x));

	//color.rgb = giveRectangleAt(vec2(0), vec2(1), vec3(rand), uv);
	*/
	
	color.rgb = giveGridOfRandomTriangles(0, 5, 5, uv);


	//color.rgb = giveSmoothRectangleAt(vec2(0), vec2(.3f), vec2(.3f), vec3(1,0,0), uv);

	/*vec2 uv_with_ratio = gl_FragCoord.xy / iResolution.y;

	color.rgb = giveCicle(vec2(.25f), .1f, .1f, .05f, uv_with_ratio, vec3(uv.x, uv.y, 0));
	color.rgb += giveCicle(vec2(.75f), .1f, .1f, .05f, uv_with_ratio, vec3(uv.x, 0, uv.y));
	color.rgb += giveCicle(vec2(.45f, .8f), .1f, .1f, .05f, uv_with_ratio, vec3(0, uv.x, uv.y));*/

	// vec2 corner = step(vec2(0.5), uv);
	// color.rgb = vec3(corner.x * corner.y); //line v
	
	//uv.x = uv.x * 10;
	//color.rgb = sinLine(uv, 0.05f, .02f, mouse);

	//color.rgb = giveStraightLine(.3f, .4f, .05f, uv);

	gl_FragColor = color;

}

vec3 giveTriangle(vec2 position, float type) {

	/*
	//Function					     // Left Top Right Bottom
	step(position.x, position.y);    // W	 W	 B     B
	step(position.y, position.x);    // B    B   W     W
	step(1 - position.x, position.y) // B    W   W     B
	step(1 - position.y, position.x) // W    B   B     W
	*/

	return step(position.x, position.y) * select(0, 1, type) + \
		   step(position.y, position.x) * select(1, 2, type) + \
		   step(1 - position.x, position.y) * select(2, 3, type) + \
		   step(position.x, 1 - position.y) * select(3, 4, type);
}

float random(float seed) {
	return fract(sin(seed * 314720.91723) * 7146502.7692);
}


vec3 giveStraightLine(float startHeight, float steigung, float thickness, vec2 position) {
	
	float pointOnLine = steigung*position.x + startHeight;
	float distanceMidToPos = abs(distance(vec2(position.x, pointOnLine), position));


	return vec3(step(thickness, distanceMidToPos) * vec3(1, 0, 0));
}

vec3 giveGridOfRandomTriangles(float seed, int rectsInX, int rectsInY, vec2 position) {
	float type = random(seed + floor(rectsInX * position.x) * rectsInX + floor(rectsInY * position.y)) * 4;
	
	position.x *= rectsInX;
	position.y *= rectsInY;

	return giveTriangle(fract(position), type);
}

vec3 giveGridOfRectangles(vec2 size, vec3 colour, vec2 position, vec2 shift, int rectsInX, int rectsInY) {

	float marginX = (1 - size.x) / 2;
	float marginY = (1 - size.y) / 2;

	vec2 rectPosition = vec2(rectsInX * position.x, rectsInY * position.y);

	float xCord = floor(rectPosition.x);
	float yCord = floor(rectPosition.y);	
	
	float selectedX = 0;
	float selectedY = 0;

	float isInRect = select(selectedX, selectedX + 10, xCord) * select(selectedY, selectedY + 10, yCord);
	 
	float shouldShiftEverySecondRow = step(1, mod(floor(rectPosition.y), 2));
	float shouldShiftEverySecondColumn = step(1, mod(floor(rectPosition.x), 2));
	
	
	rectPosition.x += shift.x * shouldShiftEverySecondRow;
	rectPosition.x -= shift.x * (1 - shouldShiftEverySecondRow);
	
	rectPosition.y += shift.y * shouldShiftEverySecondColumn;
	rectPosition.y -= shift.y * (1 - shouldShiftEverySecondColumn);
	

	
	float degree = 3.1415 * (shift.x + shift.y);

	degree = shouldShiftEverySecondRow * -degree + (1 - shouldShiftEverySecondRow) * degree;

	mat2 rotationMatrix = mat2(cos(degree), sin(degree), -sin(degree), cos(degree));

	vec2 originPosition = fract(rectPosition) - .5;
	vec2 rotatedAtOrigin = rotationMatrix * originPosition;
	vec2 rotatedPosition = rotatedAtOrigin + .5;

	float outOfBounds = select(0, 1, rotatedPosition.x) * select(0, 1, rotatedPosition.y);

	rectPosition = isInRect * outOfBounds * rotatedPosition + (1 - isInRect) * rectPosition;

	
	vec3 pixel = giveRectangleAt(vec2(marginX, marginY), size, colour, fract(rectPosition));
	



	
	vec3 newColour = isInRect * vec3(1, 0, 0) + (1 - isInRect) * vec3(0, 1, 0);

	return pixel * newColour;
}


float select(float minimum, float maximum, float value) {
	return step(minimum, value) * (1 - step(maximum, value));
}


vec3 giveRectangleAt(vec2 pos, vec2 size, vec3 colour, vec2 position) {

	vec3 rect = vec3(step(pos.x, position.x) * step(pos.y, position.y));
	vec3 bottom = vec3(1) - vec3(step(pos.x + size.x, position.x));
	vec3 left = vec3(1) - vec3(step(pos.y + size.y, position.y));
	
	rect *= bottom * left * colour;


	return rect;
}


vec3 giveSmoothRectangleAt(vec2 pos, vec2 innerSize, float startSmooth, float endSmooth, vec3 colour, vec2 position) {

	vec3 rectLeft = vec3(smoothstep(pos.x - startSmooth, pos.x + endSmooth, position.x));
	vec3 rectRight = vec3(vec3(1) - smoothstep(pos.x + innerSize.x - endSmooth, pos.x + innerSize.x + startSmooth, position.x));

	return rectLeft;
}


vec3 giveCicle(vec2 middle, float radius, float startSmooth, float endSmooth, vec2 position, vec3 colour) {
	float distanceMidToPos = abs(distance(middle, position));

	vec3 cicle = vec3(smoothstep(startSmooth, endSmooth, distanceMidToPos));

	return cicle * colour;
}

vec3 horizontalLine(float hight, float thickness, vec2 position) {
	vec3 upper = vec3(step(hight, position.y));
	vec3 lower = vec3(1) - vec3(step(hight + thickness, position.y));

	return upper * lower;
}

/*
vec3 sinLine(vec2 position, float thickness, float smoothness, vec2 mousePos) {

	float sinPosHere = sin(position.x - mousePos.x * iGlobalTime + .5f);
	sinPosHere *= position.x * (.5f - mousePos.y);
	sinPosHere += .5;

	float distanceToSin = distance(vec2(position.x, sinPosHere), position);

	return vec3(smoothstep(thickness - smoothness, thickness, distanceToSin));
}
*/



vec3 sinLine(vec2 position, float thickness, float smoothness, vec2 mousePos) {

	float sinPosHere = sin(position.x) / 2;
	sinPosHere += .5;

	float distanceToSin = distance(vec2(position.x, sinPosHere), position);

	return vec3(smoothstep(thickness - smoothness, thickness, distanceToSin));
}