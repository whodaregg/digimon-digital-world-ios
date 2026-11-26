import SwiftUI
import SpriteKit
import DigitalWorldCore

// UI/event glyphs are reconstructed pixel drawings; character PNGs remain archived originals.
enum PixelSymbols {
    static let patterns: [String:[String]] = [
        "heart":[".##..##.","########","########","########",".######.","..####..","...##...","........"],
        "heartOutline":[".##..##.","#..##..#","#......#","#......#",".#....#.","..#..#..","...##...","........"],
        "STATUS":["..##....",".####...","..##....","######..","..##....",".####...",".####...",".####..."],
        "FOOD":["........",".####...","######..","#######.","######..",".####.##","......##","........"],
        "TRAIN":["...##...","..####..","..####..","########","..####..","...##...","..#..#..",".#....#."],
        "BATTLE":["#......#","##....##",".##..##.","..####..","..####..",".##..##.","##....##","#......#"],
        "CLEAN":["...##...","..####..",".######.","...##...","...##...","...##...","...###..","....###."],
        "SLEEP":["..####..",".######.","########","########","########",".######.","..####..","........"],
        "MEDICAL":["..####..","..####..","########","########","########","########","..####..","..####.."],
        "CALL":["...##...","..####..",".######.",".######.",".######.","########","........","...##..."],
        "meat":["........",".####...","######..","#######.","######..",".####.##","......##","........"],
        "protein":["..####..",".######.","..####..","..####..",".######.","########","########",".######."],
        "fire":["..##....",".#####..","########",".#######","########",".#####..","..##....","........"],
        "water":["...#....","..###...","..###...",".#####..",".#####..","#######.","#######.",".#####.."],
        "zzz":["#######.",".....#..","....#...","...#....","..#.....",".#......","#######.","........"],
        "grave":["..####..",".######.","###..###","###..###","#......#","###..###","###..###","########"]
    ]
    static func node(_ id: String,color: UIColor,scale: CGFloat = 4) -> SKNode {
        let node = SKNode(), rows = patterns[id] ?? patterns["STATUS"]!
        for (y,row) in rows.enumerated() {
            for (x,c) in row.enumerated() where c == "#" {
                let dot = SKSpriteNode(color: color,size: CGSize(width: scale,height: scale))
                dot.position = CGPoint(x: (CGFloat(x)-3.5)*scale,y: (3.5-CGFloat(y))*scale)
                node.addChild(dot)
            }
        }
        return node
    }
}
struct PixelGlyph: View {
    let id: String
    var color: Color = .primary
    var body: some View {
        Canvas { context,size in
            let rows = PixelSymbols.patterns[id] ?? PixelSymbols.patterns["STATUS"]!, step = min(size.width,size.height)/8
            for (y,row) in rows.enumerated() {
                for (x,c) in row.enumerated() where c == "#" {
                    context.fill(Path(CGRect(x: CGFloat(x)*step,y: CGFloat(y)*step,width: step,height: step)),with: .color(color))
                }
            }
        }.accessibilityHidden(true)
    }
}
enum PixelFont {
    static func name(_ language: AppLanguage) -> String {
        switch language {
        case .japanese: return "Fusion-Pixel-12px-Mono-ja-Regular"
        case .traditional: return "Fusion-Pixel-12px-Mono-zh-Hant-Regular"
        default: return "Fusion-Pixel-12px-Mono-zh-Hans-Regular"
        }
    }
    static func font(_ size: CGFloat,language: AppLanguage) -> Font { .custom(name(language),fixedSize: size) }
}
