import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/date_symbol_data_local.dart'; // Für deutsches Datum
import 'package:flutter_localizations/flutter_localizations.dart'; //für deutschen Kalender

import 'tabs/home_tab.dart';
import 'tabs/court_tab.dart';
import 'tabs/drink_tab.dart';
import 'tabs/profile_tab.dart';
import 'admin/vorstand_home.dart';
import 'admin/trainer_home.dart';
import 'admin/admin_home.dart';

// Globale PocketBase-Instanz
final pb = PocketBase('http://api.tc-moeckmuehl.de:8090');

// Deine Settings-Record-ID hier eintragen:
const String settingsRecordId = 'b9wkhz7wuqxqpid';

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

  // Globale Farben aus der settings-Collection laden
  try {
    final settings =
        await pb.collection('settings').getOne(settingsRecordId);

    appBackColor.value = colorFromHex(
        settings.getStringValue('app_colour_back'), Colors.white);
    appFrontColor.value = colorFromHex(
        settings.getStringValue('app_colour_front'), Colors.green);

    ownBookingColor.value = colorFromHex(
        settings.getStringValue('court_color_own'), Colors.blue);
    otherBookingColor.value = colorFromHex(
        settings.getStringValue('court_color_other'), Colors.red);
  } catch (_) {
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
  final surnameController = TextEditingController(); // Neu für Registrierung
  bool isLoading = false;
  bool isLoginMode = true; // Schalter zwischen Login und Registrierung

  @override
  Widget build(BuildContext context) {
    if (pb.authStore.isValid) return const HomeScreen();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sports_tennis, size: 80, color: Colors.green),
              const SizedBox(height: 10),
              Text(
                isLoginMode ? "TC Möckmühl Login" : "Konto erstellen",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              
              // Name Feld (nur bei Registrierung sichtbar)
              if (!isLoginMode) ...[
                TextField(
                  controller: surnameController,
                  decoration: const InputDecoration(
                    labelText: "Vollständiger Name",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
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
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: "Passwort",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              
              // Passwort vergessen (nur im Login-Modus)
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
                      child: Text(isLoginMode ? "Einloggen" : "Registrieren"),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () => setState(() => isLoginMode = !isLoginMode),
                      child: Text(isLoginMode 
                        ? "Noch kein Konto? Hier registrieren" 
                        : "Bereits ein Konto? Zum Login"),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGIK FUNKTIONEN ---

  Future<void> _login() async {
    setState(() => isLoading = true);
    try {
      await pb.collection('users').authWithPassword(
        emailController.text.trim(),
        passwordController.text,
      );
      setState(() {}); // Wechsel zum HomeScreen
    } catch (e) {
      _showError("Login fehlgeschlagen. Daten prüfen.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _register() async {
    if (surnameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.length < 8) {
      _showError("Bitte alle Felder füllen (Passwort min. 8 Zeichen).");
      return;
    }
    setState(() => isLoading = true);
    try {
      await pb.collection('users').create(body: {
        "email": emailController.text.trim(),
        "password": passwordController.text,
        "passwordConfirm": passwordController.text,
        "name": surnameController.text.trim(),
      });
      // Nach Registrierung direkt einloggen
      await _login();
    } catch (e) {
      _showError("Registrierung fehlgeschlagen: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (emailController.text.isEmpty) {
      _showError("Bitte E-Mail eingeben, um Passwort zurückzusetzen.");
      return;
    }
    try {
      await pb.collection('users').requestPasswordReset(emailController.text.trim());
      _showSuccess("E-Mail zum Zurücksetzen wurde gesendet!");
    } catch (e) {
      _showError("Fehler: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
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