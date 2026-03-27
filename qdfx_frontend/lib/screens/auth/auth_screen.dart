import 'dart:convert'; // Added for JSON
import 'package:http/http.dart' as http; // Added for API calls
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // SUPABASE

import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../landing_screen.dart'; // To reuse CircuitPainter

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // State
  bool _isLogin = true; 
  bool _isProfessional = false; 
  bool _isVerifying = false; 
  String _selectedOrgType = "Media/Press";

  // Controllers
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _orgNameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();

  final List<String> _orgTypes =[
    "Media/Press",
    "Enterprise",
    "Police/Security",
    "Other Institution"
  ];

  // List of free email providers to block for Professional accounts
  final List<String> _freeEmailProviders =[
    'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'icloud.com', 'mail.ru'
  ];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    Color bg = isDark ? const Color(0xFF0B1121) : const Color(0xFFF1F5F9);
    Color cardBg = isDark ? const Color(0xFF151E32) : Colors.white;
    Color textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    Color textSub = isDark ? Colors.grey : Colors.grey[600]!;
    Color borderCol = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
    Color primary = AppTheme.primaryBlue;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children:[
          if (isDark)
            Positioned.fill(
              child: CustomPaint(painter: CircuitBoardPainter(color: Colors.white.withOpacity(0.03))),
            ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children:[
                      Image.asset('assets/logo.png', height: 40, errorBuilder: (c,e,s)=>Icon(Icons.shield, color: primary)),
                      const SizedBox(width: 10),
                      Text("QDFX", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textMain)),
                    ],
                  ),
                  const SizedBox(height: 30),

                  Container(
                    width: 500,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderCol),
                      boxShadow:[
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:[
                        Text(
                          _isLogin ? "QDFX > Login" : "QDFX > Sign Up",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textMain),
                        ),
                        const SizedBox(height: 24),

                        // --- TABS ---
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0B1121) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol),
                          ),
                          child: Row(
                            children:[
                              _buildTab("SIMPLE USER", !_isProfessional, () => setState(() => _isProfessional = false), textMain, primary),
                              _buildTab("PROFESSIONAL USER", _isProfessional, () => setState(() => _isProfessional = true), textMain, primary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- PROFESSIONAL FIELDS ---
                        if (!_isLogin && _isProfessional) ...[
                          _buildLabel("Organization Type", textMain),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0B1121) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderCol),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedOrgType,
                                dropdownColor: cardBg,
                                icon: Icon(Icons.arrow_drop_down, color: textSub),
                                style: TextStyle(color: textMain),
                                isExpanded: true,
                                items: _orgTypes.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                                onChanged: (val) => setState(() => _selectedOrgType = val!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children:[
                              Expanded(child: _buildInput("Organization Name", "e.g., Ennahar", false, isDark, textMain, borderCol, _orgNameCtrl)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildInput("Position", "e.g., Journalist", false, isDark, textMain, borderCol, _positionCtrl)),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (!_isLogin) ...[
                          _buildInput("Full Name", "Your Name", false, isDark, textMain, borderCol, _nameCtrl),
                          const SizedBox(height: 16),
                        ],

                        _buildInput(
                          _isProfessional ? "Professional Email" : "Email Address", 
                          _isProfessional ? "name@company.dz" : "name@gmail.com", 
                          false, isDark, textMain, borderCol, _emailCtrl
                        ),
                        if (!_isLogin && _isProfessional) 
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Text("Domain will be verified (No Gmail/Yahoo allowed)", style: TextStyle(color: Colors.blue.shade300, fontSize: 10)),
                          ),
                        const SizedBox(height: 16),

                        _buildInput("Password", "••••••••", true, isDark, textMain, borderCol, _passCtrl),
                        
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(onPressed: () {}, child: Text("Forgot Password?", style: TextStyle(color: textSub, fontSize: 12))),
                          ),

                        if (!_isLogin && _isProfessional) ...[
                          const SizedBox(height: 16),
                          _buildUploadBox(isDark, textMain, borderCol, primary),
                          const SizedBox(height: 8),
                          Text("Required for ID/Registration verification", style: TextStyle(color: textSub, fontSize: 10)),
                        ],

                        const SizedBox(height: 24),

                        // --- ACTION BUTTON ---
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 5,
                            ),
                            onPressed: _isVerifying ? null : () => _handleAuth(context, appState),
                            child: _isVerifying 
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children:[
                                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                    SizedBox(width: 10),
                                    Text("Verifying Domain...", style: TextStyle(color: Colors.white))
                                  ],
                                )
                              : Text(
                                  _isLogin ? "LOGIN" : (_isProfessional ? "REQUEST ACCESS" : "CREATE ACCOUNT"),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:[
                            Text(_isLogin ? "Don't have an account? " : "Already have an account? ", style: TextStyle(color: textSub)),
                            GestureDetector(
                              onTap: () => setState(() => _isLogin = !_isLogin),
                              child: Text(_isLogin ? "Sign Up" : "Login", style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("Privacy Policy • Terms of Service", style: TextStyle(color: textSub, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool isActive, VoidCallback onTap, Color textCol, Color activeCol) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: isActive ? activeCol : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: isActive ? Colors.white : textCol.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 6, left: 4), child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)));
  }

  Widget _buildInput(String label, String hint, bool isPass, bool isDark, Color textCol, Color borderCol, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        _buildLabel(label, textCol),
        TextField(
          controller: ctrl,
          obscureText: isPass,
          style: TextStyle(color: textCol),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textCol.withOpacity(0.3)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0B1121) : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
            suffixIcon: isPass ? Icon(Icons.visibility_off, size: 18, color: textCol.withOpacity(0.4)) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadBox(bool isDark, Color textCol, Color borderCol, Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF0B1121) : Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderCol, style: BorderStyle.solid)),
      child: Column(
        children:[
          Icon(Icons.cloud_upload_outlined, color: primary, size: 30),
          const SizedBox(height: 8),
          Text("UPLOAD DOCUMENT", style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  // --- REAL SUPABASE + PYTHON AUTH LOGIC ---
  void _handleAuth(BuildContext context, AppState appState) async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text;
    final supabase = Supabase.instance.client;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email and Password are required"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // ==========================================
      // FLOW 1: SIGN UP
      // ==========================================
      if (!_isLogin) {
        
        // --- A. Professional Verification ---
        if (_isProfessional) {
          // Block Gmail/Yahoo
          bool isFreeEmail = _freeEmailProviders.any((domain) => email.endsWith('@$domain'));
          if (isFreeEmail) {
            throw Exception("Professional accounts require a corporate domain (No Gmail/Yahoo).");
          }

          // Call Python Backend for Consensus Verification
          // Remember to change to 10.0.2.2 if on Android Emulator
          final url = Uri.parse('http://127.0.0.1:8000/api/auth/verify-corporate-email');
          final response = await http.post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "company_name": _orgNameCtrl.text}),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['status'] == "REJECTED") {
              throw Exception("Domain Verification Failed: ${data['message']}");
            }
          } else {
            throw Exception("Verification Server Offline.");
          }
        }

        // --- B. Create User in Supabase ---
        final AuthResponse res = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': _nameCtrl.text,
            // If professional, we save the company name. Database trigger handles the rest.
            'company_name': _isProfessional ? _orgNameCtrl.text : '', 
          }
        );

        if (res.user != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Created Successfully!"), backgroundColor: Colors.green));
        }
      } 
      
      // ==========================================
      // FLOW 2: LOGIN
      // ==========================================
      
      // Sign in with Supabase
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Fetch their profile from the database to see their tier/role
      final userData = await supabase
          .from('profiles')
          .select('subscription_plan, full_name, credits, company_name')
          .eq('id', supabase.auth.currentUser!.id)
          .single();

      // Update AppState so the Dashboard knows exactly who is logged in
      appState.setLoggedInUser(
        userData['full_name'] ?? 'User',
        email,
        userData['subscription_plan'] ?? 'free',
        userData['credits'] ?? 0,
        userData['company_name'] ?? ''
      );

      // Navigate to Dashboard
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }

    } catch (e) {
      if (mounted) {
        // Clean up the error message for the user
        String errorMsg = e.toString().replaceAll("Exception: ", "").replaceAll("AuthException: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }
}