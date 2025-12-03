import Foundation
import AppKit
import Combine
import Carbon

enum ActionMode: String, CaseIterable, Codable {
    case brightness = "Brightness"
    case shortcut = "Custom Shortcut"
}

// GestureSettings struct to hold configuration for each direction
struct GestureSettings: Codable {
    var mode: ActionMode = .brightness
    var sensitivity: Double = 0.7 // Default to ~Normal (0.15 threshold)
    var recordedKeyCode: Int?
    var recordedModifiers: Int = 0 // Store raw value for Codable simplicity
    var shortcutString: String = "None"
}

class ActionController: ObservableObject {
    @Published var isPermissionGranted: Bool = false
    @Published var isRecording: Bool = false
    
    // Dictionary to hold settings for each direction
    @Published var gestureSettings: [GestureDirection: GestureSettings] = [
        .up: GestureSettings(mode: .brightness),
        .down: GestureSettings(mode: .shortcut),
        .left: GestureSettings(mode: .shortcut),
        .right: GestureSettings(mode: .shortcut)
    ]
    
    // Current direction being configured (for UI)
    @Published var selectedDirection: GestureDirection = .up
    
    private var monitor: Any?
    private let kSavedSettings = "savedGestureSettings"
    
    init() {
        checkPermission()
        loadSettings()
    }
    
    func checkPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        isPermissionGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func openSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
    
    // MARK: - Triggering
    
    func triggerAction(for direction: GestureDirection) {
        checkPermission()
        if !isPermissionGranted {
            print("Permission missing")
            return
        }
        
        guard let settings = gestureSettings[direction] else { return }
        
        print("Triggering Action for \(direction.rawValue): \(settings.mode.rawValue)")
        
        switch settings.mode {
        case .brightness:
            increaseBrightness()
        case .shortcut:
            triggerShortcut(settings: settings)
        }
    }
    
    private func increaseBrightness() {
        print("Triggering Brightness (System Code 2)")
        simulateSystemKey(code: 2)
    }
    
    private func triggerShortcut(settings: GestureSettings) {
        guard let keyCode = settings.recordedKeyCode else {
            print("No shortcut recorded for this direction")
            return
        }
        
        let modifiers = NSEvent.ModifierFlags(rawValue: UInt(settings.recordedModifiers))
        print("Triggering Shortcut: Code \(keyCode), Mods \(modifiers)")
        
        var cgFlags = CGEventFlags()
        if modifiers.contains(.command) { cgFlags.insert(.maskCommand) }
        if modifiers.contains(.option) { cgFlags.insert(.maskAlternate) }
        if modifiers.contains(.control) { cgFlags.insert(.maskControl) }
        if modifiers.contains(.shift) { cgFlags.insert(.maskShift) }
        
        let cgKeyCode = CGKeyCode(keyCode)
        
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: cgKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: cgKeyCode, keyDown: false) else { return }
        
        down.flags = cgFlags
        up.flags = cgFlags
        
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
    
    private func simulateSystemKey(code: Int) {
        let loc = NSEvent.mouseLocation
        let data1Down = (code << 16) | (0xa << 8)
        let data1Up = (code << 16) | (0xb << 8)
        
        guard let down = NSEvent.otherEvent(with: .systemDefined, location: loc, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1Down, data2: -1),
              let up = NSEvent.otherEvent(with: .systemDefined, location: loc, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1Up, data2: -1) else { return }
        
        down.cgEvent?.post(tap: .cghidEventTap)
        up.cgEvent?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Recording
    
    func startRecording() {
        isRecording = true
        // Update string to indicate recording
        var current = gestureSettings[selectedDirection] ?? GestureSettings()
        current.shortcutString = "Press keys..."
        
        // Mutate dictionary
        var newSettings = gestureSettings
        newSettings[selectedDirection] = current
        gestureSettings = newSettings
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
            return nil
        }
    }
    
    func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        if isModifier(event.keyCode) { return }
        
        var current = gestureSettings[selectedDirection] ?? GestureSettings()
        current.recordedKeyCode = Int(event.keyCode)
        current.recordedModifiers = Int(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
        
        // Update string
        current.shortcutString = formatShortcut(code: current.recordedKeyCode!, modifiers: current.recordedModifiers)
        
        // Mutate dictionary
        var newSettings = gestureSettings
        newSettings[selectedDirection] = current
        gestureSettings = newSettings
        
        saveSettings()
        stopRecording()
    }
    
    private func isModifier(_ code: UInt16) -> Bool {
        return [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(code)
    }
    
    private func formatShortcut(code: Int, modifiers: Int) -> String {
        let mods = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        var str = ""
        if mods.contains(.control) { str += "⌃" }
        if mods.contains(.option) { str += "⌥" }
        if mods.contains(.shift) { str += "⇧" }
        if mods.contains(.command) { str += "⌘" }
        str += "\(code)"
        return str
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(gestureSettings) {
            UserDefaults.standard.set(encoded, forKey: kSavedSettings)
        }
    }
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: kSavedSettings),
           let decoded = try? JSONDecoder().decode([GestureDirection: GestureSettings].self, from: data) {
            gestureSettings = decoded
        }
    }
    
    // Helper to update mode
    func updateMode(_ mode: ActionMode) {
        var current = gestureSettings[selectedDirection] ?? GestureSettings()
        current.mode = mode
        
        // Mutate dictionary
        var newSettings = gestureSettings
        newSettings[selectedDirection] = current
        gestureSettings = newSettings
        
        saveSettings()
    }
    
    // Helper to update sensitivity
    func updateSensitivity(_ sensitivity: Double) {
        var current = gestureSettings[selectedDirection] ?? GestureSettings()
        current.sensitivity = sensitivity
        
        // Mutate dictionary
        var newSettings = gestureSettings
        newSettings[selectedDirection] = current
        gestureSettings = newSettings
        
        saveSettings()
    }
}
