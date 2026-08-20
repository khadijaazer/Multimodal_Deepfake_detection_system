import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';

class LoginScreen extends StatefulWidget {
  final String selectedRole; // 'individual', 'enterprise', 'police'
  const LoginScreen({super.key, required this.selectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Toggle: True = Login Screen, False = Sign Up / Request Access Screen
  bool isLogin = true; 
  
  // Controllers
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _nifCtrl = TextEditingController(); 
  final _badgeCtrl = TextEditingController(); 
  final _rankCtrl = TextEditingController(); 

  @override
  Widget build(BuildContext context) {
    // 1. GET CURRENT THEME STATE
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // 2. DEFINE DYNAMIC COLORS
    // Backgrounds
    Color scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color inputFill = isDark ? const Color(0xFF0F172A) : Colors.grey.shade100;
    
    // Text
    Color textMain = isDark ? Colors.white : Colors.black87;
    Color textSub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    Color iconColor = isDark ? Colors.grey.shade500 : Colors.grey.shade600;

    // Borders
    Color borderColor = isDark ? Colors.white10 : Colors.black12;

    // 3. DETERMINE ROLE COLORS
    String title = "Welcome Back";
    String subtitle = "Please enter your details.";
    Color accentColor = AppTheme.primaryBlue;
    
    if (widget.selectedRole == 'police') {
      title = isLogin ? "Official Portal" : "Request Access";
      subtitle = isLogin ? "Secure Login for Authorized Personnel" : "Identity Verification Required";
      accentColor = const Color(0xFFE53935); // Red for Security
    } else if (widget.selectedRole == 'enterprise') {
      title = isLogin ? "Enterprise Login" : "Partner Registration";
      accentColor = const Color(0xFF8E44AD); // Purple for Business
    } else {
      title = isLogin ? "Personal Login" : "Create Account";
    }

    return Scaffold(
      backgroundColor: scaffoldBg, // Dynamic Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textMain, onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 450, // Constrain width for Web
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardBg, // Dynamic Card Color
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.1), 
                  blurRadius: 30, 
                  offset: const Offset(0, 10)
                )
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER
                Icon(
                  widget.selectedRole == 'police' ? Icons.security : Icons.lock_outline, 
                  size: 50, color: accentColor
                ),
                const SizedBox(height: 16),
                Text(
                  title, 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textMain)
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSub, fontSize: 13),
                ),
                const SizedBox(height: 30),

                // -----------------------------------------------------
                // DYNAMIC FORM FIELDS
                // -----------------------------------------------------
                
                // 1. Email (Always needed)
                _buildInput("Email Address", Icons.email, _emailCtrl, inputFill, textMain, iconColor),
                const SizedBox(height: 16),

                // 2. PASSWORD
                if (isLogin || widget.selectedRole != 'police') ...[
                  _buildInput("Password", Icons.lock, _passCtrl, inputFill, textMain, iconColor, isPass: true),
                  const SizedBox(height: 16),
                ],

                // 3. ENTERPRISE FIELDS
                if (!isLogin && widget.selectedRole == 'enterprise') ...[
                  _buildInput("Company Name", Icons.business, _companyCtrl, inputFill, textMain, iconColor),
                  const SizedBox(height: 16),
                  _buildInput("NIF (Tax ID)", Icons.receipt, _nifCtrl, inputFill, textMain, iconColor),
                  const SizedBox(height: 16),
                ],

                // 4. POLICE FIELDS
                if (!isLogin && widget.selectedRole == 'police') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      "Your request will be manually reviewed by QDFX Admins. You will receive credentials via email.",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInput("Full Name", Icons.person, TextEditingController(), inputFill, textMain, iconColor),
                  const SizedBox(height: 16),
                  _buildInput("Official Badge ID", Icons.badge, _badgeCtrl, inputFill, textMain, iconColor),
                  const SizedBox(height: 16),
                  _buildInput("Rank / Grade", Icons.star, _rankCtrl, inputFill, textMain, iconColor),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),

                // -----------------------------------------------------
                // MAIN ACTION BUTTON
                // -----------------------------------------------------
ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    // 1. Get the AppState without listening
                    final state = Provider.of<AppState>(context, listen: false);

                    if (isLogin) {
                      // 2. Set the role based on selection
                      state.setRole(widget.selectedRole);

                      // 3. Navigate to Dashboard
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    } else if (widget.selectedRole == 'police') {
                      // Police Signup logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Request Sent! We will contact you shortly.")),
                      );
                    } else {
                      // Individual/Enterprise Signup logic
                      state.setRole(widget.selectedRole);
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    }
                  },
                  child: Text(
                    isLogin 
                        ? "LOGIN" 
                        : (widget.selectedRole == 'police' ? "SUBMIT REQUEST" : "CREATE ACCOUNT"),
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // -----------------------------------------------------
                // TOGGLE LOGIN / SIGNUP
                // -----------------------------------------------------
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: textSub),
                      children: [
                        TextSpan(text: isLogin 
                          ? (widget.selectedRole == 'police' ? "New Officer? " : "Don't have an account? ") 
                          : "Already have an account? "
                        ),
                        TextSpan(
                          text: isLogin 
                            ? (widget.selectedRole == 'police' ? "Request Access" : "Sign Up") 
                            : "Login",
                          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Widget for Input Fields
  Widget _buildInput(String label, IconData icon, TextEditingController ctrl, Color fill, Color text, Color iconColor, {bool isPass = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass,
      style: TextStyle(color: text), // Dynamic Text Color
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: iconColor, fontSize: 14),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        filled: true,
        fillColor: fill, // Dynamic Background Color
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), 
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2))
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), 
          borderSide: const BorderSide(color: Colors.blue)
        ),
      ),
    );
  }
}