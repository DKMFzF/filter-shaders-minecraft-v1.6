#version 120

#define DRAW_SHADOW_MAP gcolor //Configures which buffer to draw to the screen [gcolor shadowcolor0 shadowtex0 shadowtex1]

#define BLUE_AMOUNT 0.25 //[0.0 0.25 0.5 0.75 1.0]
#define GREEN_AMOUNT 0.25 //[0.0 0.25 0.5 0.75 1.0]
#define GRAY_AMOUNT 0.25 //[0.0 0.25 0.5 0.75 1.0]
#define RED_AMOUNT 0.25 //[0.0 0.25 0.5 0.75 1.0]

uniform float frameTimeCounter;
uniform sampler2D gcolor;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

varying vec2 texcoord;

vec3 make_color(in vec3 base_color, in vec3 mix_color, in float amount)
{
	return mix(base_color, mix_color, amount);
}

void main()
{
	vec3 color = texture2D(DRAW_SHADOW_MAP, texcoord).rgb;
	
	color = make_color(color, vec3(0., 0., 1.), BLUE_AMOUNT);
	color = make_color(color, vec3(0., 1., 0.), GREEN_AMOUNT);
	color = make_color(color, vec3(1., 0., 0.), RED_AMOUNT);

	float average_color = (color.r + color.b + color.g) / 3.0;
	color = make_color(color, vec3(average_color), GRAY_AMOUNT);

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color, 1.0); //gcolor
}