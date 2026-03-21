#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
convert_littre.py — Conversion des données XMLittré en base SQLite

Lit les fichiers XML du projet XMLittré
(https://bitbucket.org/Mytskine/xmlittre-data) et produit une base
SQLite avec index plein texte (FTS5).

Usage :
    python convert_littre.py [chemin_vers_xmlittre-data] [-o littre.db]

Structure réelle des fichiers XML :

    <entree terme="MOT" sens="1">
      <entete>
        <prononciation>...</prononciation>
        <nature>...</nature>
      </entete>
      <corps>
        <variante num="1">... <cit aut="X" ref="Y">texte</cit> ...</variante>
        ...
      </corps>
      <rubrique nom="HISTORIQUE">...</rubrique>
      <rubrique nom="ÉTYMOLOGIE">...</rubrique>
      <rubrique nom="SUPPLÉMENT AU DICTIONNAIRE">...</rubrique>
    </entree>
"""

import argparse
import os
import re
import sqlite3
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path


# ---------------------------------------------------------------------------
# Utilitaires
# ---------------------------------------------------------------------------

def normaliser_terme(terme: str) -> str:
    """Forme normalisée : minuscules, sans diacritiques."""
    terme = terme.lower()
    terme_nfd = unicodedata.normalize("NFD", terme)
    return "".join(c for c in terme_nfd if unicodedata.category(c) != "Mn")


def inner_xml(element: ET.Element) -> str:
    """Extrait le contenu intérieur (inner XML) d'un élément."""
    parties = []
    if element.text:
        parties.append(element.text)
    for enfant in element:
        parties.append(ET.tostring(enfant, encoding="unicode", method="html"))
    return "".join(parties).strip()


def xml_to_html(element: ET.Element) -> str:
    """
    Convertit un élément XML du Littré en HTML propre pour l'affichage.
    Transforme les balises spécifiques XMLittré en HTML sémantique.
    """
    if element is None:
        return ""

    parties = []
    if element.text:
        parties.append(element.text)

    for enfant in element:
        tag = enfant.tag

        if tag == "variante":
            num = enfant.get("num", "")
            contenu = xml_to_html(enfant)
            if num:
                parties.append(
                    f'<div class="sens"><span class="num-sens">{num}.</span> '
                    f'{contenu}</div>'
                )
            else:
                parties.append(f'<div class="sens">{contenu}</div>')

        elif tag == "cit":
            auteur = enfant.get("aut", "")
            ref = enfant.get("ref", "")
            texte_cit = xml_to_html(enfant)
            attr_auteur = f"{auteur}" if auteur else ""
            attr_ref = f", {ref}" if ref else ""
            source = f"{attr_auteur}{attr_ref}".strip(", ")
            if source:
                parties.append(
                    f'<span class="citation">{texte_cit}</span>'
                    f' <span class="auteur">[{source}]</span>'
                )
            else:
                parties.append(f'<span class="citation">{texte_cit}</span>')

        elif tag == "indent":
            contenu = xml_to_html(enfant)
            parties.append(f'<p class="indent">{contenu}</p>')

        elif tag == "rubrique":
            nom = enfant.get("nom", "")
            contenu = xml_to_html(enfant)
            parties.append(
                f'<div class="rubrique"><h4>{nom}</h4>{contenu}</div>'
            )

        elif tag == "a":
            ref = enfant.get("ref", "")
            texte = xml_to_html(enfant)
            parties.append(f'<a href="littre://{ref}">{texte}</a>')

        elif tag in ("i", "b", "br", "sup", "sub"):
            contenu = xml_to_html(enfant)
            parties.append(f'<{tag}>{contenu}</{tag}>')

        else:
            # Balise inconnue : conserver le contenu
            contenu = xml_to_html(enfant)
            parties.append(contenu)

        # Ajouter le tail (texte après la balise fermante)
        if enfant.tail:
            parties.append(enfant.tail)

    return "".join(parties)


# ---------------------------------------------------------------------------
# Lecture des fichiers XML
# ---------------------------------------------------------------------------

def lire_fichier_xml(chemin_fichier: Path) -> list[dict]:
    """Lit un fichier XML et retourne la liste des entrées."""
    entrees = []

    try:
        arbre = ET.parse(chemin_fichier)
    except ET.ParseError as e:
        print(f"  ERREUR XML dans {chemin_fichier} : {e}", file=sys.stderr)
        return entrees

    racine = arbre.getroot()

    for entree in racine.iter("entree"):
        terme = entree.get("terme", "").strip()
        if not terme:
            continue

        # --- Prononciation et nature depuis <entete> ---
        entete = entree.find("entete")
        prononciation = None
        nature = None
        if entete is not None:
            elem_pron = entete.find("prononciation")
            if elem_pron is not None and elem_pron.text:
                prononciation = elem_pron.text.strip()
            elem_nat = entete.find("nature")
            if elem_nat is not None:
                nature = inner_xml(elem_nat).strip() or None

        # --- Corps : contenu principal des définitions ---
        elem_corps = entree.find("corps")
        corps = xml_to_html(elem_corps) if elem_corps is not None else ""

        # --- Rubriques : étymologie, historique, supplément ---
        etymologie = None
        historique = None
        supplement = None
        for rubrique in entree.findall("rubrique"):
            nom = rubrique.get("nom", "")
            contenu = xml_to_html(rubrique)
            if "ÉTYMOLOGIE" in nom:
                etymologie = contenu
            elif "HISTORIQUE" in nom:
                historique = contenu
            elif "SUPPLÉMENT" in nom:
                supplement = contenu

        # Ajouter l'historique au corps si présent
        if historique:
            corps += f'<div class="historique"><h4>HISTORIQUE</h4>{historique}</div>'

        entrees.append({
            "terme": terme,
            "terme_normalise": normaliser_terme(terme),
            "prononciation": prononciation,
            "nature": nature,
            "corps": corps or "",
            "etymologie": etymologie,
            "supplement": supplement,
        })

    return entrees


# ---------------------------------------------------------------------------
# Création et peuplement de la base SQLite
# ---------------------------------------------------------------------------

def creer_base(chemin_db: Path) -> sqlite3.Connection:
    """Crée la base SQLite avec le schéma complet."""
    if chemin_db.exists():
        chemin_db.unlink()
        print(f"Base existante supprimée : {chemin_db}")

    conn = sqlite3.connect(str(chemin_db))
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            terme TEXT NOT NULL,
            terme_normalise TEXT NOT NULL,
            prononciation TEXT,
            nature TEXT,
            corps TEXT NOT NULL,
            etymologie TEXT,
            supplement TEXT
        );
    """)

    cur.execute("CREATE INDEX idx_terme ON entries(terme);")
    cur.execute("CREATE INDEX idx_terme_normalise ON entries(terme_normalise);")

    cur.execute("""
        CREATE VIRTUAL TABLE entries_fts USING fts5(
            terme,
            corps,
            etymologie,
            content='entries',
            content_rowid='id',
            tokenize='unicode61 remove_diacritics 2'
        );
    """)

    conn.commit()
    return conn


def inserer_entrees(conn: sqlite3.Connection, entrees: list[dict]) -> int:
    """Insère les entrées en une transaction."""
    conn.executemany(
        """INSERT INTO entries
           (terme, terme_normalise, prononciation, nature, corps, etymologie, supplement)
           VALUES (:terme, :terme_normalise, :prononciation, :nature, :corps, :etymologie, :supplement)""",
        entrees,
    )
    conn.commit()
    return len(entrees)


def peupler_fts(conn: sqlite3.Connection) -> None:
    """Remplit la table FTS5 depuis la table principale."""
    conn.execute("""
        INSERT INTO entries_fts(rowid, terme, corps, etymologie)
        SELECT id, terme, corps, etymologie FROM entries;
    """)
    conn.commit()


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Convertit les fichiers XMLittré en base SQLite."
    )
    parser.add_argument(
        "repertoire_xml", nargs="?", default="./xmlittre-data",
        help="Répertoire des fichiers XML (défaut : ./xmlittre-data)",
    )
    parser.add_argument(
        "-o", "--output", default="./littre.db",
        help="Fichier SQLite de sortie (défaut : ./littre.db)",
    )
    args = parser.parse_args()

    repertoire = Path(args.repertoire_xml)
    chemin_db = Path(args.output)

    if not repertoire.is_dir():
        print(f"ERREUR : '{repertoire}' introuvable.", file=sys.stderr)
        sys.exit(1)

    lettres = [chr(c) for c in range(ord("a"), ord("z") + 1)]
    fichiers = [repertoire / f"{l}.xml" for l in lettres if (repertoire / f"{l}.xml").is_file()]

    if not fichiers:
        print(f"ERREUR : aucun fichier XML dans '{repertoire}'.", file=sys.stderr)
        sys.exit(1)

    print(f"Source : {repertoire.resolve()}")
    print(f"Fichiers : {len(fichiers)}")
    print(f"Sortie : {chemin_db.resolve()}")
    print()

    conn = creer_base(chemin_db)
    total = 0

    for fichier in fichiers:
        lettre = fichier.stem.upper()
        print(f"  {lettre}...", end=" ", flush=True)
        entrees = lire_fichier_xml(fichier)
        if entrees:
            nb = inserer_entrees(conn, entrees)
            total += nb
            print(f"{nb} entrées")
        else:
            print("aucune")

    print(f"\nTotal : {total} entrées")
    print("Index FTS5...", end=" ", flush=True)
    peupler_fts(conn)
    print("OK")
    print("VACUUM...", end=" ", flush=True)
    conn.execute("VACUUM;")
    print("OK")
    conn.close()

    taille = chemin_db.stat().st_size / (1024 * 1024)
    print(f"\n{chemin_db.resolve()} — {taille:.1f} Mo, {total} entrées")


if __name__ == "__main__":
    main()
