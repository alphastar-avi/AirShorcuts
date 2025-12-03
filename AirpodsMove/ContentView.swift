import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var motionViewModel = MotionViewModel()
    @StateObject private var actionController = ActionController()
    
    @State private var showingConfigSheet = false
    
    let columns = [
        GridItem(.flexible(minimum: 150), spacing: 20),
        GridItem(.flexible(minimum: 150), spacing: 20)
    ]
    
    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Header Row
                HStack(alignment: .center) {
                    // Left: Title and Metrics
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Air Shortcuts")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 15) {
                            Label(String(format: "Pitch: %.2f", motionViewModel.pitch), systemImage: "arrow.up.and.down")
                            Label(String(format: "Yaw: %.2f", motionViewModel.yaw), systemImage: "arrow.left.and.right")
                        }
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    // Right: Status
                    ZStack {
                        if let lastGesture = motionViewModel.lastDetectedGesture {
                            Text("\(lastGesture.rawValue)!")
                                .font(.title3.bold())
                                .foregroundColor(.green)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                .transition(.scale.combined(with: .opacity))
                                .onAppear {
                                    actionController.triggerAction(for: lastGesture)
                                }
                        } else {
                            Text("Waiting for gestures...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Grid UI
                ScrollView {
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
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                

                
                // Main Toggle
                Button(action: {
                    withAnimation(.spring()) {
                        if motionViewModel.isListening {
                            motionViewModel.stopListening()
                        } else {
                            motionViewModel.startListening()
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: motionViewModel.isListening ? "stop.fill" : "play.fill")
                            .font(.title3)
                        Text(motionViewModel.isListening ? "Stop Listening" : "Start Listening")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: motionViewModel.isListening ? [Color.red.opacity(0.8), Color.red] : [Color.blue.opacity(0.8), Color.blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .shadow(color: (motionViewModel.isListening ? Color.red : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Permissions Warning
                if !actionController.isPermissionGranted {
                    PermissionWarningView(actionController: actionController)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 600)
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
        ZStack(alignment: .topLeading) { // Align toggle to top-left
            VStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(settings.isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(settings.isEnabled ? .blue : .gray)
                }
                
                VStack(spacing: 4) {
                    Text(direction.rawValue)
                        .font(.headline)
                        .foregroundColor(settings.isEnabled ? .primary : .secondary)
                    
                    Text(settings.isEnabled ? (settings.mode == .preset ? settings.preset.rawValue : "Custom Shortcut") : "Disabled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
                
                if settings.mode == .shortcut && settings.isEnabled {
                    Text(settings.shortcutString)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(settings.isEnabled ? 1.0 : 0.6) // Dim if disabled
            
            // Toggle Switch
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    actionController.toggleGesture(for: direction)
                }
            }) {
                ZStack(alignment: settings.isEnabled ? .trailing : .leading) {
                    Capsule()
                        .fill(settings.isEnabled ? Color.green : Color.red)
                        .frame(width: 36, height: 20)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .padding(2)
                        .shadow(radius: 1)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(12)
        }
        .contentShape(Rectangle()) // Make entire area tappable
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
        VStack(spacing: 25) {
            Text("Configure \(actionController.selectedDirection.rawValue)")
                .font(.title2.bold())
                .padding(.top)
            
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
            
            Divider()
            
            // Sensitivity Slider
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Sensitivity", systemImage: "slider.horizontal.3")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f", settings.sensitivity))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Slider(value: Binding(
                    get: { settings.sensitivity },
                    set: { actionController.updateSensitivity($0) }
                ), in: 0.0...1.0)
                .tint(.blue)
                
                HStack {
                    Text("Low")
                    Spacer()
                    Text("High")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Divider()
            
            if settings.mode == .shortcut {
                VStack(spacing: 15) {
                    Text("Recorded Shortcut")
                        .font(.headline)
                    
                    Text(settings.shortcutString)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    
                    Button(action: {
                        if !actionController.isRecording {
                            actionController.startRecording()
                        }
                    }) {
                        Text(actionController.isRecording ? "Press Keys..." : "Record New Shortcut")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(actionController.isRecording ? Color.orange : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(15)
                .padding(.horizontal)
            } else {
                // Preset Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select Action")
                        .font(.headline)
                    
                    Picker("Preset", selection: Binding(
                        get: { settings.preset },
                        set: { actionController.updatePreset($0) }
                    )) {
                        ForEach(PresetAction.allCases, id: \.self) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .frame(width: 350, height: 550)
        .background(.ultraThinMaterial)
    }
}

// Permission Warning Component
struct PermissionWarningView: View {
    @ObservedObject var actionController: ActionController
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Permission Missing")
                    .font(.headline)
                Text("Accessibility access is required.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                Button("Reveal App") {
                    actionController.revealAppInFinder()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .foregroundColor(.primary)
                .cornerRadius(8)
                
                Button("Fix") {
                    actionController.openSettings()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
