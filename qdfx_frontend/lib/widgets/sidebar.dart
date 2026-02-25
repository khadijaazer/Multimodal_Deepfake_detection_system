import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../l10n/translations.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final langCode = appState.currentLocale.languageCode;

    // Helper to get translation
    String t(String key) => AppTranslations.get(langCode, key);

    // Color Palette
    const Color bgNavy = Color(0xFF0F172A);      // Main Background
    const Color cardNavy = Color(0xFF1E293B);    // Settings Box Background
    const Color activeCyan = Color(0xFF06B6D4);  // The Cyan Glow Color
    const Color textGrey = Color(0xFF94A3B8);    // Inactive Text
    const Color textWhite = Colors.white;        // Active Text

    return Container(
      width: 260,
      color: bgNavy, 
      child: Stack(
        children: [
          // --------------------------------------------------
          // 1. THE CIRCUIT BOARD PATTERN (Background Layer)
          // --------------------------------------------------
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitBoardPainter(), 
            ),
          ),

          // --------------------------------------------------
          // 2. THE MENU CONTENT (Foreground Layer)
          // --------------------------------------------------
          Column(
            children: [
              
              // *** LOGO REMOVED *** 
              // Added some spacing so menu doesn't touch the top edge
              const SizedBox(height: 40), 
              
              // MENU ITEMS
              Column(
                children: [
                  _MenuItem(
                    icon: Icons.grid_view_rounded,
                    title: t('dashboard'),
                    isActive: appState.selectedIndex == 0,
                    onTap: () => appState.setIndex(0),
                  ),
                  _MenuItem(
                    icon: Icons.cloud_upload_outlined,
                    title: t('upload'),
                    isActive: false,
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.graphic_eq,
                    title: t('realtime'),
                    isActive: false,
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.history,
                    title: t('history'),
                    isActive: false,
                    onTap: () {},
                  ),
                  // --- NEW SCAM SCANNER ITEM ---
                  _MenuItem(
                    icon: Icons.text_snippet_outlined, // Icon representing text
                    title: "Text Scanner", // Or t('textScanner') if you add to translations
                    isActive: appState.selectedIndex == 3, // Index 3
                    onTap: () => appState.setIndex(3),
                  ),
                  _MenuItem(
                    icon: Icons.credit_card,
                    title: t('billing'),
                    isActive: appState.selectedIndex == 1,
                    onTap: () => appState.setIndex(1),
                  ),
                  _MenuItem(
                    icon: Icons.layers_outlined,
                    title: t('api'),
                    isActive: appState.selectedIndex == 2,
                    onTap: () => appState.setIndex(2),
                  ),
                ],
              ),

              const Spacer(),
              
              // SETTINGS CARD (Bottom Area)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: cardNavy, 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  children: [
                    // Dark Mode Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.wb_sunny_outlined, color: textGrey, size: 20),
                          const SizedBox(width: 12),
                          Text(t('darkMode'), style: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          SizedBox(
                            height: 24,
                            child: Switch(
                              value: isDark,
                              activeColor: activeCyan,
                              activeTrackColor: activeCyan.withOpacity(0.3),
                              inactiveThumbColor: textGrey,
                              inactiveTrackColor: bgNavy,
                              onChanged: (val) => appState.toggleTheme(),
                            ),
                          )
                        ],
                      ),
                    ),
                    
                    Divider(color: Colors.white.withOpacity(0.08), height: 1),
                    
                    // Language Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        children: [
                          const Icon(Icons.language, color: textGrey, size: 20),
                          const SizedBox(width: 12),
                          Text(t('language'), style: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: langCode,
                              dropdownColor: cardNavy,
                              icon: const Icon(Icons.arrow_drop_down, color: textGrey, size: 18),
                              style: const TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 'en', child: Row(children: [Text("🇺🇸 EN")])),
                                DropdownMenuItem(value: 'fr', child: Row(children: [Text("🇫🇷 FR")])),
                                DropdownMenuItem(value: 'ar', child: Row(children: [Text("🇩🇿 AR")])),
                              ],
                              onChanged: (val) {
                                if (val != null) appState.changeLanguage(val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

// --- THE MENU ITEM WIDGET ---
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _MenuItem({
    super.key, 
    required this.icon, 
    required this.title, 
    required this.onTap, 
    this.isActive = false
  });

  @override
  Widget build(BuildContext context) {
    const Color activeCyan = Color(0xFF06B6D4);
    const Color textGrey = Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50, // Fixed height for consistency
        decoration: isActive 
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  activeCyan.withOpacity(0.15),
                  Colors.transparent
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: const Border(
                left: BorderSide(color: activeCyan, width: 4), 
              ),
            ) 
          : null,
        child: Row(
          children: [
            const SizedBox(width: 20), 
            Icon(
              icon, 
              color: isActive ? activeCyan : textGrey, 
              size: 22
            ),
            const SizedBox(width: 14),
            Text(
              title, 
              style: TextStyle(
                color: isActive ? Colors.white : textGrey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- THE CIRCUIT PAINTER ---
class CircuitBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Top Left Circuit
    path.moveTo(0, size.height * 0.15);
    path.lineTo(size.width * 0.2, size.height * 0.15);
    path.lineTo(size.width * 0.3, size.height * 0.2);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.2), 3, dotPaint);

    // Bottom Right Circuit
    path.moveTo(size.width, size.height * 0.85);
    path.lineTo(size.width * 0.7, size.height * 0.85);
    path.lineTo(size.width * 0.6, size.height * 0.75);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.75), 3, dotPaint);

    // Middle Circuit
    path.moveTo(0, size.height * 0.5);
    path.lineTo(size.width * 0.15, size.height * 0.5);
    path.lineTo(size.width * 0.25, size.height * 0.6);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}