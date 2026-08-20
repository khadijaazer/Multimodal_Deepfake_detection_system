import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../l10n/translations.dart';
import 'landing_screen.dart'; // Reuse CircuitBoardPainter
import 'edit_profile_screen.dart'; // Navigation Target

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final lang = appState.currentLocale.languageCode;
    
    String tr(String key) => AppTranslations.get(lang, key);

    // --- THEME CONFIGURATION ---
    final Color scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.white;
    final Color iconBg = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1);
    final Color textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color textSub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    
    // --- DYNAMIC PLAN BADGE LOGIC ---
    String badgeText = tr('standardUser');
    Color accentColor = AppTheme.primaryBlue;
    IconData badgeIcon = Icons.person;

    if (appState.subscriptionPlan == 'enterprise') {
      badgeText = tr('enterpriseClient');
      accentColor = const Color(0xFF8E44AD);
      badgeIcon = Icons.verified_user;
    } else if (appState.subscriptionPlan == 'pro') {
      badgeText = tr('proUser');
      accentColor = const Color(0xFF00D2D3);
      badgeIcon = Icons.star;
    }

    final Color borderColor = isDark ? accentColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2);
    final List<BoxShadow> shadows = isDark 
      ? [BoxShadow(color: accentColor.withOpacity(0.15), blurRadius: 20, spreadRadius: -5)] 
      : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))];

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          if (isDark)
            Positioned.fill(
              child: CustomPaint(
                painter: CircuitBoardPainter(color: Colors.white.withOpacity(0.03)),
              ),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth > 720;

                // --- SHARED COMPONENTS ---
                final Widget topBar = Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BackButton(color: textMain),
                    Text(tr('myProfile'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textMain)),
                    IconButton(
                      icon: Icon(Icons.mode_edit_outline_outlined, color: textMain),
                      tooltip: tr('editProfile'),
                      onPressed: () => _navigateToEdit(context),
                    ),
                  ],
                );

                final Widget profileHeader = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToEdit(context),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 2),
                              boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 15)]
                            ),
                            child: CircleAvatar(
                              radius: 54,
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                              backgroundImage: const AssetImage('assets/logowhite.jpeg'), 
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                            child: const Icon(Icons.mode_edit_outline_outlined, color: Colors.white, size: 16),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      appState.userName.isEmpty ? tr('user') : appState.userName, 
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textMain),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(appState.userEmail, style: TextStyle(color: textSub), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor.withOpacity(0.5))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 14, color: accentColor),
                          const SizedBox(width: 6),
                          Text(badgeText, style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ],
                );

                final Widget accountDetailsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('accountDetails'), style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    _buildDynamicInfoCards(appState, cardBg, borderColor, iconBg, textMain, textSub, shadows, accentColor, tr),
                  ],
                );

                final Widget systemSettingsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('systemSettings'), style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                        boxShadow: shadows,
                      ),
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            icon: Icons.dark_mode_outlined,
                            title: tr('darkMode'),
                            value: isDark,
                            onChanged: (val) => appState.toggleTheme(),
                            textMain: textMain,
                            activeColor: accentColor,
                          ),
                          Divider(height: 1, color: borderColor),
                          _buildSwitchTile(
                            icon: Icons.notifications_none_outlined,
                            title: tr('notifications'),
                            value: true, 
                            onChanged: (val) {},
                            textMain: textMain,
                            activeColor: accentColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final Widget logoutButton = SizedBox(
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
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                      }
                    },
                    child: Text(tr('logOut'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                );

                // --- RENDERING STRATEGY ---
                if (isWide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          children: [
                            topBar,
                            const SizedBox(height: 40),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column (Header details)
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: borderColor),
                                      boxShadow: shadows,
                                    ),
                                    child: Column(
                                      children: [
                                        profileHeader,
                                        const SizedBox(height: 32),
                                        logoutButton,
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Right Column (Settings details)
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      accountDetailsSection,
                                      const SizedBox(height: 32),
                                      systemSettingsSection,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Standard Mobile Layout
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      topBar,
                      const SizedBox(height: 30),
                      profileHeader,
                      const SizedBox(height: 40),
                      accountDetailsSection,
                      const SizedBox(height: 30),
                      systemSettingsSection,
                      const SizedBox(height: 40),
                      logoutButton,
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
  }

  Widget _buildDynamicInfoCards(AppState appState, Color cardBg, Color borderColor, Color iconBg, Color textMain, Color textSub, List<BoxShadow> shadows, Color accentColor, String Function(String) tr) {
    String card1Label = tr('organization'); 
    String card1Value = appState.companyName.isEmpty ? tr('independent') : appState.companyName; 
    IconData card1Icon = Icons.business;

    String card2Label = tr('currentPlanLabel'); 
    String card2Value = appState.subscriptionPlan.toUpperCase(); 
    IconData card2Icon = Icons.credit_card;

    return Row(
      children: [
        Expanded(child: _buildActionCard(icon: card1Icon, label: card1Label, title: card1Value, cardBg: cardBg, borderColor: borderColor, iconBg: iconBg, textMain: textMain, textSub: textSub, shadows: shadows, accentColor: accentColor)),
        const SizedBox(width: 16),
        Expanded(child: _buildActionCard(icon: card2Icon, label: card2Label, title: card2Value, cardBg: cardBg, borderColor: borderColor, iconBg: iconBg, textMain: textMain, textSub: textSub, shadows: shadows, accentColor: accentColor)),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required String title, required Color cardBg, required Color borderColor, required Color iconBg, required Color textMain, required Color textSub, required List<BoxShadow> shadows, required Color accentColor}) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor), boxShadow: shadows),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accentColor, size: 24)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(label, style: TextStyle(color: textSub, fontSize: 12)), 
              const SizedBox(height: 4), 
              Text(title, style: TextStyle(color: textMain, fontWeight: FontWeight.bold, fontSize: 15, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis)
            ]
          ),
        ],
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