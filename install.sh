#!/bin/bash

# Téléchargement du zip du repository GitHub
curl -L -o laravel-docker.zip https://github.com/antoinebonin/laravel-docker/archive/refs/heads/main.zip

# Extraction du zip
unzip laravel-docker.zip

# Suppression des éléments non essentiels
rm -f README.md install.sh .github

# Déplacement du contenu de l'archive extraite vers le répertoire actuel
mv laravel-docker/* ./
mv laravel-docker/.* ./

# Suppression des dossiers et fichiers temporaires
rm -rf laravel-docker.zip laravel-docker

echo "🚀 Laravel-Docker est bien installé !"