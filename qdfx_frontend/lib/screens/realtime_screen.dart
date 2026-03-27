import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';

class RealTimeScreen extends StatelessWidget {
  const RealTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;

    // Theme Colors
    final bgCol = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    final cardCol = isDark ? const Color(0xFF151E32) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
    final accentCol = const Color(0xFF00D2D3); // Cyan

    return Scaffold(
      backgroundColor: bgCol,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Text("Real-Time Protection", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textCol)),
            Text("Browser Extension Hub & Usage Logs", style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 30),

            // --- 1. HERO SECTION (DOWNLOAD) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1E3A8A), const Color(0xFF1E3A8A).withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Secure your meetings instantly.", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text("Download the QDFX Browser Extension to detect deepfakes during Zoom, Google Meet, and Teams calls.", 
                          style: TextStyle(color: Colors.white70, height: 1.5)),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          children: [
                            _downloadButton(Icons.language, "Chrome Store"),
                            _downloadButton(Icons.explore, "Microsoft Edge"),
                          ],
                        )
                      ],
                    ),
                  ),
                  // Graphic
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Icon(Icons.extension, size: 100, color: Colors.white.withOpacity(0.2)),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- 2. PAIRING KEY & WALLET ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pairing Key Card
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: cardCol, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderCol)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.link, color: accentCol),
                            const SizedBox(width: 8),
                            Text("Link Extension", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text("Copy this key into the extension to link your wallet.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 20),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black26 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accentCol.withOpacity(0.3))
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text("sk_live_qdfx_8829", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, color: textCol, letterSpacing: 1), overflow: TextOverflow.ellipsis),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                color: accentCol,
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: "sk_live_qdfx_8829"));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Key Copied!")));
                                },
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 24),

                // Wallet Status Card
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: cardCol, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderCol)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [Icon(Icons.account_balance_wallet, color: Colors.green), SizedBox(width: 8), Text("Wallet Balance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol))]),
                        const SizedBox(height: 12),
                        const Text("Real-time detection consumes credits per minute per participant.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 20),
                        Text("${appState.credits} Credits", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: appState.credits > 100 ? Colors.green : Colors.red)),
                        const SizedBox(height: 5),
                        Text("Rate: 5 Credits / person / min", style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- 3. SESSION HISTORY (UPDATED WITH BILLING LOGIC) ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Session History & Usage", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textCol)),
                  const SizedBox(height: 20),
                  
                  // TABLE HEADER
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text("MEETING SOURCE", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("DURATION", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("PEOPLE", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("COST", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text("STATUS", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  Divider(color: borderCol),
                  
                  // LOG ITEMS (REPLACED LOGIC)
                  _billingLogItem("Zoom Meeting #9921", "45 mins", "4", "-900 Credits", "Safe", Colors.green, textCol),
                  _billingLogItem("Google Meet (Interview)", "12 mins", "2", "-120 Credits", "Suspicious", Colors.orange, textCol),
                  _billingLogItem("Microsoft Teams", "60 mins", "10", "-3,000 Credits", "Safe", Colors.green, textCol),
                  _billingLogItem("Zoom Webinar #1102", "5 mins", "1", "-25 Credits", "Critical", Colors.red, textCol),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _downloadButton(IconData icon, String label) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {},
    );
  }

  // UPDATED LOG ITEM WIDGET
  Widget _billingLogItem(String source, String duration, String people, String cost, String status, Color statusColor, Color textCol) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(source, style: TextStyle(fontWeight: FontWeight.w600, color: textCol, fontSize: 14))),
          Expanded(flex: 2, child: Text(duration, style: TextStyle(color: textCol.withOpacity(0.7), fontSize: 14))),
          Expanded(flex: 2, child: Text(people, style: TextStyle(color: textCol.withOpacity(0.7), fontSize: 14))),
          Expanded(flex: 2, child: Text(cost, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14))),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.3))
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}