# Littré — Dictionnaire de la langue française

Application Android offline du dictionnaire d'Émile Littré, basée sur les données XML libres de François Gannaz ([xmlittre](https://bitbucket.org/Mytskine/xmlittre-data)).

## Fonctionnalités

- **78 599 entrées** du dictionnaire Littré, consultables hors ligne
- Recherche par préfixe (autocomplete instantané)
- Recherche plein texte dans les définitions (FTS5)
- Mot du jour
- Favoris et historique de consultation
- Renvois croisés cliquables entre articles
- Mode sombre automatique
- Typographie soignée (Merriweather)

## Construction

### 1. Préparer la base de données

```bash
# Cloner les données XML
cd tools/
git clone https://bitbucket.org/Mytskine/xmlittre-data.git

# Convertir en SQLite
python3 convert_littre.py xmlittre-data -o ../assets/littre.db
```

### 2. Compiler l'application

```bash
flutter pub get
flutter build apk
```

## Architecture

```
lib/
├── main.dart                 # Point d'entrée
├── app.dart                  # MaterialApp, thème, navigation
├── models/
│   └── entry.dart            # Modèle DictionaryEntry
├── services/
│   ├── database_service.dart # Accès SQLite (singleton)
│   └── favorites_service.dart # Favoris + historique
├── screens/
│   ├── home_screen.dart      # Recherche + résultats
│   ├── entry_screen.dart     # Affichage d'un article
│   ├── favorites_screen.dart # Favoris + historique
│   └── about_screen.dart     # Crédits
└── widgets/
    ├── entry_card.dart       # Aperçu dans les listes
    ├── entry_body.dart       # Rendu HTML des définitions
    └── word_of_the_day.dart  # Mot du jour
```

## Crédits

- **Données lexicographiques** : « Le Littré » par François Gannaz — [littre.org](https://www.littre.org) — Licence CC BY-SA 3.0
- **Texte original** : Émile Littré, *Dictionnaire de la langue française*, Paris, Hachette, 1873–1874 (domaine public)
