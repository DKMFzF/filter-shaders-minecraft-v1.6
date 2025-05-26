#version 120

#include "./settings.glsl"

uniform sampler2D texture;

varying vec2 texcoord;
varying vec4 glcolor;

void main() {
	vec4 color = texture2D(texture, texcoord) * glcolor;

	#if BERSEK_MOD == 1
		color.rgb = mix(color.rgb, vec3(1., 0., 0.), 0.5);
	#endif

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}