import Foundation
import Testing
@testable import ClipboardCore

struct SwipeDecoderTests {
    private let centers = SwipeDecoder.qwertyCenters
    private func path(_ word: String, noise: Double = 0) -> [SwipePoint] {
        let keys = word.map { centers[String($0)]! }
        var result: [SwipePoint] = []
        for (start, end) in zip(keys, keys.dropFirst()) {
            for step in 0..<8 {
                let t = Double(step) / 8
                result.append(SwipePoint(x: start.x + (end.x - start.x) * t + sin(Double(step)) * noise,
                                         y: start.y + (end.y - start.y) * t + cos(Double(step)) * noise))
            }
        }
        result.append(keys.last!); return result
    }
    @Test func commonWordsAreRecognizedFromContinuousPaths() {
        let decoder = SwipeDecoder()
        for word in ["hello", "world", "keyboard", "thanks", "please", "good", "morning", "samsung"] {
            #expect(decoder.suggestions(for: path(word), keyCenters: centers).first == word)
        }
    }
    @Test func SmallTouchNoiseAndRepeatedSamplesDoNotChangeBestWord() {
        let decoder = SwipeDecoder()
        let noisy = path("hello", noise: 0.006)
        let repeated = noisy.flatMap { [$0, $0] }
        #expect(decoder.suggestions(for: noisy, keyCenters: centers).first == "hello")
        #expect(decoder.suggestions(for: repeated, keyCenters: centers).first == "hello")
    }
    @Test func actualLayoutScaleAndTranslationDoNotChangeRanking() {
        func transformed(_ p: SwipePoint) -> SwipePoint { SwipePoint(x: p.x * 430 + 18, y: p.y * 430 + 200) }
        let decoder = SwipeDecoder()
        #expect(decoder.suggestions(for: path("thanks").map(transformed), keyCenters: centers.mapValues(transformed)).first == "thanks")
    }
    @Test func addedLexiconWordsParticipateAndResultsAreBounded() {
        let decoder = SwipeDecoder(additionalWords: ["harshal", "harshal", "not a word", "123"])
        let result = decoder.suggestions(for: path("harshal"), keyCenters: centers, limit: 3)
        #expect(result.first == "harshal")
        #expect(result.count <= 3)
        #expect(Set(result).count == result.count)
    }
    @Test func tapsAndInvalidPathsProduceNoInventedWord() {
        let decoder = SwipeDecoder()
        #expect(decoder.suggestions(for: [], keyCenters: centers).isEmpty)
        #expect(decoder.suggestions(for: Array(repeating: centers["a"]!, count: 20), keyCenters: centers).isEmpty)
        #expect(decoder.suggestions(for: [SwipePoint(x: .nan, y: 0), SwipePoint(x: 0, y: 0), SwipePoint(x: 1, y: 1)], keyCenters: centers).isEmpty)
        #expect(decoder.suggestions(for: [SwipePoint(x: 4, y: 4), SwipePoint(x: 5, y: 4), SwipePoint(x: 6, y: 4)], keyCenters: centers).isEmpty)
    }
}
