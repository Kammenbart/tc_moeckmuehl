# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# Teil 1 — Projektanweisung

## Worum es geht

Flutter-App für den Tennisverein TC Möckmühl. Sie ist bereits im Apple App Store und im Google Play Store veröffentlicht und wird von echten Vereinsmitgliedern genutzt. Funktionsumfang: Platzbuchung von extern, Vereinsverwaltung und Trainingsverwaltung für die Rollen Mitglied, Vorstand und Trainer.

- Flutter, entwickelt in Visual Studio Code
- Backend: PocketBase, produktiv über eine passwortgeschützte Subdomain
- Versionierung: GitHub, Remote `git@github.com:Kammenbart/tc_moeckmuehl.git`
- Veröffentlichung getrennt über App Store Connect (Apple) und Google Play Console (Android)
- Claude Code läuft auf dem Mac (Xcode, iOS-Simulator, Android-Emulator vorhanden)
- Ein Raspberry Pi läuft dauerhaft und dient als Backup-Ziel und Watchdog

**Rollenverteilung:** Maximilian gibt die Aufgaben vor. Claude plant, programmiert, testet selbst und berichtet. Steuerung erfolgt häufig vom Handy — Antworten dann kurz und entscheidungsreif.

## Harte Regeln

Diese Regeln gelten immer und werden nicht stillschweigend gelockert. Wenn eine Aufgabe eine Regel verletzen würde, nachfragen statt umgehen.

1. **Niemals direkt auf `main` committen.** Immer ein Branch `feature/<kurzname>` oder `fix/<kurzname>`, danach ein Pull Request gegen `main`. Nicht selbst mergen.
2. **Niemals schreibend auf die Produktiv-PocketBase.** Entwicklung und Tests laufen ausschließlich gegen die lokale Dev-Instanz. Lesender Zugriff auf Produktiv nur nach ausdrücklicher Freigabe für eine konkrete Aufgabe.
3. **Keine echten Mitgliederdaten in der Entwicklung.** Testdaten sind synthetisch oder anonymisiert. Es handelt sich um personenbezogene Daten eines Vereins.
4. **Keine Veröffentlichung.** Releases werden bis einschließlich Build-Artefakt und Release-Notes vorbereitet. Upload und Einreichung in beiden Stores macht ausschließlich Maximilian.
5. **Vor jeder Schema-Änderung:** Backup ziehen, Migrationsdatei schreiben, Rollback-Weg beschreiben. In dieser Reihenfolge, bevor Code geschrieben wird.
6. **Keine Secrets ins Repo.** Keys, Passwörter, Zertifikate und Provisioning-Profile gehören nach `.env` bzw. in den Keychain. `.gitignore` vor jedem Commit prüfen.
7. **Nicht anfassen ohne ausdrückliche Freigabe:** Bundle Identifier, Package Name, Signing-Konfiguration, Firebase-Konfiguration, alles was mit Zahlungen zu tun hat.
8. **Abhängigkeiten** werden einzeln aktualisiert, mit Begründung und eigenem Commit. Kein Sammel-Bump.

## Ablauf pro Aufgabe

1. **Sitzungsstart:** Zuerst `docs/STATUS.md` lesen, dann `git status` und aktuellen Branch. Nicht anfangen, ohne zu wissen, wo der letzte Stand aufgehört hat.
2. **Verstehen:** Rückfragen gebündelt und vor Arbeitsbeginn, maximal drei auf einmal. Keine Rückfragen mitten in der Umsetzung, außer es taucht wirklich Neues auf.
3. **Planen:** Vor dem Code nennen: betroffene Dateien, Auswirkung auf das Datenbankschema, geplante Tests, grober Umfang. Bei Buchungslogik, Authentifizierung, Rollen und Berechtigungen oder Schema auf ausdrückliches OK warten.
4. **Umsetzen:** Kleine, nachvollziehbare Commits mit deutschen Commit-Messages. Lieber fünf saubere Schritte als ein großer Wurf.
5. **Testen** (siehe Testpflicht)
6. **Berichten** (siehe Berichtsformat)
7. **Pull Request öffnen, nicht mergen.** In die PR-Beschreibung gehört, was getestet wurde und was manuell zu prüfen ist.

## Testpflicht

Eine Aufgabe gilt erst als fertig, wenn getestet wurde. „Sollte funktionieren" ist kein Ergebnis.

- `flutter analyze` muss ohne Fehler durchlaufen
- `flutter test` für jede neue oder geänderte Logik, Unit- und Widget-Tests
- `integration_test` verpflichtend für alles rund um Platzbuchung, Login, Rollen und Berechtigungen
- Smoke-Test im iOS-Simulator **und** im Android-Emulator, mit Screenshots als Beleg
- Bei Buchungslogik zusätzlich die unangenehmen Fälle: Doppelbuchung, Buchung in der Vergangenheit, Stornierung kurz vor Beginn, zwei Nutzer auf demselben Platz zur selben Zeit, Zeitumstellung

**Was nicht testbar ist, wird klar benannt:** echte Endgeräte, Push-Notifications unter Produktionsbedingungen, Verhalten im Store-Review, echtes Nutzerverhalten, Lastverhalten. Diese Punkte gehören in jeden Bericht als offene Liste.

## Format der Zwischenberichte

Nach jedem abgeschlossenen Teilschritt, nicht nach Zeittakt. Kurz genug zum Lesen auf dem Handy:

```
Aufgabe:      <ein Satz>
Status:       fertig / läuft / blockiert
Gemacht:      3–5 Stichpunkte
Getestet:     was, wie, Ergebnis
Datenbank:    Schema geändert ja/nein, wenn ja: was
Branch / PR:  <name / link>
Ich brauche:  <Entscheidung, oder: nichts>
Manuell prüfen: <was am echten Gerät anzusehen ist>
Nächster Schritt: <ein Satz>
```

Bei Blockade sofort melden, nicht bis zum Ende warten. Dabei immer zwei Wege nach vorn und eine Empfehlung nennen.

## Statusdatei

`docs/STATUS.md` laufend aktuell halten: aktuelle Aufgabe, erledigte Aufgaben mit Datum, bekannte Bugs, offene Entscheidungen, was als Nächstes ansteht. Diese Datei ist das Gedächtnis über Sitzungsgrenzen hinweg.

## Backups

- **Vor jeder Schema-Änderung:** PocketBase-Backup mit Zeitstempel und Anlass
- **Täglich:** Backup der Produktiv-Datenbank, Ablage auf dem Raspberry Pi
- **Vor jeder Release-Vorbereitung:** Git-Tag setzen, Schema `release/ios-x.y.z` bzw. `release/android-x.y.z`
- Backups kommen nie ins Git-Repo
- Monatlich prüfen, ob sich ein Backup tatsächlich zurückspielen lässt. Ein ungetestetes Backup ist kein Backup.

## Release-Vorbereitung — bis hierhin und nicht weiter

Erlaubt: Version und Buildnummer in `pubspec.yaml` hochziehen; Änderungsliste auf Deutsch für beide Stores; `flutter build appbundle --release` und `flutter build ipa --release`; Checkliste der manuellen Schritte; Prüfung von Store-Metadaten, Screenshots und Datenschutzangaben.

Nicht erlaubt: hochladen, einreichen, veröffentlichen, Store-Einträge ändern. **An dieser Stelle aufhören und übergeben.**

## Ton

Deutsch, knapp, direkt. Wenn ein Auftrag technisch fragwürdig ist, ein Sicherheitsrisiko schafft oder es einen besseren Weg gibt: klar sagen, bevor die Arbeit beginnt. Ergebnisse nicht beschönigen und nichts als fertig melden, was nicht überprüft wurde. Was nicht funktioniert hat, gehört in den Bericht.

---

# Teil 2 — Technischer Stand des Repos

## Befehle

```bash
flutter pub get                      # Abhängigkeiten
flutter analyze                      # Statische Analyse (muss fehlerfrei sein)
flutter test                         # Alle Tests
flutter test test/widget_test.dart   # Einzelne Testdatei
flutter test --name "<Testname>"     # Einzelner Test nach Name
flutter run                          # App starten (Gerät wählen mit -d)
flutter devices                      # Verfügbare Simulatoren/Emulatoren

flutter build appbundle --release    # Android-Release (signiert, s.u.)
flutter build ipa --release          # iOS-Release
```

Zielplattformen sind iOS und Android. Die Ordner `linux/`, `macos/`, `web/`, `windows/` existieren noch aus dem Flutter-Template, werden aber nicht veröffentlicht — `.metadata` listet nur noch `root` und `android`.

## Architektur

**Backend-Zugriff** läuft vollständig über eine einzige globale PocketBase-Instanz: `late final PocketBase pb` in `lib/main.dart`. Es gibt keine Repository- oder Model-Schicht — Widgets rufen `pb.collection('...')` direkt auf und arbeiten mit `RecordModel` und dessen `getStringValue()` / `getBoolValue()` / `getIntValue()`. Wer das Datenmodell verstehen will, liest die Aufrufstellen, nicht eine Schemadatei.

**Session-Persistenz:** `AsyncAuthStore` schreibt das Auth-Token unter dem Schlüssel `pb_auth` in `SharedPreferences`. `main()` versucht beim Start einen `authRefresh()` mit 5 Sekunden Timeout und lässt die App bei Fehlschlag trotzdem starten.

**Rollen und Berechtigungen** stecken als Felder direkt auf dem `users`-Record und werden in `_HomeScreenState.build()` (`lib/main.dart`) ausgewertet:

- Drei boolesche Admin-Flags: `auth_admin_app`, `auth_admin_board`, `auth_admin_trainer`
- Vier ganzzahlige Vorstandsrechte: `perm_board_member`, `perm_board_cash`, `perm_board_booking`, `perm_board_beverage`
- Vier ganzzahlige Trainerrechte: `perm_trainer_trainer`, `perm_trainer_member`, `perm_trainer_bill`, `perm_trainer_reminder`

Ein Integer-Recht > 0 gilt als vorhanden; die Stufen werden an einzelne Tabs als `permission:` weitergereicht und dort feiner ausgewertet. Aus den vorhandenen Rechten baut `build()` eine Liste von `RoleEntry` und zeigt sie über `RoleFab` an — bei einer Rolle als einfacher FAB, bei mehreren aufklappbar. Von dort führen `MaterialPageRoute`s in die drei Rollen-Einstiege unter `lib/admin/`: `AdminHomeScreen`, `VorstandHomeScreen`, `TrainerHomeScreen`. Jeder Einstieg hat seine eigene `BottomNavigationBar` mit eigenen Tabs.

**Verzeichnisse:**
- `lib/main.dart` — PocketBase-Init, Login/Registrierung (`AuthWrapper`), Rollenauswertung, globale ValueNotifier
- `lib/admin/` — die drei Rollen-Einstiegsscreens
- `lib/tabs/` — alle Bildschirminhalte, nach Rolle benannt (`vorstand_*`, `trainer_*`, `admin_*`) plus die Mitglieder-Tabs (`court_tab`, `home_tab`, `drink_tab`, `profile_tab`, …)
- `lib/services/` — die vier Stellen mit Logik außerhalb der Widgets

**Globaler Zustand** läuft über `ValueNotifier` auf Top-Level in `lib/main.dart`, nicht über ein State-Management-Paket: `openNotificationsBadgeCount` sowie die Themefarben `appBackColor`, `appFrontColor`, `ownBookingColor`, `otherBookingColor`, `eventBookingColor`. Die Farben werden aus der `settings`-Collection geladen und als Hex gespeichert (`colorToHex`).

**Services:**
- `settings_service.dart` — liest/schreibt Schlüssel-Wert-Paare der `settings`-Collection. Die App-weite Konfiguration hängt an der fest verdrahteten Record-ID `settingsRecordId = 'b9wkhz7wuqxqpid'` in `lib/main.dart`.
- `email_service.dart` — SMTP über `mailer`. Zugangsdaten kommen zur Laufzeit aus der `settings`-Collection (`smtp_host`, `smtp_port`, `smtp_username`, `smtp_password`, `smtp_secure`), nicht aus dem Code.
- `member_csv_service.dart` — CSV-Import/-Export von Mitgliedern, erzeugt dabei Passwörter und verschickt Willkommensmails.
- `notification_workflow_service.dart` — Antrags-Workflow (Getränke-Storno, Mitgliedschaft): erzeugt Anträge, `applyDecision()` führt bei Genehmigung die hinterlegte Aktion auf der Zielcollection aus. Der Aktionstyp wird teils aus dem Record erschlossen (`_inferActionType`).

**PocketBase-Collections** (aus den Aufrufstellen): `users`, `bookings`, `notifications`, `invoices`, `beverage_orders`, `trainer_services`, `work`, `trainer_groups`, `settings`, `news`, `trainer_reminders`, `trainer_customers`, `member_delete_requests`, `courts`, `beverages`.

**Lokalisierung:** fest auf Deutsch. `initializeDateFormatting('de_DE')` in `main()`, `flutter_localizations` eingebunden. Texte stehen direkt im Code, es gibt keine ARB-Dateien.

## Android-Signing

`android/app/build.gradle.kts` liest `android/key.properties` (per `.gitignore` ausgeschlossen) und signiert damit den Release-Build. Fehlt die Datei, greifen leere Defaults und der Release-Build schlägt fehl — das ist beabsichtigt. Keystore liegt unter `android/app/upload-keystore.jks`. `namespace` und `applicationId` sind `de.tcmoeckmuehl.app`; laut Regel 7 nicht ohne Freigabe ändern.

## Bekannte Altlasten

Diese Punkte sind erfasst und werden über `docs/AUFGABEN.md` abgearbeitet — nicht nebenbei mitreparieren:

- **Die PocketBase-URL ist in `lib/main.dart` fest verdrahtet** (`https://api.tc-moeckmuehl.de`). Solange das so ist, läuft jeder lokale Start gegen die Produktivdatenbank. Das steht im direkten Widerspruch zu Regel 2 — bis zur Umstellung auf `--dart-define=PB_URL=...` ist beim Starten der App besondere Vorsicht geboten.
- `README.md` enthält eingecheckte Merge-Konflikt-Marker (`<<<<<<< HEAD` … `>>>>>>> Backup vor Navigations-Umbau`).
- `android/app/src/main/kotlin/com/example/tc_moeckmuehl/MainActivity.kt` deklariert `package de.tcmoeckmuehl.app` — Pfad und Package passen nicht zusammen.
- Es existiert keine lokale Dev-Instanz und keine `docs/STATUS.md`; beides wird in Abschnitt A und C der Aufgabenliste angelegt.
- Testabdeckung besteht aus zwei Dateien (`test/widget_test.dart`, `test/trainer_portal_pages_test.dart`). Es gibt keine Integrationstests, obwohl die Testpflicht sie für Buchung, Login und Rollen verlangt.
- Mehrere Tab-Dateien sind sehr groß (`court_tab.dart` ~2000 Zeilen, `trainer_portal_pages.dart` ~1760, `vorstand_members_tab.dart` ~1360). Änderungen dort brauchen mehr Lesezeit als die Dateigröße vermuten lässt.
