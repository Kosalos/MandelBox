import Foundation
import UIKit

enum RecordState { case idle,recording,playing }
let numStepsMin:Int = 25
let numStepsMax:Int = 800

var recordStruct = RecordStruct()

class Record {
    var state:RecordState = .idle
    var pIndex = Int()
    var entry = RecordEntry()
    var cameraDelta = float3()
    var focusDelta = float3()
    
    var numSteps:Int = numStepsMin
    
    var step = Int()

    func determineDeltas() {
        if recordStruct.count > 1 {
            entry = getRecordStructEntry(Int32(pIndex))
            let nextEntry = getRecordStructEntry(Int32(pIndex+1))
            
            cameraDelta = (nextEntry.camera - entry.camera) / Float(numSteps)
            focusDelta = (nextEntry.focus - entry.focus) / Float(numSteps)
        }
    }
    
    func playBack() {
        step += 1
        if step >= numSteps {
            pIndex += 1
            if pIndex >= recordStruct.count-1 { pIndex = 0 } // -1 = play to last entry, then start again (don't animate from end to beginning, but jump directly)
            step = 0
            determineDeltas()
        }
        
        entry.camera += cameraDelta
        entry.focus += focusDelta
        
        control.camera = entry.camera
        control.focus = entry.focus
    }
    
    func recordPressed() {
        if state != .recording {
            state = .recording
            recordStruct.matrix = arcBall.transformMatrix
            recordStruct.position = arcBall.endPosition
            recordStruct.count = 0
            saveControlMemory()
        }

        saveRecordStructEntry()
        vc.updateRecordButtons()
    }
    
    func playbackPressed() {
        if state == .playing {
            state = .idle
        }
        else {
            if recordStruct.count > 1 {
                state = .playing
                pIndex = 0
                step = 0
                determineDeltas()
                
                restoreControlMemory()
                vc.controlJustLoaded()
            }
        }
        
        vc.updateRecordButtons()
    }
    
    func playSpeedPressed() {
        numSteps *= 2
        if numSteps > numStepsMax { numSteps = numStepsMin }
        determineDeltas()
        vc.updateRecordButtons()
    }
    
    func getCount() -> Int { return Int(recordStruct.count) }
    
    func reset() {
        state = .idle
        recordStruct.count = 0
        vc.updateRecordButtons()
    }
}
