import UIKit

/// Original vector drawings of keyboard controls, not extracted Samsung assets.
enum KeyboardIcon: String {
    case emoji, clipboard, cursor, settings, more, globe, shift, capsLock
    case delete, enter, dismiss, keyboard, trash, left, right

    var image: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            let cg = context.cgContext
            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setFillColor(UIColor.black.cgColor)
            cg.setLineWidth(1.8)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            func line(_ points: [CGPoint], close: Bool = false) {
                guard let first = points.first else { return }
                cg.beginPath(); cg.move(to: first)
                for point in points.dropFirst() { cg.addLine(to: point) }
                if close { cg.closePath() }
                cg.strokePath()
            }
            func path(_ points: [(CGFloat, CGFloat)], close: Bool = false) {
                line(points.map { CGPoint(x: $0.0, y: $0.1) }, close: close)
            }
            func circle(_ rect: CGRect) { cg.strokeEllipse(in: rect) }
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 2) {
                cg.addPath(UIBezierPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r).cgPath)
                cg.strokePath()
            }
            switch self {
            case .emoji:
                circle(CGRect(x: 3, y: 3, width: 18, height: 18))
                cg.fillEllipse(in: CGRect(x: 7, y: 8, width: 2, height: 2))
                cg.fillEllipse(in: CGRect(x: 15, y: 8, width: 2, height: 2))
                cg.addArc(center: CGPoint(x: 12, y: 12), radius: 5, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
                cg.strokePath()
            case .clipboard:
                rect(5, 4, 14, 17)
                cg.saveGState(); cg.setBlendMode(.clear); cg.fill(CGRect(x: 9, y: 2, width: 6, height: 5)); cg.restoreGState()
                rect(9, 2, 6, 5, 1)
                path([(8, 11), (16, 11)]); path([(8, 15), (16, 15)])
            case .cursor:
                path([(3, 12), (21, 12)]); path([(7, 8), (3, 12), (7, 16)])
                path([(17, 8), (21, 12), (17, 16)]); path([(12, 4), (12, 20)])
            case .settings:
                let points: [CGPoint] = (0..<32).map { index in
                    let radius: CGFloat = [10, 10, 8, 8][index % 4]
                    let angle = CGFloat(index) * .pi / 16
                    return CGPoint(x: 12 + cos(angle) * radius, y: 12 + sin(angle) * radius)
                }
                line(points, close: true); circle(CGRect(x: 8.5, y: 8.5, width: 7, height: 7))
            case .more:
                for x in [4, 11, 18] { cg.fillEllipse(in: CGRect(x: x, y: 10, width: 3, height: 3)) }
            case .globe:
                circle(CGRect(x: 2.5, y: 2.5, width: 19, height: 19))
                circle(CGRect(x: 7, y: 2.5, width: 10, height: 19))
                path([(3, 8), (21, 8)]); path([(3, 16), (21, 16)])
            case .shift, .capsLock:
                path([(3, 11), (12, 3), (21, 11), (16, 11), (16, 19), (8, 19), (8, 11)], close: true)
                if self == .capsLock { path([(8, 22), (16, 22)]) }
            case .delete:
                path([(9, 5), (21, 5), (21, 19), (9, 19), (2, 12)], close: true)
                path([(11, 9), (17, 15)]); path([(17, 9), (11, 15)])
            case .enter:
                path([(20, 5), (20, 14), (4, 14)]); path([(9, 9), (4, 14), (9, 19)])
            case .dismiss:
                rect(3, 3, 18, 11)
                for x in stride(from: 6, through: 18, by: 4) { path([(CGFloat(x), 7), (CGFloat(x), 8)]) }
                path([(8, 18), (12, 22), (16, 18)])
            case .keyboard:
                rect(2, 5, 20, 14)
                for x in stride(from: 6, through: 18, by: 4) { path([(CGFloat(x), 9), (CGFloat(x), 10)]) }
                path([(6, 14), (7, 14)]); path([(10, 14), (18, 14)])
            case .trash:
                path([(4, 6), (20, 6)]); path([(9, 3), (15, 3)])
                path([(6, 6), (7, 21), (17, 21), (18, 6)])
                path([(10, 10), (10, 17)]); path([(14, 10), (14, 17)])
            case .left: path([(15, 5), (8, 12), (15, 19)])
            case .right: path([(9, 5), (16, 12), (9, 19)])
            }
        }.withRenderingMode(.alwaysTemplate)
    }
}
