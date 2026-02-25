import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../l10n/translations.dart';

class ApiScreen extends StatelessWidget {
  const ApiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLocale.languageCode;
    String t(String key) => AppTranslations.get(lang, key);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('devs'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(t('manageApi'), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t('activeKey'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(t('copy')),
                        onPressed: () {},
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("pk_live_51MszT...", style: TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  Text(t('warningKey'), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          Text(t('usage'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // RESPONSIVE CHART SCROLL
          Container(
            height: 250,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            // Allows scrolling if bars are too many for mobile width
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _bar(50, context), const SizedBox(width: 20),
                  _bar(80, context), const SizedBox(width: 20),
                  _bar(40, context), const SizedBox(width: 20),
                  _bar(120, context), const SizedBox(width: 20),
                  _bar(90, context), const SizedBox(width: 20),
                  _bar(140, context), const SizedBox(width: 20),
                  _bar(60, context), const SizedBox(width: 20),
                  _bar(100, context), const SizedBox(width: 20),
                  _bar(30, context),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _bar(double height, BuildContext context) {
    return Container(
      width: 30, // Thicker bars
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}