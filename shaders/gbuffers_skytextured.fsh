#version 120

#include "./settings.glsl"

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 glcolor;

void main()
{
	vec4 color = texture2D(texture, texcoord) * glcolor;

	#if RED_SUN == 1
		color = vec4(1.0, 0., 0., 1.);
	#endif

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}
