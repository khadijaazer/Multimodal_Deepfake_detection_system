import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  // 3. USER DATA
  // ----------------------------------------------------------------------
  String _userName = "User";
  String _userEmail = "";
  String _companyName = "";
  
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get companyName => _companyName;
  
  // Authentication state
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;
  
  // Landing page seen state
  bool _hasSeenLanding = false;
  bool get hasSeenLanding => _hasSeenLanding;

  // ----------------------------------------------------------------------
  // 4. UNIFIED BILLING & USAGE LIMITS
  // ----------------------------------------------------------------------
  String _subscriptionPlan = "free"; // 'free', 'pro', 'enterprise'
  
  // Real-time Extension Minutes
  int _minutesRemaining = 0;
  
  // Video Scan Usage
  int _scansUsedThisMonth = 0;
  
  // Trial scans for anonymous/free users
  int _remainingTrialScans = 5;
  
  String get subscriptionPlan => _subscriptionPlan;
  String get userRole => _subscriptionPlan;
  int get scansUsed => _scansUsedThisMonth;
  int get remainingTrialScans => _remainingTrialScans;
  
  // Limits: Free = 5 scans, Pro/Enterprise = Unlimited (9999)
  int get maxScans => _subscriptionPlan == 'free' ? 5 : 9999;
  
  // Security check for DeepfakeScreen
  bool get canUpload => _scansUsedThisMonth < maxScans;
  
  // Combined check for if user has any scans remaining
  bool get hasScansRemaining {
    if (_isLoggedIn && _subscriptionPlan != 'free') {
      return true;
    }
    return _remainingTrialScans > 0;
  }
  
  // Formats minutes into hours/minutes
  String get formattedBalance {
    if (_subscriptionPlan == 'free') return "0m";
    int h = _minutesRemaining ~/ 60;
    int m = _minutesRemaining % 60;
    if (h > 0) return "${h}h ${m}m";
    return "${m}m";
  }

  // ----------------------------------------------------------------------
  // 5. STATE UPDATE METHODS
  // ----------------------------------------------------------------------
  
  // Initialize from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _remainingTrialScans = prefs.getInt('remaining_trial_scans') ?? 5;
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _hasSeenLanding = prefs.getBool('has_seen_landing') ?? false;
    
    if (_isLoggedIn) {
      _userName = prefs.getString('user_name') ?? "User";
      _userEmail = prefs.getString('user_email') ?? "";
      _subscriptionPlan = prefs.getString('subscription_plan') ?? "free";
      _companyName = prefs.getString('company_name') ?? "";
      _scansUsedThisMonth = prefs.getInt('scans_used') ?? 0;
      _minutesRemaining = prefs.getInt('minutes_remaining') ?? 0;
    }
    
    notifyListeners();
  }
  
  // Refresh user's subscription plan from database
  Future<void> refreshUserPlan() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('subscription_plan')
            .eq('id', user.id)
            .single();
        
        final String dbPlan = data['subscription_plan'] ?? "free";
        if (_subscriptionPlan != dbPlan) {
          _subscriptionPlan = dbPlan;
          print("✅ Plan refreshed from DB: $_subscriptionPlan");
          notifyListeners();
        }
      }
    } catch (e) {
      print("❌ Error refreshing plan: $e");
      // Keep existing plan if error occurs
    }
  }
  
  // Called by auth_screen.dart
  void setLoggedInUser(String name, String email, String plan, int creds, String company) {
    _userName = name;
    _userEmail = email;
    _subscriptionPlan = plan.toLowerCase();
    _isLoggedIn = true;
    
    // Reset trial scans when user logs in
    _remainingTrialScans = 0;
    
    if (_subscriptionPlan != 'free') {
      _minutesRemaining = 600;
    }
    
    _companyName = company;
    _saveToPreferences();
    notifyListeners();
  }
  
  // Called when user logs out
  void logout() {
    _isLoggedIn = false;
    _userName = "User";
    _userEmail = "";
    _subscriptionPlan = "free";
    _companyName = "";
    _scansUsedThisMonth = 0;
    _remainingTrialScans = 5;
    _minutesRemaining = 0;
    _hasSeenLanding = false;
    
    _clearPreferences();
    notifyListeners();
  }
  
  // Called by profile_screen.dart
  void updateUserProfile(String name, String email) {
    _userName = name;
    _userEmail = email;
    _saveToPreferences();
    notifyListeners();
  }
  
  // Called by billing_screen.dart for direct updates (legacy)
  void purchasePlan(String planKey, int minutes) {
    // planKey is already normalized: 'free', 'pro', or 'enterprise'
    _subscriptionPlan = planKey;
    _minutesRemaining += minutes;
    _remainingTrialScans = 0;
    _saveToPreferences();
    notifyListeners();
  }
  
  // Called by deepfake_screen.dart for subscribed users
  void recordScanUsage() {
    _scansUsedThisMonth++;
    _saveToPreferences();
    notifyListeners();
  }
  
  // Called by landing_screen.dart for anonymous users
  void useTrialScan() async {
    if (_remainingTrialScans > 0) {
      _remainingTrialScans--;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('remaining_trial_scans', _remainingTrialScans);
      
      notifyListeners();
    }
  }
  
  // NEW: Set landing page as seen
  void setSeenLanding() async {
    _hasSeenLanding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_landing', true);
    notifyListeners();
  }
  
  // Reset trial scans (useful for testing)
  void resetTrialScans() async {
    _remainingTrialScans = 5;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('remaining_trial_scans', _remainingTrialScans);
    notifyListeners();
  }
  
  // Check if user is on free trial
  bool get isOnTrial => !_isLoggedIn && _remainingTrialScans > 0;
  
  // Get remaining trial percentage
  double get trialProgress => _remainingTrialScans / 5;
  
  // Get formatted trial status message
  String get trialStatusMessage {
    if (_isLoggedIn) {
      if (_subscriptionPlan == 'free') {
        return "Free Plan - Upgrade for unlimited scans";
      }
      return "Pro Plan - Unlimited scans";
    }
    return "$_remainingTrialScans/5 trial scans remaining";
  }

  // ----------------------------------------------------------------------
  // PERSISTENCE METHODS
  // ----------------------------------------------------------------------
  
  Future<void> _saveToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', _isLoggedIn);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('subscription_plan', _subscriptionPlan);
    await prefs.setString('company_name', _companyName);
    await prefs.setInt('remaining_trial_scans', _remainingTrialScans);
    await prefs.setInt('scans_used', _scansUsedThisMonth);
    await prefs.setInt('minutes_remaining', _minutesRemaining);
    await prefs.setBool('has_seen_landing', _hasSeenLanding);
  }
  
  Future<void> _clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('subscription_plan');
    await prefs.remove('company_name');
    await prefs.remove('scans_used');
    await prefs.remove('minutes_remaining');
    await prefs.setInt('remaining_trial_scans', 5);
    await prefs.setBool('has_seen_landing', false);
  }

  // ----------------------------------------------------------------------
  // 6. THEME DEFINITIONS
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
  // 7. LANGUAGE
  // ----------------------------------------------------------------------
  
  Locale _currentLocale = const Locale('en');
  Locale get currentLocale => _currentLocale;
  
  void changeLanguage(String code) {
    _currentLocale = Locale(code);
    notifyListeners();
  }
}