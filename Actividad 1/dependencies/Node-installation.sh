#!/usr/bin/env bash
#
# Instala Node.js LTS (por defecto 20), build-essential y PM2.
# Usa NodeSource, es idempotente y deja todo limpio.
#
# Uso:  ./install-node.sh [<major-version>]
# Ej.:  ./install-node.sh         # instala Node 20.x
#       ./install-node.sh 22      # instala Node 22.x
#

set -euo pipefail

NODE_MAJOR="${1:-20}"    # LTS actual si no se pasa parámetro
DISTRO_CODENAME=$(lsb_release -cs)

echo "🔍 1/5 - Actualizando índice APT y dependencias mínimas…"
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates gnupg build-essential

echo "🔑 2/5 - Importando GPG y añadiendo repo NodeSource ${NODE_MAJOR}.x…"
# Añadir clave sólo si no existe
if ! sudo test -f /usr/share/keyrings/nodesource.gpg; then
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key |
    sudo gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
fi

# Crear/actualizar lista sólo si no coincide
LIST_FILE="/etc/apt/sources.list.d/nodesource.list"
EXPECTED="deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x ${DISTRO_CODENAME} main"
if ! grep -qF "${EXPECTED}" "$LIST_FILE" 2>/dev/null; then
  echo "${EXPECTED}" | sudo tee "$LIST_FILE" >/dev/null
fi

echo "📦 3/5 - Instalando Node.js 18.x… - Recomendado"
sudo apt-get update -y
#sudo apt-get install -y nodejs
# 1) Añade el repo NodeSource 14.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# 2) Instala Node.js (traerá la 14.x porque ese repo es el único que
#    contiene el paquete nodejs con prioridad > 0)
sudo apt-get install -y nodejs


echo "✅    Node $(node -v) y npm $(npm -v) instalados."

echo "🚀 4/5 - Instalando PM2 globalmente…"
sudo npm install -g pm2@latest

echo "🎉 5/5 - Instalación completada."
echo "     > pm2 -v  -> $(pm2 -v)"
echo "     > Para arranque al boot: sudo pm2 startup systemd -u $USER --hp $HOME && pm2 save"
