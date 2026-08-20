import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  
  // Password controllers
  final TextEditingController _newPasswordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _isSaving = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    _nameCtrl = TextEditingController(text: state.userName);
    _emailCtrl = TextEditingController(text: state.userEmail);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // Helper method to display clean standard Snackbars
  void _showSnack(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Real-time user profile update and Supabase credential processing [2]
  Future<void> _handleSave(AppState appState, Color accentColor) async {
    setState(() => _isSaving = true);

    try {
      // 1. Update basic profile info (Local State + Database Metadata)
      appState.updateUserProfile(_nameCtrl.text.trim(), _emailCtrl.text.trim());

      // 2. Update Password if any input is provided
      if (_newPasswordCtrl.text.isNotEmpty || _confirmPasswordCtrl.text.isNotEmpty) {
        if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
          throw Exception("Passwords do not match.");
        }
        if (_newPasswordCtrl.text.length < 6) {
          throw Exception("Password must be at least 6 characters long.");
        }

        // Live Supabase authentication update [2]
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: _newPasswordCtrl.text),
        );

        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      }

      _showSnack("Profile details updated successfully.", Colors.green);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack(e.toString().replaceAll("Exception: ", ""), Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // Dynamic Theme Colors
    final Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textMain = isDark ? Colors.white : Colors.black87;
    final Color textSub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color inputFill = isDark ? const Color(0xFF0F172A) : Colors.grey.shade100;

    // Align accent color to matches the newly updated business plans [1]
    Color accentColor = AppTheme.primaryBlue;
    if (appState.subscriptionPlan.toLowerCase() == 'enterprise') {
      accentColor = const Color(0xFF8E44AD); // Enterprise Purple
    } else if (appState.subscriptionPlan.toLowerCase() == 'professional') {
      accentColor = const Color(0xFF00D2D3); // Professional SME Cyan
    } else if (appState.subscriptionPlan.toLowerCase() == 'premium') {
      accentColor = const Color(0xFF3B82F6); // Premium Blue
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text("Edit Profile Details", style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textMain),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECTION 1 : PERSONAL DETAILS ---
                Text("PERSONAL DETAILS", 
                  style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Column(
                    children: [
                      _buildModernInput(
                        label: "Full Name",
                        icon: Icons.person_outline,
                        ctrl: _nameCtrl,
                        fill: inputFill,
                        text: textMain,
                        accent: accentColor,
                      ),
                      const SizedBox(height: 16),
                      _buildModernInput(
                        label: "Email Address",
                        icon: Icons.mail_outline,
                        ctrl: _emailCtrl,
                        fill: inputFill,
                        text: textMain,
                        accent: accentColor,
                      ),
                      const SizedBox(height: 16),
                      _buildModernInput(
                        label: "Subscription Tier",
                        icon: Icons.credit_card_outlined,
                        ctrl: TextEditingController(text: appState.subscriptionPlan.toUpperCase()),
                        fill: isDark ? Colors.black26 : Colors.grey.shade200,
                        text: textSub,
                        accent: textSub,
                        readOnly: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // --- SECTION 2 : SECURITY SETTINGS (CHANGE PASSWORD) ---
                Text("SECURITY & PASSWORD", 
                  style: TextStyle(color: textSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Column(
                    children: [
                      _buildModernInput(
                        label: "New Password",
                        icon: Icons.lock_outline_rounded,
                        ctrl: _newPasswordCtrl,
                        fill: inputFill,
                        text: textMain,
                        accent: accentColor,
                        obscureText: _obscureNew,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: textSub, size: 18),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModernInput(
                        label: "Confirm New Password",
                        icon: Icons.lock_reset_rounded,
                        ctrl: _confirmPasswordCtrl,
                        fill: inputFill,
                        text: textMain,
                        accent: accentColor,
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: textSub, size: 18),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Save Changes Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _isSaving ? null : () => _handleSave(appState, accentColor),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("SAVE CHANGES", 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernInput({
    required String label,
    required IconData icon,
    required TextEditingController ctrl,
    required Color fill,
    required Color text,
    required Color accent,
    bool readOnly = false,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: TextStyle(color: text.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
          obscureText: obscureText,
          style: TextStyle(color: text, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}