import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../l10n/translations.dart';
import '../layout/responsive_layout.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen>
    with SingleTickerProviderStateMixin {
  double _rtDuration        = 45.0;
  double _rtParticipants    = 4.0;
  double _rtMonthlySessions = 8.0;
  double _upVolume          = 3.5;

  late TabController _pricingModelTabs;

  @override
  void initState() {
    super.initState();
    _pricingModelTabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _pricingModelTabs.dispose();
    super.dispose();
  }

  // --- BUSINESS PLAN CALCULATION FORMULAS [1] ---

  double _calculateRealTimeCost() {
    double baseRate           = 5.0;
    double perParticipantRate = 2.0;
    double rawCost = (baseRate * _rtDuration) +
        (_rtParticipants * perParticipantRate * _rtDuration);
    double discount = 0.0;
    if (_rtMonthlySessions >= 15.0)      discount = 0.20;
    else if (_rtMonthlySessions >= 5.0)  discount = 0.10;
    return (rawCost * (1.0 - discount)).clamp(150.0, 1500.0);
  }

  double _calculateUploadCost() {
    double freeAllowanceGb = 0.05;
    if (_upVolume <= freeAllowanceGb) return 0.0;
    double billableGb  = _upVolume - freeAllowanceGb;
    double totalCost   = 0.0;
    double remainingGb = billableGb;

    double tier1Limit = 1.0 - freeAllowanceGb;
    if (remainingGb > 0) {
      double b = remainingGb > tier1Limit ? tier1Limit : remainingGb;
      totalCost   += b * 800.0;
      remainingGb -= b;
    }
    if (remainingGb > 0) {
      double b = remainingGb > 9.0 ? 9.0 : remainingGb;
      totalCost   += b * 600.0;
      remainingGb -= b;
    }
    if (remainingGb > 0) {
      double b = remainingGb > 40.0 ? 40.0 : remainingGb;
      totalCost   += b * 400.0;
      remainingGb -= b;
    }
    if (remainingGb > 0) totalCost += remainingGb * 250.0;
    return totalCost;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ROOT BUILD
  // ═══════════════════════════════════════════════════════════════════════════
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
      } catch (_) { return fallback; }
    }

    final bgCol     = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    final cardCol   = isDark ? const Color(0xFF151E32) : Colors.white;
    final textCol   = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;

    return ResponsiveLayout(
      useScaffold: false,
      desktopBody: _buildBody(context, appState, isDark, bgCol, cardCol, textCol, borderCol, t, isMobile: false),
      tabletBody:  _buildBody(context, appState, isDark, bgCol, cardCol, textCol, borderCol, t, isMobile: false),
      mobileBody:  _buildBody(context, appState, isDark, bgCol, cardCol, textCol, borderCol, t, isMobile: true),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED BODY
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildBody(
    BuildContext context, AppState appState, bool isDark,
    Color bgCol, Color cardCol, Color textCol, Color borderCol,
    String Function(String, String) t, { required bool isMobile }
  ) {
    final double hPad = isMobile ? 16 : 32;

    return Scaffold(
      backgroundColor: bgCol,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(hPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            isMobile
                ? _buildMobileHeader(appState, textCol, t)
                : _buildDesktopHeader(appState, textCol, t),

            const SizedBox(height: 32),

            // ── Pricing sub-tabs ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol),
              ),
              child: TabBar(
                controller: _pricingModelTabs,
                indicator: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.25)),
                ),
                labelColor: AppTheme.primaryBlue,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                isScrollable: isMobile,
                labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 11 : 12),
                tabs: [
                  Tab(text: t('recurringSaaS', 'SaaS Plans')),
                  Tab(text: t('payPerUse', 'Real-Time')),
                  Tab(text: t('volumeUploads', 'Bulk Uploads')),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Tab content ──────────────────────────────────────────
            SizedBox(
              height: isMobile ? 1100 : 490,
              child: TabBarView(
                controller: _pricingModelTabs,
                children: [
                  _buildSaaSGrid(cardCol, textCol, borderCol, isMobile, t, appState),
                  _buildRealTimePayPerUseTab(cardCol, textCol, borderCol, isMobile, t),
                  _buildVolumeBasedMediaUploadTab(cardCol, textCol, borderCol, isMobile, t),
                ],
              ),
            ),

            const SizedBox(height: 40),

            _buildEnterpriseLicensingSection(cardCol, textCol, borderCol, isMobile, t),

            const SizedBox(height: 40),

            // ── Payment history ──────────────────────────────────────
            Text(
              t('paymentHistory', 'Payment History'),
              style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: textCol),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  _buildInvoiceItem(
                    id: "INV-2026-044", date: "May 12, 2026",
                    description: "Premium Individual Plan (Unlimited Detections)",
                    amount: "2,000 DZD", status: t('paid', 'Paid'),
                    textColor: textCol, isMobile: isMobile, t: t,
                  ),
                  Divider(height: 1, color: borderCol),
                  _buildInvoiceItem(
                    id: "INV-2026-015", date: "Apr 12, 2026",
                    description: "Premium Individual Plan (Unlimited Detections)",
                    amount: "2,000 DZD", status: t('paid', 'Paid'),
                    textColor: textCol, isMobile: isMobile, t: t,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileHeader(AppState appState, Color textCol, String Function(String, String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('billing', 'Billing'),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textCol)),
        const SizedBox(height: 4),
        Text(t('billingSubtitle', 'Manage your SaaS subscriptions and view invoices.'),
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.35),
                blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('currentPlan', 'Current Plan').toUpperCase(),
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(appState.subscriptionPlan.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
              Text(t('active', 'Active'),
                  style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(AppState appState, Color textCol, String Function(String, String) t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('billing', 'Billing'),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textCol)),
          const SizedBox(height: 8),
          Text(t('billingSubtitle', 'Manage your SaaS subscriptions and view invoices.'),
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(t('currentPlan', 'Current Plan').toUpperCase(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(appState.subscriptionPlan.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            Text(t('active', 'Active').toUpperCase(),
                style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2)),
          ]),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAAS GRID
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSaaSGrid(Color cardCol, Color textCol, Color borderCol,
      bool isMobile, String Function(String, String) t, AppState appState) {
    return LayoutBuilder(builder: (context, constraints) {
      final int cols = constraints.maxWidth > 1150
          ? 4
          : (constraints.maxWidth > 780 ? 2 : 1);

      if (cols == 1) {
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildPlanCard(context: context, appState: appState, t: t,
                planTitle: t('freeTrial', 'Free Trial'), planKey: 'free',
                price: "0 DZD", description: t('generalPublic', 'General public access'),
                features: ["5 deepfake analyses", "Full forensic CAM maps", "Scam detection free forever"],
                isPopular: false, cardColor: cardCol, textColor: textCol,
                borderColor: borderCol, addMinutes: 0, isMobile: true),
            const SizedBox(height: 16),
            _buildPlanCard(context: context, appState: appState, t: t,
                planTitle: t('premiumPlan', 'Premium Individual'), planKey: 'premium',
                price: "2,000 DZD", description: t('journalistsCreators', 'Journalists & creators'),
                features: ["Unlimited detections", "Regular engine updates", "Standard SLA support"],
                isPopular: true, cardColor: cardCol, textColor: textCol,
                borderColor: borderCol, addMinutes: 1440, isMobile: true),
            const SizedBox(height: 16),
            _buildPlanCard(context: context, appState: appState, t: t,
                planTitle: t('professionalPlan', 'Professional (SME)'), planKey: 'professional',
                price: "15,000 DZD", description: t('smesAgencies', 'SMEs & media agencies'),
                features: ["Unlimited detections", "Priority server speeds", "Standard SLA support", "On-demand uploads"],
                isPopular: false, cardColor: cardCol, textColor: textCol,
                borderColor: borderCol, addMinutes: 10000, isMobile: true),
            const SizedBox(height: 16),
            _buildPlanCard(context: context, appState: appState, t: t,
                planTitle: t('enterprisePlan', 'Enterprise'), planKey: 'enterprise',
                price: "300,000 DZD", description: t('banksGovTelecom', 'Banks, Gov & Telecom'),
                features: ["Unlimited detections", "Dedicated API access", "24/7 technical SLAs", "On-premise deployment"],
                isPopular: false, cardColor: cardCol, textColor: textCol,
                borderColor: borderCol, addMinutes: 100000, isMobile: true),
          ],
        );
      }

      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        crossAxisSpacing: 16, mainAxisSpacing: 16,
        childAspectRatio: cols == 2 ? 0.72 : 0.62,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildPlanCard(context: context, appState: appState, t: t,
              planTitle: t('freeTrial', 'Free Trial'), planKey: 'free',
              price: "0 DZD", description: t('generalPublic', 'General public access'),
              features: ["5 deepfake analyses", "Full forensic CAM maps", "Scam/Spam detection free"],
              isPopular: false, cardColor: cardCol, textColor: textCol,
              borderColor: borderCol, addMinutes: 0, isMobile: false),
          _buildPlanCard(context: context, appState: appState, t: t,
              planTitle: t('premiumPlan', 'Premium Individual'), planKey: 'premium',
              price: "2,000 DZD", description: t('journalistsCreators', 'Journalists & creators'),
              features: ["Unlimited detections", "Regular engine updates", "Standard SLA support"],
              isPopular: true, cardColor: cardCol, textColor: textCol,
              borderColor: borderCol, addMinutes: 1440, isMobile: false),
          _buildPlanCard(context: context, appState: appState, t: t,
              planTitle: t('professionalPlan', 'Professional (SME)'), planKey: 'professional',
              price: "15,000 DZD", description: t('smesAgencies', 'SMEs & media agencies'),
              features: ["Unlimited detections", "Priority server speeds", "Standard SLA support", "On-demand uploads"],
              isPopular: false, cardColor: cardCol, textColor: textCol,
              borderColor: borderCol, addMinutes: 10000, isMobile: false),
          _buildPlanCard(context: context, appState: appState, t: t,
              planTitle: t('enterprisePlan', 'Enterprise'), planKey: 'enterprise',
              price: "300,000 DZD", description: t('banksGovTelecom', 'Banks, Gov & Telecom'),
              features: ["Unlimited detections", "Dedicated API access", "24/7 technical SLAs", "On-premise deployment"],
              isPopular: false, cardColor: cardCol, textColor: textCol,
              borderColor: borderCol, addMinutes: 100000, isMobile: false),
        ],
      );
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REAL-TIME TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRealTimePayPerUseTab(Color cardCol, Color textCol,
      Color borderCol, bool isMobile, String Function(String, String) t) {
    final double dynamicCost       = _calculateRealTimeCost();
    final double baseSegmentRate   = (5 * _rtDuration) + (_rtParticipants * 2 * _rtDuration);
    final double discountPct       = _rtMonthlySessions >= 15 ? 20 : (_rtMonthlySessions >= 5 ? 10 : 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardCol, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol)),
      child: isMobile
          ? SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildRealTimeIntroText(t),
                const SizedBox(height: 20),
                _buildRealTimeSliders(textCol, t),
                const SizedBox(height: 20),
                _buildRealTimeResultBlock(dynamicCost, baseSegmentRate, discountPct, t),
              ]),
            )
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildRealTimeIntroText(t),
                  const SizedBox(height: 24),
                  _buildRealTimeSliders(textCol, t),
                ]),
              ),
              const SizedBox(width: 32),
              Expanded(flex: 4,
                  child: _buildRealTimeResultBlock(dynamicCost, baseSegmentRate, discountPct, t)),
            ]),
    );
  }

  Widget _buildRealTimeIntroText(String Function(String, String) t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('configCBrowserTitle', 'Real-Time Conference Extension (Config C)'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 6),
      Text(
        t('configCBrowserDesc', 'Charges vary dynamically based on computational loads, session duration, and participant volume.'),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    ]);
  }

  Widget _buildRealTimeSliders(Color textCol, String Function(String, String) t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${t('sessionDuration', 'Session Duration')}: ${_rtDuration.toInt()} ${t('minutesAbbr', 'mins')}',
          style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.bold)),
      Slider(value: _rtDuration, min: 5, max: 120, divisions: 23,
          activeColor: AppTheme.primaryBlue,
          onChanged: (val) => setState(() => _rtDuration = val)),
      const SizedBox(height: 12),
      Text('${t('activeParticipants', 'Active Participants')}: ${_rtParticipants.toInt()}',
          style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.bold)),
      Slider(value: _rtParticipants, min: 1, max: 20, divisions: 19,
          activeColor: AppTheme.primaryBlue,
          onChanged: (val) => setState(() => _rtParticipants = val)),
      const SizedBox(height: 12),
      Text('${t('monthlyUsageVolume', 'Monthly Usage Sessions')}: ${_rtMonthlySessions.toInt()}',
          style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.bold)),
      Slider(value: _rtMonthlySessions, min: 1, max: 30, divisions: 29,
          activeColor: AppTheme.primaryBlue,
          onChanged: (val) => setState(() => _rtMonthlySessions = val)),
    ]);
  }

  Widget _buildRealTimeResultBlock(double dynamicCost, double baseSegmentRate,
      double discountPct, String Function(String, String) t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('calculatedSessionRate', 'Calculated Session Cost').toUpperCase(),
            style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('${dynamicCost.toStringAsFixed(0)} DZD',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue)),
        const Divider(height: 24, color: Colors.white10),
        _calculatorLogItem(t('formulaRate', 'Raw Segment Formula'), '${baseSegmentRate.toStringAsFixed(0)} DZD'),
        _calculatorLogItem(t('volumeDiscount', 'Volume Discount'), '${discountPct.toStringAsFixed(0)}%'),
        _calculatorLogItem(t('minFloorLimit', 'Min Session Floor'), '150 DZD'),
        _calculatorLogItem(t('maxCapLimit', 'Max Session Cap'), '1,500 DZD'),
        const SizedBox(height: 12),
        Text(
          t('payPerUsePolicy', '*Charges are calculated on active session processing times and billed at monthly invoice intervals.'),
          style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VOLUME UPLOAD TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildVolumeBasedMediaUploadTab(Color cardCol, Color textCol,
      Color borderCol, bool isMobile, String Function(String, String) t) {
    final double uploadCost     = _calculateUploadCost();
    final double billableVolume = (_upVolume - 0.05).clamp(0.0, 9999.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardCol, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol)),
      child: isMobile
          ? SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildVolumeIntroText(t),
                const SizedBox(height: 20),
                _buildVolumeSlider(textCol, t),
                const SizedBox(height: 20),
                _buildVolumeResultBlock(uploadCost, billableVolume, t),
              ]),
            )
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildVolumeIntroText(t),
                  const SizedBox(height: 24),
                  _buildVolumeSlider(textCol, t),
                ]),
              ),
              const SizedBox(width: 32),
              Expanded(flex: 4,
                  child: _buildVolumeResultBlock(uploadCost, billableVolume, t)),
            ]),
    );
  }

  Widget _buildVolumeIntroText(String Function(String, String) t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('degressiveUploadTitle', 'Asynchronous Bulk Media Upload Pricing'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 6),
      Text(
        t('degressiveUploadDesc', 'Degressive pricing applies to media uploads exceeding 50 MB, rewarding high-volume archive verifications.'),
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    ]);
  }

  Widget _buildVolumeSlider(Color textCol, String Function(String, String) t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${t('batchUploadVolume', 'Batch Upload Volume')}: ${_upVolume.toStringAsFixed(2)} GB',
          style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.bold)),
      Slider(value: _upVolume, min: 0.05, max: 100.0, divisions: 200,
          activeColor: Colors.purpleAccent,
          onChanged: (val) => setState(() => _upVolume = val)),
      const SizedBox(height: 16),
      Text(t('degressiveBands', 'Band Structures (DZD/GB)').toUpperCase(),
          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      const SizedBox(height: 10),
      _bandLogItem(t('tier1Band', 'Tier 1 (50 MB - 1 GB)'),   '800 DZD / GB'),
      _bandLogItem(t('tier2Band', 'Tier 2 (1 GB - 10 GB)'),   '600 DZD / GB'),
      _bandLogItem(t('tier3Band', 'Tier 3 (10 GB - 50 GB)'),  '400 DZD / GB'),
      _bandLogItem(t('tier4Band', 'Tier 4 (50 GB +)'),         '250 DZD / GB'),
    ]);
  }

  Widget _buildVolumeResultBlock(double uploadCost, double billableVolume,
      String Function(String, String) t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('estimatedUploadCost', 'Estimated Batch Cost').toUpperCase(),
            style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('${uploadCost.toStringAsFixed(0)} DZD',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.purpleAccent)),
        const Divider(height: 24, color: Colors.white10),
        _calculatorLogItem(t('freeAllowance', 'Free Request Allowance'), '50 MB'),
        _calculatorLogItem(t('billableVolume', 'Billable Volume'), '${billableVolume.toStringAsFixed(2)} GB'),
        _calculatorLogItem(t('pricingStructure', 'Tiering Logic'), 'Degressive Bands'),
        const SizedBox(height: 12),
        Text(
          t('userConfirmationPolicy', '*This estimated charge will be presented to you for confirmation prior to processing any file payloads.'),
          style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENTERPRISE LICENSING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEnterpriseLicensingSection(Color cardCol, Color textCol,
      Color borderCol, bool isMobile, String Function(String, String) t) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1E3A8A).withOpacity(0.12),
          const Color(0xFF1D4ED8).withOpacity(0.02),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.api, color: Colors.blueAccent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t('enterpriseLicensingTitle', 'Enterprise Licensing (Dedicated API)'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          t('enterpriseLicensingDesc', 'Integrate Detectini directly into your local information systems via high-throughput annual licenses.'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 20),
        isMobile
            ? Column(children: [
                _buildApiLicenseCard('Standard API License', '2,000,000 DZD / Year',
                    'Config A, B & Scam modules; up to 100,000 calls/mo; technical onboarding; standard SLAs.',
                    cardCol, borderCol, textCol),
                const SizedBox(height: 16),
                _buildApiLicenseCard('Premium API License', '5,000,000 DZD / Year',
                    'All configurations; Edge/on-premise deployment; white-labeling; dedicated server; unlimited calls; 24/7 SLAs.',
                    cardCol, borderCol, textCol),
              ])
            : Row(children: [
                Expanded(child: _buildApiLicenseCard('Standard API License', '2,000,000 DZD / Year',
                    'Config A, B & Scam modules; up to 100,000 calls/mo; technical onboarding; standard SLAs.',
                    cardCol, borderCol, textCol)),
                const SizedBox(width: 16),
                Expanded(child: _buildApiLicenseCard('Premium API License', '5,000,000 DZD / Year',
                    'All configurations; Edge/on-premise deployment; white-labeling; dedicated server; unlimited calls; 24/7 SLAs.',
                    cardCol, borderCol, textCol)),
              ]),
      ]),
    );
  }

  Widget _buildApiLicenseCard(String title, String price, String features,
      Color cardCol, Color borderCol, Color textCol) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardCol.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textCol)),
        const SizedBox(height: 4),
        Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blueAccent)),
        const SizedBox(height: 10),
        Text(features, style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.45)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAN CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPlanCard({
    required BuildContext context,
    required AppState appState,
    required String Function(String, String) t,
    required String planTitle,
    required String planKey,
    required String price,
    required String description,
    required List<String> features,
    required bool isPopular,
    required Color cardColor,
    required Color textColor,
    required Color borderColor,
    required int addMinutes,
    required bool isMobile,
  }) {
    final bool isCurrentPlan =
        appState.subscriptionPlan.toLowerCase() == planKey;

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isPopular ? AppTheme.primaryBlue : borderColor,
            width: isPopular ? 2 : 1),
        gradient: isPopular
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [cardColor, AppTheme.primaryBlue.withOpacity(0.04)])
            : null,
        boxShadow: isPopular
            ? [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.12), blurRadius: 24)]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: AppTheme.primaryBlue, borderRadius: BorderRadius.circular(20)),
              child: Text(t('mostPopular', 'Most Popular'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          Text(planTitle,
              style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: isPopular ? AppTheme.primaryBlue : textColor)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price.split(' ')[0],
                  style: TextStyle(
                      fontSize: isMobile ? 28 : 34,
                      fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(width: 4),
              Text(
                price.contains('/') ? price.substring(price.indexOf('/')) : (planKey == 'free' ? '' : '/mo'),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_circle, size: 16,
                  color: isPopular ? AppTheme.primaryBlue : Colors.grey),
              const SizedBox(width: 10),
              Expanded(child: Text(f,
                  style: TextStyle(color: textColor, fontSize: 12, height: 1.3))),
            ]),
          )),
          if (!isMobile) const Spacer(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentPlan
                    ? Colors.green
                    : (isPopular ? AppTheme.primaryBlue : Colors.transparent),
                foregroundColor: isCurrentPlan || isPopular ? Colors.white : textColor,
                elevation: isCurrentPlan || isPopular ? 3 : 0,
                side: (isCurrentPlan || isPopular) ? BorderSide.none : BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isCurrentPlan
                  ? null
                  : () {
                      appState.purchasePlan(planKey, addMinutes);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("${t('upgradedTo', 'Upgraded to')} $planTitle ${t('plan', 'Plan')}!"),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ));
                    },
              child: Text(
                isCurrentPlan
                    ? t('currentPlan', 'Current Plan')
                    : "${t('upgradeTo', 'Upgrade to')} $planTitle",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVOICE ITEM
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInvoiceItem({
    required String id,
    required String date,
    required String description,
    required String amount,
    required String status,
    required Color textColor,
    required bool isMobile,
    required String Function(String, String) t,
  }) {
    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(description,
                  style: TextStyle(
                      color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text("$id • $date",
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amount,
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(status,
                style: const TextStyle(
                    color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ]),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.receipt_long, color: Colors.grey),
      ),
      title: Text(description,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      subtitle: Text("$id • $date",
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(amount,
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(status,
              style: const TextStyle(
                  color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER PRIMITIVES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _calculatorLogItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _bandLogItem(String label, String rate) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(rate,
            style: const TextStyle(
                color: Colors.grey, fontSize: 11, fontFamily: 'monospace')),
      ]),
    );
  }
}