import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var motionViewModel = MotionViewModel()
    @StateObject private var brightnessController = BrightnessController()
    @State private var isListening = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Pitch: \(motionViewModel.pitch, specifier: "%.2f")")
            Text(motionViewModel.gestureDetected ? "Sudden Up Gesture Detected!" : "")
                .foregroundColor(.green)
                .onChange(of: motionViewModel.gestureDetected) { old, detected in
                    if detected {
                        brightnessController.increaseBrightness()
                    }
                }
            
            Button(action: {
                if isListening {
                    motionViewModel.stopListening()
                } else {
                    motionViewModel.startListening()
                }
                isListening.toggle()
            }) {
                Text(isListening ? "Stop Listening" : "Start Listening")
                    .padding()
                    .background(isListening ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Divider()
            
            if !brightnessController.isPermissionGranted {
                VStack(spacing: 10) {
                    Text("⚠️ Accessibility Permission Missing")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text("Required to control brightness")
                        .font(.caption)
                    
                    Button("Open Settings") {
                        brightnessController.openSettings()
                    }
                    .padding(5)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    
                    Button("Reveal App in Finder") {
                        brightnessController.revealAppInFinder()
                    }
                    .padding(5)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    
                    Text("If not in list, click 'Reveal' and drag app to Settings")
                        .font(.caption2)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            } else {
                Text("Brightness Control Active")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("Tilt head UP suddenly to increase brightness")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .onAppear {
            brightnessController.checkPermission()
        }
    }
}

#Preview {
    ContentView()
}
