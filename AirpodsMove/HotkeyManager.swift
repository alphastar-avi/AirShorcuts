import Foundation
import Carbon
import AppKit

class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: ((NSEvent) -> Void)?
    
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping (NSEvent) -> Void) {
        self.eventHandler = handler
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (nextHanlder, event, userData) -> OSStatus in
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
            if let event = event {
                if let nsEvent = NSEvent(eventRef: UnsafeRawPointer(event)) {
                    hotkeyManager.eventHandler?(nsEvent)
                }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
        
        let hotKeyID = EventHotKeyID(signature: "htk1".fourCharCodeValue, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

extension String {
    var fourCharCodeValue: FourCharCode {
        return self.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
    }
}
