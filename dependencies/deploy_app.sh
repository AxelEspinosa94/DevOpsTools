#!/usr/bin/env bash
set -euo pipefail

# Configuración para entornos no interactivos (útil para apt-get, si lo llegas a usar en otros scripts)
export DEBIAN_FRONTEND=noninteractive

# 1️⃣ Comprobaciones rápidas: Asegurarse de que node, pm2 y curl estén en el PATH
for cmd in node pm2 curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ $cmd no está instalado o no está en PATH"
    exit 1
  fi
done

cd "$HOME"

# 2️⃣ Genera la aplicación Node.js (archivo app.js)
cat > app.js <<'JS'
const http = require('http');
const hostname = '0.0.0.0';    // Escucha en todas las interfaces
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  const ahora = new Date();
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(`Son las ${ahora.toLocaleString()}\n`);
});

server.listen(port, hostname, () => {
  console.log(`Server running at http://${hostname}:${port}/`);
});
JS

# 3️⃣ Arranca la aplicación con PM2 (de forma idempotente)
APP_NAME="ADC-app"

# Si ya existe la aplicación en PM2, se recarga; si no, se inicia
if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
  pm2 reload "$APP_NAME"
else
  pm2 start app.js --name "$APP_NAME" --time
fi

# 4️⃣ Configuración para que PM2 se inicie al reiniciar (startup) de forma no interactiva.
# Se usa el comando con sudo y se ignoran los posibles errores de salida (|| true)
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu || true

# Guarda la lista actual de procesos en PM2 para restaurarla en el reboot.
pm2 save

# Inicia el servicio systemd correspondiente (generalmente se crea el servicio pm2-ubuntu)
sudo systemctl start pm2-ubuntu || true

# 5️⃣ Espera activa: Verifica que el servidor esté respondiendo en el puerto 3000.
echo "⏳ Esperando al servidor en :3000..."
for i in {1..15}; do
  if curl --silent --fail http://localhost:3000 >/dev/null; then
    echo "✅ Servidor arriba en ${i}s"
    break
  fi
  sleep 1
  if [ $i -eq 15 ]; then
    echo "❌ Timeout de 15 s"
    exit 1
  fi
done

# 6️⃣ Muestra la respuesta del servidor y la ubicación de los logs
respuesta=$(curl --silent http://localhost:3000)
echo "Respuesta del servidor: $respuesta"
echo "📜 Logs en: ~/.pm2/logs/${APP_NAME}-out.log"