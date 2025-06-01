#!/usr/bin/env bash
# Instala Nginx, habilita su servicio y abre el puerto 80 en UFW
# sin cerrar tu sesión SSH. Probado en Ubuntu 20.04/22.04.

set -euo pipefail

echo "🚀  Actualizando índice de paquetes…"
sudo apt-get update -y

echo "📦  Instalando Nginx y UFW (si faltan)…"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y nginx ufw

echo "📡  Habilitando y arrancando Nginx…"
sudo systemctl enable --now nginx

echo "🛡  Asegurando que UFW permita SSH antes de activarlo…"
sudo ufw allow OpenSSH

echo "🛡  Permitiendo tráfico HTTP (puerto 80) únicamente…"
sudo ufw allow 'Nginx HTTP'

echo "🔒  Activando UFW si estaba inactivo…"
sudo ufw --force enable

echo "📊  Reglas finales de UFW:"
sudo ufw status verbose
