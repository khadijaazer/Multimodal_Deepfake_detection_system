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
  // 3. USER DATA & MULTI-ROLE LOGIC
  // ----------------------------------------------------------------------
  String _userName = "Karim Benz";
  String _userEmail = "karim@qdfx.dz";
  String _userRole = "individual"; // 'individual', 'enterprise', 'police'

  // Role Specific Data (Managed here for the Profile Screen)
  String _badgeId = "---";
  String _rank = "---";
  String _companyName = "---";
  String _nifId = "---";

  // Getters
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userRole => _userRole;
  String get badgeId => _badgeId;
  String get rank => _rank;
  String get companyName => _companyName;
  String get nifId => _nifId;

  // Function to Update Profile (Used in EditProfileScreen)
  void updateUserProfile(String name, String email) {
    _userName = name;
    _userEmail = email;
    notifyListeners();
  }

  // ----------------------------------------------------------------------
  // 4. THE ROLE SWITCHER (FOR TESTING THE 3 DESIGNS)
  // ----------------------------------------------------------------------
  void setRole(String role) {
    _userRole = role.toLowerCase();

    // Fill with mock data based on role so you can see the designs work
    if (_userRole == 'police') {
      _userName = "Officer Ahmed Yassine";
      _userEmail = "a.yassine@dgsn.dz";
      _badgeId = "DGSN-7721-X";
      _rank = "Chief Inspector";
    } else if (_userRole == 'enterprise') {
      _userName = "Media Administrator";
      _userEmail = "it@ennahar.dz";
      _companyName = "Ennahar Media Group";
      _nifId = "0016340092122";
    } else {
      _userName = "Karim Benz";
      _userEmail = "karim@gmail.com";
      _userRole = "individual";
      _badgeId = "---";
      _rank = "---";
      _companyName = "---";
      _nifId = "---";
    }

    notifyListeners(); // This refreshes all UI components immediately
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
  // 6. LANGUAGE (Optional but included for SaaS)
  // ----------------------------------------------------------------------
  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;

  void changeLanguage(String code) {
    _currentLocale = Locale(code);
    notifyListeners();
  }
}