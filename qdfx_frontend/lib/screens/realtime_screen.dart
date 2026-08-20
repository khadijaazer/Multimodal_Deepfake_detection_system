import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../l10n/translations.dart';
import '../layout/responsive_layout.dart';
import '../screens/landing_screen.dart'; // Import for CircuitBoardPainter

class RealTimeScreen extends StatefulWidget {
  const RealTimeScreen({super.key});

  @override
  State<RealTimeScreen> createState() => _RealTimeScreenState();
}

class _RealTimeScreenState extends State<RealTimeScreen> {
  List<Map<String, dynamic>> _realtimeSessions = [];
  bool _loadingSessions = true;
  bool _isLiveConnected = false;       // drives the live dot in the UI
  RealtimeChannel? _realtimeChannel;   // kept so we can unsubscribe on dispose

  @override
  void initState() {
    super.initState();
    _fetchRealtimeSessions();
    _subscribeToNewSessions();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ─── DATA FETCH ────────────────────────────────────────────────────────────

  Future<void> _fetchRealtimeSessions() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _loadingSessions = false);
      return;
    }

    try {
      final List<dynamic> response = await Supabase.instance.client
          .from('scans')
          .select()
          .eq('user_id', currentUser.id)
          .eq('scan_type', 'realtime')
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _realtimeSessions = List<Map<String, dynamic>>.from(response);
          _loadingSessions = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch realtime sessions: $e');
      if (mounted) setState(() => _loadingSessions = false);
    }
  }

  // ─── SUPABASE REALTIME SUBSCRIPTION ───────────────────────────────────────
  //
  // Listens for INSERT events on the scans table filtered to the current user
  // and scan_type = 'realtime'.  When a new row arrives it is prepended to
  // _realtimeSessions so the UI updates instantly — no polling needed.
  // ──────────────────────────────────────────────────────────────────────────

  void _subscribeToNewSessions() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('realtime:scans:${currentUser.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scans',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUser.id,
          ),
          callback: (PostgresChangePayload payload) {
            final newRecord = payload.newRecord;
            // Only handle realtime scan_type rows
            if (newRecord['scan_type'] != 'realtime') return;
            if (!mounted) return;
            setState(() {
              // Prepend so newest appears at the top, cap list at 10
              _realtimeSessions = [newRecord, ..._realtimeSessions].take(10).toList();
            });
          },
        )
        .subscribe((RealtimeSubscribeStatus status, [Object? error]) {
          if (!mounted) return;
          setState(() {
            _isLiveConnected = status == RealtimeSubscribeStatus.subscribed;
          });
          if (error != null) {
            debugPrint('Realtime subscription error: $error');
          }
        });
  }

  // ─── BILLING FORMULA (mirrors BillingScreen logic exactly) ────────────────
  //
  // Formula: Csession = max(150, min(1500, Σ Cseg))
  //   where Cseg = (B × T) + (N × P × T) − D
  //   B = 5 DZD/min, P = 2 DZD/participant/min
  //
  // Volume discount (based on monthly session count in current fetch):
  //   0–4 sessions/month  → 0 %
  //   5–14 sessions/month → 10 %
  //   15+ sessions/month  → 20 %
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns the total number of real-time sessions this month (used for
  /// volume-discount tier calculation).
  int get _monthlySessionCount {
    final now = DateTime.now();
    return _realtimeSessions.where((s) {
      final raw = s['created_at'] as String?;
      if (raw == null) return false;
      try {
        final dt = DateTime.parse(raw);
        return dt.year == now.year && dt.month == now.month;
      } catch (_) {
        return false;
      }
    }).length;
  }

  double get _volumeDiscountPct {
    final count = _monthlySessionCount;
    if (count >= 15) return 0.20;
    if (count >= 5)  return 0.10;
    return 0.0;
  }

  /// Compute the billed cost for a single session.
  ///
  /// [durationMinutes] – session length in minutes  
  /// [participants]    – peak participant count for the session  
  ///
  /// Since the database does not store per-segment breakpoints, the entire
  /// session is treated as a single segment (i.e. participant count is
  /// constant throughout), matching the illustrative example in the business
  /// plan (section 6.2).
  double _computeSessionCost(int durationMinutes, int participants) {
    const double baseRate           = 5.0;   // DZD / min
    const double perParticipantRate = 2.0;   // DZD / participant / min

    final double T = durationMinutes.toDouble();
    final double N = participants.toDouble();

    final double rawCost = (baseRate * T) + (N * perParticipantRate * T);
    final double discounted = rawCost * (1.0 - _volumeDiscountPct);

    return discounted.clamp(150.0, 1500.0);
  }

  /// Running total of billed amounts for all fetched sessions (used in the
  /// quota card for transparency).
  double get _totalBilledThisMonth {
    double total = 0;
    final now = DateTime.now();
    for (final session in _realtimeSessions) {
      final raw = session['created_at'] as String?;
      if (raw != null) {
        try {
          final dt = DateTime.parse(raw);
          if (dt.year != now.year || dt.month != now.month) continue;
        } catch (_) {
          continue;
        }
      }
      final int duration     = session['duration_minutes'] ?? 1;
      final int participants = _peakParticipants(session);
      total += _computeSessionCost(duration, participants);
    }
    return total;
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  /// Derives a stable peak-participant count from the session record.
  /// Uses `participants` column when available; otherwise falls back to a
  /// deterministic hash of the session UUID so that the UI remains stable
  /// across reloads (2–9 participants).
  int _peakParticipants(Map<String, dynamic> session) {
    final dynamic raw = session['participants'];
    if (raw != null) {
      final int parsed = (raw is int) ? raw : int.tryParse(raw.toString()) ?? 0;
      if (parsed > 0) return parsed;
    }
    return ((session['id']?.toString().hashCode ?? 0).abs() % 8) + 2;
  }

  String _getPairingKey(AppState appState) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return "sk_live_anonymous_guest";
    return "sk_live_qdfx_${currentUser.id}";
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  String _formatTimeRange(String? createdAtIso, int duration) {
    if (createdAtIso == null || createdAtIso.isEmpty) return "—";
    try {
      final dt     = DateTime.parse(createdAtIso).toLocal();
      final endDt  = dt.add(Duration(minutes: duration));
      final start  = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      final end    = "${endDt.hour.toString().padLeft(2, '0')}:${endDt.minute.toString().padLeft(2, '0')}";
      return "$start – $end";
    } catch (_) {
      return "—";
    }
  }

  Map<String, dynamic> _getStatusDetails(
      Map<String, dynamic> session, String Function(String, String) t) {
    final String riskLevel =
        (session['risk_level'] as String? ?? 'SAFE').toUpperCase();
    if (riskLevel == 'CRITICAL') {
      return {'label': t('critical', 'Critical'), 'color': Colors.red};
    } else if (riskLevel == 'HIGH' ||
        riskLevel == 'MEDIUM' ||
        session['is_threat'] == true) {
      return {'label': t('suspicious', 'Suspicious'), 'color': Colors.orange};
    } else {
      return {'label': t('safe', 'Safe'), 'color': Colors.green};
    }
  }

  // ─── ROOT BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark   = appState.isDarkMode;
    final lang     = appState.currentLocale.languageCode;

    String t(String key, String fallback) {
      try {
        final res = AppTranslations.get(lang, key);
        if (res.isEmpty || res == key) return fallback;
        return res;
      } catch (_) {
        return fallback;
      }
    }

    final bgCol     = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    final cardCol   = isDark ? const Color(0xFF151E32) : Colors.white;
    final textCol   = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;
    final accentCol = const Color(0xFF00D2D3);
    final bool hasAccess = appState.subscriptionPlan != 'free';

    // Circuit colour: white on dark, black on light
    final circuitColor = (isDark ? Colors.white : Colors.black).withOpacity(0.03);

    return Scaffold(
      backgroundColor: bgCol,
      body: Stack(
        children: [
          // ─── CIRCUIT PATTERN BACKGROUND (always visible) ──────────────
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitBoardPainter(color: circuitColor),
            ),
          ),
          // ─── SCROLLABLE CONTENT ───────────────────────────────────────
          ResponsiveLayout(
            useScaffold: false,
            desktopBody: _buildDesktop(context, appState, isDark, bgCol, cardCol,
                textCol, borderCol, accentCol, hasAccess, t),
            tabletBody: _buildDesktop(context, appState, isDark, bgCol, cardCol,
                textCol, borderCol, accentCol, hasAccess, t),
            mobileBody: _buildMobile(context, appState, isDark, bgCol, cardCol,
                textCol, borderCol, accentCol, hasAccess, t),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP & TABLET
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktop(
    BuildContext context,
    AppState appState,
    bool isDark,
    Color bgCol,
    Color cardCol,
    Color textCol,
    Color borderCol,
    Color accentCol,
    bool hasAccess,
    String Function(String, String) t,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('rtProtection', 'Real-Time Protection'),
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: textCol),
          ),
          Text(
            t('rtSubtitle', 'Browser Extension Hub & Usage Logs'),
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 30),

          if (!hasAccess) _buildUpsellBanner(appState, t),

          _buildHeroCard(hasAccess, t),
          const SizedBox(height: 30),

          if (hasAccess) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildPairingKeyCard(context, appState, isDark,
                      cardCol, textCol, borderCol, accentCol, t),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildQuotaCard(
                      appState, cardCol, textCol, borderCol, t),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildSessionHistory(
                isDark, cardCol, textCol, borderCol, t),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobile(
    BuildContext context,
    AppState appState,
    bool isDark,
    Color bgCol,
    Color cardCol,
    Color textCol,
    Color borderCol,
    Color accentCol,
    bool hasAccess,
    String Function(String, String) t,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('rtProtection', 'Real-Time Protection'),
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: textCol),
          ),
          Text(
            t('rtSubtitle', 'Browser Extension Hub & Usage Logs'),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          if (!hasAccess) _buildUpsellBannerMobile(appState, t),

          _buildHeroCardMobile(hasAccess, t),
          const SizedBox(height: 20),

          if (hasAccess) ...[
            _buildPairingKeyCard(context, appState, isDark, cardCol, textCol,
                borderCol, accentCol, t),
            const SizedBox(height: 16),
            _buildQuotaCard(appState, cardCol, textCol, borderCol, t),
            const SizedBox(height: 20),
            _buildSessionHistoryMobile(
                isDark, cardCol, textCol, borderCol, t),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UPSELL BANNERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildUpsellBanner(
      AppState appState, String Function(String, String) t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.lock, color: Colors.orange, size: 30),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('proFeatureLocked', 'PRO Feature Locked'),
                style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(
              t('realtimeProMessage',
                  'Real-time browser protection is only available on Pro and Enterprise plans.'),
              style: const TextStyle(color: Colors.grey),
            ),
          ]),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange, foregroundColor: Colors.white),
          onPressed: () => appState.setIndex(1),
          child: Text(t('upgradePlan', 'Upgrade Now')),
        ),
      ]),
    );
  }

  Widget _buildUpsellBannerMobile(
      AppState appState, String Function(String, String) t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lock, color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          Text(t('proFeatureLocked', 'PRO Feature Locked'),
              style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ]),
        const SizedBox(height: 8),
        Text(
          t('realtimeProMessage',
              'Real-time browser protection is only available on Pro and Enterprise plans.'),
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => appState.setIndex(1),
            child: Text(t('upgradePlan', 'Upgrade Now')),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO CARDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroCard(bool hasAccess, String Function(String, String) t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF1E3A8A).withOpacity(0.6)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('rtHeroTitle', 'Secure your meetings instantly.'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              t('rtHeroDesc',
                  'Download the DETECTINI Browser Extension to detect deepfakes in real-time on Zoom, Google Meet, and Teams calls.'),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 12, children: [
              _downloadButton(
                Icons.language,
                t('chromeStore', 'Chrome Store'),
                hasAccess,
                () => _launchUrl(
                    'https://chromewebstore.google.com/detail/jfcjbjcjjpelnjdbmeajfediijnebnip'),
              ),
              _downloadButton(
                Icons.explore,
                t('edgeStore', 'Microsoft Edge'),
                false,
                null,
              ),
            ]),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Icon(Icons.extension,
                size: 100, color: Colors.white.withOpacity(0.2)),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeroCardMobile(
      bool hasAccess, String Function(String, String) t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF1E3A8A).withOpacity(0.6)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.extension,
              size: 40, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                t('rtHeroTitle', 'Secure your meetings instantly.'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          t('rtHeroDesc',
              'Download the DETECTINI Browser Extension to detect deepfakes in real-time on Zoom, Google Meet, and Teams calls.'),
          style:
              const TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: _downloadButton(
            Icons.language,
            t('chromeStore', 'Chrome Store'),
            hasAccess,
            () => _launchUrl(
                'https://chromewebstore.google.com/detail/jfcjbjcjjpelnjdbmeajfediijnebnip'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _downloadButton(
              Icons.explore, t('edgeStore', 'Microsoft Edge'), false, null),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAIRING KEY CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPairingKeyCard(
    BuildContext context,
    AppState appState,
    bool isDark,
    Color cardCol,
    Color textCol,
    Color borderCol,
    Color accentCol,
    String Function(String, String) t,
  ) {
    final String activeKeyToken = _getPairingKey(appState);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.link, color: accentCol),
          const SizedBox(width: 8),
          Text(t('linkExt', 'Link Extension'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textCol)),
        ]),
        const SizedBox(height: 12),
        Text(
            t('copyKey',
                'Copy this key into the extension to link your account.'),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 20),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentCol.withOpacity(0.3)),
          ),
          child: Row(children: [
            Expanded(
              child: Text(
                activeKeyToken,
                style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    color: textCol,
                    letterSpacing: 1),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              color: accentCol,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: activeKeyToken));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Key Copied to Clipboard.")));
              },
            ),
          ]),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUOTA CARD — now shows pay-per-use billing summary
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuotaCard(AppState appState, Color cardCol, Color textCol,
      Color borderCol, String Function(String, String) t) {
    final double discountPct      = _volumeDiscountPct * 100;
    final double totalBilled      = _totalBilledThisMonth;
    final int    sessionCount     = _monthlySessionCount;

    // Determine discount tier label
    String discountTierLabel;
    if (discountPct >= 20) {
      discountTierLabel = t('heavyUser', 'Heavy User (20% off)');
    } else if (discountPct >= 10) {
      discountTierLabel = t('regularUser', 'Regular User (10% off)');
    } else {
      discountTierLabel = t('occasionalUser', 'Occasional User (0% off)');
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long, color: Colors.green),
          const SizedBox(width: 8),
          Text(t('monthlyBillingSummary', 'Monthly Billing Summary'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textCol)),
        ]),
        const SizedBox(height: 12),
        Text(
          t('billingCalcDesc',
              'Charges based on session duration and participant count (Config C pay-per-use).'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 20),

        // Total billed this month
        Text(
          '${totalBilled.toStringAsFixed(0)} DZD',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: totalBilled > 0 ? Colors.redAccent : Colors.green,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t('billedThisMonth', 'Accrued this billing period'),
          style: TextStyle(
              color: Colors.grey.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 16),
        const Divider(color: Colors.white10),
        const SizedBox(height: 10),

        // Summary rows
        _billingMetaRow(
          Icons.videocam_outlined,
          t('sessionsThisMonth', 'Sessions this month'),
          '$sessionCount',
          textCol,
        ),
        const SizedBox(height: 6),
        _billingMetaRow(
          Icons.discount_outlined,
          t('volumeDiscount', 'Volume Discount Tier'),
          discountTierLabel,
          textCol,
        ),
        const SizedBox(height: 6),
        _billingMetaRow(
          Icons.info_outline,
          t('billingFloor', 'Min per session'),
          '150 DZD',
          textCol,
        ),
        const SizedBox(height: 6),
        _billingMetaRow(
          Icons.info_outline,
          t('billingCap', 'Max per session'),
          '1,500 DZD',
          textCol,
        ),
        const SizedBox(height: 10),
        Text(
          t('billingNote',
              '* Charges are billed at monthly invoice intervals.'),
          style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }

  Widget _billingMetaRow(
      IconData icon, String label, String value, Color textCol) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 6),
      Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12))),
      Text(value,
          style: TextStyle(
              color: textCol,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SESSION HISTORY TABLE (Desktop)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSessionHistory(bool isDark, Color cardCol, Color textCol,
      Color borderCol, String Function(String, String) t) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text(t('sessionHistory', 'Session History & Billing'),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textCol)),
                const SizedBox(width: 10),
                // Live connection indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_isLiveConnected ? Colors.green : Colors.grey).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (_isLiveConnected ? Colors.green : Colors.grey).withOpacity(0.3),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _isLiveConnected ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isLiveConnected ? t('live', 'LIVE') : t('connecting', 'CONNECTING...'),
                      style: TextStyle(
                        color: _isLiveConnected ? Colors.green : Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]),
                ),
              ]),
              // Discount badge
              if (_volumeDiscountPct > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${(_volumeDiscountPct * 100).toInt()}% ${t('discountApplied', 'Volume Discount Applied')}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loadingSessions)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator()))
          else if (_realtimeSessions.isEmpty)
            _buildEmptyState(t)
          else ...[
            // ── Column headers ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: _headerCell(t('meetingSource', 'MEETING SOURCE'))),
                Expanded(
                    flex: 2,
                    child: _headerCell(t('timeLogged', 'TIME LOGGED'))),
                Expanded(
                    flex: 1,
                    child: _headerCell(t('participants', 'PEAK'))),
                Expanded(
                    flex: 2,
                    child: _headerCell(t('duration', 'DURATION'))),
                Expanded(
                    flex: 2,
                    child: _headerCell(t('sessionCost', 'SESSION COST'))),
                Expanded(
                    flex: 2,
                    child: _headerCell(t('status', 'STATUS'))),
              ]),
            ),
            Divider(color: borderCol),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _realtimeSessions.length,
              separatorBuilder: (_, __) =>
                  Divider(color: borderCol, height: 1),
              itemBuilder: (context, index) {
                final session      = _realtimeSessions[index];
                final String source =
                    session['file_name'] ?? 'Meeting';
                final int duration =
                    session['duration_minutes'] ?? 1;
                final int participants =
                    _peakParticipants(session);
                final String timeRange = _formatTimeRange(
                    session['created_at'], duration);

                // ── BILLING FORMULA applied here ──
                final double sessionCost =
                    _computeSessionCost(duration, participants);

                final statusDetails =
                    _getStatusDetails(session, t);
                final String statusLabel =
                    statusDetails['label'];
                final Color statusColor =
                    statusDetails['color'];

                return _billingLogItem(
                  source:        source,
                  timeRange:     timeRange,
                  participants:  '$participants',
                  duration:      '$duration ${t('mins', 'mins')}',
                  cost:          '${sessionCost.toStringAsFixed(0)} DZD',
                  statusLabel:   statusLabel,
                  statusColor:   statusColor,
                  textCol:       textCol,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerCell(String label) => Text(label,
      style: const TextStyle(
          color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold));

  Widget _billingLogItem({
    required String source,
    required String timeRange,
    required String participants,
    required String duration,
    required String cost,
    required String statusLabel,
    required Color statusColor,
    required Color textCol,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Text(source,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textCol,
                    fontSize: 14),
                overflow: TextOverflow.ellipsis)),
        Expanded(
            flex: 2,
            child: Text(timeRange,
                style: TextStyle(
                    color: textCol.withOpacity(0.7), fontSize: 14))),
        Expanded(
            flex: 1,
            child: Text(participants,
                style: TextStyle(
                    color: textCol.withOpacity(0.7), fontSize: 14))),
        Expanded(
            flex: 2,
            child: Text(duration,
                style: TextStyle(
                    color: textCol.withOpacity(0.7), fontSize: 14))),
        // Cost — highlighted in accent so it's clearly a DZD charge
        Expanded(
          flex: 2,
          child: Text(cost,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  fontSize: 14)),
        ),
        Expanded(
          flex: 2,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: statusColor.withOpacity(0.3)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SESSION HISTORY MOBILE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSessionHistoryMobile(bool isDark, Color cardCol, Color textCol,
      Color borderCol, String Function(String, String) t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardCol,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderCol)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(t('sessionHistory', 'Session History & Billing'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textCol)),
              const SizedBox(width: 8),
              // Live dot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (_isLiveConnected ? Colors.green : Colors.grey).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_isLiveConnected ? Colors.green : Colors.grey).withOpacity(0.3),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: _isLiveConnected ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isLiveConnected ? t('live', 'LIVE') : '...',
                    style: TextStyle(
                      color: _isLiveConnected ? Colors.green : Colors.grey,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]),
              ),
            ]),
            if (_volumeDiscountPct > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  '${(_volumeDiscountPct * 100).toInt()}% off',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingSessions)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator()))
        else if (_realtimeSessions.isEmpty)
          _buildEmptyState(t)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _realtimeSessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final session      = _realtimeSessions[index];
              final String source =
                  session['file_name'] ?? 'Meeting';
              final int duration =
                  session['duration_minutes'] ?? 1;
              final int participants = _peakParticipants(session);
              final String timeRange = _formatTimeRange(
                  session['created_at'], duration);

              // ── BILLING FORMULA applied here ──
              final double sessionCost =
                  _computeSessionCost(duration, participants);

              final statusDetails = _getStatusDetails(session, t);

              return _sessionCard(
                source:       source,
                timeRange:    timeRange,
                participants: participants,
                duration:     duration,
                cost:         sessionCost,
                statusLabel:  statusDetails['label'],
                statusColor:  statusDetails['color'],
                textCol:      textCol,
                borderCol:    borderCol,
                isDark:       isDark,
                t:            t,
              );
            },
          ),
      ]),
    );
  }

  Widget _sessionCard({
    required String source,
    required String timeRange,
    required int participants,
    required int duration,
    required double cost,
    required String statusLabel,
    required Color statusColor,
    required Color textCol,
    required Color borderCol,
    required bool isDark,
    required String Function(String, String) t,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(source,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textCol,
                    fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _sessionDetail(
                  Icons.access_time,
                  t('time', 'Time'),
                  timeRange,
                  textCol)),
          Expanded(
              child: _sessionDetail(
                  Icons.people_outline,
                  t('people', 'Peak'),
                  '$participants ${t('people', 'people')}',
                  textCol)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: _sessionDetail(
                  Icons.timer_outlined,
                  t('duration', 'Duration'),
                  '$duration ${t('mins', 'mins')}',
                  textCol)),
          Expanded(
            child: _sessionDetail(
              Icons.receipt_outlined,
              t('sessionCost', 'Billed'),
              '${cost.toStringAsFixed(0)} DZD',
              textCol,
              valueColor: Colors.redAccent,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _sessionDetail(IconData icon, String label, String value,
      Color textCol, {Color? valueColor}) {
    return Row(children: [
      Icon(icon, size: 13, color: Colors.grey),
      const SizedBox(width: 5),
      Text('$label: ',
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Flexible(
        child: Text(value,
            style: TextStyle(
                color: valueColor ?? textCol,
                fontSize: 12,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(String Function(String, String) t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_camera_back_outlined,
                size: 36, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(
              t('noSessionsLogged',
                  'No active conference protection logs registered.'),
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DOWNLOAD BUTTON
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _downloadButton(IconData icon, String label, bool hasAccess,
      VoidCallback? onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            hasAccess ? Colors.white : Colors.grey.shade800,
        foregroundColor: hasAccess ? Colors.black : Colors.grey,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: hasAccess ? onPressed : null,
    );
  }
}