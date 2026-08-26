import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_lens/core/constants/app_constants.dart';
import 'package:document_lens/providers/ocr_provider.dart';
import 'package:document_lens/core/theme/app_theme.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final ocrProvider = context.watch<OcrProvider>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AppConstants.supportedLanguages.map((lang) {
          final isSelected = ocrProvider.selectedLanguage == lang['code'];
          return GestureDetector(
            onTap: () => ocrProvider.setLanguage(lang['code']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                lang['name']!,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

