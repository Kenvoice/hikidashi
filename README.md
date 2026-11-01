# Hikidashi 引き出し

Verlauf der Zwischenablage für den Mac. Alles, was du kopierst, landet in einer
Liste in der Menüleiste: Text, Bilder und Screenshots, Dateien aus dem Finder.
Mit ⌃⌥V öffnest du die Liste an der Maus, tippst ein Wort und fügst den Eintrag
mit Enter direkt ein. 引き出し (hikidashi) heißt „Schublade“.

Entstanden als Ersatz für CopyClip, mit drei Dingen, die mir dort gefehlt haben: Bilder,
Suche im Text auf Bildern und angeheftete Einträge, die nie aus dem Verlauf
fallen.

## Was die App kann

- **Verlauf:** neueste Einträge oben, sofort durchsuchbar. Pfeiltasten wählen,
  Enter fügt in das Fenster ein, in dem du gerade warst. ⌘1 bis ⌘9 fügen den
  Eintrag mit dieser Nummer sofort ein.
- **Bilder:** Screenshots und kopierte Bilder haben einen eigenen Reiter mit
  Vorschau.
- **Text aus Bild:** ⌘T erkennt den Text auf einem Bild und kopiert ihn. Das
  läuft mit Apples eigener Texterkennung auf dem Mac (Deutsch, Englisch,
  Chinesisch, Japanisch). Neue Bilder werden im Hintergrund schon gelesen,
  deshalb findet die Suche auch Wörter auf Screenshots.
- **Anheften:** ⌘P hält einen Eintrag fest. Adresse, Signatur, ein Link, den du
  oft schickst: Angeheftetes bleibt, auch wenn du den Verlauf leerst.
- **Inbox:** ⌘I legt den Eintrag als Datei in einen Ordner deiner Wahl. Text
  wird eine `.md` mit Datum im Namen, ein Bild eine `.png`, Dateien werden
  kopiert. Gedacht für einen Notiz-Eingang, etwa in Obsidian.
- **Pausieren:** nimmt nichts auf, solange du mit vertraulichen Daten arbeitest.

Alle Tasten auf einen Blick:

| Taste | Was passiert |
|---|---|
| ⌃⌥V | Verlauf öffnen |
| Enter | einfügen |
| ⌘Enter oder ⌘C | nur kopieren |
| ⌘1 bis ⌘9 | Eintrag mit dieser Nummer einfügen |
| ⌘P | anheften oder lösen |
| ⌘T | Text aus Bild kopieren |
| ⌘I | in den Inbox-Ordner legen |
| ⌘⌫ | Eintrag löschen (bei leerer Suche) |
| ⇥ | Reiter wechseln: Verlauf, Angeheftet, Bilder |
| Esc | schließen |

Klick auf das Symbol in der Menüleiste öffnet den Verlauf, Rechtsklick die
Einstellungen.

## Deine Daten bleiben auf dem Mac

Hikidashi hat keinen einzigen Netzaufruf. Nachsehen: `grep -rn "http" src/`
findet nur Beispieltexte im Selbsttest und eine Prüfung, ob ein kopierter Text
eine Webadresse ist.

Der Verlauf liegt unter `~/Library/Application Support/Hikidashi/`:

| Datei | Inhalt |
|---|---|
| `verlauf.json` | alle Einträge mit Text, Herkunft und Zeit |
| `bilder/` | die kopierten Bilder |

Das steht im Klartext in deinem Benutzerordner. Wer mit sensiblen Daten
arbeitet, sollte die Platte verschlüsseln (FileVault) und den Verlauf ab und
zu leeren.

Nicht aufgenommen wird:

- alles, was Passwort-Manager als geheim markieren, und alles, was aus
  1Password, Bitwarden, Dashlane, LastPass, KeePassXC, Apple Passwörter oder der
  Schlüsselbundverwaltung kommt
- Text über 2 MB und Bilder über 40 MB

Der Verlauf hält 300 Einträge, davon höchstens 60 Bilder. Das Älteste fällt
raus, Angeheftetes zählt nicht mit.

## Das brauchst du

- Mac mit Apple-Chip (M1 oder neuer), macOS 14 oder neuer
- die Command Line Tools von Apple. Installieren mit `xcode-select --install`
  im Terminal, falls sie noch fehlen. Xcode selbst brauchst du nicht.

## Installieren

```bash
git clone https://github.com/Kenvoice/hikidashi.git
cd hikidashi
bash build.sh
```

`build.sh` baut die App, prüft sie mit einem Selbsttest, legt sie in den Ordner
Programme und startet sie. Danach sitzt ein Schubladen-Symbol in der
Menüleiste. Mit `bash build.sh --nur-bau` wird nur gebaut, die App liegt dann in
`build/Hikidashi.app`.

### Direkt einfügen freigeben

Damit Enter wirklich einfügt, braucht Hikidashi einmal die Freigabe unter
**Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen**. macOS
fragt beim ersten Enter selbst. Die Freigabe braucht die App, weil sie für dich
⌘V drückt. Ohne Freigabe legt Enter den Eintrag nur in die Zwischenablage, und
du fügst mit ⌘V selbst ein.

Nach jedem Neubau erkennt macOS die App als neu. Fügt Enter dann nichts mehr
ein, entferne Hikidashi unter Bedienungshilfen mit „−“ und erlaube es neu.

### Inbox-Ordner

Beim ersten ⌘I fragt die App, in welchen Ordner sie ablegen soll. Ändern geht
jederzeit über das Zahnrad: **Inbox-Ordner wählen …**. Vorbelegen lässt er sich
beim Bau:

```bash
HIKIDASHI_INBOX=~/Obsidian/Inbox bash build.sh
```

### Beim Anmelden starten

Rechtsklick auf das Symbol, **Beim Anmelden starten** anhaken.

### Deinstallieren

1. Hikidashi über das Menü beenden und aus Programme löschen.
2. `~/Library/Application Support/Hikidashi` löschen, darin liegt der Verlauf.

## Aufbau

```
src/Verlauf.swift   Ablage, Zwischenablage lesen und schreiben, Texterkennung, Inbox
src/main.swift      Fenster, Menüleiste, Tasten, Einfügen
src/Test.swift      Selbsttest und Beispieldaten
src/Icon.swift      zeichnet das App-Symbol
build.sh            baut die App ohne Xcode-Projekt, nur mit swiftc
VERSION             die Versionsnummer
```

Keine Abhängigkeiten, nur Apples eigene Bibliotheken (AppKit, Vision, Carbon
für die Tastenkombination). Die App schaut zweimal pro Sekunde, ob sich die
Zwischenablage geändert hat.

Prüfen ohne Fenster: `build/Hikidashi.app/Contents/MacOS/Hikidashi --self-test`
testet Verlauf, Grenzen, Bilder, Texterkennung, Inbox und den Passwortschutz auf
einer eigenen Test-Zwischenablage. Deine echte Zwischenablage bleibt
unberührt.

Hikidashi ist mit [Claude Code](https://claude.com/claude-code) entstanden,
ohne Xcode-Projekt.

## Lizenz

MIT, siehe [LICENSE](LICENSE).

---

Gebaut von Kenzo Weiss ·
[LinkedIn](https://www.linkedin.com/in/kenzo-weiss-ki-automatisierung) ·
[YouTube](https://www.youtube.com/@Ken-Automation2)
