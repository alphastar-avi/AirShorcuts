import Foundation
import CoreMotion
import Combine

enum GestureDirection: String, CaseIterable, Codable {
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
}

class MotionViewModel: NSObject, ObservableObject, CMHeadphoneMotionManagerDelegate {
    private let motionManager = CMHeadphoneMotionManager()
    
    @Published var pitch: Double = 0.0
    @Published var yaw: Double = 0.0
    @Published var lastDetectedGesture: GestureDirection?
    @Published var isListening = false
    @Published var isConnected = false
    
    // Thresholds for each direction (default to 0.15)
    var thresholds: [GestureDirection: Double] = [
        .up: 0.15,
        .down: 0.15,
        .left: 0.15,
        .right: 0.15
    ]
    
    private var previousPitch: Double?
    private var previousYaw: Double?
    private var baselineYaw: Double?
    
    override init() {
        super.init()
        motionManager.delegate = self
        isConnected = motionManager.isDeviceMotionAvailable
    }
    
    func updateThresholds(settings: [GestureDirection: GestureSettings]) {
        for (direction, setting) in settings {
            // Formula: Threshold = 0.40 - (Sensitivity * 0.38)
            // Sensitivity 0.0 (Low) -> 0.40 (Hard)
            // Sensitivity 1.0 (High) -> 0.02 (Very Easy)
            let threshold = 0.40 - (setting.sensitivity * 0.38)
            thresholds[direction] = threshold
        }
    }
    
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
        
        // Pitch Detection (Up/Down)
        let pitchDelta = currentPitch - prevPitch
        
        if pitchDelta > (thresholds[.up] ?? 0.15) {
            triggerGesture(.up)
        } else if pitchDelta < -(thresholds[.down] ?? 0.15) {
            triggerGesture(.down)
        }
        
        // Yaw Detection (Left/Right)
        let yawDelta = currentYaw - prevYaw
        
        if yawDelta > (thresholds[.left] ?? 0.15) {
            triggerGesture(.left)
        } else if yawDelta < -(thresholds[.right] ?? 0.15) {
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
    
    // MARK: - CMHeadphoneMotionManagerDelegate
    
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}
