import AppKit
import Carbon
import Combine

class KeyboardShortcutRecorder: ObservableObject {
    @Published var recordedShortcut: String = "No shortcut recorded"
    @Published var isRecording: Bool = false
    
    // Persistence keys
    private let kSavedKeyCode = "savedShortcutKeyCode"
    private let kSavedModifiers = "savedShortcutModifiers"
    
    private var monitor: Any?
    private var recordedKeyCode: UInt16?
    private var recordedModifiers: UInt64 = 0
    
    init() {
        loadShortcut()
    }
    
    func startRecording() {
        isRecording = true
        recordedShortcut = "Press key combination..."
        
        // Use local monitor to capture events within the app
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleEvent(event)
            return nil // Consume the event so it doesn't propagate
        }
    }
    
    func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        
        if recordedKeyCode == nil {
            loadShortcut() // Revert to saved if nothing new was recorded
        }
    }
    
    private func handleEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Ignore single modifier key presses (waiting for the actual key)
        if isModifierKey(keyCode) {
            return
        }
        
        // Save the shortcut
        recordedKeyCode = keyCode
        recordedModifiers = UInt64(flags.rawValue)
        saveShortcut()
        
        // Update UI
        formatShortcut()
        
        // Stop recording automatically
        stopRecording()
    }
    
    private func isModifierKey(_ keyCode: UInt16) -> Bool {
        // Common modifier key codes
        let modifiers: Set<UInt16> = [
            54, 55, 56, 57, 58, 59, 60, 61, 62, 63 // Command, Shift, Option, Control, etc.
        ]
        return modifiers.contains(keyCode)
    }
    
    private func saveShortcut() {
        guard let keyCode = recordedKeyCode else { return }
        UserDefaults.standard.set(Int(keyCode), forKey: kSavedKeyCode)
        UserDefaults.standard.set(Int(recordedModifiers), forKey: kSavedModifiers)
    }
    
    private func loadShortcut() {
        let savedCode = UserDefaults.standard.integer(forKey: kSavedKeyCode)
        let savedMods = UserDefaults.standard.integer(forKey: kSavedModifiers)
        
        if savedCode != 0 || UserDefaults.standard.object(forKey: kSavedKeyCode) != nil {
            recordedKeyCode = UInt16(savedCode)
            recordedModifiers = UInt64(savedMods)
            formatShortcut()
        } else {
            recordedShortcut = "No shortcut recorded"
        }
    }
    
    private func formatShortcut() {
        guard let keyCode = recordedKeyCode else {
            recordedShortcut = "No shortcut recorded"
            return
        }
        
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: UInt(recordedModifiers))
        
        if flags.contains(.control) { parts.append("Control") }
        if flags.contains(.option) { parts.append("Option") }
        if flags.contains(.shift) { parts.append("Shift") }
        if flags.contains(.command) { parts.append("Command") }
        
        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        } else {
            parts.append("Key \(keyCode)")
        }
        
        recordedShortcut = parts.joined(separator: " + ")
    }
    
    func triggerShortcut() {
        guard let keyCode = recordedKeyCode else { return }
        
        let source = CGEventSource(stateID: .hidSystemState)
        let flags = CGEventFlags(rawValue: recordedModifiers)
        
        // Create key down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else { return }
        keyDown.flags = flags
        keyDown.post(tap: .cghidEventTap)
        
        // Create key up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        keyUp.flags = flags
        keyUp.post(tap: .cghidEventTap)
        
        print("Triggered shortcut: \(recordedShortcut)")
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        // Simplified mapping or reuse the previous comprehensive one
        // For brevity reusing a smaller set, but in production should be robust
        // Ideally use TIS APIs but a map is fine for now
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
            13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J",
            40: "K", 45: "N", 46: "M", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7",
            27: "-", 28: "8", 29: "0", 24: "=", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/",
            47: ".", 50: "`", 36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape", 123: "Left",
            124: "Right", 125: "Down", 126: "Up"
        ]
        return keyMap[keyCode] ?? "Key \(keyCode)"
    }
}
