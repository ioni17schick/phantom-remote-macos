import SwiftUI
import AppKit

extension Color {
    static let bgTop = Color(red: 0.09, green: 0.095, blue: 0.11)
    static let bgBottom = Color(red: 0.025, green: 0.025, blue: 0.03)
    static let accentWarm = Color(red: 0.93, green: 0.80, blue: 0.62)
}
struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased()).font(.system(size: 10.5, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
            content
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08)))
    }
}
struct RoundIconButton: View {
    let icon: String
    var size: CGFloat = 40
    var active = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size * 0.38))
                .frame(width: size, height: size)
                .foregroundStyle(active ? .black : .white)
                .background(active ? .white : .white.opacity(0.08), in: Circle())
        }.buttonStyle(.plain)
    }
}

/// Original, abstract speaker emblem. No manufacturer artwork or logos are shipped.
struct PhantomGraphic: View {
    var width: CGFloat = 150
    var identifying = false
    var dimmed = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.22)
                .fill(LinearGradient(colors: [Color(white: 0.23), Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: width * 0.22).stroke(Color.accentWarm.opacity(identifying ? 0.9 : 0.25), lineWidth: 1.5))
            VStack(spacing: width * 0.09) {
                HStack(spacing: width * 0.025) {
                    ForEach(0..<7) { index in
                        Capsule().fill(Color.accentWarm.opacity(identifying ? 1 : 0.7))
                            .frame(width: width * 0.024, height: width * CGFloat([0.05, 0.10, 0.15, 0.21, 0.15, 0.10, 0.05][index]))
                    }
                }
                ZStack {
                    Circle().stroke(.white.opacity(0.17), lineWidth: width * 0.014)
                    Circle().fill(RadialGradient(colors: [Color(white: 0.26), Color(white: 0.07)], center: .topLeading, startRadius: 0, endRadius: width * 0.35)).padding(width * 0.035)
                    Circle().stroke(Color.accentWarm.opacity(0.5), lineWidth: 1).padding(width * 0.13)
                }.frame(width: width * 0.49, height: width * 0.49)
            }
        }
        .frame(width: width * 0.8, height: width * 0.88)
        .shadow(color: identifying ? Color.accentWarm.opacity(0.25) : .black.opacity(0.4), radius: width * 0.07, y: 5)
        .frame(width: width, height: width * 0.95)
        .opacity(dimmed ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.25), value: identifying)
        .accessibilityLabel("Lautsprecher")
    }
}
@MainActor final class DragState: ObservableObject { var start: Double? }
struct VolumeDial: View {
    @ObservedObject var p: Phantom
    @StateObject private var drag = DragState()
    var size: CGFloat = 240
    var body: some View {
        let fraction = max(0, min(1, p.volume / 100))
        ZStack {
            ForEach(0..<41) { index in
                Capsule().fill(.white.opacity(Double(index) / 40 <= fraction ? 0.8 : 0.15))
                    .frame(width: 2, height: index % 5 == 0 ? 10 : 5)
                    .offset(y: -size / 2 + size * 0.033)
                    .rotationEffect(.degrees(-135 + 270 * Double(index) / 40))
            }
            let ring = max(4, size * 0.021)
            Circle().trim(from: 0, to: 0.75).stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: ring, lineCap: .round)).rotationEffect(.degrees(135)).padding(size * 0.125)
            Circle().trim(from: 0, to: 0.75 * fraction).stroke(Color.accentWarm, style: StrokeStyle(lineWidth: ring, lineCap: .round)).rotationEffect(.degrees(135)).padding(size * 0.125)
            VStack(spacing: size * 0.016) {
                Text(p.muted ? "–" : "\(Int(p.volume))").font(.system(size: size * 0.267, weight: .ultraLight, design: .rounded)).monospacedDigit()
                Text(p.muted ? "STUMM" : "LAUTSTÄRKE").font(.system(size: max(9, size * 0.042), weight: .semibold)).tracking(2).foregroundStyle(.secondary)
                Text("Limit \(p.volumeLimit)").font(.system(size: max(9, size * 0.042))).foregroundStyle(Color.accentWarm.opacity(0.8))
            }
        }
        .frame(width: size, height: size).contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard p.canControl else { return }
                if drag.start == nil { drag.start = p.volume; p.beginDrag() }
                if let start = drag.start { p.volume = Double(VolumePolicy.dragged(start: start, translationY: value.translation.height, limit: p.volumeLimit)) }
            }
            .onEnded { _ in
                if drag.start != nil { p.sendVolume(); p.endDrag() }; drag.start = nil
            })
        .onDisappear { drag.start = nil; p.endDrag() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lautstärke")
        .accessibilityValue("\(Int(p.volume)) von 100")
        .accessibilityAdjustableAction { direction in Task { await p.step(direction == .increment ? 1 : -1, hud: false) } }
        .help("Nach oben oder unten ziehen. Ein Klick ändert die Lautstärke nicht.")
    }
}
struct SpeakerView: View {
    @ObservedObject var p: Phantom
    let device: DDevice
    var body: some View {
        let ms = p.pingMs[device.id] ?? nil
        let active = p.identifying.contains(device.id)
        VStack(spacing: 7) {
            Button { Task { await p.identify(device) } } label: {
                PhantomGraphic(width: 130, identifying: active, dimmed: !p.online)
            }.buttonStyle(.plain).disabled(!p.canControl || active)
                .accessibilityLabel("\(device.deviceName) identifizieren")
            Text(device.deviceName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            HStack(spacing: 5) {
                Circle().fill(ms == nil ? Color.orange : .green).frame(width: 6, height: 6)
                Text("\(role) · \(ms.map { "\($0) ms" } ?? "nicht bestätigt")").font(.system(size: 9.5)).foregroundStyle(.secondary)
            }
            Text(active ? "TESTTON ANGEFORDERT" : "ZUM TESTEN KLICKEN")
                .font(.system(size: 8.5, weight: .semibold)).tracking(0.7).foregroundStyle(Color.accentWarm)
        }.frame(width: 155)
    }
    var role: String {
        switch device.role { case "FrontLeft": return "Links"; case "FrontRight": return "Rechts"; default: return "Mono" }
    }
}
struct ErrorBanner: View {
    @ObservedObject var p: Phantom
    var body: some View {
        if let message = p.errorMessage {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Color.accentWarm)
                Text(message).font(.system(size: 12)).textSelection(.enabled)
                Spacer()
                Button { p.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Fehlermeldung schließen")
            }.padding(12).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
struct MainView: View {
    @ObservedObject var p = Phantom.shared
    var body: some View {
        GeometryReader { geo in
            let mode = LayoutMode(width: geo.size.width, height: geo.size.height)
            Group {
                if !p.everConnected { ScrollView { VStack(spacing: 20) { header; ErrorBanner(p: p); welcome; footer }.padding(26) } }
                else {
                    switch mode {
                    case .compact: compact(geo.size)
                    case .regular: regular
                    case .large: large(geo.size)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 0.25), value: mode)
        }
        .frame(minWidth: 280, idealWidth: 780, minHeight: 330, idealHeight: 800)
        .foregroundStyle(.white).environment(\.colorScheme, .dark)
        .background(LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom))
        .sheet(isPresented: $p.deviceSheet) { DevicesView(p: p) }
        .onAppear { p.viewAppeared() }.onDisappear { p.viewDisappeared() }
    }

    // MARK: Klein – nur Lautstärke
    func compact(_ size: CGSize) -> some View {
        let dial = max(150, min(size.width - 40, size.height - 130))
        return VStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(p.online ? Color.green : .orange).frame(width: 7, height: 7)
                Text(p.systemName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer()
                Button { p.deviceSheet = true } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).foregroundStyle(.secondary).help("Geräte …")
            }
            if let message = p.errorMessage {
                Text(message).font(.system(size: 10)).foregroundStyle(Color.accentWarm).lineLimit(2).onTapGesture { p.errorMessage = nil }
            }
            Spacer(minLength: 0)
            VolumeDial(p: p, size: dial).disabled(!p.canControl).opacity(p.online ? 1 : 0.45)
            Spacer(minLength: 0)
            volumeButtons(size: 34, mute: 42)
        }
        .padding(.horizontal, 18).padding(.top, 30).padding(.bottom, 18)
    }

    // MARK: Normal – bisherige Ansicht, flexibel in der Breite
    var regular: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                ErrorBanner(p: p)
                HStack {
                    if let first = p.speakers.first { SpeakerView(p: p, device: first) }
                    Spacer(minLength: 0)
                    VolumeDial(p: p).disabled(!p.canControl)
                    Spacer(minLength: 0)
                    if p.speakers.count > 1 { SpeakerView(p: p, device: p.speakers[1]) }
                    else { Color.clear.frame(width: 155, height: 1) }
                }.opacity(p.online ? 1 : 0.45)
                volumeButtons(size: 40, mute: 46)
                HStack(alignment: .top, spacing: 18) { playback(showNowPlaying: true); sound }
                    .disabled(!p.canControl)
                footer
            }.padding(26)
        }
    }

    // MARK: Groß / Vollbild – Now Playing
    func large(_ size: CGSize) -> some View {
        let dial = min(420, max(260, size.height * 0.42))
        return ScrollView {
            VStack(spacing: 28) {
                header
                ErrorBanner(p: p)
                HStack(alignment: .center, spacing: 48) {
                    nowPlaying(art: min(300, size.height * 0.3))
                        .frame(maxWidth: .infinity)
                    VStack(spacing: 18) {
                        VolumeDial(p: p, size: dial).disabled(!p.canControl).opacity(p.online ? 1 : 0.45)
                        volumeButtons(size: 46, mute: 56)
                        HStack(spacing: 24) { ForEach(p.speakers) { SpeakerView(p: p, device: $0) } }
                    }
                    .frame(maxWidth: .infinity)
                }
                HStack(alignment: .top, spacing: 24) { playback(showNowPlaying: false); sound }
                    .disabled(!p.canControl)
                footer
            }
            .padding(.horizontal, 48).padding(.vertical, 36)
            .frame(maxWidth: 1500)
            .frame(maxWidth: .infinity)
        }
    }

    /// Große Wiedergabe-Ansicht: Quelle, Titel, Interpret, Format und Transport-Buttons.
    func nowPlaying(art: CGFloat) -> some View {
        let info = sourceInfo(p.currentType)
        let canPrevious = p.ops.contains("previous"), canNext = p.ops.contains("next")
        let playPause = p.playing ? "pause" : "play"
        let canPlayPause = p.ops.contains(playPause)
        return VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: art * 0.12)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: art * 0.12).stroke(.white.opacity(0.08)))
                Image(systemName: info.icon).font(.system(size: art * 0.32, weight: .light)).foregroundStyle(Color.accentWarm)
            }.frame(width: art, height: art)
            VStack(spacing: 8) {
                Text("JETZT LÄUFT").font(.system(size: 11, weight: .semibold)).tracking(2.5).foregroundStyle(.secondary)
                Text(p.title.isEmpty ? info.label : p.title).font(.system(size: 30, weight: .semibold)).multilineTextAlignment(.center).lineLimit(2)
                let detail = [p.artist, p.peer].filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty { Text(detail).font(.system(size: 17)).foregroundStyle(.secondary).lineLimit(1) }
                if !p.codec.isEmpty { Text(p.codec).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.accentWarm.opacity(0.85)) }
            }
            HStack(spacing: 26) {
                RoundIconButton(icon: "backward.fill", size: 54) { Task { await p.previous() } }
                    .disabled(!canPrevious).opacity(canPrevious ? 1 : 0.35).accessibilityLabel("Zurück")
                RoundIconButton(icon: p.playing ? "pause.fill" : "play.fill", size: 76, active: canPlayPause) { Task { await p.playPause() } }
                    .disabled(!canPlayPause).opacity(canPlayPause ? 1 : 0.35).accessibilityLabel(p.playing ? "Pause" : "Wiedergabe")
                RoundIconButton(icon: "forward.fill", size: 54) { Task { await p.next() } }
                    .disabled(!canNext).opacity(canNext ? 1 : 0.35).accessibilityLabel("Weiter")
            }
            .disabled(!p.canControl)
            if !canPrevious && !canNext && !canPlayPause {
                Text("\(info.label): Wiedergabe am Zuspieler steuern – diese Quelle bietet keine Fernsteuerung.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    func volumeButtons(size: CGFloat, mute: CGFloat) -> some View {
        HStack(spacing: size * 0.35) {
            RoundIconButton(icon: "minus", size: size) { Task { await p.step(-2, hud: false) } }.accessibilityLabel("Leiser")
            RoundIconButton(icon: p.muted ? "speaker.slash.fill" : "speaker.wave.2.fill", size: mute, active: p.muted) { Task { await p.toggleMute(hud: false) } }.accessibilityLabel("Stumm umschalten")
            RoundIconButton(icon: "plus", size: size) { Task { await p.step(2, hud: false) } }.accessibilityLabel("Lauter")
        }.disabled(!p.canControl)
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(p.systemName).font(.system(size: 24, weight: .light)).tracking(2)
                Text(p.target == nil ? "Inoffizielle Fernbedienung · Beta" : "\(p.model) · \(p.speakers.count) Lautsprecher").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(p.online ? "● Verbunden" : p.status).font(.system(size: 11)).foregroundStyle(p.online ? .green : .secondary)
            Button("Geräte …") { p.deviceSheet = true }.disabled(p.busy)
        }
    }

    var welcome: some View {
        VStack(spacing: 18) {
            PhantomGraphic(width: 170)
            Text("Wähle dein Phantom-System aus.").font(.title3)
            Text("Automatisch im lokalen Netzwerk suchen oder eine IP-Adresse eingeben.").font(.callout).foregroundStyle(.secondary)
            Button("Geräte auswählen") { p.deviceSheet = true }.buttonStyle(.borderedProminent).tint(.accentWarm).foregroundStyle(.black)
        }.frame(maxWidth: .infinity).padding(.vertical, 60)
    }

    var footer: some View {
        HStack {
            Text("⌃⌥↑ / ↓ Lautstärke · ⌃⌥M Stumm").font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            if p.pending > 0 { ProgressView().controlSize(.small) }
            UpdateStatusView()
            Button("Verbindung prüfen") { Task { await p.refresh() } }.disabled(p.busy || p.target == nil).controlSize(.small)
        }
    }
    func playback(showNowPlaying: Bool) -> some View {
        Card(title: showNowPlaying ? "Wiedergabe" : "Quelle") {
            if showNowPlaying {
            HStack {
                Image(systemName: sourceInfo(p.currentType).icon).font(.title2).foregroundStyle(Color.accentWarm)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.title.isEmpty ? sourceInfo(p.currentType).label : p.title).font(.headline).lineLimit(1)
                    Text([p.artist, p.peer, p.codec].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
            }
            if p.ops.contains("play") || p.ops.contains("pause") {
                HStack {
                    if p.ops.contains("previous") { Button { Task { await p.previous() } } label: { Image(systemName: "backward.fill") } }
                    Button { Task { await p.playPause() } } label: { Image(systemName: p.playing ? "pause.fill" : "play.fill") }
                        .disabled(!p.ops.contains(p.playing ? "pause" : "play"))
                    if p.ops.contains("next") { Button { Task { await p.next() } } label: { Image(systemName: "forward.fill") } }
                }.buttonStyle(.bordered)
            }
            }
            ForEach(p.selectableSources) { source in
                Button { Task { await p.select(source) } } label: {
                    HStack {
                        Image(systemName: sourceInfo(source.type).icon)
                        Text(p.sourceLabel(source)).lineLimit(1)
                        Spacer()
                        if p.currentSourceID == source.id { Image(systemName: "checkmark").foregroundStyle(Color.accentWarm) }
                    }.padding(9).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain)
            }
            Button("Mac per AirPlay verbinden …") { p.openAirPlaySettings() }.controlSize(.small)
            Text("Spotify, Bluetooth, Roon und UPnP werden vom jeweiligen Zuspieler gestartet.").font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(minWidth: 0, maxWidth: .infinity)
    }
    var sound: some View {
        Card(title: "Klang") {
            if p.supportsNight {
                Toggle("Nachtmodus", isOn: Binding(get: { p.nightMode }, set: { value in Task { await p.setNight(value) } })).toggleStyle(.switch).tint(.accentWarm)
            }
            if p.supportsEq {
                Picker("Klang", selection: Binding(get: { p.eqPreset }, set: { value in Task { await p.setEq(value) } })) {
                    ForEach(p.eqPresets, id: \.self) { preset in Text(presetName(preset)).tag(preset) }
                }.labelsHidden()
                if p.eqPresets.contains("custom") {
                    Text("Regler aktivieren „Eigene“.").font(.caption2).foregroundStyle(.secondary)
                    adjustment("Bass", value: $p.eqLow, range: p.eqRange, unit: "dB") { p.sendCustomEq() }
                    adjustment("Höhen", value: $p.eqHigh, range: p.eqRange, unit: "dB") { p.sendCustomEq() }
                }
            }
            if p.supportsBalance { adjustment("Balance", value: $p.balance, range: -10...10, unit: "") { p.sendBalance() } }
            if !p.supportsNight && !p.supportsEq && !p.supportsBalance {
                Text("Für dieses System sind keine Klangeinstellungen verfügbar.").font(.callout).foregroundStyle(.secondary)
            }
        }.frame(minWidth: 0, maxWidth: .infinity)
    }
    func adjustment(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue)) \(unit)").monospacedDigit().foregroundStyle(.secondary) }.font(.caption)
            Slider(value: value, in: range, step: 1, onEditingChanged: { editing in if editing { p.beginDrag() } else { action(); p.endDrag() } }).tint(.accentWarm)
        }
    }
    func presetName(_ value: String) -> String { ["flat": "Neutral", "voice": "Sprache", "custom": "Eigene"][value] ?? value }
}
struct DevicesView: View {
    @ObservedObject var p: Phantom
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Lautsprecher & Verbindung").font(.title2)
                Spacer()
                Button("Fertig") { p.deviceSheet = false }.disabled(p.connecting)
            }
            ErrorBanner(p: p)
            Text("Wähle den System-Leader deines Paars. Bei einem Ausfall wechselt die App nicht auf ein anderes System.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                TextField("IP-Adresse oder hostname.local[:port]", text: $p.addressInput)
                    .textFieldStyle(.roundedBorder).onSubmit { Task { await p.addAddress() } }
                    .disabled(p.busy)
                Button("Prüfen") { Task { await p.addAddress() } }.disabled(p.busy || p.addressInput.isEmpty)
            }
            HStack {
                Button(p.searching ? "Suche läuft …" : "Im Netzwerk suchen (mDNS)") { p.rediscover() }.disabled(p.searching)
                if p.searching || p.connecting { ProgressView().controlSize(.small) }
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(p.foundDevices) { found in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(found.systemName) · \(found.device.deviceName)").font(.headline)
                                Text("\(found.endpoint.address) · \(found.device.isSystemLeader == true ? "System-Leader" : "Zweiter Lautsprecher")")
                                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            Spacer()
                            if found.device.isSystemLeader == true {
                                Button(p.target?.deviceID == found.id ? "Erneut verbinden" : "Auswählen") { Task { await p.connect(found) } }.disabled(p.busy)
                            } else { Image(systemName: "link").foregroundStyle(.secondary) }
                        }.padding(12).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if p.foundDevices.isEmpty { Text("Noch keine Geräte gefunden. Beide Lautsprecher können auch einzeln per IP hinzugefügt werden.").foregroundStyle(.secondary).padding() }
                }
            }.frame(height: 200)
            Divider()
            Stepper("Lautstärkelimit dieser App: \(p.volumeLimit)", value: $p.volumeLimit, in: 0...100).disabled(p.busy)
            Text("Standard: 60. Das Limit gilt nur für Befehle dieser App. Andere Apps und Zuspieler können weiterhin lauter stellen. Eine bereits höhere Lautstärke wird nicht automatisch abgesenkt.").font(.caption).foregroundStyle(.secondary)
            Divider()
            AutoUpdateToggle()
            if p.target != nil {
                HStack {
                    Text("Gespeichert: \(p.host)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Auswahl vergessen") { p.forgetTarget() }.disabled(p.busy)
                }
            }
        }.padding(24).frame(width: 620).foregroundStyle(.white)
            .background(Color.bgTop).environment(\.colorScheme, .dark)
    }
}
struct MenuPanel: View {
    @ObservedObject var p = Phantom.shared
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(p.systemName).font(.headline); Spacer(); Circle().fill(p.online ? .green : .orange).frame(width: 7, height: 7) }
            ErrorBanner(p: p)
            HStack {
                Button { Task { await p.step(-2, hud: false) } } label: { Image(systemName: "minus") }
                Slider(value: $p.volume, in: 0...Double(max(p.volumeLimit, Int(p.volume))), step: 1, onEditingChanged: { editing in
                    if editing { p.beginDrag() } else { p.sendVolume(); p.endDrag() }
                }).tint(.accentWarm)
                Button { Task { await p.step(2, hud: false) } } label: { Image(systemName: "plus") }
                Text("\(Int(p.volume))").monospacedDigit()
            }.disabled(!p.canControl)
            Button(p.muted ? "Stummschaltung aufheben" : "Stummschalten") { Task { await p.toggleMute(hud: false) } }.disabled(!p.canControl)
            MenuUpdateHint()
            Divider()
            HStack {
                Button("Fenster öffnen") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Beenden") { NSApp.terminate(nil) }
            }
        }.padding(14).frame(width: 340)
            .onAppear { p.viewAppeared() }.onDisappear { p.viewDisappeared() }
    }
}

// MARK: - Updates

/// Fußzeile: Version, Prüf-Button und Ergebnis. Öffnet bei einem Update nur die Release-Seite.
struct UpdateStatusView: View {
    @ObservedObject var u = UpdateChecker.shared
    var body: some View {
        HStack(spacing: 6) {
            switch u.state {
            case .idle:
                Button("\(u.currentText) · Nach Updates suchen") { Task { await u.check() } }
            case .checking:
                ProgressView().controlSize(.small)
                Text("Suche Updates …").foregroundStyle(.secondary)
            case .upToDate:
                Label("\(u.currentText) ist aktuell", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                    .onTapGesture { Task { await u.check() } }
                    .help("Klicken, um erneut zu prüfen")
            case .available(let version, let page):
                if u.canSelfUpdate {
                    Button { Task { await u.install() } } label: {
                        Label("Update \(version) installieren", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent).tint(.accentWarm).foregroundStyle(.black)
                    .help("Lädt das Update von GitHub, prüft es, legt die alte Version in den Papierkorb und startet neu.")
                    Button { NSWorkspace.shared.open(page) } label: { Image(systemName: "safari") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Release-Seite mit Änderungen öffnen")
                } else {
                    Button { NSWorkspace.shared.open(page) } label: {
                        Label("Update \(version) – Herunterladen", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent).tint(.accentWarm).foregroundStyle(.black)
                    .help(u.selfUpdateBlocker ?? "Dieses Release enthält keinen prüfbaren Download – öffnet die Release-Seite.")
                }
            case .installing(let step):
                ProgressView().controlSize(.small)
                Text(step).foregroundStyle(Color.accentWarm)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).help(message)
                Button("Erneut prüfen") { Task { await u.check() } }.help(message)
            }
        }
        .font(.system(size: 11)).controlSize(.small)
    }
}

/// Einstellung im Geräte-Fenster – standardmäßig aus.
struct AutoUpdateToggle: View {
    @ObservedObject var u = UpdateChecker.shared
    var body: some View {
        Toggle("Einmal täglich automatisch nach Updates suchen", isOn: $u.autoCheck)
        Text("Fragt dafür die öffentliche GitHub-API ab (keine persönlichen Daten, keine automatische Installation). Ohne diese Option wird nur auf Knopfdruck geprüft.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

/// Hinweis im Menüleisten-Fenster, nur wenn ein Update gefunden wurde.
struct MenuUpdateHint: View {
    @ObservedObject var u = UpdateChecker.shared
    var body: some View {
        if case .available(let version, let page) = u.state {
            Button { if u.canSelfUpdate { Task { await u.install() } } else { NSWorkspace.shared.open(page) } } label: {
                Label(u.canSelfUpdate ? "Update \(version) installieren" : "Update \(version) verfügbar", systemImage: "arrow.down.circle.fill")
            }.tint(.accentWarm)
        } else if case .installing(let step) = u.state {
            Label(step, systemImage: "arrow.down.circle").foregroundStyle(Color.accentWarm)
        }
    }
}

/// App-Menü-Eintrag: öffnet das Fenster (dort steht das Ergebnis) und startet die Prüfung.
struct CheckForUpdatesCommand: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Nach Updates suchen …") {
            openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true)
            Task { await UpdateChecker.shared.check() }
        }
    }
}
