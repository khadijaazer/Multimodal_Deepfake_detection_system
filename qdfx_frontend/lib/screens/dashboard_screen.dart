import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../l10n/translations.dart';
import 'edit_profile_screen.dart'; // This is your Profile Hub
import 'profile_screen.dart'; // This is your Profile Hub

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLocale.languageCode;
    String t(String key) => AppTranslations.get(lang, key);
    bool isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // ---------------------------------------------------------
            // 1. TOP BAR
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
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  // ---------------------------------------------------
                  // CUSTOM LOGO BUILDER (Matches your Picture)
                  // ---------------------------------------------------
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // The "Q" (Magnifying Glass Style)
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // The Ring
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F172A), width: 4), // Dark Navy Ring
                              ),
                            ),
                            // The Handle
                            Positioned(
                              bottom: 2, right: 2,
                              child: Transform.rotate(
                                angle: -0.8,
                                child: Container(
                                  width: 4, height: 12,
                                  color: const Color(0xFF2E86DE), // Blue Handle
                                ),
                              ),
                            ),
                            // The Lens Reflection
                            Positioned(
                              top: 8, left: 8,
                              child: Container(
                                width: 8, height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.lightBlueAccent.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10)
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      
                      // The Text "DFX"
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.w900, fontSize: 32),
                          children: [
                            TextSpan(text: "D", style: TextStyle(color: Color(0xFF3B82F6))), // Light Blue
                            TextSpan(text: "F", style: TextStyle(color: Color(0xFF0F172A))), // Dark Navy
                            TextSpan(text: "X", style: TextStyle(color: Color(0xFF0F172A))), // Dark Navy
                          ]
                        ),
                      ),
                    ],
                  ),
                  // ---------------------------------------------------

                  const Spacer(),

                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    onPressed: () {},
                  ),
                  const SizedBox(width: 16),
                  
                  // USER PROFILE (CLICKABLE)
                  InkWell(
                    onTap: () {
                      // Navigate to Profile Screen
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black12 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(30)
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
                            radius: 18,
                            child: const Icon(Icons.person, color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appState.userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87
                                ),
                              ),
                              Text(
                                appState.userRole.toUpperCase(),
                                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
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
            // 2. DASHBOARD TITLE
            // ---------------------------------------------------------
            Text(t('dashboard'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // ---------------------------------------------------------
            // 3. RESPONSIVE LAYOUT
            // ---------------------------------------------------------
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            _buildRecentActivitiesList(t, isDark),
                            const SizedBox(height: 24),
                            _buildUploadZone(t),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: _buildStatsArea(t, isDark),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildUploadZone(t),
                      const SizedBox(height: 24),
                      _buildRecentActivitiesList(t, isDark),
                      const SizedBox(height: 24),
                      _buildStatsArea(t, isDark),
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

  // --- WIDGETS ---
  Widget _buildUploadZone(Function t) {
    return DottedBorder(
      color: AppTheme.primaryBlue.withOpacity(0.5),
      strokeWidth: 2,
      dashPattern: const [8, 4],
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.cardDark.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 50, color: Color(0xFF5CA0F2)),
            const SizedBox(height: 16),
            const Text("File Upload", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(t('dragDrop'), style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesList(Function t, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Recent Activities", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(onPressed: (){}, child: const Text("See all")),
          ],
        ),
        const SizedBox(height: 10),
        _activityItem("Upload Analysis Template", "30 seconds ago", "Status: Processing", Colors.orange, isDark),
        _activityItem("Real-time Detection Log", "1 hour ago", "Status: Completed", Colors.green, isDark),
        _activityItem("Upload Video: evidence.mp4", "2 hours ago", "Status: Fake Detected", Colors.red, isDark),
      ],
    );
  }

  Widget _activityItem(String title, String time, String status, Color statusColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(colors: [Colors.blueGrey.shade800, Colors.black]) 
            ),
            child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark?Colors.white:Colors.black87)),
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(status.split(':').last, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildStatsArea(Function t, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recent Detections", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(40, Colors.blue),
              _bar(70, Colors.red),
              _bar(50, Colors.blue),
              _bar(30, Colors.blue),
              _bar(90, Colors.red),
              _bar(60, Colors.blue),
            ],
          )
        ],
      ),
    );
  }

  Widget _bar(double height, Color color) {
    return Container(
      width: 15,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    );
  }
}