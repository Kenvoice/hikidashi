import Cocoa

// Symbol: helle Kachel, darin eine Kommode mit herausgezogener Schublade (引き出し), aus der ein Blatt schaut.
let ziel = CommandLine.arguments[1]
let groesse = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: groesse, pixelsHigh: groesse, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
func farbe(_ hex: Int, _ a: CGFloat = 1) -> NSColor { NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a) }
func feld(_ r: NSRect, _ radius: CGFloat, _ c: NSColor) { c.setFill(); NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill() }

let kachelRahmen = NSRect(x: 100, y: 100, width: 824, height: 824)
feld(kachelRahmen, 185, farbe(0xF7F9FC))
farbe(0xE2E8F0).setStroke()
let rand = NSBezierPath(roundedRect: kachelRahmen, xRadius: 185, yRadius: 185); rand.lineWidth = 8; rand.stroke()

// Kommode: obere Schublade zu, untere herausgezogen
feld(NSRect(x: 252, y: 236, width: 520, height: 560), 56, farbe(0x2563EB, 0.16))
feld(NSRect(x: 292, y: 566, width: 440, height: 190), 36, farbe(0x2563EB, 0.9))
feld(NSRect(x: 452, y: 646, width: 120, height: 30), 15, .white)
// Blatt, das aus der offenen Schublade schaut
feld(NSRect(x: 352, y: 330, width: 320, height: 300), 26, .white)
farbe(0xCBD5E1).setStroke()
let blatt = NSBezierPath(roundedRect: NSRect(x: 352, y: 330, width: 320, height: 300), xRadius: 26, yRadius: 26); blatt.lineWidth = 6; blatt.stroke()
feld(NSRect(x: 400, y: 548, width: 200, height: 26), 13, farbe(0x22D3EE))
feld(NSRect(x: 400, y: 498, width: 150, height: 26), 13, farbe(0xEF4861))
// Schubladenfront davor
feld(NSRect(x: 222, y: 200, width: 580, height: 200), 40, farbe(0x2563EB))
feld(NSRect(x: 452, y: 284, width: 120, height: 32), 16, .white)
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: ziel))
