import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var motionViewModel = MotionViewModel()
    @StateObject private var actionController = ActionController()
    
    @State private var showingConfigSheet = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 5) {
                Text("AirpodsMove")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Pitch: \(motionViewModel.pitch, specifier: "%.2f") | Yaw: \(motionViewModel.yaw, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top)
            
            // Gesture Status
            if let lastGesture = motionViewModel.lastDetectedGesture {
                Text("\(lastGesture.rawValue) Gesture Detected!")
                    .font(.headline)
                    .foregroundColor(.green)
                    .transition(.opacity)
                    .onAppear {
                        actionController.triggerAction(for: lastGesture)
                    }
            } else {
                Text("Waiting for gesture...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Grid UI
            LazyVGrid(columns: columns, spacing: 20) {
                GestureWidget(direction: .up, icon: "arrow.up", actionController: actionController)
                    .onTapGesture {
                        actionController.selectedDirection = .up
                        showingConfigSheet = true
                    }
                
                GestureWidget(direction: .down, icon: "arrow.down", actionController: actionController)
                    .onTapGesture {
                        actionController.selectedDirection = .down
                        showingConfigSheet = true
                    }
                
                GestureWidget(direction: .left, icon: "arrow.left", actionController: actionController)
                    .onTapGesture {
                        actionController.selectedDirection = .left
                        showingConfigSheet = true
                    }
                
                GestureWidget(direction: .right, icon: "arrow.right", actionController: actionController)
                    .onTapGesture {
                        actionController.selectedDirection = .right
                        showingConfigSheet = true
                    }
            }
            .padding()
            
            // Main Toggle
            Button(action: {
                if motionViewModel.isListening {
                    motionViewModel.stopListening()
                } else {
                    motionViewModel.startListening()
                }
            }) {
                HStack {
                    Image(systemName: motionViewModel.isListening ? "stop.fill" : "play.fill")
                    Text(motionViewModel.isListening ? "Stop Listening" : "Start Listening")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(motionViewModel.isListening ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(15)
                .shadow(radius: 5)
            }
            .padding(.horizontal)
            
            // Permissions Warning
            if !actionController.isPermissionGranted {
                PermissionWarningView(actionController: actionController)
            }
        }
        .padding()
        .frame(width: 400, height: 600)
        .onAppear {
            actionController.checkPermission()
            motionViewModel.updateThresholds(settings: actionController.gestureSettings)
        }
        .onChange(of: actionController.gestureSettings.values.map { $0.sensitivity }) { _ in
            motionViewModel.updateThresholds(settings: actionController.gestureSettings)
        }
        .sheet(isPresented: $showingConfigSheet) {
            ConfigurationSheet(actionController: actionController)
        }
    }
}

// Reusable Widget View
struct GestureWidget: View {
    let direction: GestureDirection
    let icon: String
    @ObservedObject var actionController: ActionController
    
    var settings: GestureSettings {
        actionController.gestureSettings[direction] ?? GestureSettings()
    }
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.blue)
            
            Text(direction.rawValue)
                .font(.headline)
            
            Text(settings.mode.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if settings.mode == .shortcut {
                Text(settings.shortcutString)
                    .font(.caption2)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// Configuration Sheet
struct ConfigurationSheet: View {
    @ObservedObject var actionController: ActionController
    @Environment(\.presentationMode) var presentationMode
    
    var settings: GestureSettings {
        actionController.gestureSettings[actionController.selectedDirection] ?? GestureSettings()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Configure \(actionController.selectedDirection.rawValue)")
                .font(.title2)
                .padding()
            
            // Mode Picker
            Picker("Action Mode", selection: Binding(
                get: { settings.mode },
                set: { actionController.updateMode($0) }
            )) {
                ForEach(ActionMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Sensitivity Slider
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Sensitivity")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(String(format: "%.2f", settings.sensitivity))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                Slider(value: Binding(
                    get: { settings.sensitivity },
                    set: { actionController.updateSensitivity($0) }
                ), in: 0.0...1.0)
                .padding(.horizontal)
                
                HStack {
                    Text("Low")
                    Spacer()
                    Text("High")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
            
            if settings.mode == .shortcut {
                VStack {
                    Text("Recorded Shortcut: \(settings.shortcutString)")
                        .font(.headline)
                    
                    Button(actionController.isRecording ? "Press Keys..." : "Record Shortcut") {
                        if !actionController.isRecording {
                            actionController.startRecording()
                        }
                    }
                    .padding()
                    .background(actionController.isRecording ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            } else {
                Text("Controls Screen Brightness")
                    .foregroundColor(.gray)
                    .padding()
            }
            
            Spacer()
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 500)
    }
}

// Permission Warning Component
struct PermissionWarningView: View {
    @ObservedObject var actionController: ActionController
    
    var body: some View {
        VStack(spacing: 10) {
            Text("⚠️ Accessibility Permission Missing")
                .font(.headline)
                .foregroundColor(.red)
            
            HStack {
                Button("Open Settings") {
                    actionController.openSettings()
                }
                
                Button("Reveal App") {
                    actionController.revealAppInFinder()
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
}
