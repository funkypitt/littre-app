import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../services/database_service.dart';
import '../services/favorites_service.dart';
import '../widgets/entry_body.dart';

class EntryScreen extends StatefulWidget {
  final DictionaryEntry entry;

  const EntryScreen({super.key, required this.entry});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  @override
  void initState() {
    super.initState();
    // Ajouter à l'historique
    context.read<FavoritesService>().addToHistory(widget.entry.id);
  }

  void _navigateToEntry(String terme) async {
    final db = DatabaseService();
    final entry = await db.getEntryByTerm(terme);
    if (entry != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EntryScreen(entry: entry),
        ),
      );
    }
  }

  void _shareEntry() {
    final entry = widget.entry;
    final text = StringBuffer();
    text.writeln(entry.terme);
    if (entry.nature != null) text.writeln(entry.nature);
    text.writeln();
    text.writeln(entry.corps.replaceAll(RegExp(r'<[^>]*>'), ''));
    if (entry.etymologie != null) {
      text.writeln();
      text.writeln('Étymologie :');
      text.writeln(entry.etymologie!.replaceAll(RegExp(r'<[^>]*>'), ''));
    }
    Clipboard.setData(ClipboardData(text: text.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article copié dans le presse-papiers')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final favService = context.watch<FavoritesService>();
    final isFav = favService.isFavorite(entry.id);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_outline),
            color: isFav ? Colors.amber : null,
            onPressed: () => favService.toggleFavorite(entry.id),
            tooltip: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _shareEntry,
            tooltip: 'Copier l\'article',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : terme
            Text(
              entry.terme,
              style: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),

            const SizedBox(height: 4),

            // Nature grammaticale et prononciation
            Row(
              children: [
                if (entry.nature != null)
                  Text(
                    entry.nature!.replaceAll(RegExp(r'<[^>]*>'), ''),
                    style: textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (entry.nature != null && entry.prononciation != null)
                  const SizedBox(width: 12),
                if (entry.prononciation != null)
                  Text(
                    '[${entry.prononciation}]',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Corps de l'article
            EntryBody(
              html: entry.corps,
              onLinkTap: _navigateToEntry,
            ),

            // Étymologie
            if (entry.etymologie != null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ÉTYMOLOGIE',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EntryBody(
                      html: entry.etymologie!,
                      onLinkTap: _navigateToEntry,
                    ),
                  ],
                ),
              ),
            ],

            // Supplément
            if (entry.supplement != null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUPPLÉMENT (1878)',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.tertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EntryBody(
                      html: entry.supplement!,
                      onLinkTap: _navigateToEntry,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
