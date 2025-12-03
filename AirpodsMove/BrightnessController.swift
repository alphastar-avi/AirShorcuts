import Foundation
import AppKit
import Combine

class BrightnessController: ObservableObject {
    @Published var isPermissionGranted: Bool = false
    
    init() {
        checkPermission()
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
    
    func increaseBrightness() {
        checkPermission()
        
        if !isPermissionGranted {
            print("Accessibility permissions missing. Cannot control brightness.")
            return
        }
        
        print("--- Triggering Brightness Increase (Corrected) ---")
        
        // Correct Method: System Event with NX_KEYTYPE_BRIGHTNESS_UP (2)
        simulateSystemKey(code: 2, name: "System Brightness Up (2)")
    }
    
    private func simulateKey(code: CGKeyCode, name: String) {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false) else { return }
        
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        print("Simulated \(name) (Code \(code))")
    }
    
    private func simulateSystemKey(code: Int, name: String) {
        let loc = NSEvent.mouseLocation
        
        // NX_KEYTYPE_BRIGHTNESS_UP is 2
        // flags: 0xa for down, 0xb for up is standard for these events
        let data1Down = (code << 16) | (0xa << 8)
        let data1Up = (code << 16) | (0xb << 8)
        
        guard let down = NSEvent.otherEvent(with: .systemDefined, location: loc, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1Down, data2: -1),
              let up = NSEvent.otherEvent(with: .systemDefined, location: loc, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1Up, data2: -1) else { return }
        
        down.cgEvent?.post(tap: .cghidEventTap)
        up.cgEvent?.post(tap: .cghidEventTap)
        
        print("Simulated \(name)")
    }
}
