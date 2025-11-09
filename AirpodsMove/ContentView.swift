import SwiftUI

struct ContentView: View {
    @StateObject private var motionViewModel = MotionViewModel()
    @State private var isListening = false
    
    var body: some View {
        VStack {
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
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
