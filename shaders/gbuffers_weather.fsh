#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

void main() {

/* DRAWBUFFERS:7 */

	gl_FragData[0] = texture2D(texture, texcoord.st) * color;

}
