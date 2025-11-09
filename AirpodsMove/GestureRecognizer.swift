import Foundation
import CoreMotion

enum HeadGesture {
    case tiltUp
    case tiltDown
    case tiltLeft
    case tiltRight
    case unknown
}

class GestureRecognizer {
    private var initialAttitude: CMAttitude?
    
    func recognizeGesture(from motion: CMDeviceMotion) -> HeadGesture {
        guard let initialAttitude = initialAttitude else {
            self.initialAttitude = motion.attitude
            return .unknown
        }
        
        let roll = motion.attitude.roll - initialAttitude.roll
        let pitch = motion.attitude.pitch - initialAttitude.pitch
        
        if pitch > 0.5 {
            return .tiltUp
        } else if pitch < -0.5 {
            return .tiltDown
        } else if roll > 0.5 {
            return .tiltRight
        } else if roll < -0.5 {
            return .tiltLeft
        }
        
        return .unknown
    }
    
    func reset() {
        initialAttitude = nil
    }
}
