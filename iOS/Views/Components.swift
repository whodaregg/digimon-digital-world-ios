import SwiftUI
import DigitalWorldCore

enum Palette {
    static let background = Color(red: 0.035,green: 0.055,blue: 0.075)
    static let panel = Color(red: 0.07,green: 0.10,blue: 0.13)
    static let line = Color(red: 0.18,green: 0.23,blue: 0.25)
    static let mint = Color(red: 0.65,green: 0.89,blue: 0.65)
    static let muted = Color(red: 0.48,green: 0.58,blue: 0.59)
    static let amber = Color(red: 0.97,green: 0.74,blue: 0.41)
    static func screenSurface(_ mode: DisplayMode) -> Color {
        mode == .lcd ? Color(red: 0.66,green: 0.73,blue: 0.52) : Color(red: 0.08,green: 0.19,blue: 0.27)
    }
    static func screenInk(_ mode: DisplayMode) -> Color {
        mode == .lcd ? Color(red: 0.2,green: 0.28,blue: 0.2) : Color(red: 0.84,green: 0.96,blue: 1)
    }
}

struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading,spacing: 16) {
            Text(title).font(.system(.caption,design: .monospaced,weight: .bold)).tracking(2).foregroundStyle(Palette.mint)
            content
        }
        .frame(maxWidth: .infinity,alignment: .leading).padding(20)
        .background(Palette.panel,in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line,lineWidth: 1))
    }
}

struct Metric: View {
    let name: String
    let value: Int
    var color: Color = Palette.mint
    var body: some View {
        VStack(alignment: .leading,spacing: 7) {
            HStack {
                Text(name).foregroundStyle(Palette.muted)
                Spacer(minLength: 4)
                Text("\(value)").foregroundStyle(color)
            }.font(.system(.caption2,design: .monospaced,weight: .semibold))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.line)
                    Rectangle().fill(color).frame(width: proxy.size.width * CGFloat(min(100,max(0,value)))/100)
                }
            }.frame(height: 4)
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(name)，\(value)，满值100")
    }
}

struct Readout: View {
    let name: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }.font(.system(.subheadline,design: .monospaced))
    }
}

struct HeartReadout: View {
    let name: String
    let value: Int
    var body: some View {
        HStack {
            Text(name).foregroundStyle(Palette.muted)
            Spacer()
            ForEach(0..<4,id: \.self) { index in
                Image(systemName: index < value ? "heart.fill" : "heart")
                    .foregroundStyle(Palette.mint)
            }
        }.font(.subheadline).accessibilityElement(children: .ignore)
            .accessibilityLabel("\(name)，\(value)颗心，满值4")
    }
}

struct GameButton: View {
    let title: String
    var role: ButtonRole? = nil
    var action: () -> Void
    var body: some View {
        Button(role: role,action: action) {
            Text(title).font(.system(.subheadline,design: .monospaced,weight: .bold))
                .frame(maxWidth: .infinity,minHeight: 28).padding(12)
        }.buttonStyle(.borderedProminent).tint(Palette.mint).foregroundStyle(Palette.background)
    }
}

extension View {
    func pageStyle() -> some View {
        self.frame(maxWidth: 700).frame(maxWidth: .infinity).padding(16)
    }
}
