import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/entry.dart';
import '../services/database_service.dart';
import '../screens/entry_screen.dart';

/// Affiche le mot du jour sur l'écran d'accueil.
class WordOfTheDay extends StatefulWidget {
  const WordOfTheDay({super.key});

  @override
  State<WordOfTheDay> createState() => _WordOfTheDayState();
}

class _WordOfTheDayState extends State<WordOfTheDay> {
  DictionaryEntry? _entry;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWordOfTheDay();
  }

  Future<void> _loadWordOfTheDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString('wotd_date');
    final savedId = prefs.getInt('wotd_id');

    final db = DatabaseService();

    DictionaryEntry? entry;
    if (savedDate == today && savedId != null) {
      entry = await db.getEntry(savedId);
    }

    if (entry == null) {
      entry = await db.getRandomEntry();
      if (entry != null) {
        await prefs.setString('wotd_date', today);
        await prefs.setInt('wotd_id', entry.id);
      }
    }

    if (mounted) {
      setState(() {
        _entry = entry;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final entry = _entry;
    if (entry == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.auto_stories,
            size: 48,
            color: colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'Mot du jour',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EntryScreen(entry: entry),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      entry.terme,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (entry.nature != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.nature!.replaceAll(RegExp(r'<[^>]*>'), ''),
                        style: textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      entry.preview,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Appuyez pour lire l\'article complet',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
