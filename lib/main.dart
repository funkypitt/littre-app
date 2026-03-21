import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'services/favorites_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final favoritesService = FavoritesService();
  await favoritesService.init();

  runApp(
    ChangeNotifierProvider.value(
      value: favoritesService,
      child: const LittreApp(),
    ),
  );
}
