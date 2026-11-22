// Rendert das App-Icon (1024×1024) mit derselben Phantom-Grafik wie die App
import SwiftUI
import AppKit

@main struct IconMaker {
    @MainActor static func main() {
        _ = NSApplication.shared
        let tile = ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.19), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .fill(RadialGradient(colors: [Color.accentWarm.opacity(0.22), .clear], center: .init(x: 0.5, y: 0.55), startRadius: 0, endRadius: 420)))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 12)
            PhantomGraphic(width: 640)
                .offset(y: 20)
        }
        .frame(width: 1024, height: 1024)
        let r = ImageRenderer(content: tile); r.scale = 1
        let rep = NSBitmapImageRep(data: r.nsImage!.tiffRepresentation!)!
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
