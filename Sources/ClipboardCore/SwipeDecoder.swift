import Foundation

public struct SwipePoint: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// A small offline English gesture decoder. Both axes must use the same scale.
/// Pass actual laid-out letter centers so the decoder follows keyboard geometry.
public struct SwipeDecoder: Sendable {
    private let words: [String]

    public init(additionalWords: [String] = []) {
        var seen = Set<String>()
        words = (Self.commonWords + additionalWords).compactMap { input in
            let word = input.lowercased()
            guard word.count >= 2, word.count <= 24,
                  word.utf8.allSatisfy({ (97...122).contains($0) }), seen.insert(word).inserted else { return nil }
            return word
        }
    }

    public func suggestions(for path: [SwipePoint], keyCenters: [String: SwipePoint], limit: Int = 3) -> [String] {
        guard limit > 0, path.count >= 3, let first = path.first, let last = path.last,
              path.allSatisfy({ $0.x.isFinite && $0.y.isFinite }), keyCenters.count >= 3 else { return [] }
        let centers = Array(keyCenters.values)
        let nearestSpacings = centers.compactMap { center in
            centers.map { Self.distance(center, $0) }.filter { $0 > 0.00001 }.min()
        }
        guard !nearestSpacings.isEmpty else { return [] }
        let spacing = nearestSpacings.sorted()[nearestSpacings.count / 2]
        let length = Self.length(path)
        guard spacing > 0.00001, length >= spacing * 0.7 else { return [] }
        let observed = Self.resample(path, count: 32)
        var ranked: [(String, Double)] = []
        for (rank, word) in words.enumerated() {
            let letters = word.map(String.init)
            guard let start = keyCenters[letters[0]], let end = keyCenters[letters[letters.count - 1]] else { continue }
            let startDistance = Self.distance(first, start) / spacing
            let endDistance = Self.distance(last, end) / spacing
            // Endpoints carry considerably more intent than a path crossing a key.
            guard startDistance <= 1.25, endDistance <= 1.25 else { continue }
            var template: [SwipePoint] = []
            for letter in letters {
                guard let center = keyCenters[letter] else { template = []; break }
                if template.last != center { template.append(center) }
            }
            guard template.count >= 2 else { continue }
            let expected = Self.resample(template, count: 32)
            let aligned = zip(observed, expected).reduce(0.0) { $0 + Self.distance($1.0, $1.1) } / 32 / spacing
            let warped = Self.warpedDistance(observed, expected) / spacing
            let templateLength = Self.length(template)
            let lengthPenalty = abs(log(max(length, 0.00001) / max(templateLength, 0.00001)))
            let score = aligned * 0.35 + warped * 0.65 + (startDistance + endDistance) * 0.8
                + lengthPenalty * 0.3 + log(Double(rank) + 2) * 0.008
            guard score < 2.1 else { continue }
            ranked.append((word, score))
        }
        return ranked.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }.prefix(min(limit, 10)).map(\.0)
    }

    public static var qwertyCenters: [String: SwipePoint] {
        var centers: [String: SwipePoint] = [:]
        for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            let inset = [0.5, 1.0, 2.0][row]
            for (column, character) in letters.enumerated() {
                centers[String(character)] = SwipePoint(x: (Double(column) + inset) / 10, y: Double(row) * 0.125)
            }
        }
        return centers
    }

    private static func distance(_ a: SwipePoint, _ b: SwipePoint) -> Double { hypot(a.x - b.x, a.y - b.y) }
    private static func length(_ points: [SwipePoint]) -> Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }
    private static func resample(_ points: [SwipePoint], count: Int) -> [SwipePoint] {
        let total = length(points)
        guard total > 0, let first = points.first else { return Array(repeating: points.first ?? SwipePoint(x: 0, y: 0), count: count) }
        var result = [first]
        var segment = 1
        var traversed = 0.0
        for index in 1..<count {
            let target = total * Double(index) / Double(count - 1)
            while segment < points.count - 1 && traversed + distance(points[segment - 1], points[segment]) < target {
                traversed += distance(points[segment - 1], points[segment]); segment += 1
            }
            let start = points[segment - 1], end = points[segment]
            let segmentLength = distance(start, end)
            let fraction = segmentLength == 0 ? 0 : min(1, max(0, (target - traversed) / segmentLength))
            result.append(SwipePoint(x: start.x + (end.x - start.x) * fraction, y: start.y + (end.y - start.y) * fraction))
        }
        return result
    }
    private static func warpedDistance(_ observed: [SwipePoint], _ expected: [SwipePoint]) -> Double {
        let count = expected.count
        var previous = Array(repeating: Double.infinity, count: count + 1); previous[0] = 0
        for point in observed {
            var current = Array(repeating: Double.infinity, count: count + 1)
            for index in 1...count {
                current[index] = distance(point, expected[index - 1]) + min(previous[index], previous[index - 1], current[index - 1])
            }
            previous = current
        }
        return previous[count] / Double(max(observed.count, expected.count))
    }

    // Frequency order is a weak prior, never a replacement for the traced shape.
    public static let commonWords: [String] = """
    the of and to in is you that it he was for on are as with his they at be this have from or one had by word but not what all were we when your can said there use an each which she do how their if will up other about out many then them these so some her would make like him into time has look two more write go see number no way could people my than first water been call who oil its now find long down day did get come made may part over new sound take only little work know place year live me back give most very after thing our just name good sentence man think say great where help through much before line right too mean old any same tell boy follow came want show also around form three small set put end does another well large must big even such because turn here why ask went men read need land different home us move try kind hand picture again change off play spell air away animal house point page letter mother answer found study still learn should world high every near add food between own below country plant last school father keep tree never start city earth eye light thought head under story saw left few while along might close something seem next hard open example begin life always those both paper together got group often run important until children side feet car mile night walk white sea began grow took river four carry state once book hear stop without second later miss idea enough eat face watch far real almost let above girl sometimes mountain cut young talk soon list song being leave family body music color stand sun question fish area mark dog horse birds problem complete room knew since ever piece told usually friends easy heard order red door sure become top ship across today during short better best however low hours black products happened whole measure remember early waves reached listen wind rock space covered fast several hold himself toward five step morning passed true hundred against pattern numeral table north slowly money map farm pulled draw voice seen cold cried plan notice south sing war ground fall king town unit figure certain field travel wood fire upon done english road half ten fly gave box finally wait correct oh quickly person became shown minutes strong verb stars front feel fact inches street decided contain course surface produce building ocean class note nothing rest carefully scientists inside wheels stay green known island week less machine base ago stood plane system behind ran round boat game force brought understand warm common bring explain dry though language shape deep thousands yes clear equation yet government filled heat full hot check object am rule among noun power cannot able six size dark ball material special heavy fine pair circle include built matter square perhaps bill felt suddenly test direction center farmers ready anything divided general energy subject europe moon region return believe dance members picked simple cells paint mind love cause rain exercise eggs train blue wish drop developed window difference distance heart sit sum summer wall forest probably legs sat main winter wide written length reason kept interest arms brother race present beautiful store job edge past sign record finished discovered wild happy beside gone sky glass million west lay weather root instruments meet third months paragraph raised represent soft whether clothes flowers shall teacher held describe drive cross speak solve appear metal son either ice sleep village factors result jumped snow ride care floor hill pushed baby buy century outside everything tall already instead phrase soil bed copy free hope spring case laughed nation quite type themselves temperature bright lead everyone method section lake iron within dictionary hair age amount scale pounds although per broken moment tiny possible gold milk quiet natural lot stone act build middle speed count consonant someone sail rolled bear wonder smiled angle fraction africa killed melody bottom trip hole poor fight tune french died beat exactly remain dress cat century fingers per hour fun cloud laptop phone keyboard clipboard message text image photo screenshot hello thanks thank please tomorrow yesterday morning evening meeting welcome harshal samsung apple india york america friend computer internet email address whats whatsapp happy birthday sorry alright okay coming going working writing reading eating waiting cooking walking running morning tonight lunch dinner breakfast coffee tea office business university college science math engineering software hardware design develop testing code question answer send sent received receive reply close closed opened show shows showing wonderful amazing awesome really absolutely definitely maybe perhaps sure surely just please always never beautiful amazing because something nothing everything sometimes weather welcome congratulations wonderful shopping should would could want wants wanted wanting need needs needed needing work works worked thing things thankyou football cricket music movie movie photos pictures documents settings suggestions swipe cursor sound volume light dark auto automatic history save saved saving delete deleted deleting paste pasted pasting copied copying share shared sharing quick brown fox jumps lazy dog hello hell help held world word words hold home house hope how have has happy good great green going gone game google github guide goodbye thanks think thinking this there their these those them then that than three through though throw phone photo people person place point part parents program project process private public privacy power permission permissions provided provide provisions picture play player playing hello welcome morning afternoon night nice new next news now not none normal note notes network offline online works working please keyboard key keys typing typed touch touches response corner corners screen screens scrolling scroll screenshot screenshots capture captures captured capturing open opening application applications apps app action activity activate activation suggestion suggestions language languages english sentence sentences paragraph paragraphs letter letters symbol symbols emoji emojis accent accents another help helpful improve improved update updated install installed setup input output local device devices video videos audio haptic haptics strength strong setting permissions access allow allowed allows asking asks permission permission train trail trace path top bottom middle left right up down vertical horizontal start end finish return space shift caps lock backspace button buttons number numbers daily minutes welcome india indian united kingdom states america american morning yourself ourselves themselves everyone someone anyone nobody everybody anybody whenever whatever where why when how what which while whose whom who
    """.split(whereSeparator: \.isWhitespace).map(String.init)
}
