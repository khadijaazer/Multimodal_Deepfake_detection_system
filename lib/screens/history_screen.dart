import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../l10n/translations.dart';
import '../screens/landing_screen.dart'; // Import for CircuitBoardPainter

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterType = 'all'; // Use fixed values, not translated strings
  bool _isLoading = true;
  List<Map<String, dynamic>> _scans = [];

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  String t(BuildContext context, String key) {
    final appState = Provider.of<AppState>(context, listen: false);
    return AppTranslations.get(appState.currentLocale.languageCode, key);
  }

  Future<void> _loadScans() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('scans')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);

        if (mounted) {
          setState(() {
            _scans = List<Map<String, dynamic>>.from(response);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t(context, 'failedToLoadScans')}: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final lang = appState.currentLocale.languageCode;
    
    String tr(String key) => AppTranslations.get(lang, key);

    // Dynamic theme colors based on isDark
    final scaffoldBg = isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1A202C) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? const Color(0xFFCED9E6) : const Color(0xFF64748B);
    final accentPrimary = const Color(0xFF0EA5E9);
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final statCardBg = isDark ? const Color(0xFF1A202C) : const Color(0xFFF1F5F9);

    // Circuit colour: white on dark, black on light
    final circuitColor = (isDark ? Colors.white : Colors.black).withOpacity(0.03);

    // Filter & Search - using fixed filter values
    final filteredScans = _scans.where((scan) {
      final matchesFilter = _filterType == 'all' ||
          scan['scan_type'].toString().toLowerCase() == _filterType;
      final matchesSearch = _searchCtrl.text.isEmpty ||
          (scan['file_name'] ?? '').toString().toLowerCase().contains(
                _searchCtrl.text.toLowerCase(),
              );
      return matchesFilter && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ─── CIRCUIT PATTERN BACKGROUND (always visible) ──────────────
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitBoardPainter(color: circuitColor),
            ),
          ),
          // ─── SCROLLABLE CONTENT ───────────────────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // Header
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('analysisHistory'),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('historySubtitle'),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        tr('totalScans'),
                        _scans.length.toString(),
                        Icons.analytics_rounded,
                        accentPrimary,
                        textSecondary,
                        statCardBg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        tr('threatsFound'),
                        _scans.where((s) => s['is_threat'] == true).length.toString(),
                        Icons.warning_rounded,
                        const Color(0xFFDC2626),
                        textSecondary,
                        statCardBg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        tr('safeResults'),
                        _scans.where((s) => s['is_threat'] == false).length.toString(),
                        Icons.verified_user_rounded,
                        const Color(0xFF10B981),
                        textSecondary,
                        statCardBg,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Search & Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() {}),
                          style: TextStyle(
                            color: textMain,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: tr('searchByFilename'),
                            hintStyle: TextStyle(
                              color: textSecondary.withOpacity(0.5),
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: textSecondary.withOpacity(0.7),
                              size: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: borderColor.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      // Filter Dropdown - FIXED: Use fixed values with display text
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterType,
                          dropdownColor: cardBg,
                          icon: Icon(
                            Icons.filter_list_rounded,
                            color: textSecondary.withOpacity(0.7),
                            size: 18,
                          ),
                          style: TextStyle(
                            color: textMain,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          items: [
                            DropdownMenuItem(value: 'all', child: Text(tr('all'))),
                            DropdownMenuItem(value: 'video', child: Text(tr('video'))),
                            DropdownMenuItem(value: 'text', child: Text(tr('text'))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _filterType = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // History List
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(60),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: accentPrimary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                else if (filteredScans.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 56,
                            color: textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            tr('noScansFound'),
                            style: TextStyle(
                              color: textSecondary.withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchCtrl.text.isNotEmpty
                                ? tr('tryAdjustingSearch')
                                : tr('startAnalyzing'),
                            style: TextStyle(
                              color: textSecondary.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredScans.length,
                    itemBuilder: (context, index) {
                      return _buildHistoryCard(
                        filteredScans[index],
                        textMain,
                        textSecondary,
                        borderColor,
                        cardBg,
                        tr,
                      );
                    },
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    Color textSecondary,
    Color cardBg,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 16,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    Map<String, dynamic> item,
    Color textMain,
    Color textSecondary,
    Color borderColor,
    Color cardBg,
    String Function(String) tr,
  ) {
    bool isVideo = item['scan_type']?.toString().toLowerCase() == 'video';
    bool isThreat = item['is_threat'] == true;
    Color statusColor = isThreat
        ? const Color(0xFFDC2626)
        : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isVideo
                  ? const Color(0xFF0EA5E9).withOpacity(0.1)
                  : const Color(0xFFA855F7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isVideo ? Icons.video_camera_front_rounded : Icons.text_snippet_rounded,
              color: isVideo ? const Color(0xFF0EA5E9) : const Color(0xFFA855F7),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['file_name'] ?? tr('unknownFile'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(item['created_at'], tr),
                  style: TextStyle(
                    color: textSecondary.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isThreat ? Icons.warning_rounded : Icons.verified_user_rounded,
                  color: statusColor,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  isThreat ? tr('threat') : tr('safe'),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Actions
          IconButton(
            icon: Icon(
              Icons.more_vert_rounded,
              color: textSecondary.withOpacity(0.7),
              size: 18,
            ),
            tooltip: tr('downloadReport'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('generatingPdfReport')),
                  backgroundColor: const Color(0xFF0EA5E9),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString, String Function(String) tr) {
    if (dateString == null) return tr('unknownDate');
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} ${tr('minutesAgo')}';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} ${tr('hoursAgo')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ${tr('daysAgo')}';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}