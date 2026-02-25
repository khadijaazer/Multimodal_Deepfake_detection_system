import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    _nameCtrl = TextEditingController(text: state.userName);
    _emailCtrl = TextEditingController(text: state.userEmail);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // Dynamic Theme Colors
    Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color textMain = isDark ? Colors.white : Colors.black87;
    Color textSub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    Color inputFill = isDark ? const Color(0xFF0F172A) : Colors.grey.shade100;

    // Role Accent Color
    Color accentColor = AppTheme.primaryBlue;
    if (appState.userRole == 'police') accentColor = const Color(0xFFE53935);
    if (appState.userRole == 'enterprise') accentColor = const Color(0xFF8E44AD);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text("Edit Profile", style: TextStyle(color: textMain, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textMain),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Text("PERSONAL DETAILS", 
              style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),

            // Main Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Column(
                children: [
                  _buildModernInput("Full Name", Icons.person_outline, _nameCtrl, inputFill, textMain, accentColor, false),
                  const SizedBox(height: 20),
                  _buildModernInput("Email Address", Icons.mail_outline, _emailCtrl, inputFill, textMain, accentColor, false),
                  const SizedBox(height: 20),
                  
                  // Read Only Fields (Locked)
                  _buildModernInput("Role", Icons.lock_outline, TextEditingController(text: appState.userRole), 
                    isDark ? Colors.black26 : Colors.grey.shade200, textSub, textSub, true),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                onPressed: () {
                  appState.updateUserProfile(_nameCtrl.text, _emailCtrl.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Profile Updated Successfully"),
                      backgroundColor: accentColor,
                    )
                  );
                },
                child: const Text("SAVE CHANGES", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInput(String label, IconData icon, TextEditingController ctrl, Color fill, Color text, Color accent, bool readOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: TextStyle(color: text.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
          style: TextStyle(color: text),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 20),
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.transparent),
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