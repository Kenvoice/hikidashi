# Änderungen

## 1.0.0 — 2026-11-01

Erste öffentliche Fassung.

- **Verlauf** für Text, Bilder und Dateien aus dem Finder, mit Suche. ⌃⌥V öffnet
  ihn an der Maus, Enter fügt direkt ein, ⌘1 bis ⌘9 fügen sofort ein.
- **Text aus Bild** mit Apples Texterkennung, lokal. Neue Bilder werden vorab
  gelesen, damit die Suche auch Wörter auf Screenshots findet.
- **Anheften** für Einträge, die nie aus dem Verlauf fallen.
- **Inbox:** legt einen Eintrag als Datei in einen Ordner deiner Wahl. Der Ordner
  ist über das Zahnrad einstellbar und lässt sich beim Bau mit
  `HIKIDASHI_INBOX` vorbelegen.
- Passwort-Manager und als geheim markierte Inhalte werden nicht aufgenommen.
- `build.sh` liest die Version aus `VERSION` und signiert ohne
  Entwickler-Zertifikat ad hoc.
