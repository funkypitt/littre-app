// Règles communes à la recherche par mot et aux renvois : comment un mot
// tapé ou visé par un renvoi est rapproché des mots-vedettes de la base.

const _diacritics = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
const _replacements = 'aaaaaaceeeeiiiinooooouuuuyy';

/// Forme normalisée : minuscules, sans diacritiques, œ → oe, æ → ae.
///
/// La colonne terme_normalise de la base (tools/convert_littre.py) suit la
/// même règle, sauf qu'elle garde œ et æ : les requêtes lui appliquent
/// [foldedColumn] pour comparer deux formes identiques.
String normalizeTerm(String input) {
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().trim().split('')) {
    final i = _diacritics.indexOf(char);
    if (i >= 0) {
      buffer.write(_replacements[i]);
    } else if (char == 'œ') {
      buffer.write('oe');
    } else if (char == 'æ') {
      buffer.write('ae');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Expression SQL qui amène terme_normalise à la forme de [normalizeTerm].
const foldedColumn = "replace(replace(terme_normalise, 'œ', 'oe'), 'æ', 'ae')";

/// Un renvoi tel qu'il est écrit dans les articles : « retombée »,
/// « avoir.1 » (premier homographe), « point.1#var3 » (ancre ignorée).
class Reference {
  final String word;
  final int? number;

  const Reference(this.word, this.number);
}

/// Le mot visé par un lien « littre://… » d'un article. Les liens de la base
/// portent les lettres accentuées telles quelles (« littre://retombée »), ce
/// que `Uri.decodeFull` refuse : le texte est alors pris comme il est.
String referenceOfLink(String url) {
  final target = url.replaceFirst('littre://', '');
  try {
    return Uri.decodeFull(target);
  } on ArgumentError {
    return target;
  }
}

Reference parseReference(String ref) {
  final target = ref.split('#').first.trim();
  final match = RegExp(r'^(.+)\.(\d+)$').firstMatch(target);
  if (match == null) return Reference(target, null);
  return Reference(match.group(1)!.trim(), int.parse(match.group(2)!));
}

/// Les formes d'un mot-vedette, en minuscules, la première d'abord :
/// « ABONDANT, ANTE » → abondant ; « ABAT ou ABAS » → abat, abas ;
/// « ABSENTER (S') » → absenter ; « JUSQUE et JUSQUES » → jusque, jusques.
/// Les liaisons (ou, et, « à la française »…) sont en minuscules dans la base.
List<String> headwordForms(String terme) {
  final forms = <String>[];
  final bare = terme.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  for (final alternative in bare.split(RegExp(r' (?:ou|et)(?= |,|$)'))) {
    final words = alternative
        .split(',')
        .first
        .split(' ')
        .where((w) => w.isNotEmpty)
        .skipWhile((w) => w != w.toUpperCase());
    if (words.isNotEmpty) forms.add(words.join(' ').toLowerCase());
  }
  return forms;
}

/// Choisit, parmi des mots-vedettes rangés dans l'ordre du dictionnaire,
/// celui que vise le renvoi ; rend son rang, ou null si aucun ne convient.
///
/// Sans numéro : le mot-vedette identique, sinon celui dont la première
/// forme est le mot, accents compris puis accents ignorés, sinon celui qui
/// l'a pour variante. Avec un numéro : le n-ième des mots-vedettes dont la
/// première forme est le mot, le dernier si le numéro va trop loin (la base
/// ne garde pas les numéros d'homographe, qui sautent parfois un rang).
int? resolveReference(String ref, List<String> headwords) {
  final reference = parseReference(ref);
  final word = reference.word.toLowerCase();
  final normalized = normalizeTerm(word);
  if (normalized.isEmpty) return null;

  final whole = <int>[];
  final first = <int>[];
  final firstNormalized = <int>[];
  final variant = <int>[];
  for (var i = 0; i < headwords.length; i++) {
    final forms = headwordForms(headwords[i]);
    if (headwords[i].toLowerCase() == word) whole.add(i);
    if (forms.isEmpty) continue;
    if (forms.first == word) first.add(i);
    if (normalizeTerm(forms.first) == normalized) firstNormalized.add(i);
    if (forms.any((f) => normalizeTerm(f) == normalized)) variant.add(i);
  }

  final number = reference.number;
  if (number != null) {
    for (final tier in [first, firstNormalized, variant, whole]) {
      if (tier.isEmpty) continue;
      return tier[number.clamp(1, tier.length) - 1];
    }
    return null;
  }
  for (final tier in [whole, first, firstNormalized, variant]) {
    if (tier.isNotEmpty) return tier[0];
  }
  return null;
}
