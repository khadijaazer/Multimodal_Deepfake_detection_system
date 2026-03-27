import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Needed for Logout
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'landing_screen.dart'; // To reuse the CircuitBoardPainter

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // --- 1. THEME CONFIGURATION ---
    Color scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    Color cardBg = isDark ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.white;
    Color iconBg = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);
    Color textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    Color textSub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    
    // --- 2. DYNAMIC ROLE LOGIC (Using Subscription Plan) ---
    String badgeText = "STANDARD USER";
    Color accentColor = AppTheme.primaryBlue;
    IconData badgeIcon = Icons.person;

    if (appState.subscriptionPlan == 'enterprise') {
      badgeText = "ENTERPRISE CLIENT";
      accentColor = const Color(0xFF8E44AD); // Purple for Enterprise
      badgeIcon = Icons.verified_user;
    } else if (appState.subscriptionPlan == 'pro') {
      badgeText = "PRO USER";
      accentColor = const Color(0xFF00D2D3); // Cyan for Pro
      badgeIcon = Icons.star;
    }

    Color borderColor = isDark ? accentColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2);
    List<BoxShadow> shadows = isDark 
      ?[BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 20, spreadRadius: -5)] 
      :[BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))];

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children:[
          // Background Pattern
          if (isDark)
            Positioned.fill(
              child: CustomPaint(
                painter: CircuitBoardPainter(color: Colors.white.withOpacity(0.03)),
              ),
            ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children:[
                  // --- TOP BAR ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:[
                      BackButton(color: textMain),
                      Text("My Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)),
                      IconButton(icon: Icon(Icons.settings, color: textMain), onPressed: (){}),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // --- AVATAR & INFO ---
                  Stack(
                    alignment: Alignment.bottomRight,
                    children:[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accentColor, width: 2),
                          boxShadow:[BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 15)]
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          backgroundImage: const AssetImage('assets/logo.png'), 
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Read User Name & Email directly from AppState
                  Text(appState.userName.isEmpty ? "User" : appState.userName, 
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textMain)),
                  const SizedBox(height: 4),
                  Text(appState.userEmail, style: TextStyle(color: textSub)),
                  const SizedBox(height: 12),
                  
                  // SUBSCRIPTION BADGE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accentColor.withOpacity(0.5))
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children:[
                        Icon(badgeIcon, size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Text(badgeText, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- DYNAMIC ACCOUNT CARDS ---
                  Align(alignment: Alignment.centerLeft, child: Text("Account Details", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 16),
                  
                  _buildDynamicInfoCards(appState, cardBg, borderColor, iconBg, textMain, textSub, shadows, accentColor),

                  const SizedBox(height: 30),

                  // --- PREFERENCES ---
                  Align(alignment: Alignment.centerLeft, child: Text("System Settings", style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                      boxShadow: shadows,
                    ),
                    child: Column(
                      children:[
                        _buildSwitchTile(
                          icon: Icons.dark_mode_outlined,
                          title: "Dark Mode",
                          value: isDark,
                          onChanged: (val) => appState.toggleTheme(),
                          textMain: textMain,
                          activeColor: accentColor,
                        ),
                        Divider(height: 1, color: borderColor),
                        _buildSwitchTile(
                          icon: Icons.notifications_none_outlined,
                          title: "Push Notifications",
                          value: true, 
                          onChanged: (val) {},
                          textMain: textMain,
                          activeColor: accentColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- LOGOUT ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 5,
                        shadowColor: accentColor.withOpacity(0.4),
                      ),
                      onPressed: () async {
                        // REAL SUPABASE LOGOUT
                        await Supabase.instance.client.auth.signOut();
                        
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                        }
                      },
                      child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildDynamicInfoCards(AppState appState, Color cardBg, Color borderColor, Color iconBg, Color textMain, Color textSub, List<BoxShadow> shadows, Color accentColor) {
    // We now use Generic Data (Company Name & Plan) instead of Police Badge IDs
    String card1Label = "Organization:"; 
    String card1Value = appState.companyName.isEmpty ? "Independent / None" : appState.companyName; 
    IconData card1Icon = Icons.business;

    String card2Label = "Current Plan:"; 
    String card2Value = appState.subscriptionPlan.toUpperCase(); 
    IconData card2Icon = Icons.credit_card;

    return Row(
      children:[
        Expanded(child: _buildActionCard(icon: card1Icon, label: card1Label, title: card1Value, cardBg: cardBg, borderColor: borderColor, iconBg: iconBg, textMain: textMain, textSub: textSub, shadows: shadows, accentColor: accentColor, onTap: () {})),
        const SizedBox(width: 16),
        Expanded(child: _buildActionCard(icon: card2Icon, label: card2Label, title: card2Value, cardBg: cardBg, borderColor: borderColor, iconBg: iconBg, textMain: textMain, textSub: textSub, shadows: shadows, accentColor: accentColor, onTap: () {})),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required String title, required VoidCallback onTap, required Color cardBg, required Color borderColor, required Color iconBg, required Color textMain, required Color textSub, required List<BoxShadow> shadows, required Color accentColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor), boxShadow: shadows),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:[
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accentColor, size: 24)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children:[
                Text(label, style: TextStyle(color: textSub, fontSize: 12)), 
                const SizedBox(height: 4), 
                Text(title, style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 15, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis)
              ]
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required Function(bool) onChanged, required Color textMain, required Color activeColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
      child: ListTile(
        leading: Icon(icon, color: textMain.withOpacity(0.7)), 
        title: Text(title, style: TextStyle(color: textMain, fontWeight: FontWeight.w600)), 
        trailing: Switch(value: value, onChanged: onChanged, activeColor: Colors.white, activeTrackColor: activeColor)
      )
    );
  }
}