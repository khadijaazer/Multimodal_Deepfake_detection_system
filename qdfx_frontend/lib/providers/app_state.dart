import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppState extends ChangeNotifier {
  // ----------------------------------------------------------------------
  // 1. NAVIGATION & UI STATE
  // ----------------------------------------------------------------------
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  // ----------------------------------------------------------------------
  // 2. THEME MANAGEMENT
  // ----------------------------------------------------------------------
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // ----------------------------------------------------------------------
  // 3. USER DATA (Aligned with Supabase Database)
  // ----------------------------------------------------------------------
  String _userName = "Guest User";
  String _userEmail = "";
  String _companyName = ""; 
  String _jobTitle = "";

  String get userName => _userName;
  String get userEmail => _userEmail;
  String get companyName => _companyName;
  String get jobTitle => _jobTitle;

  // ----------------------------------------------------------------------
  // 4. BILLING & SUBSCRIPTION (Replaces the old "Roles")
  // ----------------------------------------------------------------------
  // Plans: 'free', 'pro', 'enterprise'
  String _subscriptionPlan = "free"; 
  int _credits = 3; // Give 3 Free trial credits on signup

  String get subscriptionPlan => _subscriptionPlan;
  int get credits => _credits;
  
  // To avoid breaking your existing UI that looks for "userRole"
  String get userRole => _subscriptionPlan; 

  bool get canUpload => _credits > 0;

  // --- SUPABASE INTEGRATION METHOD ---
  // Call this right after Supabase Auth succeeds to load real DB data
  void setLoggedInUser(String name, String email, String plan, int creds, String company) {
    _userName = name;
    _userEmail = email;
    _subscriptionPlan = plan.toLowerCase();
    _credits = creds;
    _companyName = company;
    notifyListeners();
  }

  // Used to update local UI before pushing to DB
  void updateUserProfile(String name, String email) {
    _userName = name;
    _userEmail = email;
    notifyListeners();
  }

  // Simulate buying credits (Called from Billing Screen)
  void purchasePlan(String plan, int creditsAmount) {
    _subscriptionPlan = plan.toLowerCase();
    _credits += creditsAmount;
    notifyListeners();
  }

  // Deduct a credit when doing a Deepfake Scan
  void deductCredit() {
    if (_credits > 0) {
      _credits--;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------------
  // 5. THEME DEFINITIONS
  // ----------------------------------------------------------------------
  ThemeData get currentTheme => _isDarkMode ? _darkTheme : _lightTheme;

  static final _textStyle = GoogleFonts.interTextTheme();

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF1F5F9),
    primaryColor: const Color(0xFF2E86DE),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    textTheme: _textStyle.apply(bodyColor: const Color(0xFF1E293B)),
    iconTheme: const IconThemeData(color: Color(0xFF64748B)),
    useMaterial3: true,
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    primaryColor: const Color(0xFF2E86DE),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    textTheme: _textStyle.apply(bodyColor: Colors.white),
    iconTheme: const IconThemeData(color: Colors.white70),
    useMaterial3: true,
  );

  // ----------------------------------------------------------------------
  // 6. LANGUAGE 
  // ----------------------------------------------------------------------
  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  void changeLanguage(String code) {
    _currentLocale = Locale(code);
    notifyListeners();
  }
}