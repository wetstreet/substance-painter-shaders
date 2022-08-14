import lib-defines.glsl

//: param auto texture_blue_noise
uniform sampler2D texture_blue_noise;

const ivec2 texture_blue_noise_size = ivec2(256);

//: param auto random_seed
uniform int alg_random_seed;

float getBlueNoiseThreshold()
{
  return texture(texture_blue_noise, gl_FragCoord.xy / vec2(texture_blue_noise_size)).x + 0.5 / 65536.0;
}

float getBlueNoiseThresholdTemporal()
{
  return fract(getBlueNoiseThreshold() + M_GOLDEN_RATIO * alg_random_seed);
}

float fibonacci1D(int i)
{
  return fract((float(i) + 1.0) * M_GOLDEN_RATIO);
}

vec2 fibonacci2D(int i, int nbSamples)
{
  return vec2(
    (float(i)+0.5) / float(nbSamples),
    fibonacci1D(i)
  );
}

vec2 fibonacci2DDitheredTemporal(int i, int nbSamples)
{
  vec2 s = fibonacci2D(i, nbSamples);
  s.x += getBlueNoiseThresholdTemporal();
  return s;
}
