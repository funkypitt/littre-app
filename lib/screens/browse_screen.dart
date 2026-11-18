import 'dart:math';
import 'package:flutter/material.dart';
import '../models/browse_entry.dart';
import '../services/browse_position.dart';
import '../services/database_service.dart';
import 'entry_screen.dart';

/// Feuilleter : le dictionnaire page après page, dans l'ordre du livre.
///
/// Chaque page montre les articles qui se suivent, réduits à leur début ;
/// on tourne les pages, on ouvre au hasard, on saute à une lettre.
class BrowseScreen extends StatefulWidget {
  /// Article par lequel la page doit commencer ; sans lui, la page où le
  /// lecteur s'était arrêté.
  final int? startId;

  const BrowseScreen({super.key, this.startId});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  static const _baseLines = 3;
  static const _maxLines = 14;
  static const _sidePadding = 20.0;
  static const _tilePadding = 7.0;
  static const _headGap = 2.0;
  static const _maxGap = 16.0;
  static const _fetch = 60;

  static void _reverse<T>(List<T> list) {
    final reversed = list.reversed.toList();
    list
      ..clear()
      ..addAll(reversed);
  }

  final _db = DatabaseService();
  final _position = BrowsePosition();
  final _random = Random();

  int _total = 0;
  Map<String, int> _letters = const {};

  // La page demandée : à partir de _anchor, ou finissant juste avant.
  int _anchor = 1;
  bool _forward = true;
  List<BrowseEntry>? _rows;
  int _request = 0;

  // Les pages d'où l'on vient, pour revenir exactement sur elles.
  final List<int> _previousPages = [];

  _Page? _page;
  Object? _pageKey;

  @override
  void initState() {
    super.initState();
    _position.first.addListener(_onPositionChanged);
    _open();
  }

  @override
  void dispose() {
    _position.first.removeListener(_onPositionChanged);
    super.dispose();
  }

  Future<void> _open() async {
    final total = await _db.getEntryCount();
    final letters = await _db.getLetterStarts();
    final saved = await _position.load();
    if (!mounted) return;
    _total = total;
    _letters = letters;
    // La première fois, le livre s'ouvre n'importe où.
    final start = widget.startId ?? saved ?? _randomId();
    _show(start.clamp(1, max(1, total)), forward: true);
  }

  int _randomId() => _total <= 1 ? 1 : _random.nextInt(_total) + 1;

  /// Une autre vue du feuilletage a tourné la page : celle-ci suit.
  void _onPositionChanged() {
    final first = _position.first.value;
    if (first == null || _total == 0) return;
    if (_page != null && _page!.entries.first.id == first) return;
    if (_forward && _anchor == first) return;
    _previousPages.clear();
    _show(first, forward: true);
  }

  Future<void> _show(int anchor, {required bool forward}) async {
    final request = ++_request;
    final rows = forward
        ? await _db.browseFrom(anchor, limit: _fetch)
        : await _db.browseBefore(anchor, limit: _fetch);
    if (!mounted || request != _request) return;
    if (rows.isEmpty) return;
    setState(() {
      _anchor = anchor;
      _forward = forward;
      _rows = rows;
      _pageKey = null;
    });
  }

  bool get _hasPrevious => _page != null && _page!.entries.first.id > 1;
  bool get _hasNext => _page != null && _page!.entries.last.id < _total;

  void _nextPage() {
    if (!_hasNext) return;
    _previousPages.add(_page!.entries.first.id);
    _show(_page!.entries.last.id + 1, forward: true);
  }

  void _previousPage() {
    if (!_hasPrevious) return;
    if (_previousPages.isNotEmpty) {
      _show(_previousPages.removeLast(), forward: true);
    } else {
      _show(_page!.entries.first.id, forward: false);
    }
  }

  void _jumpTo(int id) {
    _previousPages.clear();
    _show(id, forward: true);
  }

  String get _currentLetter {
    if (_page == null) return '';
    final first = _page!.entries.first.id;
    var current = '';
    for (final letter in _letters.entries) {
      if (letter.value <= first) current = letter.key;
    }
    return current;
  }

  Future<void> _chooseLetter() async {
    final current = _currentLetter;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aller à la lettre', style: textTheme.titleMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final letter in _letters.entries)
                      SizedBox(
                        width: 52,
                        height: 48,
                        child: letter.key == current
                            ? FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(letter.value),
                                child: Text(letter.key),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: () =>
                                    Navigator.of(context).pop(letter.value),
                                child: Text(letter.key),
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null && mounted) _jumpTo(chosen);
  }

  Future<void> _openEntry(BrowseEntry entry) async {
    final full = await _db.getEntry(entry.id);
    if (full == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EntryScreen(entry: full)),
    );
  }

  // ---------------------------------------------------------------------
  // Mise en page : autant d'articles que la page en contient, puis les
  // lignes restantes rendues aux articles coupés.
  // ---------------------------------------------------------------------

  TextSpan _headSpan(BrowseEntry entry, _Styles styles) {
    return TextSpan(
      style: styles.term,
      children: [
        TextSpan(text: entry.terme),
        if (entry.nature != null)
          TextSpan(text: '  ${entry.nature}', style: styles.nature),
      ],
    );
  }

  TextSpan? _bodySpan(BrowseEntry entry, _Styles styles) {
    if (entry.preview.isEmpty) return null;
    return TextSpan(
      style: styles.body,
      children: [
        for (final part in entry.preview)
          TextSpan(
            text: part.text,
            style: part.bold
                ? styles.number
                : part.italic
                    ? styles.citation
                    : null,
          ),
      ],
    );
  }

  _Page _layout(
    List<BrowseEntry> rows,
    bool forward,
    Size size,
    _Styles styles,
    TextScaler scaler,
  ) {
    final width = max(50.0, size.width - 2 * _sidePadding);

    double paragraph(TextSpan span, int maxLines, [List<bool>? exceeded]) {
      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: width);
      exceeded?.add(painter.didExceedMaxLines);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final heads = <int, double>{};
    (double, bool) measure(BrowseEntry entry, int lines) {
      final head = heads.putIfAbsent(
        entry.id,
        () => paragraph(_headSpan(entry, styles), 2),
      );
      final body = _bodySpan(entry, styles);
      if (body == null) return (2 * _tilePadding + head, false);
      final exceeded = <bool>[];
      final height = paragraph(body, lines, exceeded);
      return (2 * _tilePadding + head + _headGap + height, exceeded.first);
    }

    final entries = <BrowseEntry>[];
    final lines = <int>[];
    final heights = <double>[];
    final cut = <bool>[];
    var used = 0.0;

    for (final entry in forward ? rows : rows.reversed) {
      final (height, exceeded) = measure(entry, _baseLines);
      if (entries.isNotEmpty && used + height > size.height) break;
      entries.add(entry);
      lines.add(_baseLines);
      heights.add(height);
      cut.add(exceeded);
      used += height;
    }
    final complete = entries.length == rows.length && rows.length < _fetch;
    if (!forward) {
      _reverse(entries);
      _reverse(lines);
      _reverse(heights);
      _reverse(cut);
    }

    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < entries.length; i++) {
        if (!cut[i] || lines[i] >= _maxLines) continue;
        final (height, exceeded) = measure(entries[i], lines[i] + 1);
        final more = height - heights[i];
        if (used + more > size.height) continue;
        lines[i]++;
        heights[i] = height;
        cut[i] = exceeded;
        used += more;
        changed = true;
      }
    }

    // Le blanc qui reste se répartit entre les articles, sauf en fin de livre.
    var gap = 0.0;
    if (entries.length > 1 && !complete) {
      gap = min(_maxGap, max(0.0, size.height - used) / (entries.length - 1));
    }
    return _Page(entries, lines, gap, complete: complete);
  }

  _Page _pageFor(Size size, _Styles styles, TextScaler scaler) {
    final key = (_rows, _forward, size, scaler, styles.body, styles.term);
    if (_page == null || _pageKey != key) {
      _page = _layout(_rows!, _forward, size, styles, scaler);
      _pageKey = key;
      final page = _page!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _page != page) return;
        // En reculant jusqu'au début du livre, la première page reprend
        // sa forme : elle commence à « A » et se remplit vers l'avant.
        if (!_forward && page.complete && page.entries.first.id == 1) {
          _jumpTo(1);
          return;
        }
        _position.save(page.entries.first.id);
        setState(() {}); // mots-repères et boutons suivent la page
      });
    }
    return _page!;
  }

  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final scaler = MediaQuery.textScalerOf(context);

    final base = textTheme.bodyMedium!.copyWith(
      fontSize: 15,
      height: 1.45,
      color: colorScheme.onSurface,
    );
    final styles = _Styles(
      term: base.copyWith(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.bold,
        color: colorScheme.primary,
      ),
      nature: base.copyWith(
        fontSize: 13,
        height: 1.35,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.normal,
        color: colorScheme.onSurfaceVariant,
      ),
      body: base,
      citation: TextStyle(
        fontStyle: FontStyle.italic,
        color: colorScheme.onSurfaceVariant,
      ),
      number: TextStyle(
        fontWeight: FontWeight.bold,
        color: colorScheme.primary,
      ),
    );

    final page = _page;
    final guide = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
      color: colorScheme.onSurface,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Navigator.of(context).canPop() ? 0 : _sidePadding,
        title: page == null
            ? const Text('Feuilleter')
            : Row(
                children: [
                  Flexible(
                    child: Text(
                      page.entries.first.guideWord,
                      style: guide,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      page.entries.last.guideWord,
                      style: guide,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: _sidePadding),
                ],
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          // Où l'on est dans l'épaisseur du livre.
          child: LinearProgressIndicator(
            value: (page == null || _total == 0)
                ? 0
                : page.entries.first.id / _total,
            minHeight: 3,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _rows == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity < -200) _nextPage();
                      if (velocity > 200) _previousPage();
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return _buildPage(
                          _pageFor(size, styles, scaler),
                          styles,
                          scaler,
                        );
                      },
                    ),
                  ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildControls(colorScheme),
        ],
      ),
    );
  }

  Widget _buildPage(_Page page, _Styles styles, TextScaler scaler) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < page.entries.length; i++) ...[
            if (i > 0 && page.gap > 0) SizedBox(height: page.gap),
            _buildTile(page.entries[i], page.lines[i], styles, scaler),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(
    BrowseEntry entry,
    int lines,
    _Styles styles,
    TextScaler scaler,
  ) {
    final body = _bodySpan(entry, styles);
    return InkWell(
      onTap: () => _openEntry(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _sidePadding,
          vertical: _tilePadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: _headSpan(entry, styles),
              textScaler: scaler,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (body != null) ...[
              const SizedBox(height: _headGap),
              RichText(
                text: body,
                textScaler: scaler,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ColorScheme colorScheme) {
    final letter = _currentLetter;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.chevron_left),
              iconSize: 28,
              tooltip: 'Page précédente',
              onPressed: _hasPrevious ? _previousPage : null,
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: _letters.isEmpty ? null : _chooseLetter,
                      child: Text(
                        letter.isEmpty ? 'Lettre' : 'Lettre $letter',
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Au hasard'),
                      onPressed:
                          _total == 0 ? null : () => _jumpTo(_randomId()),
                    ),
                  ],
                ),
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.chevron_right),
              iconSize: 28,
              tooltip: 'Page suivante',
              onPressed: _hasNext ? _nextPage : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Styles {
  final TextStyle term;
  final TextStyle nature;
  final TextStyle body;
  final TextStyle citation;
  final TextStyle number;

  const _Styles({
    required this.term,
    required this.nature,
    required this.body,
    required this.citation,
    required this.number,
  });
}

/// Une page mise en place : ses articles, le nombre de lignes accordé à
/// chacun et le blanc entre eux.
class _Page {
  final List<BrowseEntry> entries;
  final List<int> lines;
  final double gap;

  /// Vrai si tous les articles demandés à la base tiennent sur la page.
  final bool complete;

  const _Page(this.entries, this.lines, this.gap, {required this.complete});
}
