import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'layout/responsive_layout.dart';
import 'widgets/sidebar.dart';
import 'l10n/translations.dart';

// SCREEN IMPORTS
import 'screens/dashboard_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/api_screen.dart';
import 'screens/auth/role_selection_screen.dart'; 
import 'screens/scam_detection_screen.dart'; // <--- THIS WAS MISSING

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: const QDFXApp(),
    ),
  );
}

class QDFXApp extends StatelessWidget {
  const QDFXApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QDFX',
      theme: appState.currentTheme,
      
      // Localization
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

      // Navigation Routes
      initialRoute: '/auth', 

      routes: {
        '/auth': (context) => const RoleSelectionScreen(),
        '/': (context) => const MainScaffold(), 
      },
    );
  }
}

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedIndex = Provider.of<AppState>(context).selectedIndex;

    Widget currentScreen;
    switch (selectedIndex) {
      case 0: 
        currentScreen = const DashboardContent(); 
        break;
      case 1: 
        currentScreen = const BillingScreen(); 
        break;
      case 2: 
        currentScreen = const ApiScreen(); 
        break;
      case 3: 
        // No 'const' here because it is stateful
        currentScreen = const ScamDetectionScreen(); 
        break;
      default: 
        currentScreen = const DashboardContent();
    }

    return Scaffold(
      body: ResponsiveLayout(
        mobileBody: MobileLayout(child: currentScreen),
        desktopBody: Row(
          children: [
            const Sidebar(),
            Expanded(child: currentScreen),
          ],
        ),
      ),
    );
  }
}

class MobileLayout extends StatelessWidget {
  final Widget child;
  const MobileLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final lang = appState.currentLocale.languageCode;
    String t(String key) => AppTranslations.get(lang, key);

    return Scaffold(
      appBar: AppBar(
         title: Image.asset(
          'assets/logo.png', 
          height: 40, 
          errorBuilder: (c,e,s) => const Text("QDFX"),
        ),
        centerTitle: true, 
        backgroundColor: Theme.of(context).cardTheme.color,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (val) => appState.changeLanguage(val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'en', child: Text("English")),
              const PopupMenuItem(value: 'fr', child: Text("Français")),
              const PopupMenuItem(value: 'ar', child: Text("العربية")),
            ],
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).cardTheme.color,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        // Ensure index doesn't crash mobile nav if > 2
        currentIndex: appState.selectedIndex > 2 ? 0 : appState.selectedIndex,
        onTap: (index) => appState.setIndex(index),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard), label: t('dashboard')),
          BottomNavigationBarItem(icon: const Icon(Icons.credit_card), label: t('billing')),
          BottomNavigationBarItem(icon: const Icon(Icons.code), label: t('api')),
        ],
      ),
    );
  }
}