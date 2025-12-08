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
                    VStack(alignment: .trailing, spacing: 8) {
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
                        
                        // Connection Status
                        HStack(spacing: 6) {
                            Circle()
                                .fill(motionViewModel.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(motionViewModel.isConnected ? "AirPods Connected" : "AirPods Not Detected")
                                .font(.caption)
                                .foregroundColor(motionViewModel.isConnected ? .green : .red)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (motionViewModel.isConnected ? Color.green : Color.red).opacity(0.1)
                        )
                        .cornerRadius(8)
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
                    
                    // Wake Me Widget
                    WakeMeWidget(actionController: actionController, motionViewModel: motionViewModel)
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
                .padding(.vertical, 20)
                
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
            motionViewModel.updateWakeMeSettings(actionController.wakeMeSettings)
        }
        .onChange(of: actionController.gestureSettings.values.map { $0.sensitivity }) { _ in
            motionViewModel.updateThresholds(settings: actionController.gestureSettings)
        }
        .onChange(of: actionController.wakeMeSettings.sensitivity) { _ in
            motionViewModel.updateWakeMeSettings(actionController.wakeMeSettings)
        }
        .onChange(of: actionController.wakeMeSettings.timeout) { _ in
            motionViewModel.updateWakeMeSettings(actionController.wakeMeSettings)
        }
        .onChange(of: actionController.wakeMeSettings.isEnabled) { _ in
            motionViewModel.updateWakeMeSettings(actionController.wakeMeSettings)
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
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1) // Adaptive border
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

// Wake Me Widget
struct WakeMeWidget: View {
    @ObservedObject var actionController: ActionController
    @ObservedObject var motionViewModel: MotionViewModel
    @State private var showingConfig = false
    
    var settings: WakeMeSettings {
        actionController.wakeMeSettings
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if motionViewModel.isAlarmTriggered {
                // Alarm Triggered State
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WAKE UP!")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        
                        Text("No activity detected.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        motionViewModel.resetAlarm()
                    }) {
                        Text("Reset Alarm")
                            .fontWeight(.bold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .foregroundColor(.red)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(20)
                .shadow(color: Color.red.opacity(0.5), radius: 10, x: 0, y: 5)
            } else {
                // Normal State
                HStack(spacing: 20) {
                    // Icon Area
                    ZStack {
                        Circle()
                            .fill(settings.isEnabled ? Color.orange.opacity(0.1) : Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(settings.isEnabled ? .orange : .gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wake Me")
                            .font(.headline)
                            .foregroundColor(settings.isEnabled ? .primary : .secondary)
                        
                        if settings.isEnabled {
                            Text("Alert after \(formatDuration(settings.timeout))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Disabled")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Toggle Switch
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            actionController.toggleWakeMe()
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
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .opacity(settings.isEnabled ? 1.0 : 0.6)
                .onTapGesture {
                    showingConfig = true
                }
            }
        }
        .sheet(isPresented: $showingConfig) {
            WakeMeConfigSheet(actionController: actionController)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// Wake Me Config Sheet
struct WakeMeConfigSheet: View {
    @ObservedObject var actionController: ActionController
    @Environment(\.presentationMode) var presentationMode
    
    @State private var sensitivity: Double
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var soundName: String
    
    @State private var previewSound: NSSound?
    @State private var previewTimer: Timer?
    
    let systemSounds = ["Ping", "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
    
    let ringtones = [
        "Radar", "Apex", "Beacon", "Chimes", "Circuit", "Constellation", "Cosmic", "Crystals", "Hillside", "Illuminate", "Night Owl", "Opening", "Playtime", "Presto", "Radiate", "Ripples", "Sencha", "Signal", "Silk", "Slow Rise", "Stargaze", "Summit", "Twinkle", "Uplift", "Waves", "By The Seaside"
    ]
    
    init(actionController: ActionController) {
        self.actionController = actionController
        _sensitivity = State(initialValue: actionController.wakeMeSettings.sensitivity)
        _minutes = State(initialValue: Int(actionController.wakeMeSettings.timeout) / 60)
        _seconds = State(initialValue: Int(actionController.wakeMeSettings.timeout) % 60)
        _soundName = State(initialValue: actionController.wakeMeSettings.soundName)
    }
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Configure Wake Me")
                .font(.title2.bold())
                .padding(.top)
            
            Divider()
            
            // Sensitivity
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Movement Sensitivity", systemImage: "slider.horizontal.3")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f", sensitivity))
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Slider(value: $sensitivity, in: 0.0...1.0)
                    .tint(.orange)
                
                HStack {
                    Text("I'll be more active\n(Needs more movement)")
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text("I'll be less active\n(Needs less active)")
                        .multilineTextAlignment(.trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            Divider()
            
            // Timeout Picker
            VStack(alignment: .leading, spacing: 10) {
                Label("Timeout Duration", systemImage: "timer")
                    .font(.headline)
                
                HStack {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0...59, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .frame(width: 140)
                    
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0...59, id: \.self) { Text("\($0) sec").tag($0) }
                    }
                    .frame(width: 140)
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(.horizontal)
            
            Divider()
            
            // Sound Picker
            VStack(alignment: .leading, spacing: 10) {
                Label("Alert Sound", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                
                Picker("Sound", selection: $soundName) {
                    Section(header: Text("Alarms")) {
                        ForEach(ringtones, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    
                    Section(header: Text("System Sounds")) {
                        ForEach(systemSounds, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: soundName) { newSound in
                    // Stop previous preview
                    previewSound?.stop()
                    previewTimer?.invalidate()
                    
                    // Preview sound
                    let ringtonePath = "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones/\(newSound).m4r"
                    var soundToPlay: NSSound?
                    
                    if FileManager.default.fileExists(atPath: ringtonePath) {
                        let url = URL(fileURLWithPath: ringtonePath)
                        soundToPlay = NSSound(contentsOf: url, byReference: true)
                    } else {
                        soundToPlay = NSSound(named: newSound)
                    }
                    
                    if let sound = soundToPlay {
                        sound.play()
                        previewSound = sound
                        
                        // Stop after 4 seconds
                        previewTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
                            sound.stop()
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            Button("Done") {
                // Stop preview
                previewSound?.stop()
                previewTimer?.invalidate()
                
                // Save settings
                var newSettings = actionController.wakeMeSettings
                newSettings.sensitivity = sensitivity
                newSettings.timeout = TimeInterval(minutes * 60 + seconds)
                newSettings.soundName = soundName
                actionController.updateWakeMeSettings(newSettings)
                
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom)
        }
        .frame(width: 350, height: 600) // Increased height for more options
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
}
