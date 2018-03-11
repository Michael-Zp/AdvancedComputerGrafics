uniform sampler2D texLastFrame;

uniform float iGlobalTime;

in vec2 uv;

void main()
{
    float color = step((sin(iGlobalTime * 4) + 1) / 2, uv.x);

    gl_FragColor = vec4(vec3(color), 1) + texture2D(texLastFrame, uv) * .75;
}