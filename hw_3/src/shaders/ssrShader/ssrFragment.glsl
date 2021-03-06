#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGDepth;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
	vec3 p3  = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z*z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if (n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth, uv).x;
  if (depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDiffuse(vec3 wi, vec3 wo, vec2 uv) {
  vec3 L = vec3(0.0);

  vec3 diffuse = GetGBufferDiffuse(uv);
  vec3 N = normalize(GetGBufferNormalWorld(uv));
  vec3 H = normalize(wi + wo);

  L = max(dot(N, H), 0.0) * diffuse;

  return L;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {
  vec3 Le = vec3(0.0);

  float visibility = GetGBufferuShadow(uv);

  Le = uLightRadiance * visibility;

  return Le;
}

#define STEP_NUM 256
#define STEP 0.05

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  bool flag = false;
  for (int i = 0; i < STEP_NUM; i++) {
    ori = ori + STEP * dir;
    vec2 uv = GetScreenCoordinate(ori);
    if (uv.x < 0.0 || uv.y > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;

    vec4 o_view = vWorldToScreen * vec4(ori, 1.0);
    float o_depth = o_view.z;

    float depth_delta = o_depth - GetGBufferDepth(uv);
    if (depth_delta > 0.0) {
      hitPos = ori;
      flag = true;
      break;
    }
  }

  return flag;
}

vec3 trans_tangent_2_world(vec3 tangent, vec3 bi_tangent, vec3 normal, vec3 dir) {
  return tangent * dir.x + bi_tangent * dir.y + normal * dir.z;
}

#define SAMPLE_NUM 16

void main() {
  vec3 color = vec3(0.0);

  float s = InitRand(gl_FragCoord.xy);

  vec3 P = vPosWorld.xyz;
  vec2 uv = GetScreenCoordinate(P);
  vec3 L = normalize(uLightDir);
  vec3 V = normalize(uCameraPos - P);

  // @diffuse
  //color = GetGBufferDiffuse(GetScreenCoordinate(P));
  
  // @shadow
  // vec3 diffuse = EvalDiffuse(L, V, uv);
  // vec3 light = EvalDirectionalLight(uv);
  // color = diffuse * light;

  // @ray tracing
  // vec3 N = normalize(GetGBufferNormalWorld(uv));
  // vec3 R = -1.0 * normalize(reflect(V, N));
  // vec3 hit = vec3(0.0);
  // if (RayMarch(P, R, hit)) {
  //   vec2 r_uv = GetScreenCoordinate(hit);
  //   color = GetGBufferDiffuse(r_uv);
  // }

  // @indirect illumination
  vec3 N = normalize(GetGBufferNormalWorld(uv));
  vec3 diffuse = EvalDiffuse(L, V, uv);
  vec3 light = EvalDirectionalLight(uv);
  color = diffuse * light;
  
  vec3 tangent;
  vec3 bi_tangent;
  LocalBasis(N, tangent, bi_tangent);
  
  vec3 i_color = vec3(0.0);
  for (int i= 0; i < SAMPLE_NUM; i++) {
    float pdf;
    vec3 R = SampleHemisphereCos(s, pdf);
    R = normalize(trans_tangent_2_world(normalize(tangent), normalize(bi_tangent), N, R));
    vec3 hit = vec3(0.0);
    if (RayMarch(P, R, hit)) {
      vec2 r_uv = GetScreenCoordinate(hit);
      vec3 r_V = normalize(P - hit);
      vec3 r_diffuse = EvalDiffuse(L, r_V, r_uv);
      vec3 r_light = EvalDirectionalLight(r_uv);

      vec3 i_light = (1.0 / pdf) * (r_diffuse * r_light);
      vec3 i_diffuse = EvalDiffuse(normalize(hit - P), V, uv);

      i_color += i_light * i_diffuse;
    }
  }
  
  color += (1.0 / float(SAMPLE_NUM)) * i_color;

  color = pow(clamp(color, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  gl_FragColor = vec4(color, 1.0);
}
