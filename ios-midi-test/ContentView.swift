import SwiftUI
import CoreMIDI
import CoreAudioKit

// 【ChatGPT】Bluetooth MIDI test
// 【FileName】ContentView.swift
// 【作成日時】2026-10-26
// 【概要】Roland LX705GP Bluetooth MIDI接続と受信音高・Velocityを検証
// 【使い方】実機iPhoneで起動し「Bluetooth MIDI機器を選ぶ」からLX705 MIDIを接続
// 【仕様】Core MIDIのNote On/Off受信、音名表示、ログ。Safari連携は対象外。

final class MidiMonitor: ObservableObject {
    @Published var status = "Bluetooth MIDI機器を接続してください"
    @Published var lastNote = "—"
    @Published var detail = ""
    @Published var log: [String] = []
    @Published var onCount = 0
    @Published var offCount = 0

    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var connected = Set<MIDIEndpointRef>()

    init() {
        let result = MIDIClientCreateWithBlock("LX705 Monitor" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.scan() }
        }
        guard result == noErr else { status = "MIDIClient作成エラー: \(result)"; return }
        let p = MIDIInputPortCreateWithBlock(client, "Input" as CFString, &port) { [weak self] packetList, _ in
            let list = packetList.pointee
            var packet = list.packet
            for _ in 0..<list.numPackets {
                let bytes = withUnsafeBytes(of: packet.data) { raw in
                    Array(raw.prefix(Int(packet.length)))
                }
                self?.decode(bytes)
                packet = MIDIPacketNext(&packet).pointee
            }
        }
        if p != noErr { status = "MIDIポート作成エラー: \(p)" }
        scan()
    }

    func scan() {
        var names: [String] = []
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            var property: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &property)
            let name = property?.takeRetainedValue() as String? ?? "MIDI Source"
            names.append(name)
            if !connected.contains(endpoint) {
                if MIDIPortConnectSource(port, endpoint, nil) == noErr {
                    connected.insert(endpoint)
                }
            }
        }
        status = names.isEmpty ? "MIDI入力が見つかりません" : "接続中: " + names.joined(separator: ", ")
    }

    private func decode(_ bytes: [UInt8]) {
        // Test target uses legacy MIDI 1.0 packet messages.
        var i = 0
        var runningStatus: UInt8 = 0
        while i < bytes.count {
            if bytes[i] >= 0xF8 { i += 1; continue }
            if bytes[i] & 0x80 != 0 {
                runningStatus = bytes[i]
                i += 1
            }
            let kind = runningStatus & 0xF0
            guard kind == 0x80 || kind == 0x90 else { break }
            guard i + 1 < bytes.count else { break }
            let note = Int(bytes[i]), velocity = Int(bytes[i + 1])
            i += 2
            let isOn = kind == 0x90 && velocity > 0
            let noteName = ["ド","ド♯","レ","レ♯","ミ","ファ","ファ♯","ソ","ソ♯","ラ","ラ♯","シ"][note % 12] + String(note / 12 - 1)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if isOn {
                    self.onCount += 1
                    self.lastNote = noteName
                    self.detail = "MIDI \(note) / Velocity \(velocity)"
                } else {
                    self.offCount += 1
                }
                self.log.insert("\(isOn ? "ON" : "OFF") \(noteName) velocity=\(velocity)", at: 0)
                if self.log.count > 60 { self.log.removeLast() }
            }
        }
    }

    deinit {
        if port != 0 { MIDIPortDispose(port) }
        if client != 0 { MIDIClientDispose(client) }
    }
}

struct ContentView: View {
    @StateObject private var monitor = MidiMonitor()
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(monitor.status).font(.subheadline)
                    Button("Bluetooth MIDI機器を選ぶ") { showPicker = true }
                        .buttonStyle(.borderedProminent)
                    Button("入力機器を再検索") { monitor.scan() }
                    Divider()
                    Text(monitor.lastNote).font(.system(size: 62, weight: .bold))
                    Text(monitor.detail)
                    Text("Note On: \(monitor.onCount) / Note Off: \(monitor.offCount)")
                    Divider()
                    Text("受信ログ").font(.headline)
                    ForEach(Array(monitor.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption, design: .monospaced))
                    }
                }.padding()
            }
            .navigationTitle("LX705 MIDI テスト")
            .sheet(isPresented: $showPicker, onDismiss: { monitor.scan() }) {
                BluetoothMIDIPicker()
            }
        }
    }
}

struct BluetoothMIDIPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CABTMIDICentralViewController {
        CABTMIDICentralViewController()
    }
    func updateUIViewController(_ uiViewController: CABTMIDICentralViewController, context: Context) {}
}
