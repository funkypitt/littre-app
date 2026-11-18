import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La page où le lecteur s'est arrêté en feuilletant : le numéro du premier
/// article de la page. Gardée d'une ouverture à l'autre, comme un marque-page.
class BrowsePosition {
  static final BrowsePosition _instance = BrowsePosition._internal();
  factory BrowsePosition() => _instance;
  BrowsePosition._internal();

  static const _key = 'browse_first_id';

  /// Premier article de la page affichée ; null tant que rien n'a été ouvert.
  final ValueNotifier<int?> first = ValueNotifier<int?>(null);

  bool _loaded = false;

  Future<int?> load() async {
    if (!_loaded) {
      final prefs = await SharedPreferences.getInstance();
      first.value ??= prefs.getInt(_key);
      _loaded = true;
    }
    return first.value;
  }

  Future<void> save(int id) async {
    if (first.value == id) return;
    first.value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, id);
  }
}
