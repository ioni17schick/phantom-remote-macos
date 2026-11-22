import SwiftUI
import AppKit

extension Color {
    static let bgTop = Color(red: 0.09, green: 0.095, blue: 0.11)
    static let bgBottom = Color(red: 0.025, green: 0.025, blue: 0.03)
    static let accentWarm = Color(red: 0.93, green: 0.80, blue: 0.62)
}
/// Gemeinsamer Skalierungsfaktor der Oberfläche (aus der Fenstergröße, siehe LayoutMode.scale).
struct UIScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
extension EnvironmentValues {
    var uiScale: CGFloat { get { self[UIScaleKey.self] } set { self[UIScaleKey.self] = newValue } }
}
struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.uiScale) private var s
    var body: some View {
        VStack(alignment: .leading, spacing: 12 * s) {
            Text(title.uppercased()).font(.system(size: 10.5 * s, weight: .semibold)).tracking(1.6 * s).foregroundStyle(.secondary)
            content
        }
        .padding(16 * s).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18 * s))
        .overlay(RoundedRectangle(cornerRadius: 18 * s).stroke(.white.opacity(0.08)))
    }
}
/// Knopf, der mit der Oberfläche skaliert (macOS-Standardknöpfe wachsen nicht mit).
struct ScaledPillStyle: ButtonStyle {
    var s: CGFloat
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12 * s, weight: prominent ? .semibold : .medium))
            .padding(.horizontal, 11 * s).padding(.vertical, 5 * s)
            .foregroundStyle(prominent ? Color.black : Color.white)
            .background(prominent ? Color.accentWarm : Color.white.opacity(configuration.isPressed ? 0.2 : 0.1),
                        in: RoundedRectangle(cornerRadius: 7 * s))
            .opacity(enabled ? 1 : 0.4)
    }
}
/// Schalter, der mit der Oberfläche skaliert.
struct ScaledSwitch: View {
    let title: String
    let isOn: Bool
    var s: CGFloat
    let set: (Bool) -> Void
    var body: some View {
        Button { set(!isOn) } label: {
            HStack {
                Text(title).font(.system(size: 13 * s))
                Spacer(minLength: 8 * s)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? Color.accentWarm : Color.white.opacity(0.18)).frame(width: 38 * s, height: 22 * s)
                    Circle().fill(.white).frame(width: 18 * s, height: 18 * s).padding(.horizontal, 2 * s).shadow(radius: 1)
                }.animation(.easeInOut(duration: 0.15), value: isOn)
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title).accessibilityValue(isOn ? "an" : "aus")
    }
}
/// Auswahl als Segmente, skaliert mit.
struct ScaledSegments: View {
    let options: [(id: String, label: String)]
    let selected: String
    var s: CGFloat
    let choose: (String) -> Void
    var body: some View {
        HStack(spacing: 3 * s) {
            ForEach(options, id: \.id) { option in
                Button { choose(option.id) } label: {
                    Text(option.label).font(.system(size: 12 * s, weight: option.id == selected ? .semibold : .regular))
                        .frame(maxWidth: .infinity).padding(.vertical, 5 * s)
                        .foregroundStyle(option.id == selected ? Color.black : Color.white)
                        .background(option.id == selected ? Color.accentWarm : Color.clear, in: RoundedRectangle(cornerRadius: 6 * s))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
        .padding(3 * s).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8 * s))
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
    @Environment(\.uiScale) private var s
    var body: some View {
        let ms = p.pingMs[device.id] ?? nil
        let active = p.identifying.contains(device.id)
        VStack(spacing: 6 * s) {
            Button { Task { await p.identify(device) } } label: {
                PhantomGraphic(width: 120 * s, identifying: active, dimmed: !p.online)
            }.buttonStyle(.plain).disabled(!p.canControl || active)
                .accessibilityLabel("\(device.deviceName) identifizieren")
            Text(device.deviceName).font(.system(size: 13 * s, weight: .semibold)).lineLimit(1)
            HStack(spacing: 5 * s) {
                Circle().fill(ms == nil ? Color.orange : .green).frame(width: 6 * s, height: 6 * s)
                Text("\(role) · \(ms.map { "\($0) ms" } ?? "nicht bestätigt")").font(.system(size: 9.5 * s)).foregroundStyle(.secondary)
            }
            Text(active ? "TESTTON ANGEFORDERT" : "ZUM TESTEN KLICKEN")
                .font(.system(size: 8.5 * s, weight: .semibold)).tracking(0.7).foregroundStyle(Color.accentWarm)
        }.frame(width: 150 * s)
    }
    var role: String {
        switch device.role { case "FrontLeft": return "Links"; case "FrontRight": return "Rechts"; default: return "Mono" }
    }
}
/// Schwebender Fehlerhinweis oben im Fenster – verschiebt keine Inhalte.
struct ErrorToast: View {
    @ObservedObject var p: Phantom
    var body: some View {
        if let message = p.errorMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.accentWarm)
                Text(message).font(.system(size: 12)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button { p.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Fehlermeldung schließen")
            }
            .padding(12).frame(maxWidth: 560)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.accentWarm.opacity(0.35)))
            .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
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
/// Wie ausführlich die Karten sein dürfen, damit alles ohne Scrollen passt.
enum CardDetail { case full, condensed, none }

struct MainView: View {
    @ObservedObject var p = Phantom.shared
    var body: some View {
        GeometryReader { geo in
            let mode = LayoutMode(width: geo.size.width, height: geo.size.height)
            let s = CGFloat(LayoutMode.scale(mode, width: geo.size.width, height: geo.size.height))
            Group {
                if !p.everConnected { welcome }
                else {
                    switch mode {
                    case .compact: compact(geo.size)
                    case .regular: regular(s)
                    case .large: large(s)
                    }
                }
            }
            .environment(\.uiScale, s)
            .controlSize(s < 0.9 ? .small : (s < 1.35 ? .regular : .large))
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .top) { ErrorToast(p: p).padding(.top, 30) }
            .animation(.easeInOut(duration: 0.25), value: mode)
            .animation(.easeInOut(duration: 0.2), value: p.errorMessage)
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
            Spacer(minLength: 0)
            VolumeDial(p: p, size: dial).disabled(!p.canControl).opacity(p.online ? 1 : 0.45)
            Spacer(minLength: 0)
            volumeButtons(size: 34, mute: 42)
        }
        .padding(.horizontal, 18).padding(.top, 30).padding(.bottom, 18)
    }

    // MARK: Normal – alles skaliert; wird es knapp, fallen erst Hinweise, dann Karten weg
    func regular(_ s: CGFloat) -> some View {
        // Erst schrittweise verkleinern, dann Hinweise weglassen, erst ganz zuletzt die Karten.
        ViewThatFits(in: .vertical) {
            regularBody(s, cards: .full)
            regularBody(s * 0.92, cards: .full)
            regularBody(s * 0.92, cards: .condensed)
            regularBody(s * 0.84, cards: .condensed)
            regularBody(max(0.7, s * 0.76), cards: .condensed)
            regularBody(s, cards: .none)
            compact(CGSize(width: 400 * s, height: 420 * s))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    func regularBody(_ s: CGFloat, cards: CardDetail) -> some View {
        VStack(spacing: 16 * s) {
            header(s)
            HStack {
                if let first = p.speakers.first { SpeakerView(p: p, device: first) }
                Spacer(minLength: 8 * s)
                VolumeDial(p: p, size: 220 * s).disabled(!p.canControl)
                Spacer(minLength: 8 * s)
                if p.speakers.count > 1 { SpeakerView(p: p, device: p.speakers[1]) }
                else { Color.clear.frame(width: 150 * s, height: 1) }
            }.opacity(p.online ? 1 : 0.45)
            volumeButtons(size: 38 * s, mute: 46 * s)
            if cards != .none {
                HStack(alignment: .top, spacing: 16 * s) {
                    playback(s, showNowPlaying: true, detail: cards)
                    sound(s, detail: cards)
                }.disabled(!p.canControl)
            }
            Spacer(minLength: 0)   // übriger Platz unten; Fußzeile bleibt am Rand
            footer(s)
        }
        .padding(.horizontal, 24 * s).padding(.top, 28 * s).padding(.bottom, 18 * s)
        .frame(maxHeight: .infinity)
        .environment(\.uiScale, s)   // Karten, Lautsprecher usw. im selben Maßstab wie diese Variante
    }

    // MARK: Groß / Vollbild – drei Spalten, alles auf einem Bildschirm
    func large(_ s: CGFloat) -> some View {
        ViewThatFits(in: .vertical) {
            largeBody(s, cards: .full, speakers: true)
            largeBody(s * 0.92, cards: .full, speakers: true)
            largeBody(s * 0.92, cards: .condensed, speakers: true)
            largeBody(s * 0.84, cards: .condensed, speakers: true)
            largeBody(s * 0.84, cards: .condensed, speakers: false)
            largeBody(max(0.7, s * 0.76), cards: .none, speakers: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    func largeBody(_ s: CGFloat, cards: CardDetail, speakers: Bool) -> some View {
        VStack(spacing: 26 * s) {
            header(s)
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 36 * s) {
                nowPlaying(s).frame(maxWidth: .infinity)
                VStack(spacing: 18 * s) {
                    VolumeDial(p: p, size: 300 * s).disabled(!p.canControl).opacity(p.online ? 1 : 0.45)
                    volumeButtons(size: 44 * s, mute: 54 * s)
                    if speakers { HStack(spacing: 16 * s) { ForEach(p.speakers) { SpeakerView(p: p, device: $0) } } }
                }.frame(maxWidth: .infinity)
                if cards != .none {
                    VStack(spacing: 16 * s) {
                        playback(s, showNowPlaying: false, detail: cards)
                        sound(s, detail: cards)
                    }.frame(maxWidth: .infinity).disabled(!p.canControl)
                }
            }
            Spacer(minLength: 0)
            footer(s)
        }
        .padding(.horizontal, 40 * s).padding(.top, 34 * s).padding(.bottom, 22 * s)
        .frame(maxHeight: .infinity)
        .environment(\.uiScale, s)
    }

    /// Große Wiedergabe-Ansicht: Quelle, Titel, Interpret, Format und Transport-Buttons.
    func nowPlaying(_ s: CGFloat) -> some View {
        let info = sourceInfo(p.currentType)
        let art = 220 * s
        let canPrevious = p.ops.contains("previous"), canNext = p.ops.contains("next")
        let canPlayPause = p.ops.contains(p.playing ? "pause" : "play")
        return VStack(spacing: 18 * s) {
            ZStack {
                RoundedRectangle(cornerRadius: art * 0.12)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: art * 0.12).stroke(.white.opacity(0.08)))
                Image(systemName: info.icon).font(.system(size: art * 0.32, weight: .light)).foregroundStyle(Color.accentWarm)
            }.frame(width: art, height: art)
            VStack(spacing: 6 * s) {
                Text("JETZT LÄUFT").font(.system(size: 11 * s, weight: .semibold)).tracking(2.5 * s).foregroundStyle(.secondary)
                Text(p.title.isEmpty ? info.label : p.title).font(.system(size: 28 * s, weight: .semibold)).multilineTextAlignment(.center).lineLimit(2)
                let detail = [p.artist, p.peer].filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty { Text(detail).font(.system(size: 16 * s)).foregroundStyle(.secondary).lineLimit(1) }
                if !p.codec.isEmpty { Text(p.codec).font(.system(size: 12 * s, weight: .medium)).foregroundStyle(Color.accentWarm.opacity(0.85)) }
            }
            HStack(spacing: 24 * s) {
                RoundIconButton(icon: "backward.fill", size: 50 * s) { Task { await p.previous() } }
                    .disabled(!canPrevious).opacity(canPrevious ? 1 : 0.35).accessibilityLabel("Zurück")
                RoundIconButton(icon: p.playing ? "pause.fill" : "play.fill", size: 70 * s, active: canPlayPause) { Task { await p.playPause() } }
                    .disabled(!canPlayPause).opacity(canPlayPause ? 1 : 0.35).accessibilityLabel(p.playing ? "Pause" : "Wiedergabe")
                RoundIconButton(icon: "forward.fill", size: 50 * s) { Task { await p.next() } }
                    .disabled(!canNext).opacity(canNext ? 1 : 0.35).accessibilityLabel("Weiter")
            }.disabled(!p.canControl)
            if !canPrevious && !canNext && !canPlayPause {
                Text("\(info.label): Wiedergabe am Zuspieler steuern – diese Quelle bietet keine Fernsteuerung.")
                    .font(.system(size: 11 * s)).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
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

    func header(_ s: CGFloat) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3 * s) {
                Text(p.systemName).font(.system(size: 24 * s, weight: .light)).tracking(2 * s)
                Text(p.target == nil ? "Inoffizielle Fernbedienung · Beta" : "\(p.model) · \(p.speakers.count) Lautsprecher").font(.system(size: 11 * s)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(p.online ? "● Verbunden" : p.status).font(.system(size: 11 * s)).foregroundStyle(p.online ? .green : .secondary)
            Button("Geräte …") { p.deviceSheet = true }.disabled(p.busy).buttonStyle(ScaledPillStyle(s: s))
        }
    }

    var welcome: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            PhantomGraphic(width: 150)
            Text("Wähle dein Phantom-System aus.").font(.title3)
            Text("Automatisch im lokalen Netzwerk suchen oder eine IP-Adresse eingeben.").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Geräte auswählen") { p.deviceSheet = true }.buttonStyle(.borderedProminent).tint(.accentWarm).foregroundStyle(.black)
            Spacer(minLength: 0)
            footer(1)
        }.padding(24)
    }

    func footer(_ s: CGFloat) -> some View {
        HStack {
            Text("⌃⌥↑ / ↓ Lautstärke · ⌃⌥M Stumm").font(.system(size: 10 * s)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            if p.pending > 0 { ProgressView().controlSize(.small) }
            UpdateStatusView()
            Button("Verbindung prüfen") { Task { await p.refresh() } }.disabled(p.busy || p.target == nil).buttonStyle(ScaledPillStyle(s: s))
        }
    }

    func playback(_ s: CGFloat, showNowPlaying: Bool, detail: CardDetail) -> some View {
        Card(title: showNowPlaying ? "Wiedergabe" : "Quelle") {
            if showNowPlaying {
                HStack(spacing: 10 * s) {
                    Image(systemName: sourceInfo(p.currentType).icon).font(.system(size: 20 * s)).foregroundStyle(Color.accentWarm)
                    VStack(alignment: .leading, spacing: 3 * s) {
                        Text(p.title.isEmpty ? sourceInfo(p.currentType).label : p.title).font(.system(size: 14 * s, weight: .semibold)).lineLimit(1)
                        Text([p.artist, p.peer, p.codec].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 11 * s)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if p.ops.contains("play") || p.ops.contains("pause") {
                        if p.ops.contains("previous") { Button { Task { await p.previous() } } label: { Image(systemName: "backward.fill") } }
                        Button { Task { await p.playPause() } } label: { Image(systemName: p.playing ? "pause.fill" : "play.fill") }
                            .disabled(!p.ops.contains(p.playing ? "pause" : "play"))
                        if p.ops.contains("next") { Button { Task { await p.next() } } label: { Image(systemName: "forward.fill") } }
                    }
                }.buttonStyle(ScaledPillStyle(s: s))
            }
            ForEach(p.selectableSources) { source in
                Button { Task { await p.select(source) } } label: {
                    HStack {
                        Image(systemName: sourceInfo(source.type).icon)
                        Text(p.sourceLabel(source)).lineLimit(1)
                        Spacer()
                        if p.currentSourceID == source.id { Image(systemName: "checkmark").foregroundStyle(Color.accentWarm) }
                    }
                    .font(.system(size: 13 * s))
                    .padding(8 * s).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9 * s))
                }.buttonStyle(.plain)
            }
            Button("Mac per AirPlay verbinden …") { p.openAirPlaySettings() }.buttonStyle(ScaledPillStyle(s: s))
            if detail == .full {
                Text("Spotify, Bluetooth, Roon und UPnP werden vom jeweiligen Zuspieler gestartet.").font(.system(size: 10 * s)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(minWidth: 0, maxWidth: .infinity)
    }

    func sound(_ s: CGFloat, detail: CardDetail) -> some View {
        Card(title: "Klang") {
            if p.supportsNight {
                ScaledSwitch(title: "Nachtmodus", isOn: p.nightMode, s: s) { value in Task { await p.setNight(value) } }
            }
            if p.supportsEq {
                ScaledSegments(options: p.eqPresets.sorted { presetOrder($0) < presetOrder($1) }.map { (id: $0, label: presetName($0)) }, selected: p.eqPreset, s: s) { value in
                    Task { await p.setEq(value) }
                }
                if p.eqPresets.contains("custom") {
                    if detail == .full { Text("Regler aktivieren „Eigene“.").font(.system(size: 10 * s)).foregroundStyle(.secondary) }
                    adjustment(s, "Bass", value: $p.eqLow, range: p.eqRange, unit: "dB") { p.sendCustomEq() }
                    adjustment(s, "Höhen", value: $p.eqHigh, range: p.eqRange, unit: "dB") { p.sendCustomEq() }
                }
            }
            if p.supportsBalance { adjustment(s, "Balance", value: $p.balance, range: -10...10, unit: "") { p.sendBalance() } }
            if !p.supportsNight && !p.supportsEq && !p.supportsBalance {
                Text("Für dieses System sind keine Klangeinstellungen verfügbar.").font(.system(size: 12 * s)).foregroundStyle(.secondary)
            }
        }.frame(minWidth: 0, maxWidth: .infinity)
    }

    func adjustment(_ s: CGFloat, _ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 3 * s) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue)) \(unit)").monospacedDigit().foregroundStyle(.secondary) }.font(.system(size: 11 * s))
            Slider(value: value, in: range, step: 1, onEditingChanged: { editing in if editing { p.beginDrag() } else { action(); p.endDrag() } }).tint(.accentWarm)
        }
    }
    func presetOrder(_ value: String) -> Int { ["flat": 0, "voice": 1, "custom": 2][value] ?? 9 }
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
    @Environment(\.uiScale) private var s
    var body: some View {
        HStack(spacing: 6) {
            switch u.state {
            case .idle:
                Button("\(u.currentText) · Nach Updates suchen") { Task { await u.check() } }.buttonStyle(ScaledPillStyle(s: s))
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
                    .buttonStyle(ScaledPillStyle(s: s, prominent: true))
                    .help("Lädt das Update von GitHub, prüft es, legt die alte Version in den Papierkorb und startet neu.")
                    Button { NSWorkspace.shared.open(page) } label: { Image(systemName: "safari") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help("Release-Seite mit Änderungen öffnen")
                } else {
                    Button { NSWorkspace.shared.open(page) } label: {
                        Label("Update \(version) – Herunterladen", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(ScaledPillStyle(s: s, prominent: true))
                    .help(u.selfUpdateBlocker ?? "Dieses Release enthält keinen prüfbaren Download – öffnet die Release-Seite.")
                }
            case .installing(let step):
                ProgressView().controlSize(.small)
                Text(step).foregroundStyle(Color.accentWarm)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).help(message)
                Button("Erneut prüfen") { Task { await u.check() } }.buttonStyle(ScaledPillStyle(s: s)).help(message)
            }
        }
        .font(.system(size: 11 * s))
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
