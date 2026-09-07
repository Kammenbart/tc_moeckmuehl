# Aufgaben — TC Möckmühl App

Abarbeitung von oben nach unten. Erledigte Punkte abhaken und in `docs/STATUS.md` vermerken.

**Bei jeder Aufgabe gilt:** eigener Branch, Tests, Pull Request, kurzer Bericht. Nicht mergen.
**Anhalten und fragen bei:** Buchungslogik, Authentifizierung, Rollen und Berechtigungen, Schema-Änderungen.
**Aufgaben mit `[ICH]`** kann Claude Code nicht ausführen, die erledigt Maximilian. Überspringen und melden.

---

## A — Arbeitsstand aufräumen

Das muss zuerst passieren. Solange der Stand unklar ist, baut alles Weitere auf Sand.

### A1 Uncommittete Änderungen klären
Zeig die Änderungen in `pubspec.yaml` und allen anderen geänderten Dateien. Schlag für jede vor: committen, verwerfen oder in einen eigenen Branch. Warte auf meine Entscheidung, bevor du etwas ausführst.
**Fertig wenn:** `git status` ist sauber.

### A2 Branch-Situation ordnen
Aktueller Branch ist `feature/enhancements-and-fixes`. Klär das Verhältnis zu `main`: Welche Commits fehlen wo? Ist `main` hinterher? Schlag vor, wie zusammengeführt wird.
**Fertig wenn:** Es ist klar, welcher Branch den veröffentlichten Stand enthält.

### A3 Release-Tags setzen `[ICH liefere die Versionsnummern]`
Vorhandene Tags (`safe-20260518`, `safe-20260521`, `safe-20260522`) sind Datumssicherungen ohne Versionsbezug. Setze zusätzlich Tags im Schema `release/ios-x.y.z` und `release/android-x.y.z` auf die Commits, die den Store-Versionen entsprechen. Die Nummern nenne ich dir.
**Fertig wenn:** Für beide Plattformen existiert ein Tag auf dem richtigen Commit, gepusht.

### A4 Secrets prüfen
Durchsuche das Repo und die Git-Historie nach versehentlich eingecheckten Zugangsdaten: PocketBase-Passwörter, API-Keys, Zertifikate, Provisioning-Profile, `.env`-Dateien. Prüfe die `.gitignore` auf Vollständigkeit.
**Fertig wenn:** Bericht liegt vor. Funde meldest du mir, bevor du irgendetwas änderst.

### A5 Statusdatei anlegen
Erstelle `docs/STATUS.md` mit dem aktuellen Stand, bekannten Bugs und offenen Entscheidungen. Halte sie ab jetzt bei jeder Aufgabe aktuell.
**Fertig wenn:** Datei existiert und ist committet.

---

## B — Sicherheitsnetz

Erst wenn das steht, wird an der App gearbeitet.

### B1 PocketBase-Backups aktivieren `[ICH]`
In der Admin-UI unter Settings, Backups den Zeitplan einschalten und ein erstes Backup manuell erzeugen und herunterladen.

### B2 Backup-Abholung auf dem Raspberry Pi einrichten
Skript, das das jeweils neueste Backup nachts vom Server holt und auf dem Pi ablegt. Alte Sicherungen nach sinnvoller Frist aufräumen. Zugangsdaten nicht ins Repo.
**Fertig wenn:** Das Skript läuft einmal erfolgreich durch und ist als Timer eingerichtet.

### B3 Restore-Test
Spiel ein Backup in eine frische lokale PocketBase-Instanz ein und prüfe, ob die Daten vollständig ankommen.
**Fertig wenn:** Der Restore ist nachweislich gelungen. Ein ungetestetes Backup zählt nicht.

---

## C — Entwicklungsumgebung trennen

Aktuell existiert nur die Produktivdatenbank. Das ist das größte Risiko im Projekt.

### C1 Lokale PocketBase aufsetzen
Gleiche Version wie produktiv, Backup eingespielt, läuft unter `http://127.0.0.1:8090`. Startanleitung in `docs/` festhalten.

### C2 Testdaten anonymisieren
Überschreibe in der lokalen Instanz alle personenbezogenen Daten: Namen, E-Mail-Adressen, Telefonnummern, Adressen. Schreib das als wiederholbares Skript, damit es nach jedem neuen Backup erneut läuft.
**Fertig wenn:** In der lokalen Datenbank steht kein echter Mitgliedsdatensatz mehr.

### C3 Backend-URL umschaltbar machen
Die PocketBase-URL kommt aus der Konfiguration, nicht aus dem Code. Umsetzung über `--dart-define=PB_URL=...` mit der Produktiv-URL als Standard.
**Fertig wenn:** Die App läuft wahlweise gegen lokal oder produktiv, ohne Codeänderung.

### C4 Gegenprobe
Starte die App gegen die lokale Instanz im iOS-Simulator und im Android-Emulator. Login, Platzbuchung, Vereinsansicht durchklicken.
**Fertig wenn:** Beide Plattformen laufen sauber gegen lokal, mit Screenshots belegt.

---

## D — Testfundament

### D1 Analyse aufräumen
`flutter analyze` fehlerfrei bekommen. Warnungen einzeln bewerten, nicht pauschal unterdrücken.

### D2 Bestandsaufnahme Tests
Welche Tests existieren, was decken sie ab, wo sind die Lücken? Priorisierte Liste, keine Umsetzung.

### D3 Integrationstests für die kritischen Pfade
Login, Rollenzuweisung, Platzbuchung, Stornierung. Getrennte Aufgaben, jeweils eigener Branch.

### D4 Randfälle absichern
Doppelbuchung desselben Platzes zur selben Zeit, Buchung in der Vergangenheit, Stornierung kurz vor Beginn, Sommerzeitumstellung, Nutzer mit alter App-Version.
**Fertig wenn:** Für jeden Fall existiert ein Test, der vorher fehlschlägt und nachher besteht.

---

## E — Ablauf einspielen

### E1 Erste echte Feature-Aufgabe
Etwas Kleines, Unkritisches, nichts an der Buchungslogik. Zweck ist, den kompletten Kreislauf einmal zu durchlaufen: Branch, Umsetzung, Tests, Bericht, Pull Request, Merge durch mich.

---

## Später

Hier trage ich laufend ein, was an Features ansteht. Diese Punkte werden erst angefasst, wenn A bis E abgeschlossen sind.

- 
- 
