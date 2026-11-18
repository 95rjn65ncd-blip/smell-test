import Testing
@testable import SmellTestCore

struct ScreenshotTextTests {
    @Test func readsTopToBottom() {
        let lines = [
            ScreenshotText.Line(text: "or it will be returned.", top: 0.40, left: 0.1),
            ScreenshotText.Line(text: "ParcelPoint: your package is on hold.", top: 0.60, left: 0.1),
            ScreenshotText.Line(text: "Pay the $1.99 fee at parcelpoint-redelivery.top", top: 0.50, left: 0.1),
        ]
        #expect(ScreenshotText.assemble(lines) ==
                "ParcelPoint: your package is on hold.\nPay the $1.99 fee at parcelpoint-redelivery.top\nor it will be returned.")
    }

    @Test func sameRowReadsLeftToRight() {
        let lines = [
            ScreenshotText.Line(text: "9:41", top: 0.98, left: 0.1),
            ScreenshotText.Line(text: "Hi Mum", top: 0.705, left: 0.5),
            ScreenshotText.Line(text: "Jess", top: 0.70, left: 0.1),
        ]
        #expect(ScreenshotText.assemble(lines) == "9:41\nJess\nHi Mum")
    }

    @Test func blankImageGivesNothing() {
        #expect(ScreenshotText.assemble([]) == nil)
        #expect(ScreenshotText.assemble([ScreenshotText.Line(text: "  \n", top: 0.5, left: 0.5)]) == nil)
    }
}
