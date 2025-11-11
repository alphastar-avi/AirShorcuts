import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var motionViewModel = MotionViewModel()
    @StateObject private var shortcutRecorder = KeyboardShortcutRecorder()
    @State private var isListening = false
    @State private var displayedShortcut: String = "No shortcut recorded"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Pitch: \(motionViewModel.pitch, specifier: "%.2f")")
            Text(motionViewModel.gestureDetected ? "Sudden Up Gesture Detected!" : "")
                .foregroundColor(.green)
            
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
            
            Button(action: {
                shortcutRecorder.startRecording(duration: 2.0) {
                    // Recording completed
                }
            }) {
                Text(shortcutRecorder.isRecording ? "Recording... Press keys now (keyboard frozen)" : "Record Keyboard Shortcut")
                    .padding()
                    .background(shortcutRecorder.isRecording ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(shortcutRecorder.isRecording)
            
            if shortcutRecorder.isRecording {
                Text("Keyboard is frozen - system shortcuts won't work")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Button(action: {
                displayedShortcut = shortcutRecorder.getRecordedShortcut()
            }) {
                Text("Execute")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Text("Recorded: \(shortcutRecorder.recordedShortcut)")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 5)
            
            Text("Displayed: \(displayedShortcut)")
                .font(.headline)
                .foregroundColor(.blue)
                .padding(.top, 10)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
