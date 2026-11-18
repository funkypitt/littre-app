// Parcourt l'application comme un lecteur : recherche, article, feuilletage.
// À chaque scène, la ligne « SHOT:<nom> » dit au script qui lance le test
// (codemagic.yaml, ios-screenshots) de prendre une capture de l'écran.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:littre_app/main.dart' as app;

Future<void> wait(WidgetTester tester, [int seconds = 2]) async {
  for (var i = 0; i < seconds * 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  await wait(tester, 2);
  // ignore: avoid_print
  print('SHOT:$name');
  await wait(tester, 6);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recherche, article, feuilletage', (tester) async {
    app.main();
    // Première ouverture : la base est copiée dans le stockage de l'app.
    for (var i = 0; i < 60 && find.text('Feuilleter').evaluate().isEmpty; i++) {
      await wait(tester, 1);
    }
    await wait(tester, 8);
    await shot(tester, '01-mot-du-jour');

    await tester.enterText(find.byType(SearchBar), 'flâne');
    await wait(tester, 3);
    expect(find.text('FLÂNER'), findsWidgets);
    FocusManager.instance.primaryFocus?.unfocus();
    await shot(tester, '02-recherche');

    await tester.tap(find.text('FLÂNER').first);
    await wait(tester, 3);
    expect(find.byTooltip("Feuilleter à partir d'ici"), findsOneWidget);
    await shot(tester, '03-article');

    await tester.tap(find.byTooltip("Feuilleter à partir d'ici"));
    await wait(tester, 3);
    expect(find.text('Au hasard'), findsOneWidget);
    expect(find.text('Lettre F'), findsOneWidget);
    expect(find.textContaining('FLÂNER', findRichText: true), findsWidgets);
    await shot(tester, '04-feuilleter');

    await tester.tap(find.byTooltip('Page suivante'));
    await wait(tester, 2);
    expect(find.text('Lettre F'), findsOneWidget);
    await tester.tap(find.byTooltip('Page précédente'));
    await wait(tester, 2);

    await tester.tap(find.text('Lettre F'));
    await wait(tester, 2);
    expect(find.text('Aller à la lettre'), findsOneWidget);
    await shot(tester, '05-lettres');

    await tester.tap(find.text('M'));
    await wait(tester, 3);
    expect(find.text('Lettre M'), findsOneWidget);
  });
}
