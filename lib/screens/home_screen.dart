import 'dart:async';
import 'package:flutter/material.dart';
import '../models/entry.dart';
import '../services/database_service.dart';
import '../widgets/entry_card.dart';
import '../widgets/word_of_the_day.dart';
import 'entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _dbService = DatabaseService();
  List<DictionaryEntry> _results = [];
  bool _isLoading = false;
  bool _isFullText = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final results = _isFullText
          ? await _dbService.searchFullText(query)
          : await _dbService.searchByPrefix(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openEntry(DictionaryEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EntryScreen(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Littré'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Rechercher un mot…',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search),
              ),
              trailing: [
                if (hasQuery)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
                IconButton(
                  icon: Icon(
                    _isFullText ? Icons.menu_book : Icons.sort_by_alpha,
                    color: _isFullText ? colorScheme.primary : null,
                  ),
                  tooltip: _isFullText
                      ? 'Recherche dans les définitions'
                      : 'Recherche par mot',
                  onPressed: () {
                    setState(() => _isFullText = !_isFullText);
                    if (hasQuery) {
                      _performSearch(_searchController.text);
                    }
                  },
                ),
              ],
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: _buildBody(hasQuery),
    );
  }

  Widget _buildBody(bool hasQuery) {
    if (!hasQuery) {
      return const WordOfTheDay();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final entry = _results[index];
        return EntryCard(
          entry: entry,
          onTap: () => _openEntry(entry),
        );
      },
    );
  }
}
