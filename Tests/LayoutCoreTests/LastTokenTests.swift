import Testing
@testable import LayoutCore

@Suite struct LastTokenTests {
    @Test func tokenIsEverythingAfterTheLastWhitespace() {
        let (prefix, token) = lastToken(in: "hello nj;е")
        #expect(prefix == 6)
        #expect(token == "nj;е")
    }

    @Test func symbolsInsideTheTokenAreKept() {
        let (prefix, token) = lastToken(in: "cegth^")
        #expect(prefix == 0)
        #expect(token == "cegth^")
    }

    @Test func trailingWhitespaceStaysWithTheToken() {
        let (prefix, token) = lastToken(in: "hello ghbdtn ")
        #expect(prefix == 6)
        #expect(token == "ghbdtn ")
    }

    @Test func newlineIsABoundaryToo() {
        let (prefix, token) = lastToken(in: "a\nb")
        #expect(prefix == 2)
        #expect(token == "b")
    }

    @Test func whitespaceOnlyHasNoToken() {
        let (prefix, token) = lastToken(in: "   ")
        #expect(prefix == 3)
        #expect(token == "")
        #expect(lastToken(in: "").token == "")
    }
}
