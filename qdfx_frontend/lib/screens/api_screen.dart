import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../l10n/translations.dart';

class ApiScreen extends StatefulWidget {
  const ApiScreen({super.key});

  @override
  State<ApiScreen> createState() => _ApiScreenState();
}

class _ApiScreenState extends State<ApiScreen> {
  bool _isKeyVisible = false;
  final String _apiKey = "pk_live_qdfx_9928_xm10_secure"; // Mock Key

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final lang = appState.currentLocale.languageCode;
    
    // Theme Colors
    final bgCol = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    final cardCol = isDark ? const Color(0xFF151E32) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
    final accentCol = const Color(0xFF00D2D3); // Cyan

    // Translation helper
    String t(String key) {
      try { return AppTranslations.get(lang, key); } catch (e) { return key; }
    }

    return Scaffold(
      backgroundColor: bgCol,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Developer Console", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textCol)),
                    Text("Manage API keys, Webhooks, and On-Premise Licenses.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green)),
                  child: const Row(children: [Icon(Icons.wifi, size: 16, color: Colors.green), SizedBox(width: 6), Text("API Systems Operational", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))]),
                )
              ],
            ),
            
            const SizedBox(height: 40),

            // --- 1. API KEY VAULT ---
            Text("API Credentials", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Production Key", style: TextStyle(color: textCol, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: accentCol.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text("ACTIVE", style: TextStyle(color: accentCol, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B1121) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderCol)
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.key, color: Colors.grey, size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _isKeyVisible ? _apiKey : "pk_live_••••••••••••••••••••••••",
                            style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: textCol, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: Icon(_isKeyVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _isKeyVisible = !_isKeyVisible),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, color: AppTheme.primaryBlue),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _apiKey));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("API Key Copied")));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Do not share this key. It grants full access to the Deepfake Detection Engine.", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text("Roll Key"),
                        style: OutlinedButton.styleFrom(foregroundColor: textCol, side: BorderSide(color: borderCol)),
                      ),
                      const SizedBox(width: 16),
                      TextButton(onPressed: () {}, child: const Text("View Documentation ->"))
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- 2. USAGE METRICS ---
            Text("Usage Analytics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMetricCard("Requests", "124.5K", "+12%", Icons.cloud_sync, Colors.blue, cardCol, textCol, borderCol)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard("Error Rate", "0.02%", "-0.01%", Icons.warning, Colors.green, cardCol, textCol, borderCol)), // Green because low error is good
                const SizedBox(width: 16),
                Expanded(child: _buildMetricCard("Avg Latency", "240ms", "~", Icons.speed, Colors.orange, cardCol, textCol, borderCol)),
              ],
            ),
            const SizedBox(height: 24),
            
            // Chart
            Container(
              height: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("API Traffic (Last 7 Days)", style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // FANCY CHART VISUALIZATION
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _chartBar(40, AppTheme.primaryBlue),
                      _chartBar(60, AppTheme.primaryBlue),
                      _chartBar(35, AppTheme.primaryBlue),
                      _chartBar(80, AppTheme.primaryBlue),
                      _chartBar(50, AppTheme.primaryBlue),
                      _chartBar(90, accentCol), // Today
                      _chartBar(20, AppTheme.primaryBlue),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((e) => Text(e, style: const TextStyle(color: Colors.grey, fontSize: 10))).toList(),
                  )
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- 3. ON-PREMISE LICENSE (Proprietary) ---
            if (appState.userRole == 'police' || appState.userRole == 'enterprise') ...[
              Text("Enterprise License (On-Premise)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF1E3A8A).withOpacity(0.1), const Color(0xFF1E3A8A).withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF1E3A8A).withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.domain_verification, color: Color(0xFF3B82F6), size: 32),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Docker Container License", style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text("Valid until: Dec 31, 2026. Hardware ID: 7721-X-MAC", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download),
                      label: const Text("Download Key File"),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                    )
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildMetricCard(String title, String value, String trend, IconData icon, Color color, Color cardCol, Color textCol, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardCol,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: Colors.grey),
              Text(trend, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textCol)),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _chartBar(double height, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Container(
          height: height * 2, // Scale up
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.3)]
            )
          ),
        ),
      ),
    );
  }
}