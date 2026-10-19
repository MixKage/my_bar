import 'package:flutter/material.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/widgets/bar_pressable.dart';

Future<AppLanguage?> showLanguageSelector(
  BuildContext context, {
  required AppLanguage selected,
  bool powerSavingMode = false,
}) => showDialog<AppLanguage>(
  context: context,
  builder: (_) =>
      _LanguageSelector(selected: selected, powerSavingMode: powerSavingMode),
);

class _LanguageSelector extends StatefulWidget {
  const _LanguageSelector({
    required this.selected,
    required this.powerSavingMode,
  });

  final AppLanguage selected;
  final bool powerSavingMode;

  @override
  State<_LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<_LanguageSelector> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final languages = AppLanguage.values
        .where((language) {
          final terms = <String>[
            language.nativeName,
            language.englishName,
            language.storageValue,
            context.appLanguageLabel(language),
            context.localizedLanguageName(language),
          ];
          return terms.any((term) => term.toLowerCase().contains(query));
        })
        .toList(growable: false);

    return Dialog(
      backgroundColor: const Color(0xFF151B30),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SizedBox(
        width: 480,
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.tr('Выберите язык', 'Choose language'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('Закрыть', 'Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.tr('Поиск языка', 'Search languages'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: languages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          context.tr('Языки не найдены', 'No languages found'),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: languages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final language = languages[index];
                        final selected = language == widget.selected;
                        final isSystem = language == AppLanguage.system;
                        return BarPressable(
                          selected: selected,
                          powerSavingMode: widget.powerSavingMode,
                          onTap: () => Navigator.of(context).pop(language),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 64),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0x268FA3FF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: selected
                                  ? Border.all(color: const Color(0x668FA3FF))
                                  : null,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        isSystem
                                            ? context.appLanguageLabel(language)
                                            : language.nativeName,
                                        textDirection:
                                            language == AppLanguage.arabic
                                            ? TextDirection.rtl
                                            : null,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isSystem
                                            ? context.tr(
                                                'Использовать язык устройства',
                                                'Use device language',
                                              )
                                            : context.localizedLanguageName(
                                                language,
                                              ),
                                        style: const TextStyle(
                                          color: Color(0xFFAEBBDC),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFFB5C1FF),
                                    size: 24,
                                  )
                                else if (isSystem)
                                  const Icon(
                                    Icons.phone_iphone_rounded,
                                    color: Color(0xFFAEBBDC),
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
