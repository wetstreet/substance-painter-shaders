import lib-defines.glsl

//: param auto texture_environment
uniform sampler2D environment_texture;
//: param auto environment_rotation
uniform float environment_rotation;
//: param auto environment_exposure
uniform float environment_exposure;
//: param auto environment_irrad_mat_red
uniform mat4 irrad_mat_red;
//: param auto environment_irrad_mat_green
uniform mat4 irrad_mat_green;
//: param auto environment_irrad_mat_blue
uniform mat4 irrad_mat_blue;

vec3 envSampleLOD(vec3 dir, float lod)
{
  // WORKAROUND: Intel GLSL compiler for HD5000 is bugged on OSX:
  // https://bugs.chromium.org/p/chromium/issues/detail?id=308366
  // It is necessary to replace atan(y, -x) by atan(y, -1.0 * x) to force
  // the second parameter to be interpreted as a float
  vec2 pos = M_INV_PI * vec2(atan(-dir.z, -1.0 * dir.x), 2.0 * asin(dir.y));
  pos = 0.5 * pos + vec2(0.5);
  pos.x += environment_rotation;
  return textureLod(environment_texture, pos, lod).rgb * environment_exposure;
}

vec3 envIrradiance(vec3 dir)
{
  float rot = environment_rotation * M_2PI;
  float crot = cos(rot);
  float srot = sin(rot);
  vec4 shDir = vec4(dir.xzy, 1.0);
  shDir = vec4(
    shDir.x * crot - shDir.y * srot,
    shDir.x * srot + shDir.y * crot,
    shDir.z,
    1.0);
  return max(vec3(0.0), vec3(
      dot(shDir, irrad_mat_red * shDir),
      dot(shDir, irrad_mat_green * shDir),
      dot(shDir, irrad_mat_blue * shDir)
    )) * environment_exposure;
}
