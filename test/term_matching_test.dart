import 'package:flutter_test/flutter_test.dart';
import 'package:littre_app/services/term_matching.dart';

void main() {
  group('normalizeTerm', () {
    test('œ et æ deviennent oe et ae, quelle que soit la casse', () {
      for (final typed in ['coeur', 'cœur', 'COEUR', 'Cœur', 'CŒUR']) {
        expect(normalizeTerm(typed), 'coeur', reason: typed);
      }
      for (final typed in ['aegagre', 'ægagre', 'AEGAGRE', 'Ægagre', 'ÆGAGRE']) {
        expect(normalizeTerm(typed), 'aegagre', reason: typed);
      }
      expect(normalizeTerm('ŒIL'), 'oeil');
      expect(normalizeTerm('bœuf'), 'boeuf');
      expect(normalizeTerm('CHŒUR'), 'choeur');
    });

    test('chaque lettre accentuée donne sa lettre nue', () {
      expect(normalizeTerm('àâäéèêëïîôöùûüÿç'), 'aaaeeeeiioouuuyc');
      expect(normalizeTerm('ÀÂÄÉÈÊËÏÎÔÖÙÛÜÇ'), 'aaaeeeeiioouuuc');
      expect(normalizeTerm('Être'), 'etre');
      expect(normalizeTerm('ABÎMÉ, ÉE'), 'abime, ee');
      expect(normalizeTerm('  Noël '), 'noel');
    });

    test('une lettre sans accent ne bouge pas', () {
      expect(normalizeTerm('maison'), 'maison');
      expect(normalizeTerm("battant-l'œil"), "battant-l'oeil");
      expect(normalizeTerm(''), '');
    });
  });

  group('referenceOfLink', () {
    test('garde les lettres accentuées écrites telles quelles', () {
      expect(referenceOfLink('littre://retombée'), 'retombée');
      expect(referenceOfLink('littre://abbé'), 'abbé');
      expect(referenceOfLink('littre://cœur'), 'cœur');
    });
    test('décode un lien encodé', () {
      expect(referenceOfLink('littre://retomb%C3%A9e'), 'retombée');
      expect(referenceOfLink('littre://avoir.1'), 'avoir.1');
    });
  });

  group('parseReference', () {
    test('mot seul', () {
      final r = parseReference('retombée');
      expect(r.word, 'retombée');
      expect(r.number, isNull);
    });

    test('numéro d\'homographe', () {
      final r = parseReference('avoir.1');
      expect(r.word, 'avoir');
      expect(r.number, 1);
      expect(parseReference("épouffer (s').2").word, "épouffer (s')");
    });

    test('ancre ignorée', () {
      final r = parseReference('point.1#var3');
      expect(r.word, 'point');
      expect(r.number, 1);
      expect(parseReference('zéro#var2').word, 'zéro');
      expect(parseReference('châlit#etymologie').number, isNull);
    });
  });

  group('headwordForms', () {
    test('terminaisons, variantes, parenthèses', () {
      expect(headwordForms('MAISON'), ['maison']);
      expect(headwordForms('ABONDANT, ANTE'), ['abondant']);
      expect(headwordForms('ABAT ou ABAS'), ['abat', 'abas']);
      expect(headwordForms('ABECQUÉ ou ABÉQUÉ, ÉE'), ['abecqué', 'abéqué']);
      expect(headwordForms("ABSENTER (S')"), ['absenter']);
      expect(headwordForms('ABRUPTO (EX)'), ['abrupto']);
      expect(headwordForms('JUSQUE et JUSQUES'), ['jusque', 'jusques']);
      expect(headwordForms('AB HOC ET AB HÂC'), ['ab hoc et ab hâc']);
    });

    test('liaisons en minuscules', () {
      expect(
        headwordForms('IMBROGLIO ou, à la française, IMBROILLE'),
        ['imbroglio'],
      );
      expect(
        headwordForms('AMBROISIE et quelquefois AMBROSIE'),
        ['ambroisie', 'ambrosie'],
      );
      expect(headwordForms('TAENIA et ses composés'), ['taenia']);
    });
  });

  group('resolveReference', () {
    test('mot avec accent', () {
      expect(resolveReference('retombée', ['RETOMBÉE']), 0);
      expect(resolveReference('abbé', ['ABBÉ']), 0);
      expect(resolveReference('cœur', ['CŒUR']), 0);
      expect(resolveReference('coeur', ['CŒUR']), 0);
    });

    test('l\'accent du renvoi départage deux mots-vedettes', () {
      const headwords = ['ACRE', 'ÂCRE'];
      expect(resolveReference('acre', headwords), 0);
      expect(resolveReference('âcre', headwords), 1);
      expect(resolveReference('côte', ['COTE', 'CÔTE', 'CÔTÉ']), 1);
    });

    test('mot-vedette avec terminaison ou variante', () {
      expect(resolveReference('abondant', ['ABONDANT, ANTE']), 0);
      expect(resolveReference('abat', ['ABAT ou ABAS']), 0);
      expect(resolveReference('abas', ['ABAS', 'ABAT ou ABAS']), 0);
      expect(resolveReference('abas', ['ABAT ou ABAS']), 0);
      expect(resolveReference('absenter', ["ABSENTER (S')"]), 0);
      // La terminaison seule n'est pas une forme du mot.
      expect(resolveReference('ante', ['ABONDANT, ANTE']), isNull);
    });

    test('le mot-vedette identique passe avant celui à terminaison', () {
      expect(resolveReference('agréé', ['AGRÉÉ, ÉE', 'AGRÉÉ']), 1);
    });

    test('le numéro choisit l\'homographe', () {
      const avoir = ['AVOIR', 'AVOIR'];
      expect(resolveReference('avoir.1', avoir), 0);
      expect(resolveReference('avoir.2', avoir), 1);
      expect(resolveReference('avoir', avoir), 0);
      // La numérotation court sur les mots-vedettes de même première forme.
      const agree = ['AGRÉÉ, ÉE', 'AGRÉÉ', 'AGRÉÉ, ÉE'];
      expect(resolveReference('agréé.1', agree), 0);
      expect(resolveReference('agréé.2', agree), 1);
      expect(resolveReference('agréé.3', agree), 2);
      expect(resolveReference('poêle.3', ['POÈLE', 'POÊLE ou POILE', 'POÊLE']), 2);
      expect(resolveReference('point.1#var3', ['POINT', 'POINT']), 0);
    });

    test('le numéro compte les mots-vedettes de même accentuation', () {
      const de = ['DE', 'DÉ', 'DÉ'];
      expect(resolveReference('dé.1', de), 1);
      expect(resolveReference('dé.2', de), 2);
      expect(resolveReference('de.1', de), 0);
      // Renvoi écrit sans accent : les accents sont ignorés.
      expect(resolveReference('tache.2', ['TÂCHE', 'TÂCHE']), 1);
    });

    test('numéro trop grand : le dernier homographe', () {
      expect(resolveReference('forme.4', ['FORME']), 0);
      expect(resolveReference('fier.3', ['FIER', 'FIER, IÈRE']), 1);
    });

    test('rien ne convient', () {
      expect(resolveReference('retombée', []), isNull);
      expect(resolveReference('abat', ['ABATAGE', 'ABATANT']), isNull);
      expect(resolveReference('', ['A']), isNull);
      expect(resolveReference('#var2', ['A']), isNull);
    });
  });
}
