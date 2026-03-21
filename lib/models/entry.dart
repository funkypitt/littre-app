/// Modèle représentant une entrée du dictionnaire Littré.
class DictionaryEntry {
  final int id;
  final String terme;
  final String termeNormalise;
  final String? prononciation;
  final String? nature;
  final String corps;
  final String? etymologie;
  final String? supplement;

  DictionaryEntry({
    required this.id,
    required this.terme,
    required this.termeNormalise,
    this.prononciation,
    this.nature,
    required this.corps,
    this.etymologie,
    this.supplement,
  });

  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      id: map['id'] as int,
      terme: map['terme'] as String,
      termeNormalise: map['terme_normalise'] as String,
      prononciation: map['prononciation'] as String?,
      nature: map['nature'] as String?,
      corps: map['corps'] as String,
      etymologie: map['etymologie'] as String?,
      supplement: map['supplement'] as String?,
    );
  }

  /// Aperçu court : première phrase du corps, texte brut.
  String get preview {
    final stripped = corps
        .replaceAll(RegExp(r'<[^>]*>'), '') // supprimer HTML
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.length <= 120) return stripped;
    return '${stripped.substring(0, 120)}…';
  }
}
