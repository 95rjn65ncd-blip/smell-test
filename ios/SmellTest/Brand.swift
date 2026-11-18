import SwiftUI

/// Colors and the logo mark, matching the app icon (concept 8b, Nov 17).
enum Brand {
    static let navy = Color(red: 0x0F / 255, green: 0x2A / 255, blue: 0x44 / 255)       // page
    static let navyRaised = Color(red: 0x16 / 255, green: 0x3A / 255, blue: 0x5C / 255) // text box, sample rows
    static let navyChip = Color(red: 0x1E / 255, green: 0x4B / 255, blue: 0x70 / 255)   // secondary buttons
    static let teal = Color(red: 0x4F / 255, green: 0xD1 / 255, blue: 0xC5 / 255)       // main action, wisp
    static let tealInk = Color(red: 0x04 / 255, green: 0x34 / 255, blue: 0x2C / 255)    // text on teal
    static let mist = Color(red: 0x9F / 255, green: 0xC3 / 255, blue: 0xDA / 255)       // quiet text on navy
}

/// The icon's message bubble with a scent wisp, drawn as vector paths (180 x 180 design box,
/// same coordinates as docs/icon8b.swift) so it stays sharp at any size.
struct WispMark: View {
    var showsDots = false

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 140
            // Content spans x 20...160, y 30...162 in the design box; center it.
            context.translateBy(x: (size.width - 140 * s) / 2 - 20 * s, y: (size.height - 134 * s) / 2 - 30 * s)
            context.scaleBy(x: s, y: s)
            context.stroke(Self.bubble, with: .color(.white), style: StrokeStyle(lineWidth: 10, lineJoin: .round))
            if showsDots {
                for x in [64.0, 90.0, 116.0] {
                    context.fill(Path(ellipseIn: CGRect(x: x - 6, y: 115, width: 12, height: 12)), with: .color(.white))
                }
            }
            context.stroke(Self.wisp, with: .color(Brand.teal), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        }
        .accessibilityHidden(true)
    }

    private static let bubble: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 34, y: 96)); p.addLine(to: CGPoint(x: 146, y: 96))
        p.addArc(tangent1End: CGPoint(x: 160, y: 96), tangent2End: CGPoint(x: 160, y: 110), radius: 14)
        p.addLine(to: CGPoint(x: 160, y: 132))
        p.addArc(tangent1End: CGPoint(x: 160, y: 146), tangent2End: CGPoint(x: 146, y: 146), radius: 14)
        p.addLine(to: CGPoint(x: 70, y: 146)); p.addLine(to: CGPoint(x: 50, y: 162)); p.addLine(to: CGPoint(x: 50, y: 146))
        p.addLine(to: CGPoint(x: 34, y: 146))
        p.addArc(tangent1End: CGPoint(x: 20, y: 146), tangent2End: CGPoint(x: 20, y: 132), radius: 14)
        p.addLine(to: CGPoint(x: 20, y: 110))
        p.addArc(tangent1End: CGPoint(x: 20, y: 96), tangent2End: CGPoint(x: 34, y: 96), radius: 14)
        p.closeSubpath()
        return p
    }()

    private static let wisp: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 90, y: 82))
        p.addCurve(to: CGPoint(x: 90, y: 48), control1: CGPoint(x: 74, y: 70), control2: CGPoint(x: 106, y: 62))
        p.addCurve(to: CGPoint(x: 98, y: 32), control1: CGPoint(x: 80, y: 40), control2: CGPoint(x: 88, y: 30))
        return p
    }()
}

/// The main action: teal capsule with dark ink, like the mockup's "Check it".
struct BrandProminentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .foregroundStyle(isEnabled ? Brand.tealInk : Brand.mist.opacity(0.7))
            .background(isEnabled ? Brand.teal : Brand.navyChip, in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    /// Navy page, dark appearance, teal accents.
    func brandScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Brand.navy.ignoresSafeArea())
            .tint(Brand.teal)
            .preferredColorScheme(.dark)
    }
}
