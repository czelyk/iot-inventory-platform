import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// --- Internationalization Imports ---
import 'package:smart_kuhlschrank/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:smart_kuhlschrank/providers/locale_provider.dart';
import 'package:smart_kuhlschrank/providers/app_settings_provider.dart';

// --- Firebase Imports ---
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_kuhlschrank/widgets/auth_gate.dart';
import 'firebase_options.dart';

// --- Screen Imports ---
import 'screens/home_screen.dart';
import 'screens/shopping_list_screen.dart';
import 'screens/notifications.dart';
import 'screens/account.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final settingsProvider = Provider.of<AppSettingsProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,

      // Tema Modunu Ayarlardan Al
      themeMode: settingsProvider.themeMode,

      // Aydınlık Tema
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),

      // Karanlık Tema
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal.shade900,
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.dark(
          primary: Colors.teal.shade200,
          secondary: Colors.tealAccent,
        ),
      ),

      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de', ''),
        Locale('en', ''),
        Locale('tr', ''),
      ],
      home: const AuthGate(),
    );
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    ShoppingListScreen(),
    NotificationsScreen(),
    AccountScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.inventory_2),
              label: l10n.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.shopping_cart),
              label: l10n.shopping,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.tune),
              label: l10n.notifications,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_circle),
              label: l10n.account,
            ),
          ],
        ),
      );
  }
}
