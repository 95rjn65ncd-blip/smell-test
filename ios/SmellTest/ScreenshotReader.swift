import Foundation
import Vision
import SmellTestCore

/// Reads the words in a screenshot with Apple's on-device text recognition (Vision).
/// The picture never leaves the phone and is never sent to any model; only the text it
/// produces goes on to the normal check, exactly like a pasted message.
enum ScreenshotReader {
    enum Failure: Error {
        case unreadable   // not an image, or Vision couldn't run
        case noText       // no words found
    }

    static func read(_ imageData: Data) async throws(Failure) -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let observations: [RecognizedTextObservation]
        do {
            observations = try await request.perform(on: imageData)
        } catch {
            throw .unreadable
        }
        let lines = observations.compactMap { obs -> ScreenshotText.Line? in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            return ScreenshotText.Line(text: text, top: Double(obs.topLeft.y), left: Double(obs.topLeft.x))
        }
        guard let text = ScreenshotText.assemble(lines) else { throw .noText }
        return text
    }
}
