#include "ShaderTypes.h"

static RecordStruct *rPtr = NULL;
static Control *cPtr = NULL;

void setRecordPointer(RecordStruct *nrPtr,Control *ncPtr) { rPtr = nrPtr; cPtr = ncPtr; }

void saveControlMemory(void) { rPtr->memory = *(cPtr); }
void restoreControlMemory(void) { *(cPtr) = rPtr->memory; }

void saveRecordStructEntry(void) {
    if(rPtr->count < MAX_ENTRY) {
        rPtr->entry[rPtr->count].camera = cPtr->camera;
        rPtr->entry[rPtr->count].focus = cPtr->focus;
        ++(rPtr->count);
    }
}

RecordEntry getRecordStructEntry(int index) {
    if(index >= rPtr->count) index = 0;         // wrap around during looping playback
    return rPtr->entry[index];
}
