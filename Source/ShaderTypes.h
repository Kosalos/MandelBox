#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

struct Control {
    vector_float3 camera;
    vector_float3 focus;
    
    float sph1,sph2;
    float box1,box2;
    
    float colorR1,colorR2;
    float colorG1,colorG2;
    float colorB1,colorB2;

    int size;
    float zoom;
    float scaleFactor;
    float epsilon;
    
    vector_float3 julia;
    bool juliaboxMode;
    
    vector_float3 light;
    
    vector_float3 future1;
    vector_float3 future2;
    vector_float3 future3;
};

#endif /* ShaderTypes_h */

