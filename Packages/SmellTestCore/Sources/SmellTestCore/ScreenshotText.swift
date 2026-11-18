import Foundation

/// Turns lines read from a screenshot (by Apple's on-device text recognition, in the app) into one
/// message to check. No network code: the picture and its text stay on the phone. Only the text
/// can ever go further, and only through the Privacy Shield like any pasted message.
public enum ScreenshotText {
    /// One recognized line. `top` and `left` are in Vision's normalized coordinates
    /// (0...1, origin at the bottom-left), so a larger `top` is higher on screen.
    public struct Line: Sendable, Equatable {
        public let text: String
        public let top: Double
        public let left: Double

        public init(text: String, top: Double, left: Double) {
            self.text = text
            self.top = top
            self.left = left
        }
    }

    /// Lines closer together than this (as a fraction of the image height) count as one row,
    /// read left to right.
    static let sameRow = 0.01

    /// Reading order: top to bottom, then left to right within a row. Blank lines are dropped.
    /// Returns nil when there's nothing to check, so the caller can say so instead of checking
    /// an empty message.
    public static func assemble(_ lines: [Line]) -> String? {
        let ordered = lines
            .map { Line(text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines), top: $0.top, left: $0.left) }
            .filter { !$0.text.isEmpty }
            .sorted { a, b in
                abs(a.top - b.top) < sameRow ? a.left < b.left : a.top > b.top
            }
        guard !ordered.isEmpty else { return nil }
        return ordered.map(\.text).joined(separator: "\n")
    }
}
