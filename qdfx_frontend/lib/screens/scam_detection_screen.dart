import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/scam_detection_service.dart';
import '../l10n/translations.dart';
import '../layout/responsive_layout.dart';
import '../screens/landing_screen.dart'; // Import for CircuitBoardPainter

class ScamDetectionScreen extends StatefulWidget {
  const ScamDetectionScreen({super.key});

  @override
  State<ScamDetectionScreen> createState() => _ScamDetectionScreenState();
}

class _ScamDetectionScreenState extends State<ScamDetectionScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  bool _isAnalyzing = false;
  bool _isServerConnected = true;
  bool _hasText = false; // NEW: tracks whether the text field has content
  Map<String, dynamic>? _result;

  final ScamDetectionService _apiService = ScamDetectionService();

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
    // Listen to text changes so the clear button shows/hides reactively
    _textCtrl.addListener(() {
      final hasText = _textCtrl.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  String t(BuildContext context, String key) {
    final appState = Provider.of<AppState>(context, listen: false);
    return AppTranslations.get(appState.currentLocale.languageCode, key);
  }

  Future<void> _checkServerConnection() async {
    final isConnected = await _apiService.checkHealth();
    if (mounted) {
      setState(() => _isServerConnected = isConnected);
    }
  }

  void _newScan() {
    setState(() {
      _textCtrl.clear();
      _hasText = false;
      _result = null;
      _isAnalyzing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(context, 'newScanReady')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _analyzeText() async {
    if (_textCtrl.text.isEmpty) {
      _showErrorDialog(t(context, 'enterTextToAnalyze'));
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    try {
      if (!_isServerConnected) {
        final isConnected = await _apiService.checkHealth();
        if (!isConnected) throw Exception(t(context, 'serverNotRunning'));
        setState(() => _isServerConnected = true);
      }

      final result = await _apiService.analyzeText(_textCtrl.text);

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          String snippet = _textCtrl.text.replaceAll('\n', ' ');
          snippet =
              snippet.length > 40 ? "${snippet.substring(0, 40)}..." : snippet;

          await Supabase.instance.client.from('scans').insert({
            'user_id': user.id,
            'scan_type': 'text',
            'file_name': '${t(context, 'textLabel')}: "$snippet"',
            'is_threat': result['isScam'],
            'confidence_score': result['confidence'],
            'risk_level':
                result['threat_level'] ?? (result['isScam'] ? 'HIGH' : 'LOW'),
          });
        }
      } catch (e) {
        debugPrint("Failed to save history to DB: $e");
      }

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _isServerConnected = false;
        });
        _showErrorDialog(
          '${t(context, 'failedToAnalyze')}: ${e.toString()}\n\n'
          '${t(context, 'serverStartMessage')} ${ScamDetectionService.baseUrl}',
        );
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(context, 'error')),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t(context, 'ok'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _checkServerConnection();
            },
            child: Text(t(context, 'retryConnection')),
          ),
        ],
      ),
    );
  }

  Color _getThreatLevelColor(String level) {
    switch (level) {
      case 'CRITICAL':
        return const Color(0xFF7B1FA2);
      case 'HIGH':
        return const Color(0xFFC62828);
      case 'MEDIUM':
        return const Color(0xFFEF6C00);
      case 'LOW':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey;
    }
  }

  IconData _getThreatLevelIcon(String level) {
    switch (level) {
      case 'CRITICAL':
        return Icons.warning_amber_rounded;
      case 'HIGH':
        return Icons.error_outline;
      case 'MEDIUM':
        return Icons.warning;
      case 'LOW':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _getThreatLevelText(String level, String Function(String) tr) {
    switch (level) {
      case 'CRITICAL':
        return tr('criticalThreat');
      case 'HIGH':
        return tr('highRisk');
      case 'MEDIUM':
        return tr('mediumRisk');
      case 'LOW':
        return tr('lowRisk');
      default:
        return tr('unknown');
    }
  }

  Widget _buildInfoChip(String label, String value, Color color,
      {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          ],
        ],
      ),
    );
  }

  // ─── Shared colors ────────────────────────────────────────────────────────

  Map<String, Color> _getColors(bool isDark) => {
        'bg': isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        'card': isDark ? const Color(0xFF1E293B) : Colors.white,
        'text': isDark ? Colors.white : Colors.black87,
        'border': isDark ? Colors.white10 : const Color(0xFFE2E8F0),
      };

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final lang = appState.currentLocale.languageCode;
    String tr(String key) => AppTranslations.get(lang, key);

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
          ResponsiveLayout(
            useScaffold: false,
            mobileBody: _buildMobile(isDark, tr),
            tabletBody: _buildTablet(isDark, tr),
            desktopBody: _buildDesktop(isDark, tr),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE  (< 600)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobile(bool isDark, String Function(String) tr) {
    final colors = _getColors(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark, tr, fontSize: 18),
          const SizedBox(height: 6),
          _buildSubtitle(isDark, tr),
          const SizedBox(height: 20),
          _buildInputCard(isDark, tr, colors, maxLines: 5),
          const SizedBox(height: 20),
          if (_result != null) _buildEnhancedResultCard(_result!, isDark, tr),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TABLET  (600 – 899)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTablet(bool isDark, String Function(String) tr) {
    final colors = _getColors(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark, tr, fontSize: 22),
          const SizedBox(height: 8),
          _buildSubtitle(isDark, tr),
          const SizedBox(height: 24),
          _buildInputCard(isDark, tr, colors, maxLines: 6),
          const SizedBox(height: 24),
          if (_result != null) _buildEnhancedResultCard(_result!, isDark, tr),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP  (≥ 900) – two-column layout
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktop(bool isDark, String Function(String) tr) {
    final colors = _getColors(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark, tr, fontSize: 26),
          const SizedBox(height: 8),
          _buildSubtitle(isDark, tr),
          const SizedBox(height: 32),

          // Two-column: input left, result right (when available)
          if (_result != null)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildInputCard(isDark, tr, colors, maxLines: 10),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: _buildEnhancedResultCard(_result!, isDark, tr),
                  ),
                ],
              ),
            )
          else
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _buildInputCard(isDark, tr, colors, maxLines: 8),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Responsive header: stacks vertically on very narrow screens to avoid overflow.
  Widget _buildHeader(bool isDark, String Function(String) tr,
      {required double fontSize}) {
    final titleText = Text(
      tr('scamDetector'),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );

    final badges = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_result != null) ...[
          _buildNewScanButton(isDark, tr),
          const SizedBox(width: 8),
        ],
        _buildServerBadge(tr),
      ],
    );

    // Use LayoutBuilder to switch between row and column on very narrow widths
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rough threshold: if width is tight, wrap to column
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText,
              const SizedBox(height: 8),
              badges,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleText),
            const SizedBox(width: 8),
            badges,
          ],
        );
      },
    );
  }

  Widget _buildNewScanButton(bool isDark, String Function(String) tr) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.7)),
      ),
      child: InkWell(
        onTap: _newScan,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.blue, size: 14),
              const SizedBox(width: 4),
              Text(
                tr('newScan'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerBadge(String Function(String) tr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _isServerConnected
            ? Colors.green.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isServerConnected
                ? Colors.green.withOpacity(0.7)
                : Colors.red.withOpacity(0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isServerConnected ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _isServerConnected ? tr('serverOnline') : tr('serverOffline'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _isServerConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(bool isDark, String Function(String) tr) {
    return Text(
      tr('scamDetectorSubtitle'),
      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
    );
  }

  Widget _buildInputCard(
    bool isDark,
    String Function(String) tr,
    Map<String, Color> colors, {
    required int maxLines,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors['card'],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors['border']!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: label + offline badge ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('pasteText'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              if (!_isServerConnected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(tr('offlineMode'),
                      style: const TextStyle(
                          fontSize: 10, color: Colors.orange)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Text field ───────────────────────────────────────────────
          TextField(
            controller: _textCtrl,
            maxLines: maxLines,
            style: TextStyle(color: colors['text'], fontSize: 15),
            decoration: InputDecoration(
              hintText: tr('exampleText'),
              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Analyze + Clear buttons ──────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isServerConnected
                          ? const Color(0xFF2E86DE)
                          : Colors.grey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 5,
                    ),
                    onPressed: (_isAnalyzing || !_isServerConnected)
                        ? null
                        : _analyzeText,
                    child: _isAnalyzing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(tr('analyzing'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1)),
                            ],
                          )
                        : Text(
                            _isServerConnected
                                ? tr('analyzeText')
                                : tr('serverOffline'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1),
                          ),
                  ),
                ),
              ),

              // Clear button — shown only when there's text (driven by listener)
              if (_hasText) ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      setState(() {
                        _textCtrl.clear();
                        _hasText = false;
                        _result = null;
                      });
                    },
                    child: const Icon(Icons.clear, size: 20),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── Result Card ──────────────────────────────────────────────────────────

  Widget _buildEnhancedResultCard(
      Map<String, dynamic> result, bool isDark, String Function(String) tr) {
    final bool isScam = result['isScam'] as bool;
    final String level = result['threat_level'] ?? (isScam ? 'HIGH' : 'LOW');
    final Color threatColor = _getThreatLevelColor(level);
    final Color statusColor = isScam ? threatColor : const Color(0xFF00C853);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.15), blurRadius: 30)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badge row ────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Verdict badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getThreatLevelIcon(level),
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      isScam
                          ? _getThreatLevelText(level, tr)
                          : tr('safeMessage'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1),
                    ),
                  ],
                ),
              ),

              // Risk score badge (scam only)
              if (isScam)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.analytics,
                          color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${tr('riskScore')}: ${result['risk_score']}/100',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),


            ],
          ),

          const SizedBox(height: 20),

          // ── Info chips ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                  child: _buildInfoChip(
                      tr('confidence'), '${result['confidence']}%', statusColor)),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoChip(
                  tr('language'),
                  result['language'] as String,
                  Colors.blue,
                  subtitle: result['language_confidence'] != null
                      ? '${result['language_confidence']}% ${tr('confidence').toLowerCase()}'
                      : null,
                ),
              ),
            ],
          ),

          // ── Scam categories ──────────────────────────────────────────
          if (result['scam_category'] != null &&
              (result['scam_category'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(tr('scamCategories'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (result['scam_category'] as List).map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(cat as String,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
          ],

          // ── Suspicious URLs ──────────────────────────────────────────
          if (result['urls_found'] != null &&
              (result['urls_found'] as List).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(tr('suspiciousUrls'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...(result['urls_found'] as List).take(3).map((url) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Text(url as String,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500)),
              );
            }),
          ],

          // ── Key indicators ───────────────────────────────────────────
          const SizedBox(height: 16),
          Text(tr('keyIndicators'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ...(result['indicators'] as List).map((indicator) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                      isScam
                          ? Icons.warning_amber
                          : Icons.check_circle,
                      size: 16,
                      color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      indicator as String,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey[300]
                              : Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            );
          }),

          // ── Safety tips ──────────────────────────────────────────────
          if (isScam &&
              result['safety_tips'] != null &&
              (result['safety_tips'] as List).isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security,
                          color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(tr('safetyTips'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...(result['safety_tips'] as List).map((tip) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(color: Colors.blue)),
                          Expanded(
                              child: Text(tip as String,
                                  style:
                                      const TextStyle(fontSize: 12))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // ── Action buttons ───────────────────────────────────────────
          const SizedBox(height: 20),
          // Use Wrap so buttons stack on narrow screens instead of overflowing
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (isScam)
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flag, size: 18),
                    label: Text(tr('reportScam')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => _showReportDialog(tr),
                  ),
                ),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _textCtrl.clear();
                    _hasText = false;
                    _result = null;
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(tr('clear')),
                ),
              ),
              if (!isScam)
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(tr('shareResult')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => _showShareDialog(result, tr),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  void _showReportDialog(String Function(String) tr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('reportScam')),
        content: Text(tr('reportScamMessage')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'))),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(tr('scamReported')),
                    backgroundColor: Colors.green),
              );
            },
            child: Text(tr('report')),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(
      Map<String, dynamic> result, String Function(String) tr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('shareResult')),
        content: Text(
          '${tr('analysisResult')}: ${result['isScam'] ? tr('scam').toUpperCase() : tr('safe').toUpperCase()}\n'
          '${tr('confidence')}: ${result['confidence']}%\n'
          '${tr('language')}: ${result['language']}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(tr('resultCopied')),
                    backgroundColor: Colors.green),
              );
            },
            child: Text(tr('copyToClipboard')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }
}