import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../l10n/translations.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  static const double _expandedWidth  = 260;
  static const double _collapsedWidth = 72;

  // Theme‑dependent colours – will be set in build()
  late Color _bgColor;
  late Color _cardColor;
  late Color _textColor;
  late Color _textGrey;
  late Color _activeCyan;
  late Color _borderColor;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _widthAnimation = Tween<double>(
      begin: _expandedWidth,
      end: _collapsedWidth,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      _isCollapsed
          ? _animationController.forward()
          : _animationController.reverse();
    });
  }

  static const List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard_outlined,    'key': 'dashboard',    'index': 0},
    {'icon': Icons.credit_card_outlined,  'key': 'billing',      'index': 1},
    {'icon': Icons.code_outlined,         'key': 'api',          'index': 2},
    {'icon': Icons.text_snippet_outlined, 'key': 'textScanner',  'index': 3},
    {'icon': Icons.cloud_upload_outlined, 'key': 'upload',       'index': 4},
    {'icon': Icons.videocam_outlined,     'key': 'realtime',     'index': 5},
    {'icon': Icons.history,               'key': 'history',      'index': 6},
    {'icon': Icons.person_outline,        'key': 'profile',      'index': 7},
  ];

  Future<void> _handleLogout(BuildContext context, AppState appState) async {
    final langCode = appState.currentLocale.languageCode;
    final String title = AppTranslations.get(langCode, 'logout') ?? 'Log Out';
    final String cancelText = AppTranslations.get(langCode, 'cancel') ?? 'Cancel';
    final String proceedText = AppTranslations.get(langCode, 'logout') ?? 'Log Out';

    String body = 'Are you sure you want to log out?';
    if (langCode == 'fr') {
      body = 'Êtes-vous sûr de vouloir vous déconnecter ?';
    } else if (langCode == 'ar') {
      body = 'هل أنت متأكد أنك تريد تسجيل الخروج؟';
    }

    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(body, style: TextStyle(color: _textGrey, fontSize: 13, height: 1.5)),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(cancelText, style: TextStyle(color: _textGrey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(proceedText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ) ?? false;

    if (confirm) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
        }
      } catch (e) {
        debugPrint('Authentication signout failed: $e');
      }
    }
  }

  // ─── THEME‑AWARE RESPONSIVE LOGO ───────────────────────────────────────────
  Widget _buildLogo({required bool isDark, double? height, double? width, bool isCollapsed = false, bool isMobile = false}) {
    final logoAsset = isDark ? 'assets/logowhite2.png' : 'assets/logolight.png';
    
    // Responsive sizing based on device type
    double logoHeight;
    double logoWidth;
    
    if (isMobile) {
      // Mobile sizes - larger for better visibility
      logoHeight = height ?? 40;
      logoWidth = width ?? 180;
    } else if (isCollapsed) {
      // Collapsed sidebar on desktop
      logoHeight = height ?? 36;
      logoWidth = width ?? 36;
    } else {
      // Expanded sidebar on desktop/tablet
      logoHeight = height ?? 44;
      logoWidth = width ?? 180;
    }
    
    if (isCollapsed && !isMobile) {
      return Image.asset(
        logoAsset,
        height: logoHeight,
        width: logoWidth,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.shield, color: _activeCyan, size: logoHeight * 0.8),
      );
    } else {
      return Image.asset(
        logoAsset,
        height: logoHeight,
        width: logoWidth,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        errorBuilder: (_, __, ___) => Text(
          'DETECTINI',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 18 : 16,
            letterSpacing: 1.2,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // Set theme‑dependent colours
    _activeCyan = const Color(0xFF06B6D4);
    if (isDark) {
      _bgColor    = const Color(0xFF0F172A); // dark blue
      _cardColor  = const Color(0xFF1E293B);
      _textColor  = Colors.white;
      _textGrey   = const Color(0xFF94A3B8);
      _borderColor = Colors.white.withOpacity(0.08);
    } else {
      _bgColor    = const Color(0xFFF8FAFC);   // light background (matches landing)
      _cardColor  = Colors.white;              // white card
      _textColor  = const Color(0xFF1E293B);   // dark slate
      _textGrey   = const Color(0xFF64748B);
      _borderColor = Colors.grey.withOpacity(0.2);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 600;
    final isTablet    = screenWidth >= 600 && screenWidth < 900;

    if (isMobile) return _buildMobileDrawer(context, isDark);
    if (isTablet) return _buildExpandedSidebar(context, isDark, showCollapseButton: false);

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, _) {
        final w = _widthAnimation.value;
        final collapsed = w < (_expandedWidth + _collapsedWidth) / 2;
        return _buildSidebarContainer(context, w, collapsed, isDark);
      },
    );
  }

  // Mobile drawer
  Widget _buildMobileDrawer(BuildContext context, bool isDark) {
    final appState = Provider.of<AppState>(context);
    final langCode = appState.currentLocale.languageCode;
    String t(String key) => AppTranslations.get(langCode, key);

    return Container(
      width: _expandedWidth,
      color: _bgColor,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: CircuitBoardPainter(isCollapsed: false, isDark: isDark))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMobileHeader(context, t, isDark),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: _menuItems.map((item) {
                    return _MenuItem(
                      icon:        item['icon'] as IconData,
                      title:       t(item['key']),
                      isActive:    appState.selectedIndex == item['index'],
                      isCollapsed: false,
                      isDark:      isDark,
                      onTap: () {
                        appState.setIndex(item['index'] as int);
                        Navigator.of(context).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
              _buildMobileFooter(appState, isDark, langCode, t),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context, String Function(String) t, bool isDark) {
    return Container(
      height: 80, // Increased height for better logo visibility on mobile
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildLogo(isDark: isDark, height: 50, width: 200, isCollapsed: false, isMobile: true),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: _textGrey, size: 24),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: t('close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFooter(AppState appState, bool isDark, String langCode, String Function(String) t) {
    return Column(
      children: [
        Divider(color: _borderColor, height: 1),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: _textGrey, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('darkMode'), style: TextStyle(color: _textGrey, fontSize: 12))),
                  Switch(
                    value: isDark,
                    activeColor: _activeCyan,
                    activeTrackColor: _activeCyan.withOpacity(0.3),
                    inactiveThumbColor: _textGrey,
                    inactiveTrackColor: _bgColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => appState.toggleTheme(),
                  ),
                ],
              ),
              Divider(color: _borderColor, height: 1),
              Row(
                children: [
                  Icon(Icons.language, color: _textGrey, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('language'), style: TextStyle(color: _textGrey, fontSize: 12))),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: langCode,
                      dropdownColor: _cardColor,
                      icon: Icon(Icons.arrow_drop_down, color: _textGrey, size: 18),
                      style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      ],
                      onChanged: (val) {
                        if (val != null) appState.changeLanguage(val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _activeCyan.withOpacity(0.2),
                child: Icon(Icons.person_outline, color: _activeCyan, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('myProfile'), style: TextStyle(color: _textColor, fontWeight: FontWeight.w600, fontSize: 12)),
                    Text(t('proUser'), style: TextStyle(color: _textGrey, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout, color: _textGrey, size: 18),
                onPressed: () => _handleLogout(context, appState),
                tooltip: t('logout'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Desktop / tablet
  Widget _buildExpandedSidebar(BuildContext context, bool isDark, {bool showCollapseButton = true}) {
    return Container(
      width: _expandedWidth,
      color: _bgColor,
      child: _buildSidebarContent(context, isCollapsed: false, showCollapseButton: showCollapseButton, isDark: isDark),
    );
  }

  Widget _buildSidebarContainer(BuildContext context, double width, bool collapsed, bool isDark) {
    return Container(
      width: width,
      color: _bgColor,
      child: _buildSidebarContent(context, isCollapsed: collapsed, showCollapseButton: true, isDark: isDark),
    );
  }

  Widget _buildSidebarContent(BuildContext context, {required bool isCollapsed, required bool showCollapseButton, required bool isDark}) {
    final appState = Provider.of<AppState>(context);
    final langCode = appState.currentLocale.languageCode;
    String t(String key) => AppTranslations.get(langCode, key);

    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: CircuitBoardPainter(isCollapsed: isCollapsed, isDark: isDark))),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isCollapsed, showCollapseButton, t, isDark),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: _menuItems.map((item) {
                  return _MenuItem(
                    icon:        item['icon'] as IconData,
                    title:       t(item['key']),
                    isActive:    appState.selectedIndex == item['index'],
                    isCollapsed: isCollapsed,
                    isDark:      isDark,
                    onTap: () => appState.setIndex(item['index'] as int),
                  );
                }).toList(),
              ),
            ),
            _buildFooter(appState, isDark, langCode, t, isCollapsed),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(bool isCollapsed, bool showCollapseButton, String Function(String) t, bool isDark) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: isCollapsed ? 16 : 20, right: isCollapsed ? 0 : 10),
            child: isCollapsed
                ? _buildLogo(isDark: isDark, height: 36, width: 36, isCollapsed: true, isMobile: false)
                : _buildLogo(isDark: isDark, height: 44, width: 180, isCollapsed: false, isMobile: false),
          ),
          if (!isCollapsed) const Spacer(),
          if (showCollapseButton)
            IconButton(
              icon: Icon(isCollapsed ? Icons.menu_open : Icons.menu, color: _textGrey, size: 22),
              onPressed: _toggleSidebar,
              tooltip: isCollapsed ? 'Expand' : 'Collapse',
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppState appState, bool isDark, String langCode, String Function(String) t, bool isCollapsed) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Divider(color: _borderColor, height: 1),
            const SizedBox(height: 8),
            Tooltip(
              message: t('darkMode'),
              child: IconButton(
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: _textGrey, size: 22),
                onPressed: () => appState.toggleTheme(),
              ),
            ),
            Tooltip(
              message: t('language'),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.language, color: _textGrey, size: 22),
                tooltip: '',
                color: _cardColor,
                onSelected: appState.changeLanguage,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'en', child: Text('EN', style: TextStyle(color: Colors.white))),
                  PopupMenuItem(value: 'fr', child: Text('FR', style: TextStyle(color: Colors.white))),
                  PopupMenuItem(value: 'ar', child: Text('AR', style: TextStyle(color: Colors.white))),
                ],
              ),
            ),
            Tooltip(
              message: t('logout'),
              child: IconButton(
                icon: Icon(Icons.logout, color: _textGrey, size: 22),
                onPressed: () => _handleLogout(context, appState),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: _textGrey, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('darkMode'), style: TextStyle(color: _textGrey, fontSize: 12))),
                  Switch(
                    value: isDark,
                    activeColor: _activeCyan,
                    activeTrackColor: _activeCyan.withOpacity(0.3),
                    inactiveThumbColor: _textGrey,
                    inactiveTrackColor: _bgColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => appState.toggleTheme(),
                  ),
                ],
              ),
              Divider(color: _borderColor, height: 1),
              Row(
                children: [
                  Icon(Icons.language, color: _textGrey, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('language'), style: TextStyle(color: _textGrey, fontSize: 12))),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: langCode,
                      dropdownColor: _cardColor,
                      icon: Icon(Icons.arrow_drop_down, color: _textGrey, size: 18),
                      style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                        DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      ],
                      onChanged: (val) => appState.changeLanguage(val!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _activeCyan.withOpacity(0.2),
                child: Icon(Icons.person_outline, color: _activeCyan, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('myProfile'), style: TextStyle(color: _textColor, fontWeight: FontWeight.w600, fontSize: 12)),
                    Text(t('proUser'), style: TextStyle(color: _textGrey, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout, color: _textGrey, size: 18),
                onPressed: () => _handleLogout(context, appState),
                tooltip: t('logout'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Menu Item Widget (theme‑aware) ──────────────────────────────────────────
class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final bool isCollapsed;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isActive = false,
    this.isCollapsed = false,
    required this.isDark,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeCyan = const Color(0xFF06B6D4);
    final textGrey   = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bgHover    = widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final activeBg   = activeCyan.withOpacity(0.12);
    final activeBorder = activeCyan.withOpacity(0.3);
    final Color iconColor = widget.isActive
        ? activeCyan
        : (_hovered ? (widget.isDark ? Colors.white : Colors.black87) : textGrey);

    final content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: widget.isActive ? activeBg : (_hovered ? bgHover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: widget.isActive ? Border.all(color: activeBorder) : null,
          ),
          child: Row(
            children: [
              SizedBox(width: widget.isCollapsed ? 20 : 14),
              if (!widget.isCollapsed)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 3,
                  height: widget.isActive ? 24 : 0,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: activeCyan, borderRadius: BorderRadius.circular(2)),
                ),
              Icon(widget.icon, color: iconColor, size: 20),
              if (!widget.isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.isActive ? (widget.isDark ? Colors.white : Colors.black87) : textGrey,
                      fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.isCollapsed) {
      return Tooltip(
        message: widget.title,
        preferBelow: false,
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: content,
      );
    }
    return content;
  }
}

// ─── Circuit‑Board Decorative Painter (theme‑aware) ──────────────────────────
class CircuitBoardPainter extends CustomPainter {
  final bool isCollapsed;
  final bool isDark;
  CircuitBoardPainter({required this.isCollapsed, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.04)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.07)
      ..style = PaintingStyle.fill;

    final path = Path();

    if (!isCollapsed) {
      path.moveTo(0, size.height * 0.15);
      path.lineTo(size.width * 0.2, size.height * 0.15);
      path.lineTo(size.width * 0.3, size.height * 0.2);
      canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.2), 3, dotPaint);

      path.moveTo(size.width, size.height * 0.85);
      path.lineTo(size.width * 0.7, size.height * 0.85);
      path.lineTo(size.width * 0.6, size.height * 0.75);
      canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.75), 3, dotPaint);

      path.moveTo(0, size.height * 0.5);
      path.lineTo(size.width * 0.15, size.height * 0.5);
      path.lineTo(size.width * 0.25, size.height * 0.6);
    } else {
      path.moveTo(0, size.height * 0.2);
      path.lineTo(size.width, size.height * 0.2);
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.2), 2, dotPaint);

      path.moveTo(0, size.height * 0.8);
      path.lineTo(size.width, size.height * 0.8);
      canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.8), 2, dotPaint);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CircuitBoardPainter old) =>
      old.isCollapsed != isCollapsed || old.isDark != isDark;
}