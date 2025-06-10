#version 120

//#define depthOfField
#define	useDynamicTonemapping

varying vec4 color;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;


void main() {

	const int		noiseTextureResolution		= 1024;
	const int		shadowMapResolution			= 1024;
	const bool 		shadowHardwareFiltering0	= true;
	const float 	shadowIntervalSize 			= 4.0f;
	const float		sunPathRotation				= -30.0f;

	#ifdef depthOfField
		const float 	centerDepthHalflife 		= 2.0f;
	#endif
	
	#ifdef useDynamicTonemapping
		const float		eyeBrightnessHalflife		= 7.5f;
	#endif

/* DRAWBUFFERS:0 */

	gl_FragData[0] = color;
	
}