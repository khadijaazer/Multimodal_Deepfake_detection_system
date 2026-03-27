import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../l10n/translations.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final lang = appState.currentLocale.languageCode;
    
    // Safety check for translation
    String t(String key) {
      try {
        return AppTranslations.get(lang, key);
      } catch (e) {
        return key; // Fallback
      }
    }

    // Theme Colors
    final bgCol = isDark ? const Color(0xFF0B1121) : const Color(0xFFF8FAFC);
    final cardCol = isDark ? const Color(0xFF151E32) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1E293B);
    final borderCol = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300;
    
    return Scaffold(
      backgroundColor: bgCol,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER & WALLET ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Billing & Credits", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textCol)),
                    const SizedBox(height: 8),
                    Text("Manage your subscription and detection credits.", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  ],
                ),
                // Current Balance Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Current Balance", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("${appState.credits}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const Text("CREDITS", style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 2)),
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(height: 50),

            // --- SECTION 1: TOP UP CREDITS (Pay As You Go) ---
            Text("Top-up Credits", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 8),
            const Text("Credits are used for Video Uploads (1 credit) and Real-time Detection (5 credits/min).", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive Switch
                if (constraints.maxWidth > 900) {
                  return Row(
                    children: [
                      // PASS CONTEXT HERE
                      Expanded(child: _buildCreditCard(context, "Starter Pack", "500 Credits", "\$15", false, cardCol, textCol, borderCol, appState)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildCreditCard(context, "Pro Pack", "2,500 Credits", "\$60", true, cardCol, textCol, borderCol, appState)), // Best Value
                      const SizedBox(width: 20),
                      Expanded(child: _buildCreditCard(context, "Enterprise Pack", "10,000 Credits", "\$200", false, cardCol, textCol, borderCol, appState)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      // PASS CONTEXT HERE
                      _buildCreditCard(context, "Starter Pack", "500 Credits", "\$15", false, cardCol, textCol, borderCol, appState),
                      const SizedBox(height: 16),
                      _buildCreditCard(context, "Pro Pack", "2,500 Credits", "\$60", true, cardCol, textCol, borderCol, appState),
                      const SizedBox(height: 16),
                      _buildCreditCard(context, "Enterprise Pack", "10,000 Credits", "\$200", false, cardCol, textCol, borderCol, appState),
                    ],
                  );
                }
              }
            ),

            const SizedBox(height: 60),

            // --- SECTION 2: MONTHLY SUBSCRIPTIONS (Features) ---
            Text("Monthly Plans", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 8),
            const Text("Unlock advanced features like API Access, Priority Processing, and Team Seats.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive Grid
                int crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.7, // Taller cards for feature lists
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildSubscriptionCard(
                      "Basic", "Free", "For individuals", 
                      ["Manual Upload", "Standard Speed", "Basic Reports"], 
                      false, cardCol, textCol, borderCol
                    ),
                    _buildSubscriptionCard(
                      "Professional", "\$49/mo", "For journalists & creators", 
                      ["All Basic Features", "Priority Processing", "Full Forensic PDF", "Real-time Extension"], 
                      true, cardCol, textCol, borderCol
                    ),
                    _buildSubscriptionCard(
                      "Organization", "\$499/mo", "For agencies & police", 
                      ["All Pro Features", "API Access", "5 Team Seats", "Dedicated Server"], 
                      false, cardCol, textCol, borderCol
                    ),
                  ],
                );
              }
            ),

            const SizedBox(height: 60),

            // --- SECTION 3: INVOICES ---
            Text("Payment History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: cardCol,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  _invoiceItem("INV-2024-001", "Feb 28, 2024", "Credit Pack (2,500)", "\$60.00", "Paid", textCol),
                  Divider(height: 1, color: borderCol),
                  _invoiceItem("INV-2024-002", "Jan 28, 2024", "Pro Subscription", "\$49.00", "Paid", textCol),
                  Divider(height: 1, color: borderCol),
                  _invoiceItem("INV-2023-012", "Dec 28, 2023", "Pro Subscription", "\$49.00", "Paid", textCol),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  // FIX: Added BuildContext context as the first argument
  Widget _buildCreditCard(BuildContext context, String title, String amount, String price, bool isBest, Color bg, Color text, Color border, AppState appState) {
    return Container(
      height: 280, // Fixed height to prevent Spacer error
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isBest ? const Color(0xFF00D2D3) : border, width: isBest ? 2 : 1),
        boxShadow: isBest ? [BoxShadow(color: const Color(0xFF00D2D3).withOpacity(0.2), blurRadius: 20)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBest) 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFF00D2D3), borderRadius: BorderRadius.circular(4)),
              child: const Text("BEST VALUE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(amount, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: text)),
          
          const Spacer(), 
          
          Text(price, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBest ? const Color(0xFF00D2D3) : Colors.grey[800],
                foregroundColor: isBest ? Colors.black : Colors.white,
              ),
              onPressed: () {
                // Simulate Top Up
                int creds = int.parse(amount.split(" ")[0].replaceAll(",", ""));
                appState.purchasePlan("Custom", creds);
                
                // FIX: Use the context passed in the arguments
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Purchased $creds credits! Balance updated."))
                );
              },
              child: const Text("Buy Now"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(String plan, String price, String sub, List<String> features, bool isPro, Color bg, Color text, Color border) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPro ? AppTheme.primaryBlue : border, width: isPro ? 2 : 1),
        gradient: isPro ? LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [bg, AppTheme.primaryBlue.withOpacity(0.05)]
        ) : null
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isPro ? AppTheme.primaryBlue : text)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          Text(price, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: text)),
          const SizedBox(height: 24),
          
          // Features List
          Expanded( 
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: features.length,
              itemBuilder: (c, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: isPro ? AppTheme.primaryBlue : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(features[i], style: TextStyle(color: text, fontSize: 13))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPro ? AppTheme.primaryBlue : Colors.transparent,
                foregroundColor: isPro ? Colors.white : text,
                elevation: isPro ? 5 : 0,
                side: isPro ? BorderSide.none : BorderSide(color: border),
              ),
              onPressed: () {},
              child: Text(isPro ? "Upgrade to Pro" : "Current Plan"),
            ),
          )
        ],
      ),
    );
  }

  Widget _invoiceItem(String id, String date, String desc, String amount, String status, Color textCol) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.receipt_long, color: Colors.grey),
      ),
      title: Text(desc, style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
      subtitle: Text("$id • $date", style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(amount, style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(status, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}