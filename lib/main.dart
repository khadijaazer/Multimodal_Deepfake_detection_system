import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/app_state.dart';
import 'layout/responsive_layout.dart';
import 'widgets/sidebar.dart';
import 'l10n/translations.dart';
import 'theme/app_theme.dart';

// SCREEN IMPORTS
import 'screens/dashboard_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/api_screen.dart';
import 'screens/scam_detection_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/deepfake_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/realtime_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qfvtxabqxurmnbsvznrj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmdnR4YWJxeHVybW5ic3Z6bnJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMTk4OTEsImV4cCI6MjA4Nzg5NTg5MX0.-yvfWpIVlgeIxAZlRC4Hk9tDyE5ihNe3YsahE2LVdJU',
  );

  final appState = AppState();
  await appState.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => appState,
      child: const QDFXApp(),
    ),
  );
}

// ─── App Root ─────────────────────────────────────────────────────────────────

class QDFXApp extends StatelessWidget {
  const QDFXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DETECTINI',
      theme: appState.currentTheme,
      locale: appState.currentLocale,
      supportedLocales: const [
        Locale('en', ''),
        Locale('fr', ''),
        Locale('ar', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/landing',
      routes: {
        '/landing': (context) => const LandingScreen(),
        '/auth':    (context) => const AuthScreen(),
        '/':        (context) => const MainScaffold(),
      },
    );
  }
}

// ─── Main Scaffold ────────────────────────────────────────────────────────────

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final appState    = Provider.of<AppState>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 600;

    final Widget currentScreen = _screenForIndex(appState.selectedIndex);

    // ── Mobile: Scaffold with Drawer ─────────────────────────────────
    if (isMobile) {
      return _MobileLayout(child: currentScreen);
    }

    // ── Tablet & Desktop: persistent sidebar ─────────────────────────
    return Scaffold(
      body: Row(
        children: [
          const Sidebar(),
          Expanded(child: currentScreen),
        ],
      ),
    );
  }

  Widget _screenForIndex(int index) {
    switch (index) {
      case 0:  return const DashboardContent();
      case 1:  return const BillingScreen();
      case 2:  return const ApiScreen();
      case 3:  return const ScamDetectionScreen();
      case 4:  return const DeepfakeScreen();
      case 5:  return const RealTimeScreen();
      case 6:  return const HistoryScreen();
      case 7:  return const ProfileScreen();
      default: return const DashboardContent();
    }
  }
}

// ─── Mobile Layout ────────────────────────────────────────────────────────────

class _MobileLayout extends StatefulWidget {
  final Widget child;
  const _MobileLayout({required this.child});

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      
      // ─── AppBar with ONLY the hamburger menu button ───────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: null,
        actions: const [],
      ),

      // ─── Drawer (uses the same Sidebar widget) ───────────────────────
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: const Sidebar(),
      ),

      // ─── Body ─────────────────────────────────────────────────────────
      body: widget.child,
    );
  }
}