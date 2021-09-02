attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute vec2 aTextureCoord;
attribute mat3 aPrecomputeLT;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;

uniform vec3 uprtLight_0;
uniform vec3 uprtLight_1;
uniform vec3 uprtLight_2;
uniform vec3 uprtLight_3;
uniform vec3 uprtLight_4;
uniform vec3 uprtLight_5;
uniform vec3 uprtLight_6;
uniform vec3 uprtLight_7;
uniform vec3 uprtLight_8;

varying highp vec3 vColor;

void main(void) {
  gl_Position = uProjectionMatrix * uViewMatrix * uModelMatrix * vec4(aVertexPosition, 1.0);

  vColor = vec3(0.0, 0.0, 0.0);

  vColor += uprtLight_0 * aPrecomputeLT[0][0];
  vColor += uprtLight_1 * aPrecomputeLT[0][1];
  vColor += uprtLight_2 * aPrecomputeLT[0][2];
  vColor += uprtLight_3 * aPrecomputeLT[1][0];
  vColor += uprtLight_4 * aPrecomputeLT[1][1];
  vColor += uprtLight_5 * aPrecomputeLT[1][2];
  vColor += uprtLight_6 * aPrecomputeLT[2][0];
  vColor += uprtLight_7 * aPrecomputeLT[2][1];
  vColor += uprtLight_8 * aPrecomputeLT[2][2];
}