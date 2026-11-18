import Cocoa

/// Ein Bild mit Text darauf, für Selbsttest und Probelauf.
func testbild(_ text: String, breite: Int = 900, hoehe: Int = 320) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: breite, pixelsHigh: hoehe, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.white.setFill(); NSRect(x: 0, y: 0, width: breite, height: hoehe).fill()
    farbe(0x2563EB).setFill(); NSRect(x: 0, y: hoehe - 60, width: breite, height: 60).fill()
    var y = CGFloat(hoehe - 130)
    for zeile in text.components(separatedBy: "\n") {
        (zeile as NSString).draw(at: NSPoint(x: 40, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: 44, weight: .semibold), .foregroundColor: NSColor.black])
        y -= 64
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// `Hikidashi --self-test`: prüft Verlauf, Grenzen, Bilder, Texterkennung, Inbox und Zwischenablage
/// in einem Wegwerf-Ordner und auf einer eigenen Zwischenablage. Die echte bleibt unberührt.
func selbsttest() throws {
    let fm = FileManager.default
    let ordner = fm.temporaryDirectory.appendingPathComponent("hikidashi-test-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: ordner) }
    func pruefe(_ ok: Bool, _ was: String) throws { guard ok else { throw VerlaufFehler.meldung("Test fehlgeschlagen: \(was)") } }
    let daten = ordner.appendingPathComponent("daten")
    let v = Verlauf(ordner: daten)
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // Verlauf und Doppelte
    v.aufnehmen(.text("Hallo"), app: "Notizen", bundle: nil, jetzt: t0)
    v.aufnehmen(.text("Welt"), app: "Safari", bundle: nil, jetzt: t0 + 1)
    v.aufnehmen(.text("Hallo"), app: "Mail", bundle: nil, jetzt: t0 + 2)
    try pruefe(v.eintraege.map(\.text) == ["Hallo", "Welt"] && v.eintraege[0].app == "Mail", "Doppeltes wandert nach oben")

    // Anheften und Grenze
    let welt = v.eintraege[1].id
    v.anheften(welt, true, jetzt: t0 + 3)
    for i in 0..<310 { v.aufnehmen(.text("Nr \(i)"), app: nil, bundle: nil, jetzt: t0 + 10 + Double(i)) }
    try pruefe(v.eintraege.filter { !$0.angeheftet }.count == Verlauf.maxEintraege, "Grenze von 300 Einträgen")
    try pruefe(v.eintrag(welt) != nil, "Angeheftetes fällt nicht aus dem Verlauf")
    try pruefe(v.liste(reiter: 1, suche: "").map(\.id) == [welt], "Reiter Angeheftet")
    try pruefe(v.liste(reiter: 0, suche: "nr 299").map(\.text) == ["Nr 299"] && v.liste(reiter: 0, suche: "NR").count == 300, "Suche")
    v.benutzt(welt, jetzt: t0 + 400)
    try pruefe(v.eintraege[0].id == welt, "Benutztes wandert nach oben")

    // Bilder
    let png = testbild("Rechnung 2026\nHikidashi Probe")
    let b = v.aufnehmen(.bild(png, 900, 320), app: "Vorschau", bundle: nil, jetzt: t0 + 500)
    try pruefe(b != nil && fm.fileExists(atPath: v.bildURL(b!)!.path), "Bild wird gespeichert")
    let b2 = v.aufnehmen(.bild(png, 900, 320), app: "Vorschau", bundle: nil, jetzt: t0 + 501)
    try pruefe(b2?.id == b?.id && v.liste(reiter: 2, suche: "").count == 1, "gleiches Bild nur einmal")
    let erkannt = try Verlauf.erkenneText(v.bildURL(b!)!)
    try pruefe(erkannt.contains("Rechnung") && erkannt.contains("2026"), "Text aus Bild (erkannt: \(erkannt))")
    v.setzeErkannt(b!.id, erkannt)
    try pruefe(v.liste(reiter: 0, suche: "rechnung").first?.id == b!.id, "Suche findet Text auf Bildern")

    // Sichern und Laden
    let v2 = Verlauf(ordner: daten)
    try pruefe(v2.eintraege == v.eintraege, "Sichern und Laden")

    // Schutz der Ablage
    func rechte(_ u: URL) -> Int { (try? fm.attributesOfItem(atPath: u.path))?[.posixPermissions] as? Int ?? -1 }
    try pruefe(rechte(daten) == 0o700 && rechte(v.bilderOrdner) == 0o700, "Ablage nur für dich lesbar")
    try pruefe(rechte(v.datei) == 0o600 && rechte(v.bildURL(b!)!) == 0o600, "Verlauf und Bilder nur für dich lesbar")
    try pruefe((try? daten.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup == true, "Ablage nicht im Backup")
    var fremd = v.eintrag(b!.id)!; fremd.bild = "../../verlauf.json"
    try pruefe(v.bildURL(fremd) == nil, "Bildname außerhalb von bilder/ wird nicht benutzt")
    try pruefe(v.aufnehmen(.bild(png, 20_000, 20_000), app: nil, bundle: nil) == nil, "Riesige Bildmaße werden abgelehnt")
    try pruefe(Verlauf.yamlText("A: \"b\"\nc") == "\"A: \\\"b\\\" c\"", "App-Name im YAML-Kopf maskiert")

    // Inbox
    let inbox = ordner.appendingPathComponent("inbox")
    try fm.createDirectory(at: inbox, withIntermediateDirectories: true)
    let z1 = try Verlauf.inDieInbox(v.eintrag(welt)!, verlauf: v, inbox: inbox, jetzt: t0)
    let inhalt = try String(contentsOf: z1[0], encoding: .utf8)
    try pruefe(z1[0].lastPathComponent.hasSuffix("-welt.md") && inhalt.contains("\nWelt\n") && inhalt.contains("tags: [inbox]"), "Inbox: Text als .md")
    let z2 = try Verlauf.inDieInbox(v.eintrag(welt)!, verlauf: v, inbox: inbox, jetzt: t0)
    try pruefe(z2[0].lastPathComponent.hasSuffix("-welt-2.md"), "Inbox: kein Überschreiben")
    let z3 = try Verlauf.inDieInbox(v.eintrag(b!.id)!, verlauf: v, inbox: inbox, jetzt: t0)
    try pruefe(z3[0].pathExtension == "png" && (try? Data(contentsOf: z3[0])) == png, "Inbox: Bild als .png")
    let probe = ordner.appendingPathComponent("Angebot Müller.pdf")
    try Data("x".utf8).write(to: probe)
    let d = v.aufnehmen(.dateien([probe]), app: "Finder", bundle: nil, jetzt: t0 + 600)!
    let z4 = try Verlauf.inDieInbox(d, verlauf: v, inbox: inbox, jetzt: t0)
    try pruefe(z4.map(\.lastPathComponent) == ["Angebot Müller.pdf"], "Inbox: Datei wird kopiert")
    try pruefe(Verlauf.kurzname("Idee für das nächste Video!") == "idee-fuer-das-naechste-video", "Dateiname aus Text")
    try pruefe(Verlauf.kurzname("你好") == "notiz", "Dateiname ohne lateinische Buchstaben")
    do { _ = try Verlauf.inDieInbox(d, verlauf: v, inbox: ordner.appendingPathComponent("gibtsnicht")); try pruefe(false, "fehlende Inbox") } catch VerlaufFehler.meldung(let t) where !t.hasPrefix("Test") {}

    // Löschen und Leeren
    let bildPfad = v.bildURL(b!)!.path
    v.loeschen(b!.id)
    try pruefe(!fm.fileExists(atPath: bildPfad) && v.eintrag(b!.id) == nil, "Löschen nimmt das Bild mit")
    v.leeren()
    try pruefe(v.eintraege.map(\.id) == [welt], "Leeren behält Angeheftetes")

    // Zwischenablage auslesen (eigene Ablage, nicht die echte)
    let pb = NSPasteboard(name: .init("de.kenzoweiss.hikidashi.test.\(UUID().uuidString)"))
    defer { pb.releaseGlobally() }
    let verdeckt = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    pb.declareTypes([.string, verdeckt], owner: nil); pb.setString("passwort123", forType: .string); pb.setString("", forType: verdeckt)
    try pruefe(Verlauf.lies(pb) == nil, "Passwörter aus Passwort-Managern werden nie aufgenommen")
    pb.declareTypes([.string], owner: nil); pb.setString("Ein Satz", forType: .string)
    if case .text(let t)? = Verlauf.lies(pb) { try pruefe(t == "Ein Satz", "Text lesen") } else { try pruefe(false, "Text lesen") }
    pb.declareTypes([.png], owner: nil); pb.setData(png, forType: .png)
    if case .bild(_, let w, let h)? = Verlauf.lies(pb) { try pruefe(w == 900 && h == 320, "Bild lesen") } else { try pruefe(false, "Bild lesen") }
    pb.declareTypes([.string, .tiff], owner: nil); pb.setString("https://example.com/bild.png", forType: .string)
    pb.setData(NSBitmapImageRep(data: png)!.tiffRepresentation!, forType: .tiff)
    if case .bild? = Verlauf.lies(pb) {} else { try pruefe(false, "Browser „Bild kopieren“ zählt als Bild") }
    pb.declareTypes([.string, .png], owner: nil); pb.setString("Zelle A1\tZelle B1", forType: .string); pb.setData(png, forType: .png)
    if case .text? = Verlauf.lies(pb) {} else { try pruefe(false, "Text mit Bild daneben (Excel) zählt als Text") }
    pb.clearContents(); pb.writeObjects([probe as NSURL])
    if case .dateien(let u)? = Verlauf.lies(pb) { try pruefe(u.map(\.path) == [probe.path], "Dateien lesen") } else { try pruefe(false, "Dateien lesen") }

    // Zurückschreiben
    let v3 = Verlauf(ordner: ordner.appendingPathComponent("daten3"))
    let tx = v3.aufnehmen(.text("Zurück"), app: nil, bundle: nil)!
    v3.schreibe(tx, auf: pb)
    try pruefe(pb.string(forType: .string) == "Zurück", "Text zurückschreiben")
    let bx = v3.aufnehmen(.bild(png, 900, 320), app: nil, bundle: nil)!
    v3.schreibe(bx, auf: pb)
    try pruefe(pb.data(forType: .png) == png && pb.data(forType: .tiff) != nil, "Bild zurückschreiben")
    v3.schreibe(d, auf: pb)
    try pruefe((pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL])?.map(\.path) == [probe.path], "Dateien zurückschreiben")
}

/// Beispiel-Einträge für den Probelauf (`--test-demo`), nur im Wegwerf-Ordner.
func demoDaten(_ v: Verlauf) {
    let jetzt = Date()
    v.aufnehmen(.text("Beste Grüße\nMax Muster\nMuster GmbH"), app: "Mail", bundle: nil, jetzt: jetzt.addingTimeInterval(-86_400 * 3))
    if let sig = v.eintraege.first { v.anheften(sig.id, true) }
    v.aufnehmen(.text("https://calendly.com/beispiel/erstgespraech"), app: "Safari", bundle: nil, jetzt: jetzt.addingTimeInterval(-86_400))
    if let link = v.eintraege.first { v.anheften(link.id, true) }
    v.aufnehmen(.text("Du bist ein erfahrener n8n-Entwickler. Baue einen Workflow, der neue Anfragen aus dem Kontaktformular liest, sie nach Dringlichkeit sortiert und eine Antwort vorschlägt."), app: "Claude", bundle: nil, jetzt: jetzt.addingTimeInterval(-5_400))
    v.aufnehmen(.dateien([URL(fileURLWithPath: "/System/Applications/Calculator.app")]), app: "Finder", bundle: nil, jetzt: jetzt.addingTimeInterval(-2_400))
    let bild = v.aufnehmen(.bild(testbild("Lieferschein Nr. 48213\n24 × Kartonage A4", breite: 1400, hoehe: 820), 1400, 820), app: "Bildschirmfoto", bundle: nil, jetzt: jetzt.addingTimeInterval(-900))
    if let bild { v.setzeErkannt(bild.id, "Lieferschein Nr. 48213\n24 × Kartonage A4") }
    v.aufnehmen(.text("Hallo Frau Becker,\n\ndanke für das nette Gespräch heute. Wie besprochen schicke ich Ihnen bis Freitag eine erste Einschätzung, welche Abläufe sich automatisieren lassen."), app: "Notizen", bundle: nil, jetzt: jetzt.addingTimeInterval(-240))
}
