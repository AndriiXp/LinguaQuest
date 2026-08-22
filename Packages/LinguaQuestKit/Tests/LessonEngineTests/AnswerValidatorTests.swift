import XCTest
@testable import LessonEngine

final class AnswerValidatorTests: XCTestCase {

    func testNormalizationStripsCaseSpacingAndPunctuation() {
        XCTAssertEqual(AnswerValidator.normalize("  Drinks. "), "drinks")
        XCTAssertEqual(AnswerValidator.normalize("I  do   not work!"), "i do not work")
        XCTAssertEqual(AnswerValidator.normalize("Thank you,"), "thank you")
    }

    func testNormalizationUnifiesApostrophes() {
        XCTAssertEqual(AnswerValidator.normalize("don\u{2019}t"), "don't")
        XCTAssertEqual(AnswerValidator.normalize("don\u{00B4}t"), "don't")
    }

    func testExactMatchIgnoresCaseAndPunctuation() {
        XCTAssertEqual(AnswerValidator.match(input: "  Drinks. ", against: ["drinks"]), .exact)
        XCTAssertEqual(
            AnswerValidator.match(input: "I don\u{2019}t work", against: ["I don't work"]),
            .exact
        )
    }

    func testTypoAcceptedInLongWords() {
        guard case .typo(let correct) = AnswerValidator.match(input: "breakfost", against: ["breakfast"]) else {
            return XCTFail("Ожидалась опечатка, а не отказ")
        }
        XCTAssertEqual(correct, "breakfast")
    }

    func testTypoRejectedInShortWords() {
        // В коротких словах одна буква меняет смысл — прощать нельзя.
        XCTAssertEqual(AnswerValidator.match(input: "he", against: ["we"]), .wrong)
        XCTAssertEqual(AnswerValidator.match(input: "cat", against: ["cot"]), .wrong)
    }

    func testChoiceModeHasNoTypoTolerance() {
        XCTAssertEqual(
            AnswerValidator.match(input: "breakfost", against: ["breakfast"], allowTypos: false),
            .wrong
        )
    }

    func testEmptyInputIsWrong() {
        XCTAssertEqual(AnswerValidator.match(input: "   ", against: ["water"]), .wrong)
    }

    func testAlternativeAnswersAccepted() {
        XCTAssertEqual(
            AnswerValidator.match(input: "bye", against: ["goodbye", "bye"]),
            .exact
        )
    }

    func testLevenshteinDistances() {
        XCTAssertEqual(AnswerValidator.levenshtein("", "abc"), 3)
        XCTAssertEqual(AnswerValidator.levenshtein("abc", ""), 3)
        XCTAssertEqual(AnswerValidator.levenshtein("kitten", "sitting"), 3)
        XCTAssertEqual(AnswerValidator.levenshtein("breakfost", "breakfast"), 1)
        XCTAssertEqual(AnswerValidator.levenshtein("same", "same"), 0)
    }
}
