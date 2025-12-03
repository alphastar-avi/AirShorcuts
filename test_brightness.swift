import AppKit

// NX_KEYTYPE_BRIGHTNESS_UP is commonly 2 or 145 depending on context
// Let's try the standard system defined event structure

func postBrightnessEvent(key: Int) {
    let loc = NSEvent.mouseLocation
    // data1 = (key << 16) | (flags << 8)
    // flags: 0xa is often used for system keys
    let data1 = (key << 16) | (0xa << 8)
    
    guard let event = NSEvent.otherEvent(
        with: .systemDefined,
        location: loc,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        subtype: 8,
        data1: data1,
        data2: -1
    ) else {
        print("Failed to create event for key \(key)")
        return
    }
    
    event.cgEvent?.post(tap: .cghidEventTap)
    print("Posted event for key \(key)")
}

// Try standard NX constants
// NX_KEYTYPE_BRIGHTNESS_UP = 2
print("Trying NX_KEYTYPE_BRIGHTNESS_UP = 2")
postBrightnessEvent(key: 2)

// Try HID usage page value
// kHIDUsage_KeyboardBrightnessUp = 145 (0x91)
print("Trying kHIDUsage_KeyboardBrightnessUp = 145")
postBrightnessEvent(key: 145)

// Try another common value
print("Trying value 113 (F15/Brightness)")
postBrightnessEvent(key: 113)
