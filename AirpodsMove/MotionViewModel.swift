import Foundation
import CoreMotion
import Combine
import AppKit

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
    
    // Wake Me State
    var wakeMeSettings: WakeMeSettings = WakeMeSettings()
    private var lastActivityTime: Date = Date()
    private var wakeMeTimer: Timer?
    
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
    
    func updateWakeMeSettings(_ settings: WakeMeSettings) {
        self.wakeMeSettings = settings
        // If settings change while listening, reset timer logic
        if isListening {
            lastActivityTime = Date()
            setupWakeMeTimer()
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
        
        // Reset Wake Me
        lastActivityTime = Date()
        setupWakeMeTimer()
        
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
    
    private func setupWakeMeTimer() {
        wakeMeTimer?.invalidate()
        if wakeMeSettings.isEnabled {
            wakeMeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkActivity()
            }
        }
    }
    
    private func checkActivity() {
        guard wakeMeSettings.isEnabled else { return }
        
        let timeSinceActivity = Date().timeIntervalSince(lastActivityTime)
        if timeSinceActivity >= wakeMeSettings.timeout {
            playAlertSound()
            // Reset to avoid spamming sound every second immediately
            // But realistically, user should wake up and move, resetting it.
            // We can add a small buffer or just let it trigger again if they stay still.
            // For now, let's reset lastActivityTime so it snoozes for the timeout duration.
            lastActivityTime = Date() 
        }
    }
    
    private func playAlertSound() {
        if let sound = NSSound(named: wakeMeSettings.soundName) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
    
    private func detectGestures(currentPitch: Double, currentYaw: Double) {
        guard let prevPitch = previousPitch, let prevYaw = previousYaw else { return }
        
        // Activity Detection for Wake Me
        // Calculate total movement magnitude
        let deltaP = abs(currentPitch - prevPitch)
        let deltaY = abs(currentYaw - prevYaw)
        
        // Activity Threshold:
        // Sensitivity 0.0 -> Needs 0.10 movement to count as activity
        // Sensitivity 1.0 -> Needs 0.01 movement
        let activityThreshold = 0.10 - (wakeMeSettings.sensitivity * 0.09)
        
        if deltaP > activityThreshold || deltaY > activityThreshold {
            lastActivityTime = Date()
        }
        
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
        wakeMeTimer?.invalidate()
        wakeMeTimer = nil
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
