//: param auto environment_max_lod
uniform float maxLod;

//: param custom {
//:   "default": 16,
//:   "label": "Quality",
//:   "widget": "combobox",
//:   "values": {
//:     "Very low (4 spp)": 4,
//:     "Low (16 spp)": 16,
//:     "Medium (32 spp)": 32,
//:     "High (64 spp)": 64,
//:     "Very high (128 spp)": 128,
//:     "Ultra (256 spp)": 256
//:   },
//:   "group": "Common Parameters"
//: }
uniform int nbSamples;

//: param custom {
//:   "default": 1.3,
//:   "label": "Horizon Fading",
//:   "min": 0.0,
//:   "max": 2.0,
//:   "group": "Common Parameters"
//: }
uniform float horizonFade;

import lib-env.glsl
import lib-emissive.glsl
import lib-random.glsl
import lib-vectors.glsl

const float EPSILON_COEF = 1e-4;

float normal_distrib(
  float ndh,
  float Roughness)
{
  // use GGX / Trowbridge-Reitz, same as Disney and Unreal 4
  // cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p3
  float alpha = Roughness * Roughness;
  float tmp = alpha / max(1e-8,(ndh*ndh*(alpha*alpha-1.0)+1.0));
  return tmp * tmp * M_INV_PI;
}

vec3 fresnel(
  float vdh,
  vec3 F0)
{
  // Schlick with Spherical Gaussian approximation
  // cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p3
  float sphg = exp2((-5.55473*vdh - 6.98316) * vdh);
  return F0 + (vec3(1.0) - F0) * sphg;
}

float G1(
  float ndw, // w is either Ln or Vn
  float k)
{
  // One generic factor of the geometry function divided by ndw
  // NB : We should have k > 0
  return 1.0 / ( ndw*(1.0-k) +  k );
}

float visibility(
  float ndl,
  float ndv,
  float Roughness)
{
  // Schlick with Smith-like choice of k
  // cf http://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf p3
  // visibility is a Cook-Torrance geometry function divided by (n.l)*(n.v)
  float k = max(Roughness * Roughness * 0.5, 1e-5);
  return G1(ndl,k)*G1(ndv,k);
}

vec3 cook_torrance_contrib(
  float vdh,
  float ndh,
  float ndl,
  float ndv,
  vec3 Ks,
  float Roughness)
{
  // This is the contribution when using importance sampling with the GGX based
  // sample distribution. This means ct_contrib = ct_brdf / ggx_probability
  return fresnel(vdh,Ks) * (visibility(ndl,ndv,Roughness) * vdh * ndl / ndh );
}

vec3 importanceSampleGGX(vec2 Xi, vec3 T, vec3 B, vec3 N, float roughness)
{
  float a = roughness*roughness;
  float cosT = sqrt((1.0-Xi.y)/(1.0+(a*a-1.0)*Xi.y));
  float sinT = sqrt(1.0-cosT*cosT);
  float phi = 2.0*M_PI*Xi.x;
  return
    T * (sinT*cos(phi)) +
    B * (sinT*sin(phi)) +
    N *  cosT;
}

float probabilityGGX(float ndh, float vdh, float Roughness)
{
  return normal_distrib(ndh, Roughness) * ndh / (4.0*vdh);
}

float distortion(vec3 Wn)
{
  // Computes the inverse of the solid angle of the (differential) pixel in
  // the cube map pointed at by Wn
  float sinT = sqrt(1.0-Wn.y*Wn.y);
  return sinT;
}

float computeLOD(vec3 Ln, float p)
{
  return max(0.0, (maxLod-1.5) - 0.5 * log2(float(nbSamples) * p * distortion(Ln)));
}

float horizonFading(float ndl, float horizonFade)
{
  float horiz = clamp(1.0 + horizonFade * ndl, 0.0, 1.0);
  return horiz * horiz;
}

vec3 pbrComputeDiffuse(vec3 normal, vec3 diffColor)
{
  return envIrradiance(normal) * diffColor;
}

vec3 pbrComputeSpecular(LocalVectors vectors, vec3 specColor, float roughness)
{
  vec3 radiance = vec3(0.0);
  float ndv = dot(vectors.eye, vectors.normal);

  for(int i=0; i<nbSamples; ++i)
  {
    vec2 Xi = fibonacci2D(i, nbSamples);
    vec3 Hn = importanceSampleGGX(
      Xi, vectors.tangent, vectors.bitangent, vectors.normal, roughness);
    vec3 Ln = -reflect(vectors.eye,Hn);

    float fade = horizonFading(dot(vectors.vertexNormal, Ln), horizonFade);

    float ndl = dot(vectors.normal, Ln);
    ndl = max( 1e-8, ndl );
    float vdh = max(1e-8, dot(vectors.eye, Hn));
    float ndh = max(1e-8, dot(vectors.normal, Hn));
    float lodS = roughness < 0.01 ? 0.0 : computeLOD(Ln, probabilityGGX(ndh, vdh, roughness));
    radiance += fade * envSampleLOD(Ln, lodS) *
      cook_torrance_contrib(vdh, ndh, ndl, ndv, specColor, roughness);
  }
  // Remove occlusions on shiny reflections
  radiance /= float(nbSamples);

  return radiance;
}