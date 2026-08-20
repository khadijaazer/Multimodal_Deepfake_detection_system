import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../l10n/translations.dart';
import 'profile_screen.dart';
import '../screens/landing_screen.dart';

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  int _totalScans = 0;
  int _threatsBlocked = 0;
  List<Map<String, dynamic>> _recentLogs = [];
  bool _isLoading = true;

  // Responsive helper getters
  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 900;
  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  double get screenPadding => isMobile ? 16 : (isTablet ? 20 : 24);
  double get welcomeFontSize => isMobile ? 24 : (isTablet ? 26 : 28);
  int get metricsCrossAxisCount => isDesktop ? 3 : (isTablet ? 2 : 1);
  double get metricsChildAspectRatio =>
      isDesktop ? 2.5 : (isTablet ? 3.0 : 3.5);

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final logs = await supabase
          .from('scans')
          .select()
          .order('created_at', ascending: false)
          .limit(4);

      final totalRes = await supabase
          .from('scans')
          .select('id')
          .count(CountOption.exact);

      final threatsRes = await supabase
          .from('scans')
          .select('id')
          .eq('is_threat', true)
          .count(CountOption.exact);

      if (mounted) {
        setState(() {
          _recentLogs = List<Map<String, dynamic>>.from(logs);
          _totalScans = totalRes.count ?? 0;
          _threatsBlocked = threatsRes.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load dashboard data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(String isoDate, String langCode) {
    try {
      final date = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) {
        return "${diff.inDays} ${AppTranslations.get(langCode, 'daysAgo')}";
      }
      if (diff.inHours > 0) {
        return "${diff.inHours} ${AppTranslations.get(langCode, 'hoursAgo')}";
      }
      if (diff.inMinutes > 0) {
        return "${diff.inMinutes} ${AppTranslations.get(langCode, 'minutesAgo')}";
      }
      return AppTranslations.get(langCode, 'justNow');
    } catch (e) {
      return AppTranslations.get(langCode, 'recentlyLabel');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final lang = appState.currentLocale.languageCode;
    final textMain = isDark ? Colors.white : Colors.black87;
    final textSub = isDark ? Colors.grey : Colors.grey[600]!;
    final circuitColor =
        (isDark ? Colors.white : Colors.black).withOpacity(0.03);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ─── CIRCUIT PATTERN BACKGROUND ───────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitBoardPainter(color: circuitColor),
            ),
          ),
          // ─── SCROLLABLE CONTENT ───────────────────────────────────────
          SingleChildScrollView(
            padding: EdgeInsets.all(screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP BAR
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildUserProfile(isDark, appState, textMain, lang),
                  ],
                ),

                const SizedBox(height: 30),

                // 2. WELCOME & SYSTEM STATUS
                _buildWelcomeSection(isDark, appState, textMain, textSub, lang),

                const SizedBox(height: 24),

                // 3. KEY METRICS
                _buildMetricsGrid(isDark, appState, lang),

                const SizedBox(height: 30),

                // 4. MAIN CONTENT AREA
                _buildMainContent(isDark, appState, lang),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RESPONSIVE COMPONENTS ====================

  Widget _buildUserProfile(
      bool isDark, AppState appState, Color textMain, String lang) {
    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black12 : Colors.grey[100],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
              radius: isMobile ? 14 : 18,
              child: Icon(Icons.person,
                  color: AppTheme.primaryBlue, size: isMobile ? 14 : 18),
            ),
            const SizedBox(width: 12),
            if (!isMobile) ...[
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isTablet ? 100 : 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.userName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                          color: textMain),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      appState.subscriptionPlan.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.keyboard_arrow_down,
                size: isMobile ? 16 : 18, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(bool isDark, AppState appState, Color textMain,
      Color textSub, String lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.get(lang, 'overview'),
                style: TextStyle(
                    fontSize: welcomeFontSize,
                    fontWeight: FontWeight.bold,
                    color: textMain),
              ),
              const SizedBox(height: 4),
              Text(
                "${AppTranslations.get(lang, 'welcome')}, ${appState.userName}",
                style:
                    TextStyle(color: textSub, fontSize: isMobile ? 12 : 14),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle,
                  size: isMobile ? 12 : 16, color: Colors.green),
              if (!isMobile) const SizedBox(width: 6),
              if (!isMobile)
                Text(
                  AppTranslations.get(lang, 'systemOperational'),
                  style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMetricsGrid(bool isDark, AppState appState, String lang) {
    final scansValue = appState.subscriptionPlan == 'free'
        ? "${appState.scansUsed} / ${appState.maxScans}"
        : AppTranslations.get(lang, 'unlimited');

    return GridView.count(
      crossAxisCount: metricsCrossAxisCount,
      shrinkWrap: true,
      crossAxisSpacing: isMobile ? 12 : 20,
      mainAxisSpacing: isMobile ? 12 : 20,
      childAspectRatio: metricsChildAspectRatio,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          AppTranslations.get(lang, 'totalScans'),
          "$_totalScans",
          AppTranslations.get(lang, 'allTime'),
          Icons.analytics,
          Colors.blue,
          isDark,
        ),
        _buildStatCard(
          AppTranslations.get(lang, 'threatsBlocked'),
          "$_threatsBlocked",
          AppTranslations.get(lang, 'scamsAndFakes'),
          Icons.shield,
          Colors.red,
          isDark,
        ),
        _buildStatCard(
          "${AppTranslations.get(lang, 'currentPlan')}: ${appState.subscriptionPlan.toUpperCase()}",
          scansValue,
          AppTranslations.get(lang, 'scansUsed'),
          Icons.auto_awesome,
          Colors.purple,
          isDark,
        ),
      ],
    );
  }

  Widget _buildMainContent(bool isDark, AppState appState, String lang) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildSectionHeader(
                  AppTranslations.get(lang, 'recentActivities'),
                  () => appState.setIndex(6),
                  lang,
                ),
                const SizedBox(height: 16),
                _buildSecurityLog(isDark, lang),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildSectionHeader(
                  AppTranslations.get(lang, 'quickActions'),
                  null,
                  lang,
                ),
                const SizedBox(height: 16),
                _buildQuickActions(isDark, appState, lang),
                const SizedBox(height: 24),
                _buildMiniChart(isDark, lang),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildSectionHeader(
            AppTranslations.get(lang, 'quickActions'),
            null,
            lang,
          ),
          const SizedBox(height: 16),
          _buildQuickActions(isDark, appState, lang),
          const SizedBox(height: 24),
          _buildSectionHeader(
            AppTranslations.get(lang, 'recentActivities'),
            () => appState.setIndex(6),
            lang,
          ),
          const SizedBox(height: 16),
          _buildSecurityLog(isDark, lang),
        ],
      );
    }
  }

  // --- COMPONENT WIDGETS ---

  Widget _buildStatCard(String title, String value, String sub, IconData icon,
      Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 20)
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            decoration:
                BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: isMobile ? 20 : 28),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: TextStyle(
                        color: isDark ? Colors.grey : Colors.grey[600],
                        fontSize: isMobile ? 10 : 12)),
                Text(
                  _isLoading ? "..." : value,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: isMobile ? 18 : 24,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(sub,
                    style: TextStyle(
                        color: color,
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, VoidCallback? onSeeAll, String lang) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold)),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding:
                  EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
              minimumSize: Size.zero,
            ),
            child: Text(
              isMobile
                  ? AppTranslations.get(lang, 'view')
                  : AppTranslations.get(lang, 'viewLog'),
            ),
          ),
      ],
    );
  }

  Widget _buildSecurityLog(bool isDark, String lang) {
    if (_isLoading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator()));
    }

    if (_recentLogs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 20 : 30),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            AppTranslations.get(lang, 'noRecentActivity'),
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: _recentLogs.map((log) {
        bool isThreat = log['is_threat'] == true;
        bool isVideo = log['scan_type'] == 'video';

        String title = isVideo
            ? AppTranslations.get(lang, 'deepfakeVideoAnalysis')
            : AppTranslations.get(lang, 'scamTextAnalysis');
        String subtitle =
            log['file_name'] ?? AppTranslations.get(lang, 'unknownFile');
        String badge = log['risk_level'] ??
            (isThreat
                ? AppTranslations.get(lang, 'critical')
                : AppTranslations.get(lang, 'safe'));
        Color color = isThreat ? Colors.red : Colors.green;

        return _logItem(
            title, subtitle, badge, color, _timeAgo(log['created_at'], lang), isDark);
      }).toList(),
    );
  }

  Widget _logItem(String title, String sub, String badge, Color color,
      String time, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E32) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 12 : 14),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: TextStyle(
                      color: isDark ? Colors.grey : Colors.grey[600],
                      fontSize: isMobile ? 10 : 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time,
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: isMobile ? 8 : 10)),
              const SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6 : 10,
                    vertical: isMobile ? 2 : 4),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  badge,
                  style: TextStyle(
                      color: color,
                      fontSize: isMobile ? 8 : 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark, AppState appState, String lang) {
    return Column(
      children: [
        _actionButton(
          AppTranslations.get(lang, 'scanNewText'),
          Icons.text_snippet,
          Colors.purple,
          () => appState.setIndex(3),
          isDark,
        ),
        const SizedBox(height: 12),
        _actionButton(
          AppTranslations.get(lang, 'uploadVideo'),
          Icons.cloud_upload,
          Colors.blue,
          () => appState.setIndex(4),
          isDark,
        ),
        const SizedBox(height: 12),
        _actionButton(
          AppTranslations.get(lang, 'apiUsage'),
          Icons.api,
          Colors.teal,
          () => appState.setIndex(2),
          isDark,
        ),
      ],
    );
  }

  Widget _actionButton(String title, IconData icon, Color color,
      VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: isMobile ? 12 : 16,
            horizontal: isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: isMobile ? 20 : 24),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 14),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: isMobile ? 12 : 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChart(bool isDark, String lang) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.get(lang, 'weeklyThreatLevel'),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12 : 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(30, Colors.blue),
                _bar(50, Colors.blue),
                _bar(40, Colors.blue),
                _bar(80, Colors.red),
                _bar(60, Colors.orange),
                _bar(20, Colors.blue),
                _bar(90, Colors.red),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _bar(double h, Color c) {
    double barWidth = isMobile ? 6 : 8;
    return Container(
      width: barWidth,
      height: h,
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
    );
  }
}