import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_service.dart';
import '../l10n/translations.dart';

class LanguageSelector extends StatelessWidget {
  final bool isDark;
  
  const LanguageSelector({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final localization = Provider.of<LocalizationService>(context);
    final currentCode = localization.locale;
    
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getFlag(currentCode),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            color: isDark ? Colors.white70 : Colors.grey[700],
            size: 20,
          ),
        ],
      ),
      onSelected: (code) {
        localization.setLocale(code);
      },
      itemBuilder: (context) => AppTranslations.supportedLanguages.map((lang) {
        return PopupMenuItem(
          value: lang['code'],
          child: Row(
            children: [
              Text(lang['flag']!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(
                lang['name']!,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: currentCode == lang['code'] 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                ),
              ),
              if (currentCode == lang['code'])
                const Spacer(),
              if (currentCode == lang['code'])
                const Icon(Icons.check, size: 16, color: Colors.green),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  String _getFlag(String code) {
    switch (code) {
      case 'en': return '🇺🇸';
      case 'fr': return '🇫🇷';
      case 'ar': return '🇩🇿';
      default: return '🌐';
    }
  }
}