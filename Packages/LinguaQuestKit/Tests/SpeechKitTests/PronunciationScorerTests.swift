import XCTest
@testable import SpeechKit

final class PronunciationScorerTests: XCTestCase {

    // MARK: - Разбор на слова

    func testWordsIgnorePunctuationAndCase() {
        XCTAssertEqual(
            PronunciationScorer.words(in: "A glass of water, please!"),
            ["a", "glass", "of", "water", "please"]
        )
    }

    func testWordsKeepApostrophes() {
        XCTAssertEqual(PronunciationScorer.words(in: "I don't work"), ["i", "don't", "work"])
    }

    // MARK: - Оценка

    func testExactMatchIsCorrect() {
        let result = PronunciationScorer.score(recognized: "Nice to meet you", expected: "Nice to meet you")
        XCTAssertEqual(result.verdict, .correct)
        XCTAssertEqual(result.score, 1, accuracy: 0.001)
        XCTAssertEqual(result.percent, 100)
    }

    func testPunctuationAndCaseDoNotMatter() {
        let result = PronunciationScorer.score(recognized: "nice, to meet you!", expected: "Nice to meet you")
        XCTAssertEqual(result.verdict, .correct)
    }

    func testMissingOneWordOutOfFiveIsStillAccepted() {
        // 4 из 5 = 80% — выше порога приёма, но ниже безупречного.
        let result = PronunciationScorer.score(
            recognized: "a glass of water",
            expected: "a glass of water please"
        )
        guard case .close(let missed) = result.verdict else {
            return XCTFail("Ожидался вердикт «почти», получен \(result.verdict)")
        }
        XCTAssertEqual(missed, ["please"])
        XCTAssertTrue(result.verdict.isAccepted)
    }

    func testHalfWrongIsRejected() {
        let result = PronunciationScorer.score(
            recognized: "good evening",
            expected: "good morning everyone here"
        )
        XCTAssertFalse(result.verdict.isAccepted)
        if case .wrong(let heard) = result.verdict {
            XCTAssertEqual(heard, "good evening")
        } else {
            XCTFail("Ожидался вердикт «не то», получен \(result.verdict)")
        }
    }

    func testEmptyRecognitionIsNotHeard() {
        let result = PronunciationScorer.score(recognized: "   ", expected: "hello")
        XCTAssertEqual(result.verdict, .notHeard)
        XCTAssertEqual(result.score, 0)
    }

    func testEmptyExpectedIsNotHeard() {
        let result = PronunciationScorer.score(recognized: "hello", expected: "")
        XCTAssertEqual(result.verdict, .notHeard)
    }

    // MARK: - Снисходительность к распознаванию

    func testVerbEndingIsForgiven() {
        // Распознаватель постоянно путает окончания — это не ошибка произношения.
        let result = PronunciationScorer.score(recognized: "she work in a bank", expected: "she works in a bank")
        XCTAssertEqual(result.verdict, .correct)
    }

    func testSingleLetterTypoInLongWordIsForgiven() {
        XCTAssertTrue(PronunciationScorer.isSameWord("breakfast", "breakfost"))
    }

    func testShortWordsAreNotConfused() {
        // В коротких словах одна буква меняет смысл — прощать нельзя.
        XCTAssertFalse(PronunciationScorer.isSameWord("he", "we"))
        XCTAssertFalse(PronunciationScorer.isSameWord("cat", "cut"))
    }

    func testDifferentWordsAreNotSame() {
        XCTAssertFalse(PronunciationScorer.isSameWord("morning", "evening"))
        XCTAssertFalse(PronunciationScorer.isSameWord("cheese", "choose"))
    }

    // MARK: - Повторы слов

    func testRepeatedWordNeedsTwoMatches() {
        // «very very good»: одно very в ответе не должно закрывать оба в эталоне.
        let result = PronunciationScorer.score(recognized: "very good", expected: "very very good")
        XCTAssertLessThan(result.score, 1)
        guard case .close(let missed) = result.verdict else {
            return XCTFail("Ожидался вердикт «почти», получен \(result.verdict)")
        }
        XCTAssertEqual(missed, ["very"])
    }

    func testExtraWordsDoNotBreakMatch() {
        // Лишние слова в распознавании не штрафуются: важен эталон целиком.
        let result = PronunciationScorer.score(recognized: "well hello there my friend", expected: "hello friend")
        XCTAssertEqual(result.verdict, .correct)
    }

    // MARK: - Границы порогов

    func testThresholdsAreOrdered() {
        XCTAssertLessThan(PronunciationScorer.acceptThreshold, PronunciationScorer.perfectThreshold)
        XCTAssertGreaterThan(PronunciationScorer.acceptThreshold, 0)
        XCTAssertLessThanOrEqual(PronunciationScorer.perfectThreshold, 1)
    }

    func testScoreIsAlwaysInUnitRange() {
        let cases = [
            ("hello", "hello world"),
            ("", "hello"),
            ("a b c d e", "a"),
            ("nothing common", "completely different phrase")
        ]
        for (recognized, expected) in cases {
            let result = PronunciationScorer.score(recognized: recognized, expected: expected)
            XCTAssertGreaterThanOrEqual(result.score, 0, "\(recognized) / \(expected)")
            XCTAssertLessThanOrEqual(result.score, 1, "\(recognized) / \(expected)")
        }
    }
}
