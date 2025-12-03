import Foundation
import AppKit
import Combine
import Carbon

enum ActionMode: String, CaseIterable {
    case brightness = "Brightness"
    case shortcut = "Custom Shortcut"
}

class ActionController: ObservableObject {
    @Published var isPermissionGranted: Bool = false
    @Published var currentMode: ActionMode = .brightness
    @Published var isRecording: Bool = false
    @Published var recordedShortcutString: String = "None"
    
    private var monitor: Any?
    private let kSavedKeyCode = "savedKeyCode"
    private let kSavedModifiers = "savedModifiers"
    
    var recordedKeyCode: Int?
    var recordedModifiers: NSEvent.ModifierFlags = []
    
    init() {
        checkPermission()
        loadShortcut()
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
    
    func triggerAction() {
        checkPermission()
        if !isPermissionGranted {
            print("Permission missing")
            return
        }
        
        switch currentMode {
        case .brightness:
            increaseBrightness()
        case .shortcut:
            triggerShortcut()
        }
    }
    
    private func increaseBrightness() {
        print("Triggering Brightness (System Code 2)")
        simulateSystemKey(code: 2)
    }
    
    private func triggerShortcut() {
        guard let keyCode = recordedKeyCode else {
            print("No shortcut recorded")
            return
        }
        
        print("Triggering Shortcut: Code \(keyCode), Mods \(recordedModifiers)")
        
        // Create CGEventFlags from NSEvent.ModifierFlags
        var cgFlags = CGEventFlags()
        if recordedModifiers.contains(.command) { cgFlags.insert(.maskCommand) }
        if recordedModifiers.contains(.option) { cgFlags.insert(.maskAlternate) }
        if recordedModifiers.contains(.control) { cgFlags.insert(.maskControl) }
        if recordedModifiers.contains(.shift) { cgFlags.insert(.maskShift) }
        
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
        recordedShortcutString = "Press keys..."
        
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
        // Ignore standalone modifiers
        if isModifier(event.keyCode) { return }
        
        recordedKeyCode = Int(event.keyCode)
        recordedModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        saveShortcut()
        updateShortcutString()
        stopRecording()
    }
    
    private func isModifier(_ code: UInt16) -> Bool {
        return [54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(code)
    }
    
    private func saveShortcut() {
        UserDefaults.standard.set(recordedKeyCode, forKey: kSavedKeyCode)
        UserDefaults.standard.set(recordedModifiers.rawValue, forKey: kSavedModifiers)
    }
    
    private func loadShortcut() {
        if let code = UserDefaults.standard.object(forKey: kSavedKeyCode) as? Int {
            recordedKeyCode = code
            let rawMods = UserDefaults.standard.integer(forKey: kSavedModifiers)
            recordedModifiers = NSEvent.ModifierFlags(rawValue: UInt(rawMods))
            updateShortcutString()
        }
    }
    
    private func updateShortcutString() {
        guard let code = recordedKeyCode else {
            recordedShortcutString = "None"
            return
        }
        
        var str = ""
        if recordedModifiers.contains(.control) { str += "⌃" }
        if recordedModifiers.contains(.option) { str += "⌥" }
        if recordedModifiers.contains(.shift) { str += "⇧" }
        if recordedModifiers.contains(.command) { str += "⌘" }
        
        // Simple mapping for demo, real app would use TIS functions
        str += "\(code)" 
        recordedShortcutString = str
    }
}
