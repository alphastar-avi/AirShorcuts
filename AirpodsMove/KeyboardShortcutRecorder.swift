import Foundation
import AppKit
import Combine
import CoreGraphics

class KeyboardShortcutRecorder: ObservableObject {
    @Published var recordedShortcut: String = "No shortcut recorded"
    @Published var isRecording: Bool = false
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recordingTimer: Timer?
    private var recordedKeyCode: UInt16?
    private var recordedModifiers: CGEventFlags = []
    private var completionHandler: (() -> Void)?
    private let recordingLock = NSLock()
    private var _isRecordingInternal: Bool = false
    
    func startRecording(duration: TimeInterval = 2.0, completion: @escaping () -> Void) {
        recordingLock.lock()
        _isRecordingInternal = true
        recordingLock.unlock()
        
        isRecording = true
        recordedKeyCode = nil
        recordedModifiers = []
        completionHandler = completion
        recordedShortcut = "Listening for \(Int(duration)) seconds... Press a key combination"
        
        // Request accessibility permissions if needed
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            recordedShortcut = "Accessibility permissions required. Please enable in System Preferences."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.stopRecording()
                completion()
            }
            return
        }
        
        // Create event tap to intercept keyboard events
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let recorder = Unmanaged<KeyboardShortcutRecorder>.fromOpaque(refcon!).takeUnretainedValue()
                return recorder.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            recordedShortcut = "Failed to create event tap. Check accessibility permissions."
            stopRecording()
            completion()
            return
        }
        
        // Create run loop source and add to main run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        // Set timer to stop recording after duration
        recordingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.recordedKeyCode == nil {
                self.stopRecording()
                completion()
            }
        }
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Check if we're recording (thread-safe check)
        recordingLock.lock()
        let currentlyRecording = _isRecordingInternal
        recordingLock.unlock()
        
        if !currentlyRecording {
            // Not recording, pass event through
            return Unmanaged.passUnretained(event)
        }
        
        // Only process keyDown events when recording
        if type == .keyDown {
            // Capture the key code and modifiers immediately (synchronously)
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // Extract modifier flags (only the ones we care about)
            let modifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
            let extractedModifiers = flags.intersection(modifierMask)
            let capturedKeyCode = UInt16(keyCode)
            
            // Mark that we're no longer recording (thread-safe)
            recordingLock.lock()
            _isRecordingInternal = false
            recordingLock.unlock()
            
            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.recordedModifiers = extractedModifiers
                self.recordedKeyCode = capturedKeyCode
                self.isRecording = false  // Update @Published property on main thread
                
                // Format and notify
                self.formatShortcut()
                self.completionHandler?()
                
                // Stop recording (cleanup event tap, etc.)
                self.cleanupEventTap()
            }
            
            // Return nil to suppress the event (prevent system from processing it)
            // This "freezes" the keyboard - the event never reaches macOS
            return nil
        }
        
        // For flagsChanged and other events, pass them through
        // We only capture when a non-modifier key is actually pressed
        return Unmanaged.passUnretained(event)
    }
    
    private func cleanupEventTap() {
        // Disable and remove event tap
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        
        // Remove run loop source from main run loop
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    func stopRecording() {
        recordingLock.lock()
        _isRecordingInternal = false
        recordingLock.unlock()
        
        isRecording = false
        cleanupEventTap()
        
        if recordedKeyCode == nil {
            recordedShortcut = "No shortcut recorded (timeout)"
        }
    }
    
    private func formatShortcut() {
        guard let keyCode = recordedKeyCode else {
            recordedShortcut = "No shortcut recorded"
            return
        }
        
        var parts: [String] = []
        
        // Add modifier keys in standard order
        if recordedModifiers.contains(.maskControl) {
            parts.append("Control")
        }
        if recordedModifiers.contains(.maskAlternate) {
            parts.append("Option")
        }
        if recordedModifiers.contains(.maskShift) {
            parts.append("Shift")
        }
        if recordedModifiers.contains(.maskCommand) {
            parts.append("Command")
        }
        
        // Add the key
        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        } else {
            parts.append("Key \(keyCode)")
        }
        
        recordedShortcut = parts.joined(separator: " + ")
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        // Comprehensive key code mapping
        let keyMap: [UInt16: String] = [
            // Letters
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
            13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            
            // Numbers
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 25: "9", 26: "7", 27: "-",
            28: "8", 29: "0", 24: "=",
            
            // Symbols
            30: "]", 33: "[", 39: "'", 41: ";", 42: "\\",
            43: ",", 44: "/", 47: ".", 50: "`",
            
            // Special keys
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete",
            53: "Escape", 117: "Forward Delete", 115: "Home",
            119: "End", 116: "Page Up", 121: "Page Down",
            
            // Arrow keys
            123: "Left Arrow", 124: "Right Arrow",
            125: "Down Arrow", 126: "Up Arrow",
            
            // Function keys (standard macOS key codes)
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
            
            // Additional function keys (some Macs)
            113: "F13", 106: "F14", 107: "F15", 105: "F16",
            114: "F17", 112: "F18", 110: "F19"
        ]
        
        return keyMap[keyCode]
    }
    
    func getRecordedShortcut() -> String {
        return recordedShortcut
    }
    
    func hasRecordedShortcut() -> Bool {
        return recordedKeyCode != nil
    }
    
    deinit {
        stopRecording()
    }
}

