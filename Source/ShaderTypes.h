#pragma once

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

typedef struct {
    int version;
    vector_float3 camera;
    vector_float3 focus;
    matrix_float4x4 transformMatrix;
    matrix_float3x3 endPosition;

    float sph1,sph2,sph3;
    float box1,box2;
    
    float colorR1,colorR2;
    float colorG1,colorG2;
    float colorB1,colorB2;

    int xSize,ySize;
    float zoom;
    float scaleFactor;
    float epsilon;
    
    vector_float3 julia;
    bool juliaboxMode;
    
    vector_float3 light;
    
    float toeIn;
    bool burningShip;
    float maxDist;
    float contrast;
    float blinn;
    bool bfuture1;
    int ifuture2;
    vector_float2 future2;
    vector_float2 future3;
}  Control;

//MARK: -

#define MAX_ENTRY 100

typedef struct{
    vector_float3 camera;
    vector_float3 focus;
} RecordEntry;

typedef struct{
    int version;
    Control memory;
    int count;
    RecordEntry entry[MAX_ENTRY];
} RecordStruct;

#ifndef __METAL_VERSION__

void setRecordPointer(RecordStruct *rPtr,Control *cPtr);
void saveControlMemory(void);
void restoreControlMemory(void);
void saveRecordStructEntry(void);
RecordEntry getRecordStructEntry(int index);

#endif

