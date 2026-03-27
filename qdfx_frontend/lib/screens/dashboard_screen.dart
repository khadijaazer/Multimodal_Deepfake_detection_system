import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../l10n/translations.dart';
import 'edit_profile_screen.dart'; // Profile Hub
import 'profile_screen.dart'; // Profile Hub

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLocale.languageCode;
    String t(String key) => AppTranslations.get(lang, key);
    bool isDark = appState.isDarkMode;

    // Theme Helpers
    Color textMain = isDark ? Colors.white : Colors.black87;
    Color textSub = isDark ? Colors.grey : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // ---------------------------------------------------------
            // 1. TOP BAR (Logo + User) - KEEPING YOUR LOGO LOGIC
            // ---------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), 
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Row(
                children: [
                  // CUSTOM LOGO
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0F172A), width: 4))),
                            Positioned(bottom: 2, right: 2, child: Transform.rotate(angle: -0.8, child: Container(width: 4, height: 12, color: const Color(0xFF2E86DE)))),
                            Positioned(top: 8, left: 8, child: Container(width: 8, height: 4, decoration: BoxDecoration(color: Colors.lightBlueAccent.withOpacity(0.5), borderRadius: BorderRadius.circular(10))))
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      RichText(text: const TextSpan(style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.w900, fontSize: 32), children: [TextSpan(text: "D", style: TextStyle(color: Color(0xFF3B82F6))), TextSpan(text: "F", style: TextStyle(color: Color(0xFF0F172A))), TextSpan(text: "X", style: TextStyle(color: Color(0xFF0F172A)))]))
                    ],
                  ),

                  const Spacer(),

                  IconButton(icon: const Icon(Icons.notifications_none), color: isDark ? Colors.white70 : Colors.grey[600], onPressed: () {}),
                  const SizedBox(width: 16),
                  
                  // USER PROFILE
                  InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: isDark ? Colors.black12 : Colors.grey[100], borderRadius: BorderRadius.circular(30)),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: AppTheme.primaryBlue.withOpacity(0.2), radius: 18, child: const Icon(Icons.person, color: AppTheme.primaryBlue)),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(appState.userName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textMain)), Text(appState.userRole.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold))]),
                          const SizedBox(width: 8),
                          Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[600])
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // ---------------------------------------------------------
            // 2. WELCOME & SYSTEM STATUS
            // ---------------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Dashboard Overview", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textMain)),
                    Text("Welcome back, ${appState.userName}", style: TextStyle(color: textSub)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green)),
                  child: const Row(children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 6), Text("System Operational", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))]),
                )
              ],
            ),
            const SizedBox(height: 24),

            // ---------------------------------------------------------
            // 3. KEY METRICS (Replaces the big Upload Box)
            // ---------------------------------------------------------
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive Grid for Cards
                int crossAxisCount = constraints.maxWidth > 900 ? 3 : 1;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: constraints.maxWidth > 900 ? 2.5 : 3.5, // Aspect ratio for cards
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatCard("Total Scans", "1,204", "+12% this week", Icons.analytics, Colors.blue, isDark),
                    _buildStatCard("Threats Blocked", "42", "High Risk", Icons.shield, Colors.red, isDark),
                    _buildStatCard("Credits Remaining", "850", "Pro Plan", Icons.credit_card, Colors.purple, isDark),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // ---------------------------------------------------------
            // 4. MAIN CONTENT AREA (Split View)
            // ---------------------------------------------------------
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT: RECENT SECURITY ALERTS (Log)
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildSectionHeader("Recent Security Alerts", () {}),
                            const SizedBox(height: 16),
                            _buildSecurityLog(isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // RIGHT: QUICK ACTIONS & USAGE
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildSectionHeader("Quick Actions", null),
                            const SizedBox(height: 16),
                            _buildQuickActions(context, isDark, appState),
                            const SizedBox(height: 24),
                            _buildMiniChart(isDark),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // Mobile Layout (Vertical)
                  return Column(
                    children: [
                      _buildSectionHeader("Quick Actions", null),
                      const SizedBox(height: 16),
                      _buildQuickActions(context, isDark, appState),
                      const SizedBox(height: 24),
                      _buildSectionHeader("Recent Security Alerts", (){}),
                      const SizedBox(height: 16),
                      _buildSecurityLog(isDark),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPONENT WIDGETS ---

  Widget _buildStatCard(String title, String value, String sub, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 12)),
              Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(sub, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (onSeeAll != null) 
          TextButton(onPressed: onSeeAll, child: const Text("View Log")),
      ],
    );
  }

  Widget _buildSecurityLog(bool isDark) {
    return Column(
      children: [
        _logItem("Deepfake Video Detected", "Evidence_04.mp4", "Critical", Colors.red, isDark),
        _logItem("Scam Text Analysis", "SMS Report #992", "Medium", Colors.orange, isDark),
        _logItem("Real-time Monitor Started", "Zoom Meeting ID: 882...", "Info", Colors.blue, isDark),
        _logItem("API Key Generated", "Ennahar TV - Key 02", "Success", Colors.green, isDark),
      ],
    );
  }

  Widget _logItem(String title, String sub, String badge, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)), // Status Indicator
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
              Text(sub, style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark, AppState appState) {
    return Column(
      children: [
        _actionButton(context, "Scan New Text", Icons.text_snippet, Colors.purple, () => appState.setIndex(3), isDark),
        const SizedBox(height: 12),
        _actionButton(context, "Upload Video", Icons.cloud_upload, Colors.blue, () => appState.setIndex(4), isDark),
        const SizedBox(height: 12),
        _actionButton(context, "API Usage", Icons.api, Colors.teal, () => appState.setIndex(2), isDark),
      ],
    );
  }

  Widget _actionButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChart(bool isDark) {
    // A simple visual placeholder for a chart to keep it clean
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Weekly Threat Level", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(30, Colors.blue), _bar(50, Colors.blue), _bar(40, Colors.blue),
              _bar(80, Colors.red), _bar(60, Colors.orange), _bar(20, Colors.blue), _bar(90, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _bar(double h, Color c) {
    return Container(width: 8, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)));
  }
}