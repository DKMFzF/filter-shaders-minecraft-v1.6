#version 120

uniform sampler2D gaux1;
varying vec4 texcoord;

void main() {
	vec4 color = texture2D(gaux1, texcoord.st);

	/* DRAWBUFFERS:0 */
	gl_FragColor = color;
}
