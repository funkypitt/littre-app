import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../services/database_service.dart';
import '../services/favorites_service.dart';
import '../widgets/entry_card.dart';
import 'entry_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoris'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.star), text: 'Favoris'),
            Tab(icon: Icon(Icons.history), text: 'Historique'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FavoritesTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    final favService = context.watch<FavoritesService>();
    final ids = favService.favoriteIds.toList();

    if (ids.isEmpty) {
      return const _EmptyState(
        icon: Icons.star_outline,
        message: 'Aucun favori pour le moment',
        subtitle: 'Appuyez sur l\'étoile dans un article\npour l\'ajouter ici.',
      );
    }

    return _EntryList(ids: ids);
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final favService = context.watch<FavoritesService>();
    final ids = favService.historyIds;

    if (ids.isEmpty) {
      return const _EmptyState(
        icon: Icons.history,
        message: 'Aucun historique',
        subtitle: 'Les articles consultés\napparaîtront ici.',
      );
    }

    return Column(
      children: [
        Expanded(child: _EntryList(ids: ids)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Effacer l\'historique'),
            onPressed: () => favService.clearHistory(),
          ),
        ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  final List<int> ids;
  const _EntryList({required this.ids});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: ids.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        return FutureBuilder<DictionaryEntry?>(
          future: DatabaseService().getEntry(ids[index]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final entry = snapshot.data;
            if (entry == null) return const SizedBox.shrink();
            return EntryCard(
              entry: entry,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EntryScreen(entry: entry),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
