import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart'; // Für deutsches Datum
import 'package:flutter_localizations/flutter_localizations.dart'; //für deutschen Kalender
import 'dart:async';

import 'tabs/home_tab.dart';
import 'tabs/court_tab.dart';
import 'tabs/drink_tab.dart';
import 'tabs/profile_tab.dart';
import 'admin/vorstand_home.dart';
import 'admin/trainer_home.dart';
import 'admin/admin_home.dart';

// Deine Settings-Record-ID hier eintragen:
const String settingsRecordId = 'b9wkhz7wuqxqpid';
late final PocketBase pb;

// Globale Farbnutzer
// Hintergrundfarbe der App
final ValueNotifier<Color> appBackColor =
    ValueNotifier<Color>(Colors.white);

// Vordergrund / Akzentfarbe (bisher grün)
final ValueNotifier<Color> appFrontColor =
    ValueNotifier<Color>(Colors.green);

// Farben für Platzbelegung
final ValueNotifier<Color> ownBookingColor =
    ValueNotifier<Color>(Colors.blue); // Eigene Buchungen

final ValueNotifier<Color> otherBookingColor =
    ValueNotifier<Color>(Colors.red); // Fremde Buchungen

final ValueNotifier<Color> eventBookingColor =
    ValueNotifier<Color>(Colors.purple); // Verbands-/Turnierbuchungen


// Hilfsfunktionen für Hex <-> Color
Color colorFromHex(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    var value = hex.toUpperCase().replaceAll('#', '');
    if (value.length == 6) {
      value = 'FF$value'; // volle Deckkraft
    }
    return Color(int.parse(value, radix: 16));
  } catch (_) {
    return fallback;
  }
}

String colorToHex(Color color) {
  final value = color.toARGB32().toRadixString(16).padLeft(8, '0'); // AARRGGBB
  return '#${value.substring(2)}'; // wir speichern nur RRGGBB
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de_DE', null);

  // SharedPreferences einmal laden
  late final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint("Fehler beim Laden von SharedPreferences: $e");
    rethrow;
  }

  // PocketBase mit persistentem AuthStore initialisieren
  try {
    pb = PocketBase(
      'https://api.tc-moeckmuehl.de',
      authStore: AsyncAuthStore(
        save: (String data) async {
          try {
            await prefs.setString('pb_auth', data);
          } catch (e) {
            debugPrint("Fehler beim Speichern des Auth-Tokens: $e");
          }
        },
        // initial ist ein String? (keine Funktion!)
        initial: prefs.getString('pb_auth'),
        clear: () async {
          try {
            await prefs.remove('pb_auth');
          } catch (e) {
            debugPrint("Fehler beim Löschen des Auth-Tokens: $e");
          }
        },
      ),
    );
  } catch (e) {
    debugPrint("Fehler bei PocketBase-Initialisierung: $e");
    // Continue anyway - app kann offline laufen
  }

  // Optional: gespeicherte Session refreshen (mit Timeout)
  try {
    await pb.collection('users').authRefresh().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint("Session-Refresh Timeout");
        throw TimeoutException('Auth refresh timed out');
      },
    );
  } catch (e) {
    debugPrint("Fehler beim Session-Refresh: $e");
    try {
      pb.authStore.clear();
    } catch (e2) {
      debugPrint("Fehler beim Löschen der Auth-Session: $e2");
    }
  }

  // Globale Farben aus der settings-Collection laden (mit Timeout)
  try {
    final settings = await pb
        .collection('settings')
        .getOne(settingsRecordId)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint("Settings-Abfrage Timeout");
            throw TimeoutException('Settings fetch timed out');
          },
        );

    appBackColor.value = colorFromHex(
        settings.getStringValue('app_colour_back'), Colors.white);
    appFrontColor.value = colorFromHex(
        settings.getStringValue('app_colour_front'), Colors.green);

    ownBookingColor.value = colorFromHex(
        settings.getStringValue('court_color_own'), Colors.blue);
    otherBookingColor.value = colorFromHex(
        settings.getStringValue('court_color_other'), Colors.red);
    eventBookingColor.value = colorFromHex(
        settings.getStringValue('court_color_event'), Colors.purple);
  } catch (e) {
    debugPrint("Fehler beim Laden der Farben: $e");
    // Falls Laden fehlschlägt, bleiben die Standardfarben
  }

  runApp(const TCMoeckmuehlApp());
}

class TCMoeckmuehlApp extends StatelessWidget {
  const TCMoeckmuehlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appFrontColor,
      builder: (context, frontColor, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: appBackColor,
          builder: (context, backColor, _) {
            return MaterialApp(
              title: 'TC Möckmühl',
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('de', 'DE'),
              ],
              locale: const Locale('de', 'DE'),
              theme: ThemeData(
                colorSchemeSeed: frontColor,          // Akzent/Vordergrund
                scaffoldBackgroundColor: backColor,   // Hintergrund
                appBarTheme: AppBarTheme(
                  backgroundColor: frontColor,
                  foregroundColor: Colors.white,
                ),
                useMaterial3: true,
              ),
              home: const AuthWrapper(),
            );
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final forenameController = TextEditingController();
  final surnameController = TextEditingController();

  bool isLoading = false;
  bool isLoginMode = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    forenameController.dispose();
    surnameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (pb.authStore.isValid) return const HomeScreen();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_tennis, size: 80, color: Colors.green),
                const SizedBox(height: 10),
                Text(
                  isLoginMode ? "TC Möckmühl Login" : "Konto erstellen",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Vor-/Nachname nur bei Registrierung
                if (!isLoginMode) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: forenameController,
                          decoration: const InputDecoration(
                            labelText: "Vorname",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          autofillHints: const [AutofillHints.givenName],
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: surnameController,
                          decoration: const InputDecoration(
                            labelText: "Nachname",
                            border: OutlineInputBorder(),
                          ),
                          autofillHints: const [AutofillHints.familyName],
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                ],

                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "E-Mail",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: isLoginMode ? "Passwort" : "Neues Passwort",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  obscureText: true,
                  autofillHints: isLoginMode
                      ? const [AutofillHints.password]
                      : const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () =>
                      isLoginMode ? _login() : _register(),
                ),

                // Passwort vergessen (nur Login)
                if (isLoginMode)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text("Passwort vergessen?"),
                    ),
                  ),

                const SizedBox(height: 20),
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: appFrontColor.value,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isLoginMode ? _login : _register,
                        child:
                            Text(isLoginMode ? "Einloggen" : "Registrieren"),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: () =>
                            setState(() => isLoginMode = !isLoginMode),
                        child: Text(
                          isLoginMode
                              ? "Noch kein Konto? Hier registrieren"
                              : "Bereits ein Konto? Zum Login",
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
  setState(() => isLoading = true);
  try {
    await pb.collection('users').authWithPassword(
      emailController.text.trim(),
      passwordController.text,
    );

    // Login ok → HomeScreen
    setState(() {}); 
  } catch (e) {
    debugPrint("Login-Fehler: $e");

    if (e is ClientException) {
      final msg = (e.response['message'] ?? '').toString().toLowerCase();

      // Spezielle Meldung für "E-Mail noch nicht verifiziert"
      if (msg.contains('verify') && msg.contains('email')) {
        _showError(
          "E-Mail-Adresse noch nicht bestätigt.\n"
          "Bitte E-Mail öffnen und den Bestätigungslink anklicken.",
        );
        return;
      }
    }

    _showError("Login fehlgeschlagen. Daten prüfen.");
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}

  Future<void> _register() async {
  if (forenameController.text.isEmpty ||
      surnameController.text.isEmpty ||
      emailController.text.isEmpty ||
      passwordController.text.length < 8) {
    _showError(
      "Bitte alle Felder füllen (Vorname, Nachname, E-Mail, Passwort min. 8 Zeichen).",
    );
    return;
  }

  setState(() => isLoading = true);
  try {
    // 1. User anlegen
    await pb.collection('users').create(body: {
      "email": emailController.text.trim(),
      "password": passwordController.text,
      "passwordConfirm": passwordController.text,
      "forename": forenameController.text.trim(),
      "surname": surnameController.text.trim(),
      "name":
          "${forenameController.text.trim()} ${surnameController.text.trim()}",
    });

    // 2. Verifizierungs-Mail auslösen
    await pb.collection('users').requestVerification(
      emailController.text.trim(),
    );

    // 3. Hinweis anzeigen und auf Login umschalten
    _showSuccess(
      "Registrierung erfolgreich.\nBitte E-Mail-Adresse bestätigen, bevor du dich einloggst.",
    );
    setState(() => isLoginMode = true);
  } catch (e) {
    // Spezifische Meldung, wenn E-Mail schon existiert
    if (e is ClientException) {
      final msg = (e.response['message'] ?? '').toString().toLowerCase();
      final data = e.response['data'] as Map<String, dynamic>?;

      final emailError = data?['email']?['message']?.toString().toLowerCase();

      if (emailError != null &&
          (emailError.contains('exists') ||
           emailError.contains('already'))) {
        _showError("Diese E-Mail-Adresse ist bereits registriert.");
        return;
      }

      if (msg.contains('exists') || msg.contains('already')) {
        _showError("Diese E-Mail-Adresse ist bereits registriert.");
        return;
      }
    }

    _showError("Registrierung fehlgeschlagen: $e");
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}
  
  Future<void> _resetPassword() async {
    if (emailController.text.isEmpty) {
      _showError("Bitte E-Mail eingeben, um Passwort zurückzusetzen.");
      return;
    }
    try {
      await pb
          .collection('users')
          .requestPasswordReset(emailController.text.trim());
      _showSuccess("E-Mail zum Zurücksetzen wurde gesendet!");
    } catch (e) {
      _showError("Fehler: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  DateTime? _targetDate;

  void jumpToCourtTab(DateTime date) {
    setState(() {
      _targetDate = date; // Datum speichern
      _index = 1;         // Tab wechseln
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final user = pb.authStore.model;
    if (user == null) return const AuthWrapper();

    final record = user as RecordModel;

    // Admin-Rollen
    final isAppAdmin     = record.getBoolValue('auth_admin_app');
    final isBoardAdmin   = record.getBoolValue('auth_admin_board');
    final isTrainerAdmin = record.getBoolValue('auth_admin_trainer');

    // Vorstands-Rechte
    final permBoardMember   = record.getIntValue('perm_board_member');
    final permBoardCash     = record.getIntValue('perm_board_cash');
    final permBoardBooking  = record.getIntValue('perm_board_booking');
    final permBoardBeverage = record.getIntValue('perm_board_beverage');

    // Trainer-Rechte
    final permTrainerTrainer  = record.getIntValue('perm_trainer_trainer');
    final permTrainerMember   = record.getIntValue('perm_trainer_member');
    final permTrainerBill     = record.getIntValue('perm_trainer_bill');
    final permTrainerReminder = record.getIntValue('perm_trainer_reminder');

    // Hat irgendein Vorstandsrecht oder ist Board-Admin/App-Admin?
    final hasBoardRight = isAppAdmin ||
        isBoardAdmin ||
        permBoardMember   > 0 ||
        permBoardCash     > 0 ||
        permBoardBooking  > 0 ||
        permBoardBeverage > 0;

    // Hat irgendein Trainerrecht oder ist Trainer-Admin/App-Admin?
    final hasTrainerRight = isAppAdmin ||
        isTrainerAdmin ||
        permTrainerTrainer  > 0 ||
        permTrainerMember   > 0 ||
        permTrainerBill     > 0 ||
        permTrainerReminder > 0;

    // Rechte in eine Liste packen
    final List<_RoleEntry> roles = [];

    // Vorstand-Button anzeigen, wenn irgendein Board-Recht
    if (hasBoardRight) {
      roles.add(_RoleEntry(
        label: 'Vorstand',
        icon: Icons.account_balance,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const VorstandHomeScreen(),
            ),
          );
        },
      ));
    }

    // Trainer-Button anzeigen, wenn irgendein Trainer-Recht
    if (hasTrainerRight) {
      roles.add(_RoleEntry(
        label: 'Trainer',
        icon: Icons.fitness_center,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TrainerHomeScreen(),
            ),
          );
        },
      ));
    }

    // Admin-Button nur für App-Admin
    if (isAppAdmin) {
      roles.add(_RoleEntry(
        label: 'Admin',
        icon: Icons.settings,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AdminHomeScreen(),
            ),
          );
        },
      ));
    }

        return Scaffold(
            body: IndexedStack(
        index: _index,
        children: [
          HomeTab(onNavigateToCourt: jumpToCourtTab), // Kein const!
          CourtTab(key: ValueKey(_targetDate), initialDate: _targetDate), // Kein const!
          const DrinkTab(),
          ProfileTab(onLogout: () => setState(() => pb.authStore.clear())),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (v) => setState(() => _index = v),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: appFrontColor.value,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Start"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Plätze"),
          BottomNavigationBarItem(icon: Icon(Icons.local_drink), label: "Getränke"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
      floatingActionButton: roles.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 70.0), // höher setzen
              child: RoleFab(roles: roles),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }
}

class _RoleEntry {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _RoleEntry({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}
class RoleFab extends StatefulWidget {
  final List<_RoleEntry> roles;
  const RoleFab({super.key, required this.roles});

  @override
  State<RoleFab> createState() => _RoleFabState();
}

class _RoleFabState extends State<RoleFab> {
  bool _isOpen = false;

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    // nur eine Rolle: wie klassischer einzelner FAB
    if (widget.roles.length == 1) {
      final r = widget.roles.first;
      return FloatingActionButton(
        heroTag: 'fab_single_role',
        onPressed: r.onTap,
        backgroundColor: appFrontColor.value,
        child: Icon(
          r.icon,
          color: Colors.white,
        ),
      );
    }

    // mehrere Rollen: aufgeklappte Buttons
    const double buttonSpacing = 60.0;

    return SizedBox(
      width: 80,
      height: 80 + widget.roles.length * buttonSpacing,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          if (_isOpen)
            ...List.generate(widget.roles.length, (index) {
              final r = widget.roles[index];
              return Positioned(
                bottom: (index + 1) * buttonSpacing,
                right: 0,
                child: FloatingActionButton.small(
                  heroTag: 'fab_role_$index',
                  backgroundColor: appFrontColor.value,
                  onPressed: r.onTap,
                  child: Icon(
                    r.icon,
                    color: Colors.white,
                  ),
                ),
              );
            }),
          FloatingActionButton(
            heroTag: 'fab_role_main',
            backgroundColor: appFrontColor.value,
            onPressed: _toggle,
            child: Icon(
              _isOpen ? Icons.close : Icons.menu,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}