import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var motionViewModel = MotionViewModel()
    @StateObject private var actionController = ActionController()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AirpodsMove")
                .font(.largeTitle)
                .padding()
            
            Text("Pitch: \(motionViewModel.pitch, specifier: "%.2f")")
            Text(motionViewModel.gestureDetected ? "Sudden Up Gesture Detected!" : "")
                .foregroundColor(.green)
                .onChange(of: motionViewModel.gestureDetected) { old, detected in
                    if detected {
                        actionController.triggerAction()
                    }
                }
            
            Button(motionViewModel.isListening ? "Stop Listening" : "Start Listening") {
                if motionViewModel.isListening {
                    motionViewModel.stopListening()
                } else {
                    motionViewModel.startListening()
                }
            }
            .padding()
            .background(motionViewModel.isListening ? Color.red : Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Divider()
            
            Picker("Action Mode", selection: $actionController.currentMode) {
                ForEach(ActionMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            if actionController.currentMode == .shortcut {
                VStack {
                    Text("Recorded Shortcut: \(actionController.recordedShortcutString)")
                        .font(.headline)
                    
                    Button(actionController.isRecording ? "Press Keys..." : "Record Shortcut") {
                        if !actionController.isRecording {
                            actionController.startRecording()
                        }
                    }
                    .padding(5)
                    .background(actionController.isRecording ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            } else {
                Text("Controls Screen Brightness")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Divider()
            
            if !actionController.isPermissionGranted {
                VStack(spacing: 10) {
                    Text("⚠️ Accessibility Permission Missing")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Button("Open Settings") {
                        actionController.openSettings()
                    }
                    .padding(5)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    
                    Button("Reveal App in Finder") {
                        actionController.revealAppInFinder()
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
            }
        }
        .padding()
        .onAppear {
            actionController.checkPermission()
        }
    }
}

#Preview {
    ContentView()
}
