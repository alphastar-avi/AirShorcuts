import Foundation
import CoreMotion
import Combine

enum GestureDirection: String, CaseIterable, Codable {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
}

class MotionViewModel: ObservableObject {
    private let motionManager = CMHeadphoneMotionManager()
    
    @Published var pitch: Double = 0.0
    @Published var yaw: Double = 0.0
    @Published var lastDetectedGesture: GestureDirection?
    @Published var isListening = false
    
    private var previousPitch: Double?
    private var previousYaw: Double?
    private var baselineYaw: Double?
    
    func startListening() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Headphone motion data is not available.")
            return
        }
        
        isListening = true
        // Reset baseline on start
        previousPitch = nil
        previousYaw = nil
        baselineYaw = nil
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else { return }
            
            let attitude = motion.attitude
            let currentPitch = attitude.pitch
            let currentYaw = attitude.yaw
            
            self.pitch = currentPitch
            self.yaw = currentYaw
            
            // Initialize baseline if needed
            if self.baselineYaw == nil { self.baselineYaw = currentYaw }
            
            self.detectGestures(currentPitch: currentPitch, currentYaw: currentYaw)
            
            self.previousPitch = currentPitch
            self.previousYaw = currentYaw
        }
    }
    
    private func detectGestures(currentPitch: Double, currentYaw: Double) {
        guard let prevPitch = previousPitch, let prevYaw = previousYaw else { return }
        
        // Thresholds (tunable)
        let pitchThreshold = 0.15 // Radians
        let yawThreshold = 0.15   // Radians
        
        // Pitch Detection (Up/Down)
        let pitchDelta = currentPitch - prevPitch
        
        if pitchDelta > pitchThreshold {
            triggerGesture(.up)
        } else if pitchDelta < -pitchThreshold {
            triggerGesture(.down)
        }
        
        // Yaw Detection (Left/Right)
        // Note: Yaw wraps around at PI/-PI, but for small head movements simple delta is usually fine.
        // We might need to handle wrap-around if the user is facing exactly backwards, but unlikely for this use case.
        let yawDelta = currentYaw - prevYaw
        
        if yawDelta > yawThreshold {
            triggerGesture(.left) // Positive yaw is typically left (check coordinate system)
        } else if yawDelta < -yawThreshold {
            triggerGesture(.right)
        }
    }
    
    private func triggerGesture(_ gesture: GestureDirection) {
        // Debounce: Don't trigger if we just triggered
        if lastDetectedGesture != nil { return }
        
        print("Gesture Detected: \(gesture.rawValue)")
        lastDetectedGesture = gesture
        
        // Reset after a short delay to allow re-triggering
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.lastDetectedGesture = nil
        }
    }
    
    func stopListening() {
        motionManager.stopDeviceMotionUpdates()
        previousPitch = nil
        previousYaw = nil
        baselineYaw = nil
        isListening = false
    }
}
