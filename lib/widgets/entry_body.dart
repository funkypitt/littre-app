import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Rendu riche d'un article du Littré (HTML → widgets Flutter).
class EntryBody extends StatelessWidget {
  final String html;
  final void Function(String terme)? onLinkTap;

  const EntryBody({
    super.key,
    required this.html,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Couleurs adaptées au mode sombre
    final citationColor = isDark
        ? const Color(0xFFD7CCC8) // brun clair
        : const Color(0xFF5D4037); // brun foncé
    final auteurColor = isDark
        ? const Color(0xFFBCAAA4)
        : const Color(0xFF795548);
    final numColor = colorScheme.primary;

    return Html(
      data: html,
      style: {
        "body": Style(
          fontSize: FontSize(15),
          lineHeight: const LineHeight(1.6),
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        ".sens": Style(
          margin: Margins.only(bottom: 12),
        ),
        ".num-sens": Style(
          fontWeight: FontWeight.bold,
          fontSize: FontSize(16),
          color: numColor,
        ),
        ".citation": Style(
          fontStyle: FontStyle.italic,
          color: citationColor,
        ),
        ".auteur": Style(
          fontSize: FontSize(13),
          color: auteurColor,
          fontWeight: FontWeight.w600,
        ),
        ".indent": Style(
          margin: Margins.only(left: 12, bottom: 8),
        ),
        ".rubrique": Style(
          margin: Margins.only(top: 16),
        ),
        ".historique": Style(
          margin: Margins.only(top: 16),
        ),
        "h4": Style(
          fontWeight: FontWeight.bold,
          fontSize: FontSize(14),
          color: colorScheme.primary,
          letterSpacing: 1.0,
          margin: Margins.only(bottom: 8),
        ),
        "i": Style(
          fontStyle: FontStyle.italic,
        ),
        "b": Style(
          fontWeight: FontWeight.bold,
        ),
        "a": Style(
          color: colorScheme.primary,
          textDecoration: TextDecoration.underline,
        ),
      },
      onLinkTap: (url, attributes, element) {
        if (url != null && url.startsWith('littre://') && onLinkTap != null) {
          final terme = Uri.decodeFull(url.replaceFirst('littre://', ''));
          onLinkTap!(terme);
        }
      },
    );
  }
}
