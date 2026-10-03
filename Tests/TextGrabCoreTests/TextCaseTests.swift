import Testing

@testable import TextGrabCore

@Suite struct TextCaseTests {
  @Test(arguments: [
    ("Hello, World", "HELLO, WORLD"),
    ("straße", "STRASSE"),
    ("", ""),
  ])
  func upper(input: String, expected: String) {
    #expect(TextCase.upper.apply(to: input) == expected)
  }

  @Test(arguments: [
    ("Hello, WORLD", "hello, world"),
    ("ÉCLAIR", "éclair"),
    ("", ""),
  ])
  func lower(input: String, expected: String) {
    #expect(TextCase.lower.apply(to: input) == expected)
  }

  @Test(arguments: [
    ("the lord of the rings", "The Lord Of The Rings"),
    ("don't STOP me", "Don't Stop Me"),
    ("(quoted) \"words\"", "(Quoted) \"Words\""),
    ("3rd place", "3rd Place"),
    ("rock-and-roll", "Rock-and-roll"),
    ("éclair über", "Éclair Über"),
    ("привет мир", "Привет Мир"),
    ("", ""),
  ])
  func title(input: String, expected: String) {
    #expect(TextCase.title.apply(to: input) == expected)
  }

  @Test func titleKeepsWhitespaceAndLineBreaksAsTheyAre() {
    #expect(TextCase.title.apply(to: "  one\ttwo\n\nthree  ") == "  One\tTwo\n\nThree  ")
  }
}
