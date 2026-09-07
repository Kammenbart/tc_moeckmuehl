# Status — TC Möckmühl App

Wird bei jeder Aufgabe aktualisiert. Beim Sitzungsstart zuerst lesen, dann `git status`
und den aktuellen Branch prüfen.

**Letzte Aktualisierung:** 08.09.2026

---

## Aktueller Stand

- **Branch:** `feature/enhancements-and-fixes` — enthält den veröffentlichten Stand
- **Version:** 1.0.2+4 (in beiden Stores veröffentlicht)
- **`main`:** steht auf 1.0.1+2, war nie im Store, ist noch nicht abgelöst
- **Backend:** ausschließlich Produktiv (`https://api.tc-moeckmuehl.de`), keine Dev-Instanz
- **Tests:** 6 Widget-Tests, keine Integrationstests
- **`flutter analyze`:** keine Fehler, 14 Warnungen, 56 Hinweise

---

## Erledigte Aufgaben

| Datum | Aufgabe | Ergebnis |
|---|---|---|
| 08.09.2026 | Ablage aufgeräumt | Projektanweisung, Aufgabenliste, Icon-Quellen und die beiden Claude-Ordner nach iCloud Drive verschoben (`Claude/`, `TC Möckmühl App/`) |
| 08.09.2026 | CLAUDE.md angelegt | Regelwerk plus technischer Repo-Stand aus `/init` |
| 08.09.2026 | **A1** Uncommittete Änderungen | 4 Commits: Release-Konfiguration 1.0.2+4, Mitteilungs-Badge, Abhängigkeiten, Dokumentation. Tote Kotlin-Datei gelöscht. `git status` sauber. |
| 08.09.2026 | **A2** Branch-Situation | Belegt: der Feature-Branch enthält den veröffentlichten Stand. Zusammenführung vorbereitet, aber **noch nicht abgeschlossen** |
| 08.09.2026 | **A4** Secrets-Prüfung | Keine Zugangsdaten im Repo oder in der Historie. `.gitignore`-Lücken geschlossen, generierte Dateien ausgetragen |
| 08.09.2026 | **A5** Statusdatei | Diese Datei |

---

## Bekannte Probleme

### Kritisch

**Die PocketBase-URL ist fest verdrahtet.** `lib/main.dart:163` zeigt auf
`https://api.tc-moeckmuehl.de`. Jeder lokale Start läuft damit gegen die echten
Mitgliederdaten — ein Verstoß gegen Harte Regel 2. Es gibt keine Dev-Instanz, gegen
die stattdessen entwickelt werden könnte.
→ Aufgabe **C3**, auf Entscheidung vom 08.09.2026 direkt hinter Abschnitt A vorgezogen.

### Offen

- **Bundle Identifier nur teilweise umgestellt.** Release und Debug stehen auf
  `de.tcmoeckmuehl.app`, die **Profile**-Konfiguration noch auf
  `com.example.tcMoeckmuehl`. Release-Builds sind nicht betroffen,
  `flutter run --profile` läuft aber unter der falschen ID.
  Regel-7-geschützt, Änderung nur nach ausdrücklicher Freigabe.
- **`README.md` enthält eingecheckte Merge-Konflikt-Marker**
  (`<<<<<<< HEAD` … `>>>>>>> Backup vor Navigations-Umbau`).
- **`MainActivity.kt` liegt unter `com/example/…`**, deklariert aber
  `package de.tcmoeckmuehl.app`. Kotlin toleriert das, sauber ist es nicht.
- **`MARKETING_VERSION = 0.0.2`** im pbxproj, während `pubspec.yaml` auf 1.0.2 steht.
  Seit dem Entfernen von `FLUTTER_BUILD_NAME` sollte die Version aus `pubspec.yaml`
  durchschlagen — beim nächsten iOS-Build prüfen.
- **14 Analyzer-Warnungen**, darunter vier `invalid_null_aware_operator` in
  `trainer_portal_pages.dart`, ungenutzte Variablen und `_buildCharts` ohne Verwendung.
  → Aufgabe **D1**.
- **SMTP-Passwort liegt in der `settings`-Collection.** Im Repo steht korrekt keins,
  aber wer die Collection lesen darf, sieht es im Klartext. Die PocketBase-Zugriffsregeln
  sind zu prüfen — das geht nur in der Admin-UI.

---

## Offene Entscheidungen

| Thema | Worum es geht |
|---|---|
| **Merge nach `main`** | Der Befehl `git merge -s ours main` wurde von der Berechtigungsprüfung blockiert. Maximilian muss ihn selbst ausführen oder die Konflikte beim PR auf GitHub lösen. Die vorbereitete Commit-Nachricht liegt bereit. |
| **A3 Release-Tags** | Maximilian liefert die Versionsnummern, die den Store-Ständen entsprechen. Ohne sie können `release/ios-x.y.z` und `release/android-x.y.z` nicht gesetzt werden. |
| **Onboarding** | `lib/onboarding_screen.dart` (334 Zeilen) existiert nur in `main` und war nie im Store. Fachlich noch gewollt? Wenn ja, eigene Aufgabe mit eigenem Branch. Abrufbar über Commit `c63ceed`. |
| **`settings`-Zugriffsregeln** | Siehe SMTP-Passwort oben. |

---

## Als Nächstes

Reihenfolge nach Entscheidung vom 08.09.2026: **A3 → C3 → B → D → E**
(C3 wurde vor Abschnitt B gezogen, weil die fest verdrahtete Produktiv-URL
regelkonformes Arbeiten sonst unmöglich macht.)

1. **A3** — Release-Tags setzen, sobald die Versionsnummern vorliegen `[ICH]`
2. **C3** — Backend-URL über `--dart-define=PB_URL=...` umschaltbar machen
3. **B1** — PocketBase-Backups in der Admin-UI einschalten `[ICH]`
4. **B2** — Backup-Abholung auf dem Raspberry Pi einrichten
5. **B3** — Restore-Test
6. **C1/C2/C4** — lokale Instanz, Testdaten anonymisieren, Gegenprobe

---

## Nicht überprüfbar

Diese Punkte kann Claude Code grundsätzlich nicht selbst testen und gehören in jeden
Bericht als offene Liste:

- Verhalten auf echten Endgeräten
- Push-Notifications unter Produktionsbedingungen
- Verhalten im Store-Review
- Echtes Nutzerverhalten und Lastverhalten
- Alles, was schreibenden Zugriff auf die Produktivdatenbank bräuchte (Regel 2)
