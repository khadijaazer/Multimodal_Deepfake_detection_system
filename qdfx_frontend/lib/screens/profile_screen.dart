import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final String role = appState.userRole.toLowerCase();

    // 1. DYNAMIC THEME COLORS
    Color bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color textMain = isDark ? Colors.white : Colors.black87;
    Color textSub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    Color borderColor = isDark ? Colors.white10 : Colors.black12;

    // 2. ROLE-SPECIFIC DATA MAPPING
    Color accentColor;
    String roleBadge;
    String box1Label, box1Value;
    IconData box1Icon, box2Icon;
    String box2Label, box2Value;

   if (role == 'police') {
      accentColor = const Color(0xFFE53935);
      roleBadge = "OFFICIAL PERSONNEL";
      box1Label = "Badge ID";
      box1Value = appState.badgeId; // Use state variable
      box1Icon = Icons.badge;
      box2Label = "Rank / Grade";
      box2Value = appState.rank;    // Use state variable
      box2Icon = Icons.military_tech;
    } else if (role == 'enterprise') {
      accentColor = const Color(0xFF8E44AD);
      roleBadge = "ENTERPRISE ACCOUNT";
      box1Label = "Company";
      box1Value = appState.companyName; // Use state variable
      box1Icon = Icons.business;
      box2Label = "NIF (Tax ID)";
      box2Value = appState.nifId;      // Use state variable
      box2Icon = Icons.receipt_long;
    } else {
      accentColor = const Color(0xFF2E86DE);
      roleBadge = "INDIVIDUAL USER";
      box1Label = "Account ID";
      box1Value = "QDFX-9920";
      box1Icon = Icons.fingerprint;
      box2Label = "Member Since";
      box2Value = "Jan 2024";
      box2Icon = Icons.calendar_today;
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textMain),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // --- HEADER: AVATAR & NAME ---
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundImage: const NetworkImage('https://i.pravatar.cc/300'),
                        backgroundColor: accentColor.withOpacity(0.1),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: cardBg, width: 3)
                          ),
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(appState.userName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textMain)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(roleBadge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                  const SizedBox(height: 4),
                  Text(appState.userEmail, style: TextStyle(color: textSub, fontSize: 14)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- SECTION: QUICK DATA BOXES (Dynamically populated based on Role) ---
            Row(
              children: [
                _buildDataBox(box1Label, box1Value, box1Icon, cardBg, textMain, textSub, accentColor),
                const SizedBox(width: 12),
                _buildDataBox(box2Label, box2Value, box2Icon, cardBg, textMain, textSub, accentColor),
              ],
            ),

            const SizedBox(height: 24),

            // --- SECTION: SETTINGS LIST ---
            _buildSectionHeader("ACCOUNT SETTINGS", textSub),
            Container(
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  _buildListTile(Icons.person_outline, "Edit Personal Info", textMain, textSub, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  }),
                  if (role == 'enterprise')
                    _buildListTile(Icons.api, "API Keys & Access", textMain, textSub, () {}),
                  if (role == 'police')
                    _buildListTile(Icons.assignment_turned_in_outlined, "Official Clearance", textMain, textSub, () {}),
                  _buildListTile(Icons.mail_outline, "Change Email", textMain, textSub, () {}),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- SECTION: PREFERENCES ---
            _buildSectionHeader("PREFERENCES", textSub),
            Container(
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.dark_mode_outlined, color: textMain, size: 22),
                    title: Text("Dark Mode", style: TextStyle(color: textMain, fontWeight: FontWeight.w500)),
                    trailing: Switch(
                      value: isDark,
                      activeColor: accentColor,
                      onChanged: (val) => appState.toggleTheme(),
                    ),
                  ),
                  _buildListTile(Icons.notifications_none, "Notifications", textMain, textSub, () {}),
                ],
              ),
            ),

            const SizedBox(height: 30),
// --- TEMPORARY TEST BUTTONS ---
            const SizedBox(height: 20),
            Text("DEVELOPER TOOLS: SWITCH ROLES", 
              style: TextStyle(color: textSub, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTestButton("Individual", const Color(0xFF2E86DE), appState),
                _buildTestButton("Enterprise", const Color(0xFF8E44AD), appState),
                _buildTestButton("Police", const Color(0xFFE53935), appState),
              ],
            ),
            const SizedBox(height: 30),
            
         
            // --- LOGOUT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E86DE), // Logo Blue
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI HELPER COMPONENTS ---

  Widget _buildSectionHeader(String title, Color textSub) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: TextStyle(color: textSub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildDataBox(String label, String value, IconData icon, Color bg, Color text, Color sub, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg, 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: Colors.white10)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(color: sub, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, Color text, Color sub, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: text, size: 22),
      title: Text(title, style: TextStyle(color: text, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: sub, size: 20),
    );
  }
  Widget _buildTestButton(String label, Color color, AppState state) {
    return GestureDetector(
      onTap: () => state.setRole(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}