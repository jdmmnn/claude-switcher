# Claude Switcher

Kleine macOS-Menüleisten-App, um mehrere Claude-Desktop-Instanzen (z. B. privat und Arbeit) getrennt nebeneinander zu betreiben.

> Inoffizielles Projekt, nicht mit Anthropic verbunden und nicht von Anthropic unterstützt. „Claude“ ist eine Marke von Anthropic.

Jedes Profil ist die normale Claude-App, gestartet mit einem eigenen `--user-data-dir` ([Hintergrund](https://philippstracker.com/multiple-claude-instances/)). Vorbild für die Bedienung: [claudeswitch.dev](https://claudeswitch.dev/).

## Voraussetzungen

- macOS 15 oder neuer
- Claude Desktop
- Xcode Command Line Tools (`xcode-select --install`)

## Bauen und installieren

```bash
bash ClaudeSwitcher/build.sh
```

Die App landet in `~/Applications/Claude Switcher.app`. Eine bereits laufende Version vorher beenden und danach neu öffnen.

## Bedienung

Die App hat kein Dock-Symbol. In der Menüleiste steht je laufender Instanz ein Punkt in der Profilfarbe:

- ausgefüllt: Instanz ist vorne
- Ring: Instanz läuft im Hintergrund oder ist ausgeblendet
- Personen-Symbol: keine Instanz läuft

Ein Klick auf ein Profil im Menü startet es oder holt es nach vorne. Ist es bereits vorne, wird es ausgeblendet (läuft aber weiter).

Über „Profile verwalten…“ lassen sich Profile anlegen, umbenennen, umfärben, beenden und aus der Liste entfernen.

## Daten

| Was | Wo |
|---|---|
| Profilliste | `~/Library/Application Support/ClaudeSwitcher/profiles.json` |
| Standardprofil (bestehende Installation) | `~/Library/Application Support/Claude` |
| Weitere Profile | `~/.claude-instances/<name>` |

Beim Entfernen eines Profils bleibt sein Datenordner erhalten.

## Einschränkungen

- Beim ersten Login eines Profils die anderen Instanzen beenden, sonst kann der Login-Link im falschen Fenster landen.
- Getrennt wird nur der Datenordner von Claude Desktop. `~/.claude` (Claude Code: Einstellungen, Skills, Memory) wird von der App nicht pro Profil getrennt.
- Alle Instanzen haben im Dock dasselbe Claude-Icon.
- Kein automatischer Start bei der Anmeldung; bei Bedarf unter Systemeinstellungen → Allgemein → Anmeldeobjekte hinzufügen.

## Dateien

| Datei | Inhalt |
|---|---|
| `ClaudeSwitcher/main.swift` | App und Oberfläche |
| `ClaudeSwitcher/badges.swift` | Punkte in der Menüleiste |
| `ClaudeSwitcher/icon.swift` | zeichnet das App-Icon |
| `ClaudeSwitcher/build.sh` | bauen, signieren (ad hoc), installieren |

## Lizenz

[MIT](LICENSE)
