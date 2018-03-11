uniform sampler2D texLastFrame;

uniform float iGlobalTime;
uniform vec2 iResolution;
uniform sampler2D texLastFrame0;
uniform sampler2D texLastFrame1;
uniform sampler2D texLastFrame2;


in vec2 uv;

out vec4 a;
out vec4 b;
out vec4 c;

void func()
{
	a = a;
	b = b;
	c = c;


    b = vec4(0, 1, 0, 1);
    a = vec4(1, 0, 0, 1);
    c = vec4(0, 0, 1, 1);
}

void main()
{
	a = texture2D(texLastFrame0, uv);
	b = texture2D(texLastFrame1, uv);
	c = texture2D(texLastFrame2, uv);

    func();
}