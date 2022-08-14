import lib-pbr.glsl

float normal_distrib(
  vec3 localH,
  vec2 alpha)
{
  localH.xy /= alpha;
  float tmp = dot(localH, localH);
  return 1.0 / (M_PI * alpha.x * alpha.y * tmp * tmp);
}

float G1(
  vec3 localW,
  vec2 alpha)
{
  // One generic factor of the geometry function divided by ndw
  localW.xy *= alpha;
  return 2.0 / (localW.z + length(localW));
}

float visibility(
  vec3 localL,
  vec3 localV,
  vec2 alpha)
{
  // visibility is a Cook-Torrance geometry function divided by (n.l)*(n.v)
  return G1(localL, alpha) * G1(localV, alpha);
}

vec3 cook_torrance_contrib(
  float vdh,
  float ndh,
  vec3 localL,
  vec3 localE,
  vec3 Ks,
  vec2 alpha)
{
  // This is the contribution when using importance sampling with the GGX based
  // sample distribution. This means ct_contrib = ct_brdf / ggx_probability
  return fresnel(vdh, Ks) * (visibility(localL, localE, alpha) * vdh * localL.z / ndh);
}

vec3 importanceSampleGGX(vec2 Xi, vec2 alpha)
{
  float phi = 2.0 * M_PI * Xi.x;
  vec2 slope = sqrt(Xi.y / (1.0 - Xi.y)) * alpha * vec2(cos(phi), sin(phi));
  return normalize(vec3(slope, 1.0));
}

float probabilityGGX(vec3 localH, float vdh, vec2 alpha)
{
  return normal_distrib(localH, alpha) * localH.z / (4.0 * vdh);
}

vec3 pbrComputeSpecularAnisotropic(LocalVectors vectors, vec3 specColor, vec2 roughness)
{
  vec3 radiance = vec3(0.0);
  vec2 alpha = roughness * roughness;
  mat3 TBN = mat3(vectors.tangent, vectors.bitangent, vectors.normal);
  vec3 localE = vectors.eye * TBN;

  for(int i=0; i<nbSamples; ++i)
  {
    vec2 Xi = fibonacci2DDitheredTemporal(i, nbSamples);
    vec3 localH = importanceSampleGGX(Xi, alpha);
    vec3 localL = reflect(-localE, localH);

    if (localL.z > 0.0)
    {
      vec3 Ln = TBN * localL;
      float vdh = max(1e-8, dot(localE, localH));

      float fade = horizonFading(dot(vectors.vertexNormal, Ln), horizonFade);
      float pdf = probabilityGGX(localH, vdh, alpha);
      float lodS = max(roughness.x, roughness.y) < 0.01 ? 0.0 : computeLOD(Ln, pdf);
      // Offset lodS to trade bias for more noise
      lodS -= 1.0;
      vec3 preconvolvedSample = envSampleLOD(Ln, lodS);

      radiance +=
        fade * cook_torrance_contrib(vdh, localH.z, localL, localE, specColor, alpha) *
        preconvolvedSample;
    }
  }

  return radiance / float(nbSamples);
}
