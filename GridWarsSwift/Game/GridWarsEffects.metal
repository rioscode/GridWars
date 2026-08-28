#include <metal_stdlib>
using namespace metal;

struct GridWarsEffectInstance {
    float4 geometry;
    float4 color;
    float4 parameters;
};

struct GridWarsEffectUniforms {
    float4 drawableAndScale;
    float4 offsetAndCamera;
};

struct GridWarsEffectRasterData {
    float4 position [[position]];
    float4 color;
};

static float2 gridWarsUnitCorner(uint vertexID) {
    switch (vertexID) {
        case 0: return float2(0.0, 0.0);
        case 1: return float2(1.0, 0.0);
        case 2: return float2(0.0, 1.0);
        case 3: return float2(0.0, 1.0);
        case 4: return float2(1.0, 0.0);
        default: return float2(1.0, 1.0);
    }
}

vertex GridWarsEffectRasterData gridWarsEffectVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    const device GridWarsEffectInstance *instances [[buffer(0)]],
    constant GridWarsEffectUniforms &uniforms [[buffer(1)]]) {
    const GridWarsEffectInstance instance = instances[instanceID];
    const float2 corner = gridWarsUnitCorner(vertexID);
    float2 scenePosition;

    if (instance.parameters.x < 0.5) {
        scenePosition = instance.geometry.xy + corner * instance.geometry.zw;
    } else {
        const float2 start = instance.geometry.xy;
        const float2 end = instance.geometry.zw;
        const float2 delta = end - start;
        const float inverseLength = rsqrt(max(dot(delta, delta), 0.000001));
        const float2 normal = float2(-delta.y, delta.x) * inverseLength;
        const float side = corner.y * 2.0 - 1.0;
        scenePosition = mix(start, end, corner.x)
            + normal * side * instance.parameters.y * 0.5;
    }

    const float2 drawableSize = uniforms.drawableAndScale.xy;
    const float scale = uniforms.drawableAndScale.z;
    const float2 contentOffset = uniforms.offsetAndCamera.xy;
    const float2 cameraOffset = uniforms.offsetAndCamera.zw;
    const float2 drawablePosition = (scenePosition - cameraOffset) * scale + contentOffset;
    const float2 clipPosition = drawablePosition / drawableSize * 2.0 - 1.0;

    GridWarsEffectRasterData output;
    output.position = float4(clipPosition, 0.0, 1.0);
    output.color = instance.color;
    return output;
}

fragment half4 gridWarsEffectFragment(GridWarsEffectRasterData input [[stage_in]]) {
    const float alpha = clamp(input.color.a, 0.0, 1.0);
    return half4(half3(input.color.rgb * alpha), half(alpha));
}
