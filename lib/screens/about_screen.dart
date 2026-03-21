import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Logo / icône
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.menu_book,
                size: 48,
                color: colorScheme.primary,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Littré',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),
            Text(
              'Dictionnaire de la langue française',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // Crédits
            _CreditCard(
              title: 'Données lexicographiques',
              children: [
                const Text(
                  '« Le Littré » par François Gannaz — littre.org',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Licence Creative Commons BY-SA 3.0',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            const SizedBox(height: 12),

            _CreditCard(
              title: 'Texte original',
              children: [
                const Text(
                  'Émile Littré',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'Dictionnaire de la langue française\n'
                  'Paris, Hachette, 1873–1874',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Domaine public',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _CreditCard(
              title: 'Application',
              children: [
                const Text(
                  'Application Android réalisée avec Flutter.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  '78 599 entrées — consultation hors ligne',
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _CreditCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
