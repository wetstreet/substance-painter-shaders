import lib-normal.glsl

//: param auto is_2d_view
uniform bool is2DView;

//: param auto is_perspective_projection
uniform bool is_perspective;

//: param auto world_eye_position
uniform vec3 camera_pos;

//: param auto world_camera_direction
uniform vec3 camera_dir;

//: param auto facing
uniform int facing;

bool isBackFace() {
  return facing == -1 || (facing == 0 && !gl_FrontFacing);
}

vec3 getEyeVec(vec3 position) {
  return is_perspective ?
    normalize(camera_pos - position) :
    -camera_dir;
}

vec3 tangentSpaceToWorldSpace(vec3 vecTS, V2F inputs) {
  return normalize(
    vecTS.x * inputs.tangent +
    vecTS.y * inputs.bitangent +
    vecTS.z * inputs.normal);
}

vec3 worldSpaceToTangentSpace(vec3 vecWS, V2F inputs) {
  // Assume the transformation is orthogonal
  return normalize(vecWS * mat3(inputs.tangent, inputs.bitangent, inputs.normal));
}

struct LocalVectors {
  vec3 vertexNormal;
  vec3 tangent, bitangent, normal, eye;
};

LocalVectors computeLocalFrame(V2F inputs, vec3 normal, float anisoAngle) {
  LocalVectors vectors;
  vectors.vertexNormal = inputs.normal;
  vectors.normal = normal;

  // Flip the normals for back facing polygons
  if (isBackFace()) {
    vectors.vertexNormal = -vectors.vertexNormal;
    vectors.normal = -vectors.normal;
  }

  vectors.eye = is2DView ?
    vectors.normal : // In 2D view, put view vector along the normal
    getEyeVec(inputs.position);

  // Trick to remove black artifacts
  // Backface ? place the eye at the opposite - removes black zones
  if (dot(vectors.eye, vectors.normal) < 0.0) {
    vectors.eye = reflect(vectors.eye, vectors.normal);
  }

  // Create a local frame for BRDF work
  vec3 tangent = normalize(
    inputs.tangent
    - vectors.normal * dot(inputs.tangent, vectors.normal)
  );
  vec3 bitangent = normalize(
    inputs.bitangent
    - vectors.normal * dot(inputs.bitangent, vectors.normal)
    - tangent * dot(inputs.bitangent, tangent)
  );

  float cosAngle = cos(anisoAngle);
  float sinAngle = sin(anisoAngle);
  vectors.tangent = cosAngle * tangent - sinAngle * bitangent;
  vectors.bitangent = cosAngle * bitangent + sinAngle * tangent;

  return vectors;
}

LocalVectors computeLocalFrame(V2F inputs) {
  // Get world space normal
  vec3 normal = computeWSNormal(inputs.sparse_coord, inputs.tangent, inputs.bitangent, inputs.normal);
  return computeLocalFrame(inputs, normal, 0.0);
}
