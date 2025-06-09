#version 120

//#define shakingCamera

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform float frameTimeCounter;

void main() {

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec3 worldpos = position.xyz + cameraPosition;
	
	bool istopv = worldpos.y > cameraPosition.y + 5.0;
	
	
	if (!istopv) position.xz += vec2(1.0, 0.0);
	
	#ifdef shakingCamera
		position.xy += vec2(0.01 * sin(frameTimeCounter * 2.0), 0.01 * cos(frameTimeCounter * 3.0));
	#endif
	
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;	
	
	color = gl_Color;
	
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
}