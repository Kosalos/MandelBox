#include <metal_stdlib>
#import "ShaderTypes.h"

using namespace metal;

constant int MAX_ITERS = 10; // adjust this higher for better/slower rendering
constant int MAX_STEPS = 70; // adjust this higher for better/slower rendering

//MARK: -

float3 getColor(float3 pos,constant Control &control)
{
    // For the Juliabox, c is a constant. For the Mandelbox, c is variable.
    float3 c = control.juliaboxMode ? control.julia : pos;
    float3 v = pos;
    float minDist = 1.0;
    
    for (int i = 0; i < MAX_ITERS; i++) {
        
        v = clamp(v, -control.box1, control.box1) * control.box2 - v;
        if(control.burningShip) v = -abs(v);

        // Sphere fold.
        float mag = dot(v, v);
        if (mag < control.sph1)
            v = v * control.sph1 * 2;
        else if (mag < control.sph2)
            v = v / mag;
        
        v = v * control.scaleFactor + c;
        minDist = min(minDist, length(v));
    }
    
    float fractionalIterationCount = log(dot(v, v));
    float3 cc = float3(
                  control.colorB1 + control.colorB2 * sin(fractionalIterationCount * 0.52 + 0.7),
                  control.colorG1 + control.colorG2 * sin(fractionalIterationCount * 0.73 + 1.8),
                  control.colorR1 + control.colorR2 * sin(fractionalIterationCount * 0.31 + 1.1));
    
    return saturate(cc);
}


//MARK: -

float distanceEstimate(float3 rayPos, float constant1, float constant2,constant Control &control)
{
    // For the Juliabox, c is a constant. For the Mandelbox, c is variable.
    float3 c = control.juliaboxMode ? control.julia : rayPos;
    float3 v = rayPos;
    float dr = 1.5;
    
    for (int i = 0; i < MAX_ITERS; i++) {
        
        // Box fold
        v = clamp(v, -control.box1, control.box1) * control.box2 - v;
        if(control.burningShip) v = -abs(v);

        // Sphere fold.
        float mag = dot(v, v);
        if (mag < control.sph1)
        {
            v = v * control.sph3;
            dr = dr * control.sph3;
        }
        else if (mag < control.sph2)
        {
            v = v / mag;
            dr = dr / mag;
        }
        
        v = v * control.scaleFactor + c;
        dr = dr * abs(control.scaleFactor) + 1.0;
    }
    
    return (length(v) - constant1) / dr - constant2;
}

float distanceEstimate(float3 rayPos,constant Control &control)
{
    float constant1 = abs(control.scaleFactor - 1.0);
    float constant2 = pow(float(abs(control.scaleFactor)), float(1 - MAX_ITERS));
    return distanceEstimate(rayPos, constant1, constant2, control);
}

//MARK: -

float3 getNormal(float3 pos,constant Control &control)
{
    // boxplorer's method for estimating the normal at a point
    float4 eps = float4(0, control.epsilon, 2.0 * control.epsilon, 3.0 * control.epsilon);
    return normalize(float3(
                            -distanceEstimate(pos - eps.yxx,control) + distanceEstimate(pos + eps.yxx,control),
                            -distanceEstimate(pos - eps.xyx,control) + distanceEstimate(pos + eps.xyx,control),
                            -distanceEstimate(pos - eps.xxy,control) + distanceEstimate(pos + eps.xxy,control)));
}

float3 getBlinnShading(float3 normal, float3 view, float3 light)
{
    // boxplorer's method
    float3 halfLV = normalize(light + view);
    float spe = pow(max( dot(normal, halfLV), 0.420 ), 32);
    float dif = dot(normal, light) * 0.5 + 0.75;
    return dif + spe; // * specularColor;
}

float getAmbientOcclusion(float3 pos, float3 normal,constant Control &control)
{
    float ambientOcclusion = 1.0;
    float w = 0.1 / control.epsilon / 5.0;
    float distance = 2.0 * control.epsilon * 5.0;
    
    for (int i = 0; i < 5; i++) {
        ambientOcclusion -= (distance - distanceEstimate(pos + normal * distance,control)) * w;
        w *= 0.95;
        distance = distance * 2.0 - control.epsilon * 5.0;
    }
    
    // Smaller value = Darker
    return saturate(ambientOcclusion);
}

//MARK: -

float4 rayMarch(float3 rayDir,constant Control &control) {
    int stepCount = 0;
    
    float constant1 = abs(control.scaleFactor - 1.0);
    float constant2 = pow(float(abs(control.scaleFactor)), float(1 - MAX_ITERS));
    float distance = 0.0;
    float ee = sin(control.epsilon);
    float de = 1;
    float3 rayPos;
    
    for (int i = 0; i < MAX_STEPS && de >= ee && distance <= control.maxDist; i++) {
        rayPos = control.camera + rayDir * distance;
        de = distanceEstimate(rayPos, constant1, constant2, control);
        
        distance += de * 0.95;
        stepCount++;
    }
    
    ///////////////////
    
    float3 finalRayPos = control.camera + distance * rayDir;
    
    float4 color = float4(0,0,0,1);
    
    if (distance < control.maxDist) {
        // The (log(epsilon) * 2.0) offset is to compensate for the fact
        // that more steps are taken when epsilon is small.
        float lee = log(control.epsilon) * 2.0;
        float adjusted = max(0.0, float(stepCount) + lee);
        float adjustedMax = float(MAX_STEPS) + lee;
        
        // Sqrt increases contrast.
        float distRatio = sqrt(adjusted / adjustedMax) * 6;
        
        color = float4(getColor(finalRayPos,control) * (1.0 - distRatio), 1.0);
        
        // Calculating the normal can screw up when the point is not close
        // enough to the fractal due to timeout.
        if (stepCount < MAX_STEPS) {
            float3 normal = getNormal(finalRayPos,control);
            color = float4(mix(float3(0.0, 0.0, 0.0), color.xyz,
                               getAmbientOcclusion(finalRayPos, normal,control) * 5 + 0.05),
                           1.0);
            
            // Use two lights.
//            float3 light = mix(
//                               getBlinnShading(normal, rayDir, normalize(float3(1.0, 2.0, 3.0))),
//                               getBlinnShading(normal, rayDir, normalize(float3(-1.0, 1.5, 2.5))),
//                               0.5);

            float3 light = getBlinnShading(normal, rayDir, control.light);

            color = float4(mix(light, color.xyz, 0.8), 1.0);
            
            float dd = length(finalRayPos - control.camera);    // fog effect
            float hk = float(1 - dd * 2 / control.maxDist);
            color *= float4(hk,hk,hk,1);
            
            color.x = 0.5 + (color.x - 0.45) * control.contrast;
            color.y = 0.5 + (color.y - 0.45) * control.contrast;
            color.z = 0.5 + (color.z - 0.45) * control.contrast;
        }
    }
    
    return saturate(color);
}

//MARK: -

float3 toRectangular(float3 sph) {
    return float3(sph.x * sin(sph.z) * cos(sph.y),
                  sph.x * sin(sph.z) * sin(sph.y),
                  sph.x * cos(sph.z));
}

float3 toSpherical(float3 rec) {
    return float3(length(rec),
                  atan2(rec.y,rec.x),
                  atan2(sqrt(rec.x*rec.x+rec.y*rec.y), rec.z));
}

kernel void mandelBoxShader
(
 texture2d<float, access::write> outTexture [[texture(0)]],
 constant Control &control [[buffer(0)]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x > uint(control.xSize)) return;
    if(p.y > uint(control.ySize)) return;
    
    float minSz = float(min(control.xSize,control.ySize));
    float2 uv = float2(float(p.x) / minSz, float(p.y) / minSz);     // map pixel to 0..1
    float3 viewVector = control.focus - control.camera;
    float3 topVector = toSpherical(viewVector);
    topVector.z += 1.5708;
    topVector = toRectangular(topVector);
    
    float3 sideVector = cross(viewVector,topVector);
    sideVector = normalize(sideVector) * length(topVector);
    
    float dx = control.zoom * (uv.x - 0.5);
    float dy = -control.zoom * (uv.y - 0.5);
    
    float3 direction = normalize((sideVector * dx) + (topVector * dy) + viewVector);
    
    outTexture.write(rayMarch(direction,control),p);
}
