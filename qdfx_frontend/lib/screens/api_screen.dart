import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../l10n/translations.dart';
import '../screens/landing_screen.dart'; // Import for CircuitBoardPainter

const String _backendBase = 'http://localhost:7860';

// ── Design Tokens ──────────────────────────────────────────────────────────────
// DARK palette
class _D {
  static const bg      = Color(0xFF060D1A);
  static const surface = Color(0xFF0D1626);
  static const card    = Color(0xFF111D30);
  static const border  = Color(0xFF1A2D45);
  static const muted   = Color(0xFF4B637A);
  static const text    = Color(0xFFE2EBF4);
  static const textDim = Color(0xFF7A9BB5);
}

// LIGHT palette
class _L {
  static const bg      = Color(0xFFF0F4F8);
  static const surface = Color(0xFFFFFFFF);
  static const card    = Color(0xFFFFFFFF);
  static const border  = Color(0xFFCDD7E3);
  static const muted   = Color(0xFF8FA3B4);
  static const text    = Color(0xFF0F1E2D);
  static const textDim = Color(0xFF4A6175);
}

// Shared accent colors (same in both themes)
class _A {
  static const cyan   = Color(0xFF06B6D4);
  static const blue   = Color(0xFF3B82F6);
  static const indigo = Color(0xFF6366F1);
  static const green  = Color(0xFF10B981);
  static const amber  = Color(0xFFF59E0B);
  static const red    = Color(0xFFEF4444);
  static const mono   = 'monospace';
}

// ── Theme-aware color helper ───────────────────────────────────────────────────
class _T {
  final bool dark;
  const _T(this.dark);

  Color get bg      => dark ? _D.bg      : _L.bg;
  Color get surface => dark ? _D.surface : _L.surface;
  Color get card    => dark ? _D.card    : _L.card;
  Color get border  => dark ? _D.border  : _L.border;
  Color get muted   => dark ? _D.muted   : _L.muted;
  Color get text    => dark ? _D.text    : _L.text;
  Color get textDim => dark ? _D.textDim : _L.textDim;

  // Accents are always the same
  Color get cyan   => _A.cyan;
  Color get blue   => _A.blue;
  Color get indigo => _A.indigo;
  Color get green  => _A.green;
  Color get amber  => _A.amber;
  Color get red    => _A.red;

  static const mono = _A.mono;
}

// ── Data Models ────────────────────────────────────────────────────────────────
class ApiKeyRow {
  final String id, prefix, label, plan, status;
  final int quota, used;
  final String? lastUsed;
  const ApiKeyRow({
    required this.id, required this.prefix, required this.label,
    required this.plan, required this.quota, required this.used,
    required this.status, this.lastUsed,
  });
  factory ApiKeyRow.fromJson(Map<String, dynamic> j) => ApiKeyRow(
    id: j['id'] ?? '', prefix: j['prefix'] ?? '', label: j['label'] ?? 'Key',
    plan: j['plan'] ?? 'pro', quota: j['quota'] ?? 5000, used: j['used'] ?? 0,
    status: j['status'] ?? 'active', lastUsed: j['last_used'],
  );
  double get usageRatio => quota > 0 ? (used / quota).clamp(0.0, 1.0) : 0.0;
  int get remaining => (quota - used).clamp(0, quota);
  bool get isActive => status == 'active';
}

class WebhookRow {
  final String id, name, url, status;
  final List<String> events;
  final int successCount, failCount;
  final String? lastTriggered;
  const WebhookRow({
    required this.id, required this.name, required this.url,
    required this.events, required this.status,
    required this.successCount, required this.failCount, this.lastTriggered,
  });
  factory WebhookRow.fromJson(Map<String, dynamic> j) => WebhookRow(
    id: j['id'] ?? '', name: j['name'] ?? '', url: j['url'] ?? '',
    events: List<String>.from(j['events'] ?? []),
    status: j['status'] ?? 'active',
    successCount: j['success_count'] ?? 0,
    failCount: j['fail_count'] ?? 0,
    lastTriggered: j['last_triggered'],
  );
}

class ChartPoint {
  final String date;
  final int requests;
  const ChartPoint(this.date, this.requests);
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class ApiScreen extends StatefulWidget {
  const ApiScreen({super.key});
  @override
  State<ApiScreen> createState() => _ApiScreenState();
}

class _ApiScreenState extends State<ApiScreen> with TickerProviderStateMixin {
  bool _loading = true;
  String? _revealedKey;
  bool _keyVisible = false;

  List<ApiKeyRow> _keys = [];
  List<WebhookRow> _webhooks = [];
  List<ChartPoint> _chart = [];

  int _totalRequests = 0;
  double _errorRate = 0;
  double _avgLatency = 0;

  final _whNameCtrl = TextEditingController();
  final _whUrlCtrl  = TextEditingController();
  bool _showWhForm  = false;
  bool _whSaving    = false;

  late TabController _tabs;
  Map<String, dynamic>? _license;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAll());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _whNameCtrl.dispose();
    _whUrlCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';
  String get _lang =>
      Provider.of<AppState>(context, listen: false).currentLocale.languageCode;
  String t(String key) => AppTranslations.get(_lang, key);

  // Derives theme tokens from AppState
  _T get _c {
    final appState = Provider.of<AppState>(context, listen: false);
    return _T(appState.isDarkMode);
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) =>
      http.post(Uri.parse('$_backendBase/api$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));

  Future<http.Response> _get(String path) =>
      http.get(Uri.parse('$_backendBase/api$path'))
          .timeout(const Duration(seconds: 20));

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
          color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: error ? _A.red : _A.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchKeys(), _fetchWebhooks(), _fetchUsage(), _fetchLicense()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchKeys() async {
    try {
      final r = await _get('/keys?user_id=$_userId');
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        _keys = (data['keys'] as List).map((e) => ApiKeyRow.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchWebhooks() async {
    try {
      final r = await _get('/webhooks?user_id=$_userId');
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        _webhooks = (data['webhooks'] as List)
            .map((e) => WebhookRow.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchUsage() async {
    try {
      final r = await _get('/usage/summary?user_id=$_userId');
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        _totalRequests = (data['total_requests'] ?? 0) as int;
        _errorRate     = (data['error_rate'] ?? 0).toDouble();
        _avgLatency    = (data['avg_latency_ms'] ?? 0).toDouble();
        _chart = (data['chart'] as List)
            .map((e) => ChartPoint(e['date'], e['requests'] ?? 0)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchLicense() async {
    try {
      final r = await _get('/enterprise/license?user_id=$_userId');
      if (r.statusCode == 200) {
        setState(() => _license = jsonDecode(r.body));
      }
    } catch (_) {}
  }

  Future<void> _generateKey(String plan) async {
    try {
      final r = await _post('/keys/generate', {
        'user_id': _userId,
        'label': '${plan[0].toUpperCase()}${plan.substring(1)} Production Key',
        'plan': plan,
      });
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() { _revealedKey = data['raw_key']; _keyVisible = true; });
        await _fetchKeys();
        _snack(t('keyGenerated'));
      } else {
        _snack('${t('generationFailed')}: ${r.body}', error: true);
      }
    } catch (e) { _snack('${t('networkError')}: $e', error: true); }
  }

  Future<void> _rollKey(String keyId) async {
    final ok = await _confirmDialog(t('rollApiKey'), t('rollKeyConfirm'));
    if (!ok) return;
    try {
      final r = await _post('/keys/roll', {'key_id': keyId, 'user_id': _userId});
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        setState(() { _revealedKey = data['raw_key']; _keyVisible = true; });
        await _fetchKeys();
        _snack(t('keyRolled'));
      } else { _snack('${t('rollFailed')}: ${r.body}', error: true); }
    } catch (e) { _snack('${t('networkError')}: $e', error: true); }
  }

  Future<void> _revokeKey(String keyId) async {
    final ok = await _confirmDialog(t('revokeKey'), t('revokeKeyConfirm'));
    if (!ok) return;
    try {
      final r = await _post('/keys/revoke', {'key_id': keyId, 'user_id': _userId});
      if (r.statusCode == 200) { await _fetchKeys(); _snack(t('credentialRevoked')); }
    } catch (e) { _snack('${t('networkError')}: $e', error: true); }
  }

  Future<void> _createWebhook() async {
    if (_whNameCtrl.text.trim().isEmpty || _whUrlCtrl.text.trim().isEmpty) {
      _snack(t('webhookFieldsRequired'), error: true); return;
    }
    setState(() => _whSaving = true);
    try {
      final r = await _post('/webhooks', {
        'user_id': _userId,
        'name':    _whNameCtrl.text.trim(),
        'url':     _whUrlCtrl.text.trim(),
        'events':  ['detection.result'],
      });
      if (r.statusCode == 200) {
        _whNameCtrl.clear(); _whUrlCtrl.clear();
        setState(() => _showWhForm = false);
        await _fetchWebhooks();
        _snack(t('webhookSaved'));
      } else { _snack('${t('webhookFailed')}: ${r.body}', error: true); }
    } catch (e) { _snack('${t('networkError')}: $e', error: true); }
    finally { if (mounted) setState(() => _whSaving = false); }
  }

  Future<void> _toggleWebhook(WebhookRow wh) async {
    final newStatus = wh.status == 'active' ? 'paused' : 'active';
    try {
      await _post('/webhooks/toggle', {
        'webhook_id': wh.id, 'user_id': _userId, 'status': newStatus,
      });
      await _fetchWebhooks();
      _snack('${t('webhookNow')} $newStatus.');
    } catch (_) {}
  }

  Future<void> _deleteWebhook(String id) async {
    final ok = await _confirmDialog(t('removeWebhook'), t('removeWebhookConfirm'));
    if (!ok) return;
    try {
      final r = await http.delete(
        Uri.parse('$_backendBase/api/webhooks/$id?user_id=$_userId'));
      if (r.statusCode == 200) { await _fetchWebhooks(); _snack(t('webhookRemoved')); }
    } catch (_) {}
  }

  Future<bool> _confirmDialog(String title, String body) async {
    final c = _c;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.red.withOpacity(0.3), width: 1.5),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.warning_rounded, color: c.red, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: TextStyle(
                  color: c.text, fontWeight: FontWeight.bold, fontSize: 15))),
              ]),
              const SizedBox(height: 14),
              Text(body, style: TextStyle(
                color: c.textDim, fontSize: 13, height: 1.6)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _outlineBtn(
                  t('cancel'), c.muted, c, () => Navigator.pop(ctx, false))),
                const SizedBox(width: 12),
                Expanded(child: _solidBtn(
                  t('proceed'), c.red, c, () => Navigator.pop(ctx, true))),
              ]),
            ]),
          ),
        ),
      ),
    ) ?? false;
  }

  // ─── ROOT BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Listen to AppState so the widget rebuilds on theme toggle
    final appState = Provider.of<AppState>(context);
    final c = _T(appState.isDarkMode);
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 600;
    final double pad = isMobile ? 16.0 : (sw < 900 ? 24.0 : 32.0);

    // Circuit colour: white on dark, black on light
    final circuitColor = (appState.isDarkMode ? Colors.white : Colors.black).withOpacity(0.03);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ─── CIRCUIT PATTERN BACKGROUND (always visible) ──────────────
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitBoardPainter(color: circuitColor),
            ),
          ),
          // ─── SCROLLABLE CONTENT ───────────────────────────────────────
          _loading
              ? _buildLoader(c)
              : RefreshIndicator(
                  onRefresh: _fetchAll,
                  color: c.cyan,
                  backgroundColor: c.card,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(isMobile, appState, c),
                        const SizedBox(height: 24),
                        if (_revealedKey != null) ...[
                          _buildKeyBanner(c),
                          const SizedBox(height: 20),
                        ],
                        _buildTabBar(isMobile, c),
                        const SizedBox(height: 20),
                        _buildTabContent(isMobile, sw, appState, c),
                        const SizedBox(height: 36),
                        _buildEnterprisePanel(isMobile, appState, c),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ─── LOADER ────────────────────────────────────────────────────────────────
  Widget _buildLoader(_T c) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 44, height: 44,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(c.cyan))),
      const SizedBox(height: 18),
      AnimatedBuilder(animation: _pulse, builder: (_, __) =>
        Opacity(opacity: _pulse.value,
          child: Text('INITIALIZING SECURE CONSOLE...',
            style: TextStyle(color: c.cyan, fontSize: 11,
              fontFamily: _T.mono, letterSpacing: 2)))),
    ]),
  );

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile, AppState appState, _T c) {
    final badge = AnimatedBuilder(animation: _pulse, builder: (_, __) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.green.withOpacity(_pulse.value * 0.6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6,
            decoration: BoxDecoration(
              color: c.green.withOpacity(_pulse.value),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: c.green, blurRadius: 4 * _pulse.value)])),
          const SizedBox(width: 6),
          Text('GATEWAY ONLINE', style: TextStyle(
            color: c.green, fontSize: 10, fontFamily: _T.mono,
            fontWeight: FontWeight.bold, letterSpacing: 1)),
        ]),
      ));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isMobile) ...[
        badge,
        const SizedBox(height: 12),
      ],
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
              shaderCallback: (b) => LinearGradient(
                colors: [c.text, c.cyan]).createShader(b),
              child: Text(
                isMobile ? 'Dev Console' : t('developerHub'),
                style: TextStyle(
                  fontSize: isMobile ? 24 : 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5)),
            ),
            const SizedBox(height: 4),
            Text(t('apiDescription'),
              style: TextStyle(color: c.textDim, fontSize: 12)),
          ])),
          if (!isMobile) ...[const SizedBox(width: 16), badge],
        ],
      ),
    ]);
  }

  // ─── REVEALED KEY BANNER ───────────────────────────────────────────────────
  Widget _buildKeyBanner(_T c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: c.amber.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.amber.withOpacity(0.35), width: 1.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.warning_amber_rounded, color: c.amber, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(t('copyToken'), style: TextStyle(
          color: c.amber, fontWeight: FontWeight.bold, fontSize: 12))),
        GestureDetector(
          onTap: () => setState(() => _revealedKey = null),
          child: Icon(Icons.close_rounded, color: c.muted, size: 16)),
      ]),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border)),
        child: Row(children: [
          Icon(Icons.vpn_key_outlined, color: c.muted, size: 13),
          const SizedBox(width: 8),
          Expanded(child: Text(
            _keyVisible
                ? (_revealedKey ?? '')
                : '${_revealedKey?.substring(0, 14) ?? ''}••••••••••••••••••••••••••',
            style: TextStyle(fontFamily: _T.mono, fontSize: 12,
              color: c.text, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
          _iconBtn(
            _keyVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            c.muted, () => setState(() => _keyVisible = !_keyVisible)),
          _iconBtn(Icons.copy_rounded, c.cyan, () {
            Clipboard.setData(ClipboardData(text: _revealedKey ?? ''));
            _snack(t('credentialCopied'));
          }),
        ]),
      ),
    ]),
  );

  // ─── TAB BAR ───────────────────────────────────────────────────────────────
  Widget _buildTabBar(bool isMobile, _T c) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border)),
    child: TabBar(
      controller: _tabs,
      indicator: BoxDecoration(
        color: c.cyan.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cyan.withOpacity(0.3))),
      labelColor: c.cyan,
      unselectedLabelColor: c.muted,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      tabs: [
        Tab(icon: const Icon(Icons.key_rounded, size: 15),
          text: isMobile ? 'Keys' : t('apiCredentials')),
        Tab(icon: const Icon(Icons.analytics_outlined, size: 15),
          text: isMobile ? 'Usage' : t('usageAnalytics')),
        Tab(icon: const Icon(Icons.webhook, size: 15), text: t('webhooks')),
      ],
    ),
  );

  // ─── TAB CONTENT ROUTER ────────────────────────────────────────────────────
  Widget _buildTabContent(bool isMobile, double sw, AppState appState, _T c) {
    switch (_tabs.index) {
      case 0: return _buildKeysTab(isMobile, appState, c);
      case 1: return _buildUsageTab(isMobile, c);
      case 2: return _buildWebhooksTab(isMobile, c);
      default: return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 0 — KEYS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildKeysTab(bool isMobile, AppState appState, _T c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isMobile)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _genButton('pro', c.indigo, appState, c),
          const SizedBox(height: 10),
          _genButton('enterprise', c.blue, appState, c),
        ])
      else
        Row(children: [
          _genButton('pro', c.indigo, appState, c),
          const SizedBox(width: 12),
          _genButton('enterprise', c.blue, appState, c),
        ]),
      const SizedBox(height: 22),
      if (_keys.isEmpty)
        _emptyState(t('noKeys'), Icons.key_off_outlined, c)
      else
        ..._keys.map((k) => _buildKeyCard(k, isMobile, c)),
    ]);
  }

  Widget _genButton(String plan, Color color, AppState appState, _T c) {
    final userPlan = appState.subscriptionPlan.toLowerCase();
    final hasAccess = plan == 'pro'
        ? (userPlan == 'pro' || userPlan == 'enterprise')
        : (userPlan == 'enterprise');
    final labels = {
      'pro': t('generateProKey'),
      'enterprise': t('generateEnterpriseKey'),
    };
    return GestureDetector(
      onTap: () => hasAccess
          ? _generateKey(plan)
          : _showUpgradeDialog(plan, appState, c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: hasAccess ? color.withOpacity(0.12) : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasAccess ? color.withOpacity(0.4) : c.border)),
        child: Row(mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(hasAccess ? Icons.add_rounded : Icons.lock_outline_rounded,
            size: 14, color: hasAccess ? color : c.muted),
          const SizedBox(width: 8),
          Text(labels[plan] ?? plan, style: TextStyle(
            color: hasAccess ? color : c.muted,
            fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _buildKeyCard(ApiKeyRow key, bool isMobile, _T c) {
    final planColor = key.plan == 'enterprise'
        ? c.blue : key.plan == 'pro' ? c.indigo : c.cyan;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: key.isActive ? planColor.withOpacity(0.25) : c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header strip
        Container(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: planColor.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: c.border))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: planColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.vpn_key_rounded, color: planColor, size: 15)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(key.label, style: TextStyle(
                color: c.text, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                key.lastUsed != null
                    ? '${t('lastActiveCall')} ${_formatDate(key.lastUsed!)}'
                    : t('noQueriesLogged'),
                style: TextStyle(
                  color: c.muted, fontSize: 10, fontFamily: _T.mono),
                overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 6),
            _badge(key.plan.toUpperCase(), planColor),
            const SizedBox(width: 6),
            _badge(key.isActive ? 'ACTIVE' : 'REVOKED',
              key.isActive ? c.green : c.red),
          ]),
        ),

        // Body
        Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border)),
              child: Row(children: [
                Icon(Icons.lock_outline, color: c.muted, size: 13),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${key.prefix}••••••••••••••••••••••••',
                  style: TextStyle(fontFamily: _T.mono, fontSize: 12,
                    color: c.text, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
              ]),
            ),

            const SizedBox(height: 14),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(t('monthlyQueryQuota'),
                style: TextStyle(color: c.muted, fontSize: 11)),
              Text('${_fmt(key.used)} / ${_fmt(key.quota)} ${t('queries')}',
                style: TextStyle(color: c.text, fontSize: 11,
                  fontWeight: FontWeight.bold, fontFamily: _T.mono)),
            ]),
            const SizedBox(height: 7),

            LayoutBuilder(builder: (ctx, bc) {
              final barColor = key.usageRatio > 0.9 ? c.red
                  : key.usageRatio > 0.7 ? c.amber : planColor;
              return Stack(children: [
                Container(height: 6, width: bc.maxWidth,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(6))),
                Container(
                  height: 6,
                  width: bc.maxWidth * key.usageRatio,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [barColor, barColor.withOpacity(0.5)]),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(
                      color: barColor.withOpacity(0.35), blurRadius: 4)])),
              ]);
            }),
            const SizedBox(height: 5),
            Text('${_fmt(key.remaining)} ${t('queriesRemaining')}',
              style: TextStyle(
                color: key.usageRatio > 0.9 ? c.red : c.textDim,
                fontSize: 11, fontFamily: _T.mono)),

            if (key.isActive) ...[
              const SizedBox(height: 14),
              if (isMobile)
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _outlineBtn(t('rollToken'), c.textDim, c,
                    () => _rollKey(key.id), icon: Icons.refresh_rounded),
                  const SizedBox(height: 8),
                  _outlineBtn(t('revokeAccess'), c.red, c,
                    () => _revokeKey(key.id), icon: Icons.block_rounded),
                ])
              else
                Row(children: [
                  _outlineBtn(t('rollToken'), c.textDim, c,
                    () => _rollKey(key.id), icon: Icons.refresh_rounded),
                  const SizedBox(width: 10),
                  _outlineBtn(t('revokeAccess'), c.red, c,
                    () => _revokeKey(key.id), icon: Icons.block_rounded),
                ]),
            ],
          ]),
        ),
      ]),
    );
  }

  void _showUpgradeDialog(String plan, AppState appState, _T c) {
    final label = plan.toUpperCase();
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.amber.withOpacity(0.3), width: 1.5)),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.lock_outline_rounded,
                  color: c.amber, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text('$label ${t('tierRequired')}',
                style: TextStyle(color: c.text,
                  fontWeight: FontWeight.bold, fontSize: 15))),
            ]),
            const SizedBox(height: 14),
            Text(
              '${t('currentPlanMsg')} (${appState.subscriptionPlan.toUpperCase()}) '
              '${t('noPermissions')} $label ${t('credentials')}. ${t('upgradeMessage')}',
              style: TextStyle(color: c.textDim, fontSize: 13, height: 1.6)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: _outlineBtn(
                t('cancel'), c.muted, c, () => Navigator.pop(ctx))),
              const SizedBox(width: 12),
              Expanded(child: _solidBtn(t('upgradePlan'), c.blue, c, () {
                Navigator.pop(ctx); appState.setIndex(1);
              }, icon: Icons.star_rounded)),
            ]),
          ]),
        ),
      ),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1 — USAGE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildUsageTab(bool isMobile, _T c) {
    final maxReq = _chart.isEmpty
        ? 1
        : _chart.map((ch) => ch.requests).reduce((a, b) => a > b ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isMobile)
        Column(children: [
          _kpiCard(t('aggregatedInquiries'), _fmt(_totalRequests),
            t('activeQueries'), Icons.cloud_sync_outlined, c.blue, c),
          const SizedBox(height: 12),
          _kpiCard(t('errorRate'), '${_errorRate.toStringAsFixed(2)}%',
            _errorRate < 1 ? t('healthyNode') : t('verificationIssue'),
            Icons.warning_amber_rounded, _errorRate < 1 ? c.green : c.red, c),
          const SizedBox(height: 12),
          _kpiCard(t('meanLatency'), '${_avgLatency.toStringAsFixed(0)}ms',
            t('operationalSpeed'), Icons.speed,
            _avgLatency < 400 ? c.green : c.amber, c),
        ])
      else
        Row(children: [
          Expanded(child: _kpiCard(t('aggregatedInquiries'), _fmt(_totalRequests),
            t('activeQueries'), Icons.cloud_sync_outlined, c.blue, c)),
          const SizedBox(width: 14),
          Expanded(child: _kpiCard(t('errorRate'), '${_errorRate.toStringAsFixed(2)}%',
            _errorRate < 1 ? t('healthyNode') : t('verificationIssue'),
            Icons.warning_amber_rounded, _errorRate < 1 ? c.green : c.red, c)),
          const SizedBox(width: 14),
          Expanded(child: _kpiCard(t('meanLatency'), '${_avgLatency.toStringAsFixed(0)}ms',
            t('operationalSpeed'), Icons.speed,
            _avgLatency < 400 ? c.green : c.amber, c)),
        ]),

      const SizedBox(height: 22),

      Container(
        padding: EdgeInsets.all(isMobile ? 14 : 22),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: c.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.bar_chart_rounded, color: c.cyan, size: 15)),
            const SizedBox(width: 10),
            Expanded(child: Text(t('queryVolume'), style: TextStyle(
              color: c.text, fontWeight: FontWeight.bold, fontSize: 13))),
            _badge('7D', c.cyan),
          ]),
          const SizedBox(height: 20),

          SizedBox(
            height: isMobile ? 110 : 150,
            child: _chart.isEmpty
                ? Center(child: Text('No data', style: TextStyle(
                    color: c.muted, fontSize: 12)))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _chart.asMap().entries.map((entry) {
                      final i = entry.key;
                      final ch = entry.value;
                      final ratio = maxReq > 0 ? ch.requests / maxReq : 0.0;
                      final isToday = i == _chart.length - 1;
                      final barColor = isToday ? c.cyan : c.blue;
                      final maxBarH = isMobile ? 80.0 : 115.0;
                      return Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              height: (ratio * maxBarH).clamp(3.0, maxBarH),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [barColor, barColor.withOpacity(0.2)]),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5)),
                                boxShadow: isToday ? [BoxShadow(
                                  color: barColor.withOpacity(0.4),
                                  blurRadius: 6)] : [],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_shortDate(ch.date), style: TextStyle(
                              color: isToday ? barColor : c.muted,
                              fontSize: isMobile ? 8 : 9,
                              fontFamily: _T.mono,
                              fontWeight: isToday
                                  ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                      ));
                    }).toList(),
                  ),
          ),
        ]),
      ),
    ]);
  }

  Widget _kpiCard(String title, String value, String subtitle,
      IconData icon, Color color, _T c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color)),
          Flexible(child: _badge(subtitle, color)),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w900,
          color: c.text, fontFamily: _T.mono)),
        const SizedBox(height: 3),
        Text(title, style: TextStyle(color: c.muted, fontSize: 11)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2 — WEBHOOKS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildWebhooksTab(bool isMobile, _T c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _solidBtn(
        _showWhForm ? t('cancelSetup') : t('addWebhookNode'),
        _showWhForm ? c.muted : c.cyan,
        c,
        () => setState(() => _showWhForm = !_showWhForm),
        icon: _showWhForm ? Icons.close : Icons.add_rounded),

      if (_showWhForm) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.cyan.withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('addWebhookTitle'), style: TextStyle(
              color: c.text, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 14),
            _field(_whNameCtrl, t('webhookNameHint'), c),
            const SizedBox(height: 10),
            _field(_whUrlCtrl, t('webhookUrlHint'), c),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _solidBtn(
                _whSaving ? '...' : t('createWebhookNode'),
                c.cyan,
                c,
                _whSaving ? null : _createWebhook)),
          ]),
        ),
      ],

      const SizedBox(height: 18),
      if (_webhooks.isEmpty)
        _emptyState(t('noWebhooks'), Icons.webhook_outlined, c)
      else
        ..._webhooks.map((w) => _buildWebhookCard(w, isMobile, c)),
    ]);
  }

  Widget _buildWebhookCard(WebhookRow wh, bool isMobile, _T c) {
    final isActive = wh.status == 'active';
    final statusColor = isActive ? c.green : c.amber;
    final total = wh.successCount + wh.failCount;
    final rate = total > 0 ? wh.successCount / total : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? statusColor.withOpacity(0.2) : c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AnimatedBuilder(animation: _pulse, builder: (_, __) =>
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(isActive ? _pulse.value : 0.4),
                shape: BoxShape.circle,
                boxShadow: isActive ? [BoxShadow(
                  color: statusColor, blurRadius: 4 * _pulse.value)] : []))),
          Expanded(child: Text(wh.name, style: TextStyle(
            color: c.text, fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis)),
          Switch(
            value: isActive,
            onChanged: (_) => _toggleWebhook(wh),
            activeColor: c.green,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          _iconBtn(Icons.delete_outline_rounded, c.red,
            () => _deleteWebhook(wh.id)),
        ]),
        const SizedBox(height: 6),
        Text(wh.url, style: TextStyle(
          color: c.muted, fontSize: 11, fontFamily: _T.mono),
          overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _badge('DETECTION.RESULT', c.cyan),
          _badge(
            '${(rate * 100).toStringAsFixed(0)}% ${t('deliveryIndex')}',
            rate > 0.9 ? c.green : c.amber),
          Text(
            '✓ ${wh.successCount}  ✗ ${wh.failCount}',
            style: TextStyle(color: c.muted, fontSize: 11,
              fontFamily: _T.mono)),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENTERPRISE PANEL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEnterprisePanel(bool isMobile, AppState appState, _T c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.domain_verification_rounded, color: c.blue, size: 15),
        const SizedBox(width: 8),
        Text(t('enterpriseLicensing'), style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, color: c.text)),
      ]),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 14 : 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            c.blue.withOpacity(0.10), c.blue.withOpacity(0.02)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.blue.withOpacity(0.25))),
        child: _license == null
            ? _buildNoLicense(isMobile, appState, c)
            : _buildActiveLicense(isMobile, c),
      ),
    ]);
  }

  Widget _buildNoLicense(bool isMobile, AppState appState, _T c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.blue.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.domain_verification_rounded,
            color: c.blue, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('dockerLicense'), style: TextStyle(
            color: c.text, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(t('dockerDescription'), style: TextStyle(
            color: c.muted, fontSize: 12)),
        ])),
      ]),
      const SizedBox(height: 14),
      _solidBtn(t('viewEnterprisePlans'), c.blue, c,
        () => appState.setIndex(1), icon: Icons.star_rounded),
    ]);
  }

  Widget _buildActiveLicense(bool isMobile, _T c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.blue.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.verified_rounded, color: c.blue, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_license!['label'] ?? t('enterpriseSuite'),
            style: TextStyle(color: c.text,
              fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'Expires: ${_formatDate(_license!['license']?['valid_until'] ?? '')}  ·  '
            'Node: ${_license!['license']?['hardware_id'] ?? '—'}',
            style: TextStyle(color: c.muted, fontSize: 11,
              fontFamily: _T.mono)),
          const SizedBox(height: 4),
          Text(
            '${_fmt(_license!['used'] ?? 0)} / ${_fmt(_license!['quota'] ?? 0)} '
            '${t('allocationsUsed')}',
            style: TextStyle(color: c.cyan, fontSize: 11,
              fontFamily: _T.mono, fontWeight: FontWeight.bold)),
        ])),
      ]),
      const SizedBox(height: 14),
      _solidBtn(t('downloadBinKey'), c.blue, c, _downloadLicense,
        icon: Icons.download_rounded),
    ]);
  }

  Future<void> _downloadLicense() async {
    try {
      final res = await _get('/enterprise/license?user_id=$_userId');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final payload = {
          'license_id': data['license']?['id'] ?? 'lic_9a2b8c3d',
          'user_id': _userId,
          'organization_label': data['label'] ?? 'Enterprise On-Premise',
          'expires_at': data['license']?['valid_until'] ?? '2027-06-01',
          'hardware_id': data['license']?['hardware_id'] ?? 'hw_node_docker_x86_64',
          'cryptographic_seal': base64Encode(
            utf8.encode(DateTime.now().toIso8601String())),
        };
        await Printing.sharePdf(
          bytes: const Utf8Encoder().convert(jsonEncode(payload)),
          filename: 'detectini_lic.key');
        _snack(t('licenseDownloaded'));
      } else { _snack('${t('downloadFailed')}: ${res.body}', error: true); }
    } catch (e) { _snack('${t('downloadError')}: $e', error: true); }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED PRIMITIVES  (all now take _T c)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: color.withOpacity(0.22))),
    child: Text(label, style: TextStyle(
      color: color, fontSize: 9, fontFamily: _T.mono,
      fontWeight: FontWeight.bold, letterSpacing: 0.4)));

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
    IconButton(
      icon: Icon(icon, size: 17, color: color),
      onPressed: onTap,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      splashRadius: 16);

  Widget _solidBtn(String label, Color color, _T c, VoidCallback? onTap,
      {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.75), color.withOpacity(0.5)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(
            color: color.withOpacity(0.2), blurRadius: 10,
            offset: const Offset(0, 3))]),
        child: Row(mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _outlineBtn(String label, Color color, _T c, VoidCallback? onTap,
      {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35))),
        child: Row(mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, _T c) => TextField(
    controller: ctrl,
    style: TextStyle(color: c.text, fontSize: 13, fontFamily: _T.mono),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: c.muted, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      filled: true,
      fillColor: c.bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.cyan, width: 1.5))));

  Widget _emptyState(String msg, IconData icon, _T c) => Container(
    height: 140,
    alignment: Alignment.center,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 32, color: c.muted.withOpacity(0.4)),
      const SizedBox(height: 10),
      Text(msg, style: TextStyle(color: c.muted, fontSize: 13),
        textAlign: TextAlign.center),
    ]));

  // ─── Helpers ────────────────────────────────────────────────────────────────
  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return iso; }
  }

  String _shortDate(String iso) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    try { return days[DateTime.parse(iso).weekday - 1]; }
    catch (_) { return iso.length > 5 ? iso.substring(5) : iso; }
  }
}