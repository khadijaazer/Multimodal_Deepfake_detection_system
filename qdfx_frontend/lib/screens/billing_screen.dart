import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../l10n/translations.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDark = appState.isDarkMode;
    final lang = appState.currentLocale.languageCode;
    String t(String key) => AppTranslations.get(lang, key);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('subPlans'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(t('manageLimits'), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          // RESPONSIVE GRID
          LayoutBuilder(builder: (context, constraints) {
            // Determine columns based on width
            int crossAxisCount = 1;
            double aspectRatio = 1.1; // Default for Mobile (Squarish)

            if (constraints.maxWidth > 1100) {
              crossAxisCount = 4; // Large Desktop
              aspectRatio = 0.8; // Tall cards
            } else if (constraints.maxWidth > 700) {
              crossAxisCount = 2; // Tablet
              aspectRatio = 1.0; 
            } else {
              crossAxisCount = 1; // Mobile
              aspectRatio = 1.5; // Wide cards for mobile scrolling
            }

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: aspectRatio,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPriceCard(context, t('saas'), "\$20", t('upload'), isDark, false, t('subscribe')),
                _buildPriceCard(context, t('realtime'), "\$50", t('realtime'), isDark, true, t('subscribe')),
                _buildPriceCard(context, t('volume'), "\$70", t('upload'), isDark, false, t('subscribe')),
                _buildPriceCard(context, t('enterprise'), "\$1000+", t('api'), isDark, false, t('subscribe')),
              ],
            );
          }),

          const SizedBox(height: 40),
          Text(t('invoices'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Invoice Table
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                  ),
                  title: Text("${t('invoice')} #${10239 - index}"),
                  subtitle: const Text("2026-02-10"),
                  trailing: const Text("\$20.00", style: TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context, String title, String price, String sub, bool isDark, bool highlighted, String btnText) {
    Color primary = Theme.of(context).primaryColor;
    Color bg = highlighted ? primary.withOpacity(0.1) : (isDark ? const Color(0xFF1E293B) : Colors.white);
    Color border = highlighted ? primary : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(price, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primary)),
          const SizedBox(height: 8),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: highlighted ? primary : (isDark ? Colors.black26 : Colors.grey[200]),
                foregroundColor: highlighted ? Colors.white : (isDark ? Colors.white : Colors.black87),
              ),
              onPressed: () {},
              child: Text(btnText),
            ),
          )
        ],
      ),
    );
  }
}