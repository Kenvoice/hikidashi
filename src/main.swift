import Cocoa
import Carbon.HIToolbox
import ServiceManagement
import ApplicationServices

// Farben aus context/brand-assets/design/design-system.html
func farbe(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
let tinte1 = farbe(0x0D1117), tinte3 = farbe(0x475569), tinte4 = farbe(0x94A3B8), linie = farbe(0xCBD5E1), blau = farbe(0x2563EB)
let grund = farbe(0xF7F9FC), kachel = farbe(0xEEF2F7), auswahlFarbe = farbe(0xE3ECFD)

// MARK: Bausteine

final class Panel: NSPanel {
    var beiEsc: (() -> Void)?
    var beiTaste: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == UInt16(kVK_Escape), event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            beiEsc?(); return
        }
        super.sendEvent(event)
    }
    /// Die App wird nie „aktiv“ (sonst verliert das Fenster dahinter den Fokus), deshalb greift kein Menü.
    /// Die üblichen Tastenkürzel laufen hier.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard mods.contains(.command) else { return super.performKeyEquivalent(with: event) }
        if beiTaste?(event) == true { return true }
        let taste = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let aktion: Selector?
        switch (taste, mods.contains(.shift)) {
        case ("c", false): aktion = #selector(NSText.copy(_:))
        case ("x", false): aktion = #selector(NSText.cut(_:))
        case ("v", false): aktion = #selector(NSText.paste(_:))
        case ("a", false): aktion = #selector(NSText.selectAll(_:))
        case ("z", false): aktion = Selector(("undo:"))
        case ("z", true): aktion = Selector(("redo:"))
        default: aktion = nil
        }
        if let aktion, NSApp.sendAction(aktion, to: nil, from: self) { return true }
        return super.performKeyEquivalent(with: event)
    }
}

/// Helle Fläche mit Haarlinie, zieht das Fenster mit.
final class Flaeche: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let form = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        grund.setFill(); form.fill()
        linie.setStroke(); form.lineWidth = 1; form.stroke()
    }
}

/// Weiße Karte für die Vorschau.
final class Karte: NSView {
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let form = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 9, yRadius: 9)
        NSColor.white.setFill(); form.fill()
        farbe(0xE2E8F0).setStroke(); form.lineWidth = 1; form.stroke()
    }
}

final class Zeile: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        auswahlFarbe.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 1), xRadius: 8, yRadius: 8).fill()
    }
    override var isEmphasized: Bool { get { false } set {} }
}

final class Zelle: NSTableCellView {
    let symbol = NSImageView(), titel = NSTextField(labelWithString: ""), meta = NSTextField(labelWithString: "")
    let nummer = NSTextField(labelWithString: ""), punkt = NSView()

    init() {
        super.init(frame: .zero)
        identifier = .init("z")
        symbol.wantsLayer = true
        symbol.layer?.cornerRadius = 6; symbol.layer?.masksToBounds = true
        symbol.layer?.backgroundColor = kachel.cgColor
        symbol.imageScaling = .scaleProportionallyUpOrDown
        titel.font = .systemFont(ofSize: 12.5, weight: .medium); titel.textColor = tinte1; titel.lineBreakMode = .byTruncatingTail
        meta.font = .systemFont(ofSize: 10.5); meta.textColor = tinte4; meta.lineBreakMode = .byTruncatingTail
        nummer.font = .monospacedSystemFont(ofSize: 10, weight: .regular); nummer.textColor = tinte4; nummer.alignment = .right
        punkt.wantsLayer = true; punkt.layer?.backgroundColor = blau.cgColor; punkt.layer?.cornerRadius = 3
        for v in [symbol, titel, meta, nummer, punkt] as [NSView] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        titel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        meta.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nummer.setContentHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            symbol.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            symbol.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbol.widthAnchor.constraint(equalToConstant: 34), symbol.heightAnchor.constraint(equalToConstant: 34),
            titel.leadingAnchor.constraint(equalTo: symbol.trailingAnchor, constant: 10),
            titel.trailingAnchor.constraint(lessThanOrEqualTo: nummer.leadingAnchor, constant: -6),
            titel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            meta.leadingAnchor.constraint(equalTo: titel.leadingAnchor),
            meta.trailingAnchor.constraint(lessThanOrEqualTo: nummer.leadingAnchor, constant: -6),
            meta.topAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            nummer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            nummer.centerYAnchor.constraint(equalTo: titel.centerYAnchor),
            punkt.widthAnchor.constraint(equalToConstant: 6), punkt.heightAnchor.constraint(equalToConstant: 6),
            punkt.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            punkt.centerYAnchor.constraint(equalTo: meta.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

func aktionsKnopf(_ symbol: String, _ titel: String, _ hilfe: String, _ ziel: AnyObject, _ aktion: Selector) -> NSButton {
    let b = NSButton(title: titel, image: NSImage(systemSymbolName: symbol, accessibilityDescription: titel) ?? NSImage(), target: ziel, action: aktion)
    b.isBordered = false; b.imagePosition = .imageLeading; b.toolTip = hilfe
    b.contentTintColor = tinte3; b.font = .systemFont(ofSize: 11.5, weight: .medium)
    b.symbolConfiguration = .init(pointSize: 11.5, weight: .medium)
    b.translatesAutoresizingMaskIntoConstraints = false
    return b
}

func linieView() -> NSView {
    let t = NSBox(); t.boxType = .custom; t.borderWidth = 0; t.fillColor = farbe(0xE2E8F0)
    t.translatesAutoresizingMaskIntoConstraints = false
    return t
}

func vorschaubild(_ url: URL, _ max: Int) -> NSImage? {
    guard let q = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let o: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: max, kCGImageSourceCreateThumbnailWithTransform: true]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(q, 0, o as CFDictionary) else { return nil }
    return NSImage(cgImage: cg, size: .zero)
}

func ersteZeile(_ t: String?) -> String? {
    guard let t else { return nil }
    let zeile = t.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
    return zeile.map { String($0.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ").prefix(140)) }
}

func wann(_ d: Date) -> String {
    let s = -d.timeIntervalSinceNow
    if s < 60 { return "gerade eben" }
    if s < 3600 { return "vor \(Int(s / 60)) Min." }
    let f = DateFormatter(); f.locale = Locale(identifier: "de_DE")
    let k = Calendar.current
    if k.isDateInToday(d) { f.dateFormat = "HH:mm"; return f.string(from: d) }
    if k.isDateInYesterday(d) { f.dateFormat = "HH:mm"; return "gestern " + f.string(from: d) }
    f.dateFormat = "dd.MM. HH:mm"; return f.string(from: d)
}

func zahl(_ n: Int) -> String {
    let f = NumberFormatter(); f.locale = Locale(identifier: "de_DE"); f.numberStyle = .decimal
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

let bildEndungen: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "tif", "webp", "bmp"]

// MARK: App

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    static var shared: App!
    static let probe = CommandLine.arguments.contains("--schnappschuss")
    let verlauf: Verlauf
    /// Vorgabe aus dem Bau (inbox-ordner.txt). Was in den Einstellungen gewählt ist, geht vor.
    let inboxVorgabe: URL?
    let speicher = App.probe ? UserDefaults(suiteName: "de.kenzoweiss.hikidashi.probe")! : UserDefaults.standard

    var panel: Panel!
    var suche: NSSearchField!
    var reiter: NSSegmentedControl!
    var liste: NSTableView!
    var leer: NSTextField!
    var karte: Karte!
    var vorschauText: NSTextView!
    var vorschauRahmen: NSScrollView!
    var vorschauBild: NSImageView!
    var info: NSTextField!
    var einfuegenKnopf: NSButton!, pinKnopf: NSButton!, ocrKnopf: NSButton!, inboxKnopf: NSButton!, loeschKnopf: NSButton!
    var hinweis: NSTextField!
    var knopfReihe: NSStackView!
    var hinweisTimer: Timer?
    var statusItem: NSStatusItem!
    var tastenRef: EventHotKeyRef?
    var letzterStand = -1
    var treffer: [Eintrag] = []
    var vorher: NSRunningApplication?
    var verstecktUm = Date.distantPast
    var bildCache: [String: NSImage] = [:]
    var erkennungLaeuft = Set<String>()
    var wartendeKopie: String?
    let erkennung = DispatchQueue(label: "hikidashi.erkennung", qos: .utility)

    var direktEinfuegen: Bool { get { speicher.object(forKey: "direkt") as? Bool ?? true } set { speicher.set(newValue, forKey: "direkt") } }
    var pausiert: Bool {
        get { speicher.bool(forKey: "pausiert") }
        set { speicher.set(newValue, forKey: "pausiert"); statusItem?.button?.appearsDisabled = newValue }
    }
    var aktuell: Eintrag? { let r = liste.selectedRow; return r >= 0 && r < treffer.count ? treffer[r] : nil }

    var inboxOrdner: URL? {
        if let p = speicher.string(forKey: "inbox"), FileManager.default.fileExists(atPath: p) { return URL(fileURLWithPath: p) }
        return inboxVorgabe
    }

    init(verlauf: Verlauf, inboxVorgabe: URL?) { self.verlauf = verlauf; self.inboxVorgabe = inboxVorgabe }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        baueFenster()
        baueMenueleiste()
        if App.probe { probelauf(); return }
        if !registriereTaste() { meldung("Die Tastenkombination ⌃⌥V ist schon belegt. Hikidashi öffnest du über das Symbol in der Menüleiste.") }
        let uhr = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.pruefeZwischenablage() }
        RunLoop.main.add(uhr, forMode: .common)
        pruefeZwischenablage() // nimmt auf, was beim Start schon drin liegt
        for e in verlauf.eintraege where e.art == .bild && e.erkannt != true { erkenne(e.id) }
    }

    // MARK: Zwischenablage beobachten

    func pruefeZwischenablage() {
        let pb = NSPasteboard.general
        guard pb.changeCount != letzterStand else { return }
        letzterStand = pb.changeCount
        guard !pausiert else { return }
        let vorne = NSWorkspace.shared.frontmostApplication
        if let b = vorne?.bundleIdentifier, Verlauf.ignorierteApps.contains(b) { return }
        guard let inhalt = Verlauf.lies(pb),
              let neu = verlauf.aufnehmen(inhalt, app: vorne?.localizedName, bundle: vorne?.bundleIdentifier) else { return }
        if neu.art == .bild, neu.erkannt != true { erkenne(neu.id) }
        if panel.isVisible { aktualisiereListe() }
    }

    /// Text auf Bildern erkennen, damit die Suche ihn findet und „Text aus Bild“ sofort geht.
    func erkenne(_ id: String, danachKopieren: Bool = false) {
        guard let e = verlauf.eintrag(id), e.art == .bild, let url = verlauf.bildURL(e) else { return }
        if e.erkannt == true { if danachKopieren { kopiereErkannt(e) }; return }
        if danachKopieren { wartendeKopie = id; zeigeHinweis("Text wird erkannt …", dauer: 30) }
        if erkennungLaeuft.contains(id) { return }
        erkennungLaeuft.insert(id)
        let arbeit = {
            let text = (try? Verlauf.erkenneText(url)) ?? ""
            DispatchQueue.main.async {
                self.erkennungLaeuft.remove(id)
                self.verlauf.setzeErkannt(id, text)
                if self.wartendeKopie == id, let e = self.verlauf.eintrag(id) { self.wartendeKopie = nil; self.kopiereErkannt(e) }
                else if self.panel.isVisible, self.aktuell?.id == id { self.zeigeVorschau() }
            }
        }
        if danachKopieren { DispatchQueue.global(qos: .userInitiated).async(execute: arbeit) } else { erkennung.async(execute: arbeit) }
    }

    func kopiereErkannt(_ e: Eintrag) {
        guard let t = e.text, !t.isEmpty else { zeigeHinweis("Auf dem Bild ist kein Text zu erkennen."); return }
        let pb = NSPasteboard.general
        pb.clearContents(); pb.setString(t, forType: .string)
        letzterStand = pb.changeCount
        let neu = verlauf.aufnehmen(.text(t), app: "Text aus Bild", bundle: nil)
        reiter.selectedSegment = 0; suche.stringValue = ""
        aktualisiereListe(waehle: neu?.id)
        zeigeHinweis("Text erkannt und kopiert (\(zahl(t.count)) Zeichen). ↵ fügt ihn ein.")
    }

    // MARK: Aufbau

    func baueFenster() {
        let groesse = NSSize(width: speicher.object(forKey: "breite") as? Double ?? 800, height: speicher.object(forKey: "hoehe") as? Double ?? 470)
        panel = Panel(contentRect: NSRect(origin: .zero, size: groesse),
                      styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for art in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { panel.standardWindowButton(art)?.isHidden = true }
        panel.appearance = NSAppearance(named: .aqua) // immer hell, wie das Design-System
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        panel.minSize = NSSize(width: 760, height: 380)
        panel.delegate = self
        panel.beiEsc = { [weak self] in self?.esc() }
        panel.beiTaste = { [weak self] e in self?.kuerzel(e) ?? false }

        let flaeche = Flaeche()
        panel.contentView = flaeche

        // Kopfzeile: Suche · Reiter · Zahnrad
        suche = NSSearchField()
        suche.placeholderString = "Suchen, auch Text auf Bildern"
        suche.delegate = self; suche.sendsSearchStringImmediately = true
        suche.translatesAutoresizingMaskIntoConstraints = false
        reiter = NSSegmentedControl(labels: ["Verlauf", "Angeheftet", "Bilder"], trackingMode: .selectOne, target: self, action: #selector(reiterGewechselt))
        reiter.selectedSegment = 0
        reiter.translatesAutoresizingMaskIntoConstraints = false
        reiter.toolTip = "Reiter wechseln mit ⇥"
        let zahnrad = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Einstellungen")!, target: self, action: #selector(zeigeZahnradMenue(_:)))
        zahnrad.isBordered = false; zahnrad.contentTintColor = tinte3; zahnrad.toolTip = "Einstellungen"
        zahnrad.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        zahnrad.translatesAutoresizingMaskIntoConstraints = false

        // Liste links
        liste = NSTableView()
        liste.headerView = nil; liste.backgroundColor = .clear; liste.rowHeight = 46
        liste.addTableColumn(NSTableColumn(identifier: .init("e")))
        liste.dataSource = self; liste.delegate = self
        liste.style = .plain; liste.intercellSpacing = NSSize(width: 0, height: 2)
        liste.refusesFirstResponder = true // Tippen geht immer in die Suche
        liste.target = self; liste.doubleAction = #selector(einfuegenAusListe)
        let zeilenMenue = NSMenu(); zeilenMenue.delegate = self; liste.menu = zeilenMenue
        let listenRahmen = NSScrollView(); listenRahmen.documentView = liste; listenRahmen.drawsBackground = false
        listenRahmen.hasVerticalScroller = true; listenRahmen.autohidesScrollers = true
        listenRahmen.translatesAutoresizingMaskIntoConstraints = false
        leer = NSTextField(wrappingLabelWithString: "")
        leer.font = .systemFont(ofSize: 12); leer.textColor = tinte4; leer.alignment = .center
        leer.translatesAutoresizingMaskIntoConstraints = false

        // Vorschau rechts
        karte = Karte(); karte.translatesAutoresizingMaskIntoConstraints = false
        vorschauRahmen = NSScrollView(); vorschauRahmen.drawsBackground = false
        vorschauRahmen.hasVerticalScroller = true; vorschauRahmen.autohidesScrollers = true
        vorschauRahmen.translatesAutoresizingMaskIntoConstraints = false
        vorschauText = NSTextView(frame: .zero)
        vorschauText.isEditable = false; vorschauText.isSelectable = true; vorschauText.isRichText = false
        vorschauText.drawsBackground = false
        vorschauText.font = .systemFont(ofSize: 13); vorschauText.textColor = tinte1
        vorschauText.textContainerInset = NSSize(width: 10, height: 10)
        vorschauText.isVerticallyResizable = true; vorschauText.isHorizontallyResizable = false
        vorschauText.autoresizingMask = [.width]; vorschauText.textContainer?.widthTracksTextView = true
        vorschauRahmen.documentView = vorschauText
        vorschauBild = NSImageView(); vorschauBild.imageScaling = .scaleProportionallyDown
        vorschauBild.translatesAutoresizingMaskIntoConstraints = false
        vorschauBild.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        vorschauBild.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        karte.addSubview(vorschauRahmen); karte.addSubview(vorschauBild)

        info = NSTextField(labelWithString: "")
        info.font = .systemFont(ofSize: 11); info.textColor = tinte3; info.lineBreakMode = .byTruncatingTail
        info.translatesAutoresizingMaskIntoConstraints = false
        info.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        einfuegenKnopf = NSButton(title: "Einfügen  ↵", target: self, action: #selector(einfuegenKlick))
        einfuegenKnopf.bezelStyle = .push; einfuegenKnopf.bezelColor = blau; einfuegenKnopf.controlSize = .regular
        einfuegenKnopf.toolTip = "In das Fenster einfügen, in dem du gerade warst (↵). Nur kopieren: ⌘↵"
        einfuegenKnopf.translatesAutoresizingMaskIntoConstraints = false
        pinKnopf = aktionsKnopf("pin", "Anheften", "Anheften: bleibt für immer, auch beim Leeren (⌘P)", self, #selector(anheftenUmschalten))
        ocrKnopf = aktionsKnopf("text.viewfinder", "Text aus Bild", "Den Text auf dem Bild erkennen und kopieren (⌘T)", self, #selector(textAusBild))
        inboxKnopf = aktionsKnopf("tray.and.arrow.down", "Inbox", "Als Datei in deinen Inbox-Ordner legen (⌘I)", self, #selector(inDieInbox))
        loeschKnopf = aktionsKnopf("trash", "Löschen", "Aus dem Verlauf löschen (⌘⌫)", self, #selector(loeschen))
        knopfReihe = NSStackView(views: [einfuegenKnopf, NSView(), pinKnopf, ocrKnopf, inboxKnopf, loeschKnopf])
        knopfReihe.orientation = .horizontal; knopfReihe.spacing = 10
        knopfReihe.translatesAutoresizingMaskIntoConstraints = false

        // Fußzeile
        hinweis = NSTextField(labelWithString: "")
        hinweis.font = .systemFont(ofSize: 11); hinweis.lineBreakMode = .byTruncatingTail
        hinweis.translatesAutoresizingMaskIntoConstraints = false

        let oben = linieView(), mitte = linieView(), unten = linieView()
        for v in [suche!, reiter!, zahnrad, oben, listenRahmen, leer!, mitte, karte!, info!, knopfReihe!, unten, hinweis!] as [NSView] { flaeche.addSubview(v) }
        let listenBreite: CGFloat = 300
        NSLayoutConstraint.activate([
            suche.topAnchor.constraint(equalTo: flaeche.topAnchor, constant: 14),
            suche.leadingAnchor.constraint(equalTo: flaeche.leadingAnchor, constant: 14),
            suche.heightAnchor.constraint(equalToConstant: 26),
            reiter.leadingAnchor.constraint(equalTo: suche.trailingAnchor, constant: 12),
            reiter.centerYAnchor.constraint(equalTo: suche.centerYAnchor),
            zahnrad.leadingAnchor.constraint(equalTo: reiter.trailingAnchor, constant: 10),
            zahnrad.trailingAnchor.constraint(equalTo: flaeche.trailingAnchor, constant: -14),
            zahnrad.centerYAnchor.constraint(equalTo: suche.centerYAnchor),
            zahnrad.widthAnchor.constraint(equalToConstant: 22),

            oben.topAnchor.constraint(equalTo: suche.bottomAnchor, constant: 12),
            oben.leadingAnchor.constraint(equalTo: flaeche.leadingAnchor), oben.trailingAnchor.constraint(equalTo: flaeche.trailingAnchor),
            oben.heightAnchor.constraint(equalToConstant: 1),

            listenRahmen.topAnchor.constraint(equalTo: oben.bottomAnchor, constant: 6),
            listenRahmen.leadingAnchor.constraint(equalTo: flaeche.leadingAnchor),
            listenRahmen.widthAnchor.constraint(equalToConstant: listenBreite),
            listenRahmen.bottomAnchor.constraint(equalTo: unten.topAnchor, constant: -6),
            leer.centerYAnchor.constraint(equalTo: listenRahmen.centerYAnchor, constant: -20),
            leer.leadingAnchor.constraint(equalTo: listenRahmen.leadingAnchor, constant: 28),
            leer.trailingAnchor.constraint(equalTo: listenRahmen.trailingAnchor, constant: -28),

            mitte.topAnchor.constraint(equalTo: oben.bottomAnchor), mitte.bottomAnchor.constraint(equalTo: unten.topAnchor),
            mitte.leadingAnchor.constraint(equalTo: listenRahmen.trailingAnchor), mitte.widthAnchor.constraint(equalToConstant: 1),

            karte.topAnchor.constraint(equalTo: oben.bottomAnchor, constant: 14),
            karte.leadingAnchor.constraint(equalTo: mitte.trailingAnchor, constant: 14),
            karte.trailingAnchor.constraint(equalTo: flaeche.trailingAnchor, constant: -14),
            karte.bottomAnchor.constraint(equalTo: info.topAnchor, constant: -8),
            vorschauRahmen.topAnchor.constraint(equalTo: karte.topAnchor, constant: 1),
            vorschauRahmen.bottomAnchor.constraint(equalTo: karte.bottomAnchor, constant: -1),
            vorschauRahmen.leadingAnchor.constraint(equalTo: karte.leadingAnchor, constant: 1),
            vorschauRahmen.trailingAnchor.constraint(equalTo: karte.trailingAnchor, constant: -1),
            vorschauBild.topAnchor.constraint(equalTo: karte.topAnchor, constant: 10),
            vorschauBild.bottomAnchor.constraint(equalTo: karte.bottomAnchor, constant: -10),
            vorschauBild.leadingAnchor.constraint(equalTo: karte.leadingAnchor, constant: 10),
            vorschauBild.trailingAnchor.constraint(equalTo: karte.trailingAnchor, constant: -10),

            info.leadingAnchor.constraint(equalTo: karte.leadingAnchor, constant: 2),
            info.trailingAnchor.constraint(equalTo: karte.trailingAnchor),
            info.bottomAnchor.constraint(equalTo: knopfReihe.topAnchor, constant: -10),
            knopfReihe.leadingAnchor.constraint(equalTo: karte.leadingAnchor),
            knopfReihe.trailingAnchor.constraint(equalTo: karte.trailingAnchor),
            knopfReihe.bottomAnchor.constraint(equalTo: unten.topAnchor, constant: -12),
            knopfReihe.heightAnchor.constraint(equalToConstant: 28),

            unten.leadingAnchor.constraint(equalTo: flaeche.leadingAnchor), unten.trailingAnchor.constraint(equalTo: flaeche.trailingAnchor),
            unten.heightAnchor.constraint(equalToConstant: 1),
            unten.bottomAnchor.constraint(equalTo: flaeche.bottomAnchor, constant: -30),
            hinweis.leadingAnchor.constraint(equalTo: flaeche.leadingAnchor, constant: 16),
            hinweis.trailingAnchor.constraint(equalTo: flaeche.trailingAnchor, constant: -16),
            hinweis.centerYAnchor.constraint(equalTo: flaeche.bottomAnchor, constant: -15),
        ])
        standardHinweis()
    }

    func baueMenueleiste() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let bild = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "Hikidashi")!
        bild.isTemplate = true
        statusItem.button?.image = bild
        statusItem.button?.toolTip = "Hikidashi: Zwischenablage (⌃⌥V). Rechtsklick für Einstellungen."
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusGeklickt)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.appearsDisabled = pausiert
    }

    func einstellungsMenue() -> NSMenu {
        let m = NSMenu()
        func eintrag(_ titel: String, _ aktion: Selector, an: Bool? = nil) {
            let e = NSMenuItem(title: titel, action: aktion, keyEquivalent: ""); e.target = self
            if let an { e.state = an ? .on : .off }
            m.addItem(e)
        }
        eintrag("Verlauf öffnen (⌃⌥V)", #selector(oeffneVonMenue))
        m.addItem(.separator())
        eintrag("Direkt einfügen", #selector(direktUmschalten), an: direktEinfuegen)
        if direktEinfuegen && !AXIsProcessTrusted() { eintrag("Freigabe fürs direkte Einfügen …", #selector(frageFreigabe)) }
        eintrag("Pausieren", #selector(pauseUmschalten), an: pausiert)
        eintrag("Beim Anmelden starten", #selector(autostart), an: SMAppService.mainApp.status == .enabled)
        m.addItem(.separator())
        eintrag("Verlauf leeren …", #selector(leeren))
        eintrag("Ablage im Finder zeigen", #selector(zeigeAblage))
        eintrag(inboxOrdner.map { "Inbox-Ordner: \($0.lastPathComponent) …" } ?? "Inbox-Ordner wählen …", #selector(inboxWaehlen))
        m.addItem(.separator())
        let ende = NSMenuItem(title: "Hikidashi beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        m.addItem(ende)
        return m
    }

    // MARK: Zeigen und Verstecken

    @objc func statusGeklickt() {
        let ev = NSApp.currentEvent
        if ev?.type == .rightMouseUp || ev?.modifierFlags.contains(.control) == true || ev?.modifierFlags.contains(.option) == true {
            statusItem.menu = einstellungsMenue()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }
        if panel.isVisible { verstecke() }
        else if Date().timeIntervalSince(verstecktUm) > 0.3 { zeige(beiMaus: false) }
    }

    @objc func oeffneVonMenue() { zeige(beiMaus: false) }

    func umschalten() { if panel.isVisible && panel.isKeyWindow { verstecke() } else { zeige(beiMaus: true) } }

    func zeige(beiMaus: Bool) {
        if let vorne = NSWorkspace.shared.frontmostApplication, vorne != .current { vorher = vorne }
        suche.stringValue = ""
        reiter.selectedSegment = 0
        aktualisiereListe(waehle: nil, oben: true)
        standardHinweis()
        positioniere(beiMaus: beiMaus)
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(suche)
    }

    func positioniere(beiMaus: Bool) {
        let g = panel.frame.size
        let maus = NSEvent.mouseLocation
        var p: NSPoint
        if !beiMaus, let knopf = statusItem.button, let f = knopf.window {
            let r = f.convertToScreen(knopf.convert(knopf.bounds, to: nil))
            p = NSPoint(x: r.midX - g.width / 2, y: r.minY - g.height - 6)
        } else {
            p = NSPoint(x: maus.x - 40, y: maus.y - g.height + 30)
        }
        let schirm = NSScreen.screens.first { NSMouseInRect(maus, $0.frame, false) } ?? NSScreen.main
        if let v = schirm?.visibleFrame {
            p.x = min(max(p.x, v.minX + 8), v.maxX - g.width - 8)
            p.y = min(max(p.y, v.minY + 8), v.maxY - g.height - 8)
        }
        panel.setFrameOrigin(p)
    }

    @objc func verstecke() { verstecke(zurueck: true) }

    func verstecke(zurueck: Bool) {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        verstecktUm = Date()
        if zurueck { vorher?.activate() }
    }

    func windowDidResignKey(_ notification: Notification) {
        if !App.probe { verstecke(zurueck: false) } // Klick daneben: zu
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        speicher.set(Double(panel.frame.width), forKey: "breite"); speicher.set(Double(panel.frame.height), forKey: "hoehe")
    }

    func esc() {
        if !suche.stringValue.isEmpty { suche.stringValue = ""; aktualisiereListe(waehle: nil, oben: true) } else { verstecke() }
    }

    // MARK: Liste

    func aktualisiereListe(waehle id: String? = nil, oben: Bool = false) {
        let vorherId = oben ? nil : (id ?? aktuell?.id)
        treffer = verlauf.liste(reiter: reiter.selectedSegment, suche: suche.stringValue)
        liste.reloadData()
        let i = vorherId.flatMap { v in treffer.firstIndex { $0.id == v } } ?? (treffer.isEmpty ? -1 : 0)
        if i >= 0 { liste.selectRowIndexes([i], byExtendingSelection: false); liste.scrollRowToVisible(i) }
        else { liste.deselectAll(nil) }
        leer.isHidden = !treffer.isEmpty
        if !suche.stringValue.trimmingCharacters(in: .whitespaces).isEmpty { leer.stringValue = "Nichts gefunden." }
        else {
            switch reiter.selectedSegment {
            case 1: leer.stringValue = "Noch nichts angeheftet.\n\nWähl einen Eintrag und drück ⌘P. Angeheftetes bleibt für immer, gut für Signatur, Links und Adressen."
            case 2: leer.stringValue = "Noch keine Bilder.\n\nTipp: ⌘⇧⌃4 legt einen Bildschirmausschnitt direkt in die Zwischenablage."
            default: leer.stringValue = "Noch nichts kopiert.\n\nAlles, was du ab jetzt kopierst, landet hier."
            }
        }
        zeigeVorschau()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { treffer.count }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { Zeile() }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let z = (tableView.makeView(withIdentifier: .init("z"), owner: nil) as? Zelle) ?? Zelle()
        let e = treffer[row]
        z.symbol.contentTintColor = tinte4
        z.symbol.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        var art: String
        switch e.art {
        case .text:
            z.symbol.imageScaling = .scaleNone
            z.symbol.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
            z.titel.stringValue = ersteZeile(e.text) ?? "(Leerzeichen)"
            art = "\(zahl(e.text?.count ?? 0)) Zeichen"
        case .bild:
            z.symbol.imageScaling = .scaleProportionallyUpOrDown
            z.symbol.image = miniatur(e)
            z.titel.stringValue = ersteZeile(e.text) ?? "Bild"
            art = "Bild \(e.breite ?? 0) × \(e.hoehe ?? 0)"
        case .datei:
            z.symbol.imageScaling = .scaleProportionallyUpOrDown
            let pfade = e.dateien ?? []
            z.symbol.image = pfade.first.map { NSWorkspace.shared.icon(forFile: $0) }
            let name = pfade.first.map { ($0 as NSString).lastPathComponent } ?? "Datei"
            z.titel.stringValue = pfade.count > 1 ? "\(name) + \(pfade.count - 1) weitere" : name
            art = pfade.count > 1 ? "\(pfade.count) Dateien" : "Datei"
        }
        z.meta.stringValue = [art, e.app, wann(e.zeit)].compactMap { $0 }.joined(separator: " · ")
        z.nummer.stringValue = row < 9 ? "⌘\(row + 1)" : ""
        z.punkt.isHidden = !e.angeheftet
        z.toolTip = e.angeheftet ? "Angeheftet" : nil
        return z
    }

    func miniatur(_ e: Eintrag) -> NSImage? {
        if let b = bildCache[e.id] { return b }
        guard let url = verlauf.bildURL(e), let b = vorschaubild(url, 96) else { return nil }
        bildCache[e.id] = b
        return b
    }

    func tableViewSelectionDidChange(_ notification: Notification) { zeigeVorschau() }

    func zeigeVorschau() {
        guard let e = aktuell else {
            karte.isHidden = true; knopfReihe.isHidden = true; info.stringValue = ""
            return
        }
        karte.isHidden = false; knopfReihe.isHidden = false
        var teile: [String] = []
        if let app = e.app { teile.append("Aus \(app)") }
        teile.append(wann(e.zeit))
        switch e.art {
        case .text:
            zeigeText(e.text ?? "")
            let t = e.text ?? ""
            teile.append("\(zahl(t.count)) Zeichen")
            let zeilen = t.split(whereSeparator: \.isNewline).count
            if zeilen > 1 { teile.append("\(zahl(zeilen)) Zeilen") }
        case .bild:
            zeigeBild(verlauf.bildURL(e).flatMap { NSImage(contentsOf: $0) })
            teile.append("\(e.breite ?? 0) × \(e.hoehe ?? 0) Pixel")
            if e.erkannt == true { teile.append(e.text == nil ? "kein Text darauf" : "Text erkannt") }
            else if erkennungLaeuft.contains(e.id) { teile.append("Text wird erkannt …") }
        case .datei:
            let pfade = e.dateien ?? []
            if pfade.count == 1, bildEndungen.contains((pfade[0] as NSString).pathExtension.lowercased()), let b = NSImage(contentsOfFile: pfade[0]) {
                zeigeBild(b)
            } else {
                zeigeText(pfade.map { "\(($0 as NSString).lastPathComponent)\n    \(($0 as NSString).deletingLastPathComponent)" }.joined(separator: "\n\n"))
            }
            let fehlen = pfade.filter { !FileManager.default.fileExists(atPath: $0) }.count
            teile.append(pfade.count == 1 ? "1 Datei" : "\(pfade.count) Dateien")
            if fehlen > 0 { teile.append("\(fehlen) gibt es nicht mehr") }
        }
        if e.angeheftet { teile.append("angeheftet") }
        info.stringValue = teile.joined(separator: " · ")
        pinKnopf.title = e.angeheftet ? "Lösen" : "Anheften"
        pinKnopf.image = NSImage(systemSymbolName: e.angeheftet ? "pin.slash" : "pin", accessibilityDescription: nil)
        ocrKnopf.isHidden = e.art != .bild
    }

    func zeigeText(_ t: String) {
        vorschauBild.isHidden = true; vorschauRahmen.isHidden = false
        let kurz = t.count > 60_000 ? String(t.prefix(60_000)) + "\n\n… (gekürzt angezeigt, eingefügt wird alles)" : t
        vorschauText.string = kurz
        vorschauText.scroll(.zero)
    }

    func zeigeBild(_ b: NSImage?) {
        vorschauRahmen.isHidden = true; vorschauBild.isHidden = false
        vorschauBild.image = b
    }

    // MARK: Tasten

    func control(_ control: NSControl, textView: NSTextView, doCommandBy befehl: Selector) -> Bool {
        let zeile = liste.selectedRow
        switch befehl {
        case #selector(NSResponder.moveDown(_:)):
            let n = min(zeile + 1, treffer.count - 1)
            if n >= 0 { liste.selectRowIndexes([n], byExtendingSelection: false); liste.scrollRowToVisible(n) }
            return true
        case #selector(NSResponder.moveUp(_:)):
            let n = max(zeile - 1, 0)
            if !treffer.isEmpty { liste.selectRowIndexes([n], byExtendingSelection: false); liste.scrollRowToVisible(n) }
            return true
        case #selector(NSResponder.insertNewline(_:)):
            if let e = aktuell { uebernehmen(e, einfuegen: true) }
            return true
        case #selector(NSResponder.insertTab(_:)):
            reiter.selectedSegment = (reiter.selectedSegment + 1) % 3; reiterGewechselt(); return true
        case #selector(NSResponder.insertBacktab(_:)):
            reiter.selectedSegment = (reiter.selectedSegment + 2) % 3; reiterGewechselt(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            esc(); return true
        default:
            return false
        }
    }

    func controlTextDidChange(_ obj: Notification) { aktualisiereListe(waehle: nil, oben: true) }

    /// ⌘-Kürzel im Fenster. false heißt: normal weiterreichen (z. B. ⌘C auf markiertem Text).
    func kuerzel(_ e: NSEvent) -> Bool {
        let taste = e.charactersIgnoringModifiers?.lowercased() ?? ""
        let markiert = ((panel.firstResponder as? NSTextView)?.selectedRange().length ?? 0) > 0
        if let n = Int(taste), (1...9).contains(n) {
            if n <= treffer.count { uebernehmen(treffer[n - 1], einfuegen: true) }
            return true
        }
        switch taste {
        case "p": anheftenUmschalten(); return true
        case "t": textAusBild(); return true
        case "i": inDieInbox(); return true
        case "f": panel.makeFirstResponder(suche); return true
        case "\r": nurKopieren(); return true
        case "c" where !markiert: nurKopieren(); return true
        default: break
        }
        if e.keyCode == UInt16(kVK_Delete), suche.stringValue.isEmpty { loeschen(); return true }
        return false
    }

    // MARK: Aktionen

    @objc func reiterGewechselt() { aktualisiereListe(waehle: nil, oben: true) }
    @objc func einfuegenKlick() { if let e = aktuell { uebernehmen(e, einfuegen: true) } }
    @objc func einfuegenAusListe() { if liste.clickedRow >= 0 { uebernehmen(treffer[liste.clickedRow], einfuegen: true) } }
    @objc func nurKopieren() { if let e = aktuell { uebernehmen(e, einfuegen: false) } }

    /// Legt den Eintrag in die Zwischenablage, schließt das Fenster und fügt (mit Freigabe) direkt ein.
    func uebernehmen(_ e: Eintrag, einfuegen: Bool) {
        let pb = NSPasteboard.general
        verlauf.schreibe(e, auf: pb)
        letzterStand = pb.changeCount
        verlauf.benutzt(e.id)
        verstecke()
        guard einfuegen, direktEinfuegen, !App.probe else { return }
        guard AXIsProcessTrusted() else {
            if !speicher.bool(forKey: "freigabeGefragt") { speicher.set(true, forKey: "freigabeGefragt"); frageFreigabe() }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { App.drueckeEinfuegen() }
    }

    /// Schickt ⌘V an das Fenster vorne. Braucht die Freigabe unter Bedienungshilfen.
    static func drueckeEinfuegen() {
        let quelle = CGEventSource(stateID: .combinedSessionState)
        for unten in [true, false] {
            let ev = CGEvent(keyboardEventSource: quelle, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: unten)
            ev?.flags = .maskCommand
            ev?.post(tap: .cghidEventTap)
        }
    }

    @objc func frageFreigabe() {
        let optionen = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(optionen)
    }

    @objc func anheftenUmschalten() {
        guard let e = aktuell else { return }
        verlauf.anheften(e.id, !e.angeheftet)
        aktualisiereListe(waehle: e.id)
        zeigeHinweis(e.angeheftet ? "Gelöst. Der Eintrag ist jetzt wieder normaler Verlauf." : "Angeheftet. Bleibt für immer, auch beim Leeren. Alles Angeheftete steht im Reiter Angeheftet.")
    }

    @objc func textAusBild() {
        guard let e = aktuell else { return }
        guard e.art == .bild else { zeigeHinweis("Text aus Bild geht nur bei Bildern."); return }
        erkenne(e.id, danachKopieren: true)
    }

    @objc func inDieInbox() {
        guard let e = aktuell else { return }
        guard let ordner = inboxOrdner ?? waehleInboxOrdner() else { return }
        do {
            let ziele = try Verlauf.inDieInbox(e, verlauf: verlauf, inbox: ordner)
            zeigeHinweis("In der Inbox: " + ziele.map(\.lastPathComponent).joined(separator: ", "))
        } catch { zeigeHinweis(error.localizedDescription) }
    }

    @objc func loeschen() {
        guard let e = aktuell else { return }
        let zeile = liste.selectedRow
        verlauf.loeschen(e.id); bildCache[e.id] = nil
        treffer = verlauf.liste(reiter: reiter.selectedSegment, suche: suche.stringValue)
        let n = min(zeile, treffer.count - 1)
        aktualisiereListe(waehle: n >= 0 ? treffer[n].id : nil)
        zeigeHinweis("Gelöscht.")
    }

    // MARK: Einstellungen

    @objc func zeigeZahnradMenue(_ knopf: NSButton) {
        einstellungsMenue().popUp(positioning: nil, at: NSPoint(x: 0, y: knopf.bounds.height + 4), in: knopf)
    }

    @objc func direktUmschalten() {
        direktEinfuegen.toggle()
        if direktEinfuegen && !AXIsProcessTrusted() { frageFreigabe() }
        standardHinweis()
    }

    @objc func pauseUmschalten() { pausiert.toggle(); standardHinweis() }

    @objc func autostart() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch { meldung("Autostart ließ sich nicht ändern: \(error.localizedDescription)") }
    }

    @objc func leeren() {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = "Verlauf leeren?"
        a.informativeText = "Alles außer den angehefteten Einträgen wird gelöscht."
        a.addButton(withTitle: "Leeren"); a.addButton(withTitle: "Abbrechen")
        if a.runModal() == .alertFirstButtonReturn { verlauf.leeren(); bildCache.removeAll() }
    }

    @objc func zeigeAblage() { NSWorkspace.shared.activateFileViewerSelecting([verlauf.datei]) }

    @objc func inboxWaehlen() { _ = waehleInboxOrdner() }

    /// Fragt nach dem Ordner, in den ⌘I Einträge als Datei legt, und merkt ihn sich.
    func waehleInboxOrdner() -> URL? {
        NSApp.activate(ignoringOtherApps: true)
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false; p.canCreateDirectories = true
        p.message = "In welchen Ordner soll Hikidashi Einträge als Datei legen (⌘I)?"
        p.prompt = "Wählen"
        if let v = inboxOrdner { p.directoryURL = v }
        guard p.runModal() == .OK, let url = p.url else { return nil }
        speicher.set(url.path, forKey: "inbox")
        zeigeHinweis("Inbox-Ordner: " + url.path)
        return url
    }

    // MARK: Hinweise

    func standardHinweis() {
        hinweisTimer?.invalidate()
        if pausiert {
            hinweis.textColor = farbe(0xEF4861); hinweis.stringValue = "Pausiert: Neues wird gerade nicht aufgenommen. Zahnrad → Pausieren."
        } else if direktEinfuegen && !AXIsProcessTrusted() && !App.probe {
            hinweis.textColor = tinte3; hinweis.stringValue = "↵ kopiert. Damit ↵ auch direkt einfügt: Zahnrad → Freigabe fürs direkte Einfügen."
        } else {
            hinweis.textColor = tinte4
            hinweis.stringValue = "↵ einfügen   ⌘1–9 direkt   ⌘↵ nur kopieren   ⌘P anheften   ⌘T Text aus Bild   ⌘I Inbox   ⇥ Reiter   esc zu"
        }
    }

    func zeigeHinweis(_ text: String, dauer: TimeInterval = 4) {
        hinweisTimer?.invalidate()
        hinweis.textColor = blau; hinweis.stringValue = text
        hinweisTimer = Timer.scheduledTimer(withTimeInterval: dauer, repeats: false) { [weak self] _ in self?.standardHinweis() }
    }

    func meldung(_ inhalt: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert(); a.messageText = "Hikidashi"; a.informativeText = inhalt; a.runModal()
    }

    // MARK: Rechtsklick auf einen Eintrag

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let r = liste.clickedRow
        guard r >= 0, r < treffer.count else { return }
        liste.selectRowIndexes([r], byExtendingSelection: false)
        let e = treffer[r]
        func eintrag(_ titel: String, _ aktion: Selector) { let i = NSMenuItem(title: titel, action: aktion, keyEquivalent: ""); i.target = self; menu.addItem(i) }
        eintrag("Einfügen", #selector(einfuegenKlick))
        eintrag("Nur kopieren", #selector(nurKopieren))
        menu.addItem(.separator())
        eintrag(e.angeheftet ? "Lösen" : "Anheften", #selector(anheftenUmschalten))
        if e.art == .bild { eintrag("Text aus Bild", #selector(textAusBild)) }
        eintrag("In die Inbox", #selector(inDieInbox))
        if e.art != .text { eintrag("Im Finder zeigen", #selector(imFinder)) }
        menu.addItem(.separator())
        eintrag("Löschen", #selector(loeschen))
    }

    @objc func imFinder() {
        guard let e = aktuell else { return }
        let urls = e.art == .bild ? [verlauf.bildURL(e)].compactMap { $0 } : (e.dateien ?? []).map { URL(fileURLWithPath: $0) }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    // MARK: Tastenkombination

    func registriereTaste() -> Bool {
        var art = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { App.shared.umschalten() }; return noErr
        }, 1, &art, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x48494B49), id: 1) // "HIKI"
        return RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &tastenRef) == noErr
    }

    // MARK: Probelauf

    /// Nur zum Prüfen: `--daten <ordner> --schnappschuss bild.png [--test-demo] [--test-suche S] [--test-reiter N] [--test-zeile N]`
    /// zeigt das Fenster mit einem Wegwerf-Verlauf, speichert ein Bild davon und beendet sich.
    func probelauf() {
        let args = CommandLine.arguments
        func wert(_ name: String) -> String? { args.firstIndex(of: name).flatMap { args.count > $0 + 1 ? args[$0 + 1] : nil } }
        if args.contains("--test-demo") { demoDaten(verlauf) }
        zeige(beiMaus: false)
        panel.center()
        if let r = wert("--test-reiter").flatMap(Int.init) { reiter.selectedSegment = r; reiterGewechselt() }
        if let s = wert("--test-suche") { suche.stringValue = s; aktualisiereListe(waehle: nil, oben: true) }
        if let z = wert("--test-zeile").flatMap(Int.init), z < treffer.count { liste.selectRowIndexes([z], byExtendingSelection: false) }
        if let h = wert("--test-hinweis") { zeigeHinweis(h) }
        let ziel = wert("--schnappschuss")!
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let v = self.panel.contentView!
            if let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                v.cacheDisplay(in: v.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: ziel))
            }
            NSApp.terminate(nil)
        }
    }
}

// MARK: Start

/// Inbox-Ordner, den der Bau vorbelegt hat (`--inbox <ordner>` geht vor). Ohne Vorgabe fragt die App beim ersten ⌘I.
func findeInboxVorgabe() -> URL? {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--inbox"), args.count > i + 1 { return URL(fileURLWithPath: args[i + 1]) }
    guard let url = Bundle.main.url(forResource: "inbox-ordner", withExtension: "txt"),
          let pfad = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    let ordner = URL(fileURLWithPath: pfad.trimmingCharacters(in: .whitespacesAndNewlines))
    return FileManager.default.fileExists(atPath: ordner.path) ? ordner : nil
}

let argumente = CommandLine.arguments
if argumente.contains("--self-test") {
    do { try selbsttest(); print("Hikidashi: Selbsttest bestanden") }
    catch { fputs("Hikidashi: \(error.localizedDescription)\n", stderr); exit(1) }
    exit(0)
}
if !App.probe, let id = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != .current }) {
    exit(0) // läuft schon, sonst würden zwei Hikidashis denselben Verlauf schreiben
}
let datenOrdner = argumente.firstIndex(of: "--daten").flatMap { argumente.count > $0 + 1 ? URL(fileURLWithPath: argumente[$0 + 1]) : nil } ?? Verlauf.standardOrdner
let delegate = App(verlauf: Verlauf(ordner: datenOrdner), inboxVorgabe: findeInboxVorgabe())
App.shared = delegate
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
