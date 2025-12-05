#!/bin/bash
#
#  generate-icons.sh
#  Generate icons from photoprism website for MacOS Launcher App.
#
#  Copyright (C) 2025 Chris Bansart (@chrisbansart)
#  https://github.com/chrisbansart
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <https://www.gnu.org/licenses/>.
#

set -euo pipefail

# Script pour générer les icônes de l'app PhotoPrism à partir du logo officiel SVG
# Nécessite: curl, qlmanage ou rsvg-convert (pour SVG->PNG), sips (macOS built-in)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/PhotoPrismLauncher/Assets.xcassets"
APPICON_DIR="$ASSETS_DIR/AppIcon.appiconset"
STATUSBAR_DIR="$ASSETS_DIR/StatusBarIcon.imageset"

# URL du logo PhotoPrism officiel (SVG)
LOGO_SVG_URL="https://dl.photoprism.app/img/logo/logo.svg"

echo ">> Création des dossiers..."
mkdir -p "$APPICON_DIR"
mkdir -p "$STATUSBAR_DIR"

# Téléchargement du logo SVG
TEMP_SVG="/tmp/photoprism_logo.svg"
TEMP_LOGO="/tmp/photoprism_logo_1024.png"

echo ">> Téléchargement du logo PhotoPrism (SVG)..."
if curl -fsSL "$LOGO_SVG_URL" -o "$TEMP_SVG" 2>/dev/null; then
    echo "   Logo SVG téléchargé depuis $LOGO_SVG_URL"
else
    echo "!! Impossible de télécharger le logo SVG."
    exit 1
fi

# Conversion SVG -> PNG (1024x1024)
echo ">> Conversion SVG -> PNG..."

if command -v rsvg-convert &>/dev/null; then
    # Méthode 1: rsvg-convert (librsvg, via Homebrew: brew install librsvg)
    rsvg-convert -w 1024 -h 1024 "$TEMP_SVG" -o "$TEMP_LOGO"
    echo "   Converti avec rsvg-convert"
elif command -v qlmanage &>/dev/null; then
    # Méthode 2: qlmanage (macOS built-in, Quick Look)
    # Note: qlmanage peut avoir des limitations avec certains SVG
    qlmanage -t -s 1024 -o /tmp "$TEMP_SVG" 2>/dev/null
    # qlmanage crée un fichier avec extension .png ajoutée au nom original
    if [[ -f "/tmp/photoprism_logo.svg.png" ]]; then
        mv "/tmp/photoprism_logo.svg.png" "$TEMP_LOGO"
        echo "   Converti avec qlmanage"
    else
        echo "!! qlmanage n'a pas pu convertir le SVG"
        echo "   Installez librsvg: brew install librsvg"
        exit 1
    fi
elif command -v convert &>/dev/null; then
    # Méthode 3: ImageMagick
    convert -background none -density 300 -resize 1024x1024 "$TEMP_SVG" "$TEMP_LOGO"
    echo "   Converti avec ImageMagick"
else
    echo "!! Aucun outil de conversion SVG trouvé."
    echo "   Installez l'un des outils suivants:"
    echo "     - librsvg: brew install librsvg"
    echo "     - ImageMagick: brew install imagemagick"
    exit 1
fi

# Vérifier que la conversion a réussi
if [[ ! -f "$TEMP_LOGO" ]]; then
    echo "!! Échec de la conversion SVG -> PNG"
    exit 1
fi

# Vérification que sips est disponible (macOS uniquement)
if ! command -v sips &>/dev/null; then
    echo "!! 'sips' non disponible. Ce script nécessite macOS."
    echo "   Copiez manuellement les icônes dans les tailles requises."
    exit 1
fi

echo ">> Génération des icônes de l'application..."

# Tailles pour AppIcon (macOS)
declare -a ICON_SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for entry in "${ICON_SIZES[@]}"; do
    size="${entry%%:*}"
    filename="${entry##*:}"
    echo "   - $filename (${size}x${size})"
    sips -z "$size" "$size" "$TEMP_LOGO" --out "$APPICON_DIR/$filename" >/dev/null 2>&1
done

echo ">> Génération de l'icône de la barre de menu..."

# L'icône de la barre de menu doit être en noir/blanc (template image)
# Taille recommandée: 18x18 @1x, 36x36 @2x

# D'abord créer une version de l'icône
sips -z 18 18 "$TEMP_LOGO" --out "$STATUSBAR_DIR/statusbar_icon.png" >/dev/null 2>&1
sips -z 36 36 "$TEMP_LOGO" --out "$STATUSBAR_DIR/statusbar_icon@2x.png" >/dev/null 2>&1

echo ">> Icônes générées avec succès!"
echo ""
echo "IMPORTANT: Les icônes de la barre de menu devraient être des 'template images'"
echo "(noir sur fond transparent) pour s'adapter au mode clair/sombre."
echo "Vous pouvez les éditer manuellement ou utiliser le logo tel quel."
echo ""
echo "Dossiers créés:"
echo "  - $APPICON_DIR"
echo "  - $STATUSBAR_DIR"

# Nettoyage
rm -f "$TEMP_LOGO" "$TEMP_SVG"
