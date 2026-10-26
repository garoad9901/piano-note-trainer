# iOS Bluetooth MIDI diagnostic v0.1.0

LX705GP Bluetooth MIDI → iPhone Core MIDI native diagnostic.

## Requirements
- Xcode on a Mac, iOS deployment target iOS 16+
- Bluetooth permission in Info.plist: NSBluetoothAlwaysUsageDescription = 電子ピアノのBluetooth MIDIに接続するため使用します。
- Enable Core MIDI Bluetooth device discovery from app.

## Steps
1. Create an iOS SwiftUI App project in Xcode.
2. Add ContentView.swift from this folder to the project.
3. Run on physical iPhone (not simulator).
4. In the app tap Bluetooth MIDI機器を選ぶ, select LX705 MIDI and connect.
5. Play C3/C4/C5, repeated notes, quiet notes, chords. Check Note On/Off and velocity.

Safari cannot directly access Bluetooth MIDI through Web MIDI. The native test app verifies the MIDI layer separately. The future Safari integration will need a separately validated transport (e.g. native wrapper/WKWebView JavaScript bridge); no Safari integration is implied by this diagnostic.
