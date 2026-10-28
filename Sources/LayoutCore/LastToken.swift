/// Splits the text before the cursor into a prefix and the last whitespace-delimited token
/// (keeping any trailing whitespace with the token). Symbols count as part of the token, since
/// in the wrong layout they are letters: ";" is "ж", "^" is ",".
public func lastToken(in text: String) -> (prefixLength: Int, token: String) {
    guard let lastNonSpace = text.lastIndex(where: { !$0.isWhitespace }) else {
        return (text.count, "")
    }
    let content = text[...lastNonSpace]
    let start = content.lastIndex(where: { $0.isWhitespace }).map { text.index(after: $0) } ?? text.startIndex
    return (text.distance(from: text.startIndex, to: start), String(text[start...]))
}
