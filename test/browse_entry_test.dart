import 'package:flutter_test/flutter_test.dart';
import 'package:littre_app/models/browse_entry.dart';

String plain(List<PreviewPart> parts) => parts.map((p) => p.text).join();

void main() {
  test('un article court est rendu en entier, sans points de suspension', () {
    final parts = previewOf(
      '\n<div class="sens">Qui exalte. Des passions exaltantes.\n</div>\n',
      complete: true,
    );
    expect(plain(parts), 'Qui exalte. Des passions exaltantes.');
  });

  test('citations en italique, numéros de sens en gras', () {
    final parts = previewOf(
      '<div class="sens"><span class="num-sens">1.</span> Au propre. \n'
      '<span class="citation">Tiens cette vue abaissée</span> '
      '<span class="auteur">[ROTROU, Bél. I, 6]</span>\n</div>',
      complete: true,
    );
    expect(plain(parts),
        '1. Au propre. Tiens cette vue abaissée [ROTROU, Bél. I, 6]');
    expect(parts.first.bold, isTrue);
    expect(parts.firstWhere((p) => p.text.startsWith('Tiens')).italic, isTrue);
    expect(parts.last.italic, isFalse);
  });

  test('un article coupé finit par des points de suspension', () {
    final parts = previewOf(
      '<div class="sens">Action de mettre bas. <span class="cita',
      complete: false,
    );
    expect(plain(parts), 'Action de mettre bas. …');
  });

  test("l'historique reste hors de l'aperçu", () {
    final parts = previewOf(
      '<div class="sens">Brise du matin.</div>'
      '<div class="historique"><h4>HISTORIQUE</h4>XIIe s.</div>',
      complete: true,
    );
    expect(plain(parts), 'Brise du matin. …');
  });

  test("pas d'espaces en double entre les sens", () {
    final parts = previewOf(
      '<div class="sens">Serpent.\n<p class="indent">On dit aussi guivre.\n</p>\n</div>\n'
      '<div class="sens"><span class="num-sens">2.</span> Autre sens.</div>',
      complete: true,
    );
    expect(plain(parts), 'Serpent. On dit aussi guivre. 2. Autre sens.');
  });

  test('mot-repère', () {
    const e = BrowseEntry(id: 1, terme: 'ABAISSÉ, ÉE', nature: null, preview: []);
    expect(e.guideWord, 'ABAISSÉ');
  });
}
