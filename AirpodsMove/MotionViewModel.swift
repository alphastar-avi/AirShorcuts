import Foundation
import CoreMotion
import Combine

class MotionViewModel: ObservableObject {
    private let motionManager = CMHeadphoneMotionManager()
    private var timer: Timer?
    
    @Published var pitch: Double = 0.0
    @Published var gestureDetected = false
    @Published var isListening = false
    
    private var previousPitch: Double?
    
    func startListening() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Headphone motion data is not available.")
            return
        }
        
        isListening = true
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else { return }
            
            let attitude = motion.attitude
            let currentPitch = attitude.pitch
            
            self.pitch = currentPitch
            
            if let previousPitch = self.previousPitch {
                if currentPitch - previousPitch > 0.1 { // Sudden up gesture
                    self.gestureDetected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.gestureDetected = false
                    }
                }
            }
            
            self.previousPitch = currentPitch
        }
    }
    
    func stopListening() {
        motionManager.stopDeviceMotionUpdates()
        previousPitch = nil
        isListening = false
    }
}
