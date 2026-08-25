# Retrospektive: Portierung von Grid Wars nach Swift

Stand: 25. August 2026

Branch: `codex/swift-port`

Letzter abgeschlossener Portierungs-Commit: `83d7f80 Verify physical iPhone touch and lifecycle`

## Kurzfazit

Die Portierung ist von einem kleinen, spielbaren Swift-Prototyp zu einer umfassend geprüften macOS-/iOS-Fassung gewachsen. Am Ende standen nicht nur kompilierender Swift-Code, sondern eine quellengestützte Fidelity-Matrix, deterministische Referenzaufnahmen, automatisierte Tests, Simulator-Builds und ein erfolgreicher Test auf einem physischen iPhone.

Das Ergebnis ist fachlich stark. Der Weg dorthin war jedoch deutlich teurer und iterativer als nötig. Die wichtigsten Ursachen waren ein zu früher Prototyp ohne vollständige Bestandsaufnahme, eine erst später aufgebaute Capture-Infrastruktur, spät konsultierte Laufzeit-Interna von BlitzMax/Max2D und zu viele vollständige Prüfzyklen nach kleinen Änderungen.

„1:1“ bedeutet im erreichten Ergebnis:

- Spiellogik, Zustandsübergänge, Eingaben, Persistenz und deterministische Regeln wurden gegen den Originalcode nachvollzogen und getestet.
- Grafik und Timing wurden systematisch mit dem Original verglichen.
- Verbleibende, technisch bedingte Rasterunterschiede zwischen OpenGL/Max2D und SpriteKit sind dokumentiert und als begrenzte Plattformabweichungen bewertet.
- iOS verwendet für Betriebssystemverhalten wie App-Beenden die passende Plattformentsprechung, nicht eine wortwörtliche Desktop-Implementierung.

Eine pauschale Behauptung bitgenauer Pixelidentität auf allen Apple-Geräten wäre daher zu stark. Die sinnvollere Aussage ist: Das definierte Fidelity-Ziel wurde mit dokumentierten Grenzen und belastbarer Evidenz erreicht.

## Ausgewertete Grundlagen

Diese Retrospektive stützt sich auf:

- den Git-Verlauf zwischen dem Stand vor der Portierung (`249bf9b6`) und `83d7f80`;
- die aktuellen Projektdateien und die Dokumentation in `PLAN.md`, `FIDELITY.md`, `docs/CAPTURE-REVIEW.md`, `docs/RUNTIME-SMOKE.md` und `docs/SWIFT-REWRITE.md`;
- die lokale Codex-Session-Logdatei vom 24. August (nicht im Repository).

Für den 25. August existiert kein eigener Session-Ordner. Die am 24. August gestartete JSONL-Datei läuft zeitlich bis in den 25. August weiter und enthält damit beide Arbeitstage.

Die Auswertung enthält absichtlich keine Apple-Team-ID, E-Mail-Adresse, Gerätekennung, Seriennummer oder andere vertrauliche Account-/Gerätedaten.

## Was gemacht wurde

### Repository und Arbeitsgrundlage

- Das ursprüngliche BlitzMax-Projekt wurde inventarisiert und seine Struktur erklärt.
- Für die Portierung wurde der Branch `codex/swift-port` angelegt.
- `PLAN.md` und `AGENTS.md` wurden erstellt; später kamen eine detaillierte Fidelity-Matrix und weitere Prüfberichte hinzu.
- Die ursprünglichen `.bmx`-Dateien sowie `gfx/` und `sounds/` blieben zwischen Ausgangsstand und Abschluss-Commit unverändert. Assets wurden für das Swift-Ziel kopiert, nicht im Original ersetzt.

### Swift-Port

- Eine gemeinsame Swift-6-Codebasis für macOS und iOS wurde mit SwiftUI und SpriteKit aufgebaut.
- Spielregeln wurden soweit möglich in plattformneutrale Werttypen ausgelagert, damit sie ohne laufende SpriteKit-Ansicht deterministisch testbar sind.
- Alle wesentlichen Spielsysteme wurden portiert: Spieler, Schüsse, Gegner und Generatoren, Grid-Varianten, Partikel, Power-ups, Menüs, Optionen, Highscores, Audio, Pause-/Fortsetzungslogik und Persistenz.
- Die Ressourcen des Originals wurden in das Apple-Ziel eingebunden.
- Startskripte, Xcode-Projekt und Testtargets wurden ergänzt.

### Fidelity und Referenzen

- `FIDELITY.md` wurde als Zuordnung Originalquelle → Swift-Implementierung → Evidenz aufgebaut.
- Offizielle beziehungsweise quellnahe BlitzBasic-/BlitzMax-Referenzen wurden unter `docs/bb/` archiviert, insbesondere zu Zufallszahlen, Max2D, Audio und Laufzeitsemantik.
- Für das Original wurde ein isolierter Capture-Harness erstellt, der nicht in den normalen Benutzerzustand unter `~/.config` schreibt.
- Ein deterministischer Katalog mit 136 Originalaufnahmen wurde erzeugt. Dazu wurden entsprechende Swift-Aufnahmen generiert und paarweise geprüft.
- Wiederholte Aufnahmen wurden per Hash auf Determinismus geprüft; Contact Sheets und Einzelbilder wurden zusätzlich visuell beurteilt.

### Plattform- und Laufzeitprüfung

- Die macOS-Fassung wurde gebaut und in einem vollständigen Laufzeitpfad geprüft.
- Der iOS-Test-Build lief für den Simulator durch; iPhone- und iPad-Darstellung wurden im Simulator kontrolliert.
- Nach ausdrücklicher Freigabe wurden Signierung, Gerätebereitstellung und Entwicklervertrauen für ein physisches iPhone eingerichtet.
- Auf dem echten Gerät lief ein UI-Test mit realen Touch-Ereignissen für Bewegung, Zielen, Bombe, Menü, Fortsetzen, Home/Vordergrund und Kaltstart.
- Die Persistenzdateien wurden im App-Container geprüft.

### Dokumentation und Versionsverlauf

- Die README enthält den direkten Startweg: `./scripts/run-macos.sh`.
- Zusätzliche Dokumente beschreiben Portierung, Capture-Prüfung, Laufzeittests und verbleibende Abweichungen.
- Die Arbeit wurde auf Wunsch in zahlreichen Meilenstein-Commits gesichert.

## Ergebnis in Zahlen

| Kennzahl | Ergebnis |
| --- | ---: |
| Portierungs-Commits | 81 |
| Geänderte/ergänzte Dateien im Portierungsbereich | 1.234 |
| Netto-Diff | 82.577 Einfügungen, 4 Löschungen |
| Swift-Dateien | 18 |
| Swift-Code einschließlich Tests | 18.008 Zeilen |
| macOS-Tests am Abschluss | 127 erfolgreich |
| Physischer iPhone-UI-Test | 1 erfolgreich, 0 Fehler |
| Deterministische Capture-Fälle | 136 Paare |
| Archivierte Referenzdateien unter `docs/bb/` | 1.025 |

Der große Datei- und Zeilenzuwachs besteht zu einem erheblichen Teil aus archivierter Referenzdokumentation und Original-Captures; er ist nicht mit 82.000 Zeilen neu geschriebener Swift-Logik gleichzusetzen.

## Was gut gelaufen ist

### 1. Das Original wurde schließlich zur tatsächlichen Autorität

Die beste Entscheidung war, nicht bei „sieht ähnlich aus“ stehenzubleiben. `FIDELITY.md` zwingt jede relevante Funktion in eine überprüfbare Kette aus Originalquelle, Swift-Ziel und Evidenz. Dadurch wurden implizite Regeln sichtbar, die bei einer freien Neuimplementierung leicht verloren gegangen wären.

### 2. Testbare Architektur statt reiner Szenenlogik

Die Trennung deterministischer Regeln von SpriteKit erleichterte Tests für Gegnerverhalten, Rasterauswahl, Zufallsfolgen, Zustände und Persistenz. Das war besonders wertvoll, wenn GUI-Automation eingeschränkt oder ein gleichzeitiger Tastendruck nicht zuverlässig automatisierbar war.

### 3. Deterministische Bildvergleiche wurden ernst genommen

Der Original-Harness, feste Zustände und wiederholbare Aufnahmen machten Grafikdiskussionen messbar. Besonders gut war, dass ein Bildmetrik-Wert nicht als alleiniger Beweis behandelt wurde: Unterschiede wurden auch als Contact Sheet und in voller Auflösung angesehen.

### 4. Fehlgeschlagene Rendering-Experimente wurden verworfen

Alternative Raster- und SpriteKit-Ansätze wurden gemessen. Wenn sie die Gesamtähnlichkeit verschlechterten, wurden sie zurückgenommen. Das ist bessere Fidelity-Arbeit als eine Änderung nur deshalb zu behalten, weil sie lokal plausibel aussieht.

### 5. Die Prüfung endete nicht beim Compiler

Die Kombination aus 127 macOS-Tests, Simulator-Builds, visueller Prüfung und echtem iPhone-Test ist wesentlich belastbarer als ein bloßer erfolgreicher Build. Der Hardwaretest deckte konkrete Probleme auf, die auf dem Simulator oder in Unit-Tests nicht sichtbar waren.

### 6. Grenzen von Berechtigungen wurden respektiert

Vor Geräte-Registrierung, Provisioning und Developer Trust wurde angehalten und die notwendige Freigabe eingeholt. Damit blieb die technische Arbeit innerhalb der erteilten Autorisierung.

### 7. Original und Verlauf blieben nachvollziehbar

Die Legacy-Dateien wurden nicht umgeschrieben. Branch, Meilenstein-Commits, Prüfberichte und archivierte Referenzen machen die Portierung später auditierbar.

## Was schlecht beziehungsweise unnötig teuer gelaufen ist

### 1. Der erste Swift-Stand kam vor der vollständigen Inventur

Der erste spielbare Stand enthielt nur drei Gegnertypen und fünf Tests. Zu diesem Zeitpunkt war die Aufgabe zunächst noch als allgemeine Portierung formuliert; das spätere 1:1-Ziel erhöhte den Anspruch deutlich. Trotzdem wäre eine vollständige System- und Akzeptanzmatrix vor dem ersten größeren Implementierungsschritt sinnvoll gewesen. Der frühe Prototyp führte später zu viel Nacharbeit.

### 2. Die Verifikationsarchitektur kam zu spät

Der Capture-Katalog wuchs schrittweise von kleineren Teilmengen auf 67, dann 87 und schließlich 136 Fälle. Frühe Retina-Aufnahmen des Originals erfassten durch eine falsche Interpretation des 2×-Framebuffers nur den linken oberen Ausschnitt. Der Fehler wurde erkannt und korrigiert, aber ein validierter Capture-Harness hätte vor der grafischen Feinarbeit stehen müssen.

### 3. BlitzMax-/Max2D-Interna wurden erst im Verlauf tief geprüft

Details von `BRL.Random`, Typkonvertierungen, Max2D-Rasterung und direktem OpenGL-Verhalten beeinflussen sichtbare und deterministische Ergebnisse. Weil diese Quellen erst später systematisch archiviert und ausgewertet wurden, mussten bereits portierte Regeln und Renderentscheidungen erneut geprüft werden.

### 4. Der Arbeitsprozess erzeugte sehr viel Tool- und Kontextverkehr

Die Session lief über viele Kontextkompaktierungen; derselbe große Kontext wurde dabei sehr häufig erneut verarbeitet.

Ursachen waren unter anderem wiederholte Voll-Builds, große Capture-Läufe, umfangreiche Terminalausgaben und sehr kleine aufeinanderfolgende Rendering-Experimente.

### 5. Viele Patches und Befehle mussten wiederholt werden

Eine grobe Mustersuche in den Logs fand unter anderem 66 Vorkommen von `script failed`, 32 von `test failed`, 12 von `build failed`, 56 fehlgeschlagene `apply_patch`-Muster und 231 `permission denied`-Muster. Das sind keine 397 eindeutigen Fehler: Wiederholungen, zitierte Ausgaben und erneute Renderings können mehrfach gezählt sein. Als Prozesssignal sind die Werte trotzdem nützlich. Besonders fragile Mehrfach-Patches auf bereits veränderten Dateien und ungenaue Annahmen über Sandbox-/GUI-Rechte kosteten Zeit.

### 6. Vollständige Prüfmatrizen wurden zu oft nach kleinen Änderungen ausgeführt

Ein einzelner Pixel- oder Blending-Versuch braucht zuerst einen fokussierten Test und wenige repräsentative Captures. Häufige vollständige Builds und Katalogläufe verlängerten die Schleife, ohne proportional mehr Erkenntnis zu liefern.

### 7. Laufzeit- und Hardware-Risiken wurden spät vorgezogen

GUI-Sperren, Simulatorzustand, Signierung, Developer Mode, Gerätevertrauen und der Tunnel zum physischen Gerät wurden erst spät vollständig geklärt. Der erste Hardware-UI-Test enthielt außerdem zwei konkrete Schwächen:

- Nach Home/Vordergrund wurde ein veralteter `XCUIApplication.state` ausgewertet.
- Der Tap auf „Continue“ verwendete eine falsche relative Y-Position, weil das 4:3-Spielfeld im Gerätefenster aspect-fit dargestellt wird.

Beides wurde korrigiert. Ein früher minimaler XCUITest hätte diese Klasse von Problemen früher sichtbar gemacht. Auch die gedreht gespeicherte Pixelmatrix der Gerätescreenshots hätte durch sofortige visuelle Kontrolle früher auffallen können.

### 8. Die Commit-Historie ist feiner als für Reviews optimal

81 Commits entsprechen dem ausdrücklichen Wunsch nach Sicherung pro Meilenstein. Einige pixelnahe Versuche hätten dennoch besser lokal gebündelt und erst nach bestandener Evidenz als ein fachlicher Meilenstein committed werden können. Das hätte die spätere Review-Historie ruhiger gemacht.

## Was man konkret besser machen könnte

### Phase 0: Akzeptanzvertrag und Preflight

Vor Implementierung:

1. Ausgangscommit, Branch und fremde Working-Tree-Änderungen festhalten.
2. Originalquellen und Assets als unveränderliche Referenz definieren.
3. „1:1“ in überprüfbare Kategorien zerlegen: Regeln, Timing, Grafik, Audio, Eingabe, Persistenz und plattformspezifische Entsprechungen.
4. Xcode, Swift, BlitzMax, GUI-Zugriff, Simulatoren und optional physische Geräte früh prüfen.
5. Signierung und Developer Mode nur diagnostizieren; Änderungen daran weiterhin erst nach ausdrücklicher Freigabe vornehmen.

### Phase 1: Vollständige Quell- und Referenzinventur

- Alle Subsysteme, Gegner, Generatoren, Grid-Funktionen, Menüs und Speicherformate erfassen.
- Relevante Laufzeitquellen zu RNG, Zahlkonvertierung, Max2D, OpenGL und Audio vor dem Port lesen.
- Für jedes Subsystem vorab Originalpfad, Zieltyp und geplante Evidenz in `FIDELITY.md` eintragen.

### Phase 2: Harness vor Feinarbeit

- Den Original-Harness isoliert und ohne Benutzerdaten bauen.
- Retina-/Framebuffer-Skalierung mit einem bekannten Testbild validieren.
- Seed, Timing, Fenstergröße und Eingaben deterministisch machen.
- Den vollständigen Capture-Katalog früh festlegen und zweimal identisch reproduzieren.

### Phase 3: Subsystemweise Portierung

Für jedes fachliche Arbeitspaket:

1. Originalcode und Laufzeitsemantik lesen.
2. Plattformneutrale Regeln implementieren.
3. Kleine fokussierte Unit-Tests schreiben.
4. SpriteKit-Integration ergänzen.
5. Nur die relevanten Captures vergleichen.
6. Ledger aktualisieren und einen fachlich verständlichen Commit erstellen.

Reihenfolge und implizite Konvertierungen des Originals sollten ausdrücklich bewahrt werden; „sauberere“ Umordnungen können Zufallsfolgen und Bilder verändern.

### Phase 4: Rendering mit Hypothesen statt globalen Offsets

- Koordinatentransformationen an klaren Systemgrenzen durchführen.
- Pixelzentrum, Linienendpunkte, Blendmodi und Textmetriken getrennt behandeln.
- Pro Experiment nur eine Variable ändern.
- Erst repräsentative Einzelbilder prüfen; den vollen 136er-Katalog nur an Meilensteinen ausführen.
- Regressionen konsequent zurücknehmen und akzeptierte Plattformgrenzen dokumentieren.

### Phase 5: Plattformtests früh staffeln

- Früh einen macOS-Smoke-Test und einen minimalen iOS-XCUITest etablieren.
- Danach iPhone- und iPad-Simulatoren prüfen.
- Sobald autorisiert und verfügbar, einen kurzen physischen Touch-/Lifecycle-Test ausführen, nicht erst am Projektende.
- Screenshots unmittelbar auf Orientierung, Safe Areas und aspect-fit prüfen.

### Phase 6: Abschlussaudit

- Vollständige Unit-/UI-Testmatrix ausführen.
- Original- und Swift-Captures vollständig vergleichen.
- Persistenz auf macOS, Simulator und physischem Gerät prüfen.
- Offene Ledger-Zeilen und bekannte Grenzen explizit dokumentieren.
- Erst dann den Abschluss-Commit erzeugen.

## Empfohlenes Meilenstein-Paket

Jeder größere Commit sollte ein kleines, einheitliches Evidenzpaket besitzen:

- betroffene Originalstellen;
- betroffene Swift-Dateien;
- fokussierte Testkommandos und Ergebnisse;
- relevante Original-/Swift-Captures;
- aktualisierte `FIDELITY.md`-Zeilen;
- bekannte Abweichungen oder bewusst gewählte Plattformentsprechungen.

Das reduziert Wiederholungen und macht Reviews möglich, ohne die komplette Session-Historie lesen zu müssen.

## Abgeleiteter Skill

Aus den wiederkehrenden Problemen wurde ein enger, wiederverwendbarer Skill erstellt:

- `skills/blitzmax-swift-fidelity/SKILL.md`

Er ist bewusst kein allgemeiner „Programmiere besser“-Skill. Er greift nur bei quellgetreuen BlitzMax-/Max2D-Portierungen oder entsprechenden Audits nach Swift/SpriteKit. Er kodiert insbesondere:

- Akzeptanzmatrix und Preflight vor der Implementierung;
- frühe Prüfung der Legacy-Laufzeitsemantik;
- isolierte deterministische Captures;
- eine gestaffelte statt ständig vollständige Teststrategie;
- besondere Regeln für Koordinaten, Rasterung und Zufallsreihenfolge;
- frühe Simulator-/Hardwaretests;
- saubere Berechtigungsgrenzen und redigierte Evidenz.

Der Standardpfad `.agents/skills/` war in dieser Laufzeit schreibgeschützt. Daher liegt die validierbare Skill-Quelle im normalen Repo-Verzeichnis `skills/`. Zur automatischen persönlichen Erkennung kann dieser Ordner später nach `~/.codex/skills/blitzmax-swift-fidelity/` kopiert werden.

## Verbleibende Risiken und Grenzen

- OpenGL/Max2D und SpriteKit rasterisieren bestimmte Linien, Punkte, Sprites und Texte nicht in jedem Fall pixelidentisch. Die bekannten Differenzen sind begrenzt und dokumentiert.
- Ein physisches iPhone wurde erfolgreich getestet; ein physisches iPad war nicht Teil der abschließenden Evidenz. Die iPad-Prüfung erfolgte im Simulator.
- Der aktuelle Working Tree enthält nach dem Abschluss-Commit eine nicht zu dieser Retrospektive gehörende Änderung an `GridWars.xcodeproj/project.pbxproj`. Sie wurde hier weder verändert noch inhaltlich bewertet. Xcode-Projektdateien bleiben damit ein Bereich, für den eine deterministische Generierung oder zumindest eine gesonderte Normalisierungsprüfung sinnvoll wäre.

## Schlussfolgerung

Das Projekt endete mit einer ungewöhnlich tief geprüften Portierung und guter technischer Dokumentation. Besonders wertvoll sind die Kombination aus unverändertem Original, Source-to-Evidence-Ledger, deterministischen Captures und echtem Hardwaretest.

Der größte Verbesserungshebel liegt nicht in mehr Implementierung, sondern in einer besseren Reihenfolge: erst Akzeptanz und Laufzeitsemantik, dann Harness, dann subsystemweise Portierung, fokussierte Evidenz und zuletzt die volle Matrix. Genau diese Reihenfolge ist im neuen Skill festgehalten.
