#version 330

out vec4 channel0;
out vec4 channel1;
out vec4 channel2;
out vec4 channel3;
out vec4 channel4;


void main()
{
	channel0 = vec4(0, 0, 0, -1);
	channel1 = vec4(1);
	channel2 = vec4(0);
	channel3 = vec4(-1, 0, -1, -1);
	channel4 = vec4(-1);
}