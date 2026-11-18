import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation
let N = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: N, height: N, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ h: UInt32) -> CGColor { CGColor(red: CGFloat((h>>16)&255)/255, green: CGFloat((h>>8)&255)/255, blue: CGFloat(h&255)/255, alpha: 1) }
ctx.setFillColor(c(0x0F2A44)); ctx.fill(CGRect(x: 0, y: 0, width: N, height: N))
ctx.translateBy(x: 0, y: CGFloat(N)); ctx.scaleBy(x: 1, y: -1)
let k = CGFloat(N) / 180
ctx.scaleBy(x: k, y: k); ctx.translateBy(x: 90, y: 90); ctx.scaleBy(x: 0.86, y: 0.86); ctx.translateBy(x: -90, y: -97)
let p = CGMutablePath()
p.move(to: CGPoint(x: 34, y: 96)); p.addLine(to: CGPoint(x: 146, y: 96))
p.addArc(tangent1End: CGPoint(x: 160, y: 96), tangent2End: CGPoint(x: 160, y: 110), radius: 14)
p.addLine(to: CGPoint(x: 160, y: 132))
p.addArc(tangent1End: CGPoint(x: 160, y: 146), tangent2End: CGPoint(x: 146, y: 146), radius: 14)
p.addLine(to: CGPoint(x: 70, y: 146)); p.addLine(to: CGPoint(x: 50, y: 162)); p.addLine(to: CGPoint(x: 50, y: 146))
p.addLine(to: CGPoint(x: 34, y: 146))
p.addArc(tangent1End: CGPoint(x: 20, y: 146), tangent2End: CGPoint(x: 20, y: 132), radius: 14)
p.addLine(to: CGPoint(x: 20, y: 110))
p.addArc(tangent1End: CGPoint(x: 20, y: 96), tangent2End: CGPoint(x: 34, y: 96), radius: 14)
p.closeSubpath()
ctx.addPath(p); ctx.setStrokeColor(c(0xFFFFFF)); ctx.setLineWidth(7); ctx.setLineJoin(.round); ctx.strokePath()
ctx.setFillColor(c(0xFFFFFF))
for x in [64.0, 90.0, 116.0] { ctx.fillEllipse(in: CGRect(x: x-6, y: 115, width: 12, height: 12)) }
let w = CGMutablePath()
w.move(to: CGPoint(x: 90, y: 82))
w.addCurve(to: CGPoint(x: 90, y: 48), control1: CGPoint(x: 74, y: 70), control2: CGPoint(x: 106, y: 62))
w.addCurve(to: CGPoint(x: 98, y: 32), control1: CGPoint(x: 80, y: 40), control2: CGPoint(x: 88, y: 30))
ctx.addPath(w); ctx.setStrokeColor(c(0x4FD1C5)); ctx.setLineWidth(8); ctx.setLineCap(.round); ctx.strokePath()
let img = ctx.makeImage()!
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
