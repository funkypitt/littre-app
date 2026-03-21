import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion des favoris et de l'historique.
class FavoritesService extends ChangeNotifier {
  static const _favoritesKey = 'favorites';
  static const _historyKey = 'history';
  static const _maxHistory = 100;

  Set<int> _favoriteIds = {};
  List<int> _historyIds = [];
  SharedPreferences? _prefs;

  Set<int> get favoriteIds => _favoriteIds;
  List<int> get historyIds => _historyIds;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFavorites();
    _loadHistory();
  }

  void _loadFavorites() {
    final data = _prefs?.getStringList(_favoritesKey) ?? [];
    _favoriteIds = data.map((s) => int.parse(s)).toSet();
  }

  void _loadHistory() {
    final data = _prefs?.getStringList(_historyKey) ?? [];
    _historyIds = data.map((s) => int.parse(s)).toList();
  }

  bool isFavorite(int id) => _favoriteIds.contains(id);

  Future<void> toggleFavorite(int id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    await _prefs?.setStringList(
      _favoritesKey,
      _favoriteIds.map((i) => i.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> addToHistory(int id) async {
    _historyIds.remove(id); // Supprimer si déjà présent
    _historyIds.insert(0, id); // Ajouter en tête
    if (_historyIds.length > _maxHistory) {
      _historyIds = _historyIds.sublist(0, _maxHistory);
    }
    await _prefs?.setStringList(
      _historyKey,
      _historyIds.map((i) => i.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _historyIds.clear();
    await _prefs?.setStringList(_historyKey, []);
    notifyListeners();
  }
}
