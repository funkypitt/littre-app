/// Un morceau du début d'un article, avec sa mise en forme.
class PreviewPart {
  final String text;
  final bool italic;
  final bool bold;

  const PreviewPart(this.text, {this.italic = false, this.bold = false});
}

/// Un article tel qu'il paraît sur une page que l'on feuillette : le mot,
/// sa nature et le début de sa définition.
class BrowseEntry {
  final int id;
  final String terme;
  final String? nature;
  final List<PreviewPart> preview;

  const BrowseEntry({
    required this.id,
    required this.terme,
    required this.nature,
    required this.preview,
  });

  /// [debut] est le début du corps de l'article (HTML), [longueur] la
  /// longueur du corps entier.
  factory BrowseEntry.fromMap(Map<String, dynamic> map) {
    final debut = (map['debut'] as String?) ?? '';
    final longueur = (map['longueur'] as int?) ?? debut.length;
    final nature = (map['nature'] as String?)
        ?.replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
    return BrowseEntry(
      id: map['id'] as int,
      terme: map['terme'] as String,
      nature: (nature == null || nature.isEmpty) ? null : nature,
      preview: previewOf(debut, complete: longueur <= debut.length),
    );
  }

  /// Le mot seul, pour les mots-repères du haut de page :
  /// « ABAISSÉ, ÉE » → « ABAISSÉ ».
  String get guideWord => terme.split(RegExp(r',| ou | et ')).first.trim();
}

const _maxPreviewLength = 1200;

/// Le début d'un article en texte mis en forme : citations en italique,
/// numéros de sens en gras. [complete] dit si [html] est l'article entier.
List<PreviewPart> previewOf(String html, {required bool complete}) {
  var source = html;
  var cut = !complete;

  // L'historique et les rubriques ne font pas partie de l'aperçu.
  for (final marker in ['<div class="historique"', '<div class="rubrique"']) {
    final at = source.indexOf(marker);
    if (at >= 0) {
      source = source.substring(0, at);
      cut = true;
    }
  }
  // Une balise coupée en deux par la troncature.
  final open = source.lastIndexOf('<');
  if (open >= 0 && source.indexOf('>', open) < 0) {
    source = source.substring(0, open);
  }

  final parts = <PreviewPart>[];
  final buffer = StringBuffer();
  var italic = false;
  var bold = false;
  var length = 0;
  final spans = <String>[];
  var endsWithSpace = true;

  void flush() {
    if (buffer.isEmpty) return;
    parts.add(PreviewPart(buffer.toString(), italic: italic, bold: bold));
    buffer.clear();
  }

  void addText(String raw) {
    final text = raw
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
    // Jamais deux espaces de suite, même de part et d'autre d'une balise.
    final kept = endsWithSpace ? text.replaceFirst(RegExp(r'^ '), '') : text;
    if (kept.isEmpty) return;
    endsWithSpace = kept.endsWith(' ');
    buffer.write(kept);
    length += kept.length;
  }

  final tag = RegExp(r'<(/?)([a-zA-Z0-9]+)([^>]*)>');
  var position = 0;
  for (final match in tag.allMatches(source)) {
    if (length >= _maxPreviewLength) break;
    addText(source.substring(position, match.start));
    position = match.end;

    final closing = match.group(1) == '/';
    final name = match.group(2)!.toLowerCase();
    final attributes = match.group(3)!;

    if (name == 'span') {
      flush();
      if (closing) {
        final kind = spans.isEmpty ? '' : spans.removeLast();
        if (kind == 'citation') italic = false;
        if (kind == 'num-sens') bold = false;
      } else {
        final kind = attributes.contains('citation')
            ? 'citation'
            : attributes.contains('num-sens')
                ? 'num-sens'
                : '';
        spans.add(kind);
        if (kind == 'citation') italic = true;
        if (kind == 'num-sens') bold = true;
      }
    } else if (name == 'i') {
      flush();
      italic = !closing || spans.contains('citation');
    } else if (name == 'div' || name == 'p' || name == 'br') {
      addText(' ');
    }
  }
  if (length < _maxPreviewLength) {
    addText(source.substring(position));
  } else {
    cut = true;
  }
  flush();

  final cleaned = [...parts];
  if (cleaned.isNotEmpty) {
    final last = cleaned.removeLast();
    final text = last.text.trimRight();
    if (text.isNotEmpty) {
      cleaned.add(PreviewPart(
        cut ? '$text …' : text,
        italic: cut ? false : last.italic,
        bold: last.bold,
      ));
    }
  }
  return cleaned;
}
