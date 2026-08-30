import 'package:eagly/presentation/components/animation_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/log_level.dart';
import '../../../../presentation/theme/log_level_presentation.dart';
import 'filter_bar_shared.dart';
import 'log_filter_controller.dart';

export 'log_filter_controller.dart'
    show
        InlineFilterController,
        InlineFilterTextController,
        LogFilterSuggestions;

/// A single Logcat-style filter field with syntax highlighting, key/value
/// autosuggestions, and a dedicated level dropdown. Fully driven by an
/// [InlineFilterController]: it owns no filter state of its own and reports
/// changes through the controller.
class InlineFilterBar extends StatefulWidget {
  const InlineFilterBar({super.key, required this.controller});

  final InlineFilterController controller;

  static const List<InlineFilterKeyDefinition> keyDefinitions = [
    InlineFilterKeyDefinition(
      canonicalKey: 'package',
      aliases: {'package', 'pkg', 'app', 'process'},
      icon: Icons.apps_outlined,
      label: 'package:',
      description: '按软件包或进程名筛选',
    ),
    InlineFilterKeyDefinition(
      canonicalKey: 'tag',
      aliases: {'tag', 'category'},
      icon: Icons.sell_outlined,
      label: 'tag:',
      description: '按标记筛选',
    ),
    InlineFilterKeyDefinition(
      canonicalKey: 'message',
      aliases: {'message', 'msg', 'text'},
      icon: Icons.message_outlined,
      label: 'message:',
      description: '仅筛选日志消息文本',
    ),
    InlineFilterKeyDefinition(
      canonicalKey: 'pid',
      aliases: {'pid', 'tid', 'thread', 'pidtid'},
      icon: Icons.tag_outlined,
      label: 'pid:',
      description: '按 PID、TID 或 PID/TID 筛选',
    ),
    InlineFilterKeyDefinition(
      canonicalKey: 'level',
      aliases: {'level', 'lvl', 'priority'},
      icon: Icons.flag_outlined,
      label: 'level:',
      description: '按日志优先级筛选',
    ),
    InlineFilterKeyDefinition(
      canonicalKey: 'age',
      aliases: {'age', 'maxage', 'since'},
      icon: Icons.schedule_outlined,
      label: 'age:',
      description: '按最长时间筛选（如 5m、1h、2d）',
    ),
  ];

  /// Preset max-age values offered as suggestions after the user types `age:`.
  static const List<(String, String)> agePresets = [
    ('1m', '最近 1 分钟'),
    ('5m', '最近 5 分钟'),
    ('15m', '最近 15 分钟'),
    ('30m', '最近 30 分钟'),
    ('1h', '最近 1 小时'),
    ('6h', '最近 6 小时'),
    ('12h', '最近 12 小时'),
    ('1d', '最近 1 天'),
  ];

  @override
  State<InlineFilterBar> createState() => _InlineFilterBarState();
}

class _InlineFilterBarState extends State<InlineFilterBar> {
  bool _helpVisible = false;

  final ScrollController _suggestionsScrollController = ScrollController();
  final Map<String, GlobalKey> _suggestionItemKeys = <String, GlobalKey>{};
  TextEditingValue? _lastSuggestionEditingValue;
  List<_InlineFilterSuggestion> _currentSuggestions = const [];
  String _lastSuggestionQuerySignature = '';
  int _highlightedSuggestionIndex = 0;

  InlineFilterController get _controller => widget.controller;
  LogFilterSuggestions get _sources => _controller.suggestions;
  bool get _isIos => _controller.isIos;

  @override
  void dispose() {
    _suggestionsScrollController.dispose();
    super.dispose();
  }

  void _reopenSuggestions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.focusNode.requestFocus();
    });
  }

  String _suggestionIdentity(_InlineFilterSuggestion suggestion) {
    return [
      suggestion.label,
      suggestion.subtitle,
      suggestion.replacementText,
    ].join('');
  }

  GlobalKey _suggestionItemKey(_InlineFilterSuggestion suggestion) {
    final identity = _suggestionIdentity(suggestion);
    return _suggestionItemKeys.putIfAbsent(identity, GlobalKey.new);
  }

  void _ensureHighlightedSuggestionVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentSuggestions.isEmpty) return;
      final suggestion = _currentSuggestions[_highlightedSuggestionIndex];
      final itemContext = _suggestionItemKey(suggestion).currentContext;
      if (itemContext == null) return;
      Scrollable.ensureVisible(
        itemContext,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  KeyEventResult _handleSuggestionKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _currentSuggestions.isEmpty) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedSuggestionIndex =
            (_highlightedSuggestionIndex + 1) % _currentSuggestions.length;
      });
      _ensureHighlightedSuggestionVisible();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedSuggestionIndex =
            (_highlightedSuggestionIndex - 1 + _currentSuggestions.length) %
            _currentSuggestions.length;
      });
      _ensureHighlightedSuggestionVisible();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _applySuggestion(_currentSuggestions[_highlightedSuggestionIndex]);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  List<_InlineFilterSuggestion> _buildSuggestions(TextEditingValue value) {
    _lastSuggestionEditingValue = value;
    final querySignature = '${value.text}${value.selection.extentOffset}';
    final context = InlineFilterEditContext.fromEditingValue(value);
    final activeToken = context.activeToken;
    final colonIndex = activeToken.text.indexOf(':');
    final suggestions =
        colonIndex > 0 && context.cursorOffset > activeToken.start + colonIndex
        ? () {
            final keyText = _bareKeyText(
              activeToken.text.substring(0, colonIndex),
            );
            final valueText = activeToken.text.substring(colonIndex + 1);
            // The literal key + operator + colon the user typed (e.g. `-tag~:`),
            // preserved so a chosen value keeps the operator intact.
            final keyPrefix = activeToken.text.substring(0, colonIndex + 1);
            final keyDefinition = InlineFilterBar.keyDefinitions.firstWhere(
              (definition) => definition.aliases.contains(keyText),
              orElse: () => const InlineFilterKeyDefinition.unknown(),
            );
            if (keyDefinition.canonicalKey == null) {
              return _matchingKeySuggestions(activeToken.text);
            }
            return _valueSuggestionsForKey(
              keyDefinition,
              valueText,
              keyPrefix: keyPrefix,
            );
          }()
        : _matchingKeySuggestions(activeToken.text);

    _currentSuggestions = suggestions;
    if (_currentSuggestions.isEmpty) {
      _highlightedSuggestionIndex = 0;
    } else if (querySignature != _lastSuggestionQuerySignature ||
        _highlightedSuggestionIndex >= _currentSuggestions.length) {
      _highlightedSuggestionIndex = 0;
    }
    _lastSuggestionQuerySignature = querySignature;
    if (_currentSuggestions.isNotEmpty) {
      _ensureHighlightedSuggestionVisible();
    }
    return suggestions;
  }

  /// Strips advanced-syntax decorations — a leading `-` (negation) and a
  /// trailing `=`/`~` (exact/regex) — from a key fragment so it resolves against
  /// [InlineFilterKeyDefinition.aliases].
  String _bareKeyText(String rawKey) {
    var key = rawKey.trim().toLowerCase();
    if (key.startsWith('-')) key = key.substring(1);
    if (key.endsWith('=') || key.endsWith('~')) {
      key = key.substring(0, key.length - 1);
    }
    return key;
  }

  List<_InlineFilterSuggestion> _matchingKeySuggestions(String query) {
    final trimmed = query.trim();
    // A leading `-` starts a negated filter; keep it on the replacement so the
    // completed token stays `-key:`.
    final negated = trimmed.startsWith('-');
    final prefix = negated ? '-' : '';
    final normalizedQuery = (negated ? trimmed.substring(1) : trimmed)
        .toLowerCase();
    return InlineFilterBar.keyDefinitions
        .where((definition) {
          if (normalizedQuery.isEmpty) return true;
          return definition.aliases.any(
            (alias) => alias.startsWith(normalizedQuery),
          );
        })
        .map(
          (definition) => _InlineFilterSuggestion(
            label: '$prefix${definition.displayLabel(isIos: _isIos)}',
            subtitle: definition.displayDescription(isIos: _isIos),
            icon: definition.icon,
            replacementText: '$prefix${definition.displayKey(isIos: _isIos)}:',
            addTrailingSpace: false,
            applyImmediately: false,
            reopenSuggestions: true,
          ),
        )
        .toList(growable: false);
  }

  List<_InlineFilterValueCandidate> _packageValueCandidates() {
    return _mergeValueCandidates([
      for (final entry in _sources.recentPackageFilters())
        _InlineFilterValueCandidate(
          value: entry,
          subtitle: 'Recent package filter',
        ),
      for (final entry in _sources.knownPackageFilters())
        _InlineFilterValueCandidate(
          value: entry,
          subtitle: 'Known package from logs',
        ),
    ]);
  }

  List<_InlineFilterValueCandidate> _mergeValueCandidates(
    List<_InlineFilterValueCandidate> candidates,
  ) {
    final deduped = <_InlineFilterValueCandidate>[];
    final seen = <String>{};
    for (final c in candidates) {
      final trimmed = c.value.trim();
      if (trimmed.isEmpty) continue;
      if (!seen.add(trimmed.toLowerCase())) continue;
      deduped.add(
        _InlineFilterValueCandidate(value: trimmed, subtitle: c.subtitle),
      );
    }
    return deduped;
  }

  bool _isBoundaryMatch(String candidate, String query) =>
      filterBoundaryMatch(candidate, query);

  Iterable<_InlineFilterValueCandidate> _matchingValueCandidates(
    List<_InlineFilterValueCandidate> candidates,
    String normalizedValue,
  ) sync* {
    if (normalizedValue.isEmpty) {
      yield* candidates;
      return;
    }

    final preferredMatches = <_InlineFilterValueCandidate>[];
    final secondaryMatches = <_InlineFilterValueCandidate>[];
    for (final candidate in candidates) {
      final normalizedCandidate = candidate.value.toLowerCase();
      if (!normalizedCandidate.contains(normalizedValue)) continue;
      final bucket = _isBoundaryMatch(normalizedCandidate, normalizedValue)
          ? preferredMatches
          : secondaryMatches;
      bucket.add(candidate);
    }

    yield* preferredMatches;
    yield* secondaryMatches;
  }

  List<_InlineFilterSuggestion> _valueSuggestionsForKey(
    InlineFilterKeyDefinition keyDefinition,
    String rawValue, {
    required String keyPrefix,
  }) {
    final normalizedValue = _normalizeValue(rawValue).toLowerCase();
    if (keyDefinition.canonicalKey == 'age') {
      return InlineFilterBar.agePresets
          .where(
            (preset) =>
                normalizedValue.isEmpty ||
                preset.$1.startsWith(normalizedValue),
          )
          .map(
            (preset) => _InlineFilterSuggestion(
              label: 'age:${preset.$1}',
              subtitle: preset.$2,
              icon: keyDefinition.icon,
              replacementText: 'age:${preset.$1}',
              addTrailingSpace: true,
              applyImmediately: true,
              reopenSuggestions: false,
            ),
          )
          .toList(growable: false);
    }
    if (keyDefinition.canonicalKey == 'level') {
      final supportedLevels = _isIos
          ? LogLevel.iosValues
          : LogLevel.androidValues;
      return supportedLevels
          .where((level) {
            if (normalizedValue.isEmpty) return true;
            return level.code.contains(normalizedValue) ||
                level
                    .displayLabel(isIos: _isIos)
                    .toLowerCase()
                    .contains(normalizedValue) ||
                level
                    .displayCode(isIos: _isIos)
                    .toLowerCase()
                    .contains(normalizedValue);
          })
          .map(
            (level) => _InlineFilterSuggestion(
              label: 'level:${level.code}',
              subtitle: level.labelWithDisplayCode(isIos: _isIos),
              icon: keyDefinition.icon,
              level: level,
              replacementText: 'level:${level.code}',
              addTrailingSpace: true,
              applyImmediately: true,
              reopenSuggestions: false,
            ),
          )
          .toList(growable: false);
    }

    final valueCandidates = switch (keyDefinition.canonicalKey) {
      'package' => _packageValueCandidates(),
      'tag' => _mergeValueCandidates([
        for (final entry in _sources.recentTagFilters())
          _InlineFilterValueCandidate(
            value: entry,
            subtitle: _isIos ? 'Recent category filter' : 'Recent tag filter',
          ),
      ]),
      'message' => _mergeValueCandidates([
        for (final entry in _sources.recentMessageFilters())
          _InlineFilterValueCandidate(
            value: entry,
            subtitle: 'Recent message filter',
          ),
      ]),
      'pid' => _mergeValueCandidates([
        for (final entry in _sources.recentPidTidFilters())
          _InlineFilterValueCandidate(
            value: entry,
            subtitle: 'Recent pid/tid filter',
          ),
      ]),
      _ => const <_InlineFilterValueCandidate>[],
    };

    // Preserve the exact key + operator the user typed (`keyPrefix`) so a picked
    // value keeps its operator, e.g. `-tag~:` + `auth` → `-tag~:auth`.
    return _matchingValueCandidates(valueCandidates, normalizedValue)
        .map(
          (entry) => _InlineFilterSuggestion(
            label: '$keyPrefix${_formatInlineValue(entry.value)}',
            subtitle: entry.subtitle,
            icon: keyDefinition.icon,
            replacementText: '$keyPrefix${_formatInlineValue(entry.value)}',
            addTrailingSpace: true,
            applyImmediately: true,
            reopenSuggestions: false,
          ),
        )
        .toList(growable: false);
  }

  String _formatInlineValue(String value) {
    final trimmed = value.trim();
    final needsQuotes =
        trimmed.contains(RegExp(r'\s')) || trimmed.contains('"');
    if (!needsQuotes) return trimmed;
    return '"${trimmed.replaceAll('"', r'\"')}"';
  }

  String _normalizeValue(String rawValue) {
    var normalized = rawValue.trim();
    if (normalized.length >= 2 &&
        normalized.startsWith('"') &&
        normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    return normalized.replaceAll(r'\"', '"');
  }

  void _applySuggestion(_InlineFilterSuggestion suggestion) {
    final value =
        _lastSuggestionEditingValue ?? _controller.textController.value;
    final context = InlineFilterEditContext.fromEditingValue(value);
    final activeToken = context.activeToken;
    final replacement = suggestion.addTrailingSpace
        ? '${suggestion.replacementText} '
        : suggestion.replacementText;
    final nextText =
        value.text.substring(0, activeToken.start) +
        replacement +
        value.text.substring(activeToken.end);
    final offset = activeToken.start + replacement.length;
    _controller.applySuggestionText(
      nextText,
      selection: TextSelection.collapsed(offset: offset),
      applyImmediately: suggestion.applyImmediately,
    );
    if (suggestion.reopenSuggestions) {
      _reopenSuggestions();
    }
  }

  void _appendToken(String token, {required bool applyImmediately}) {
    final existingText = _controller.textController.text;
    final prefix = existingText.trim().isEmpty
        ? ''
        : RegExp(r'\s$').hasMatch(existingText)
        ? ''
        : ' ';
    final suffix = applyImmediately ? ' ' : '';
    final nextText = '$existingText$prefix$token$suffix';
    _controller.applySuggestionText(
      nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      applyImmediately: applyImmediately,
    );
  }

  Widget _buildHelpSection(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSection(
      visible: _helpVisible,
      axis: Axis.vertical,
      child: Container(
        key: const ValueKey('inline-filter-help'),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              Icons.tips_and_updates_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Text(
              'Bare words search the whole log entry. Use key:value for '
              'package, ${_isIos ? 'category' : 'tag'}, pid, message, '
              'level, or age (e.g. age:1h). Add =: for an exact match, ~: for '
              'regex, or a leading - to exclude — e.g. -package:test or '
              'tag~:auth.*. Quote values with spaces.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            ActionChip(
              label: const Text('package:'),
              onPressed: () =>
                  _appendToken('package:', applyImmediately: false),
            ),
            ActionChip(
              label: Text(_isIos ? 'category:' : 'tag:'),
              onPressed: () => _appendToken(
                _isIos ? 'category:' : 'tag:',
                applyImmediately: false,
              ),
            ),
            ActionChip(
              label: const Text('message:'),
              onPressed: () =>
                  _appendToken('message:', applyImmediately: false),
            ),
            ActionChip(
              label: const Text('level:error'),
              onPressed: () =>
                  _appendToken('level:error', applyImmediately: true),
            ),
            ActionChip(
              label: const Text('age:1h'),
              onPressed: () => _appendToken('age:1h', applyImmediately: true),
            ),
            ActionChip(
              label: const Text('-package:'),
              onPressed: () =>
                  _appendToken('-package:', applyImmediately: false),
            ),
            ActionChip(
              label: const Text('message~:'),
              onPressed: () =>
                  _appendToken('message~:', applyImmediately: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelDropdown(BuildContext context) {
    return LogLevelDropdown(
      selectedLogLevel: _controller.selectedLevel,
      onLogLevelChanged: (level) {
        if (level != null) _controller.setLevel(level);
      },
      isIos: _isIos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLevelDropdown(context),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: kFilterFieldHeight,
                child: RawAutocomplete<_InlineFilterSuggestion>(
                  textEditingController: _controller.textController,
                  focusNode: _controller.focusNode,
                  optionsBuilder: _buildSuggestions,
                  displayStringForOption: (option) => option.label,
                  onSelected: _applySuggestion,
                  fieldViewBuilder:
                      (
                        context,
                        fieldController,
                        fieldFocusNode,
                        onFieldSubmitted,
                      ) {
                        return Focus(
                          canRequestFocus: false,
                          onKeyEvent: (_, event) =>
                              _handleSuggestionKeyEvent(event),
                          child: TextField(
                            controller: fieldController,
                            focusNode: fieldFocusNode,
                            style: const TextStyle(fontSize: 12),
                            decoration: filterInputDecoration(
                              context,
                              hintText: _isIos
                                  ? '例如 package:com.example.app category:Network level:error，或直接输入文本'
                                  : '例如 package:com.example.app tag:Auth level:error，或直接输入文本',
                              prefixIcon: Icons.message,
                            ),
                            onSubmitted: (_) {
                              _controller.applyNow();
                              onFieldSubmitted();
                            },
                          ),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    final materialOptions = options.toList(growable: false);
                    if (materialOptions.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            maxWidth: 540,
                          ),
                          child: ListView.separated(
                            controller: _suggestionsScrollController,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: materialOptions.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final option = materialOptions[index];
                              return Builder(
                                builder: (context) {
                                  final isHighlighted =
                                      _highlightedSuggestionIndex == index;
                                  final backgroundColor = isHighlighted
                                      ? theme.colorScheme.secondaryContainer
                                      : null;
                                  return InkWell(
                                    key: _suggestionItemKey(option),
                                    onTap: () => _applySuggestion(option),
                                    child: ColoredBox(
                                      color:
                                          backgroundColor ?? Colors.transparent,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Expanded(
                                              child: option.level != null
                                                  ? LogLevelLabel(
                                                      level: option.level!,
                                                      isIos: _isIos,
                                                      text: option.label,
                                                      compact: true,
                                                      textStyle: theme
                                                          .textTheme
                                                          .bodySmall,
                                                    )
                                                  : Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Icon(
                                                          option.icon,
                                                          size: 12,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            option.label,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      isHighlighted
                                                                      ? theme
                                                                            .colorScheme
                                                                            .onSecondaryContainer
                                                                      : null,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                            if (option.subtitle.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  option.subtitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.end,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontSize: 10,
                                                        color: isHighlighted
                                                            ? theme
                                                                  .colorScheme
                                                                  .onSecondaryContainer
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: _helpVisible ? 'Hide filter help' : 'Show filter help',
              onPressed: () => setState(() => _helpVisible = !_helpVisible),
              icon: Icon(_helpVisible ? Icons.help : Icons.help_outline),
            ),
          ],
        ),
        _buildHelpSection(context),
      ],
    );
  }
}

class _InlineFilterSuggestion {
  const _InlineFilterSuggestion({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.level,
    required this.replacementText,
    required this.addTrailingSpace,
    required this.applyImmediately,
    required this.reopenSuggestions,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final LogLevel? level;
  final String replacementText;
  final bool addTrailingSpace;
  final bool applyImmediately;
  final bool reopenSuggestions;
}

class _InlineFilterValueCandidate {
  const _InlineFilterValueCandidate({
    required this.value,
    required this.subtitle,
  });

  final String value;
  final String subtitle;
}

class InlineFilterKeyDefinition {
  const InlineFilterKeyDefinition({
    required this.canonicalKey,
    required this.aliases,
    required this.icon,
    required this.label,
    required this.description,
  });

  const InlineFilterKeyDefinition.unknown()
    : canonicalKey = null,
      aliases = const <String>{},
      icon = Icons.help_outline,
      label = '',
      description = '';

  final String? canonicalKey;
  final Set<String> aliases;
  final IconData icon;
  final String label;
  final String description;

  /// Key surfaced to the user. iOS presents the `tag` filter as `category` to
  /// match the log column header, while still filtering on tags under the hood.
  String displayKey({required bool isIos}) =>
      isIos && canonicalKey == 'tag' ? 'category' : (canonicalKey ?? '');

  /// `key:` label shown in suggestions, platform-aware.
  String displayLabel({required bool isIos}) => '${displayKey(isIos: isIos)}:';

  /// Description shown in suggestions, platform-aware.
  String displayDescription({required bool isIos}) =>
      isIos && canonicalKey == 'tag' ? '按类别筛选' : description;
}
