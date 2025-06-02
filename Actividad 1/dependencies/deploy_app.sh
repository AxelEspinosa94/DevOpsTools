#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------
# 0. Prerrequisitos
# ------------------------------------------------------------------
for cmd in node pm2 curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ $cmd no está instalado o no está en PATH"
    exit 1
  fi
done

# ------------------------------------------------------------------
# 1. Creación de la aplicación
# ------------------------------------------------------------------
sudo mkdir -p /opt/myapp
sudo chown "$USER":"$USER" /opt/myapp
cd /opt/myapp

cat > app.js <<'JS'
const http = require('http');
const hostname = '0.0.0.0';
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  const now = new Date();
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(`Son las ${now.toLocaleString()}\n`);
});

server.listen(port, hostname, () => {
  console.log(`Server running at http://${hostname}:${port}/`);
});
JS

# ------------------------------------------------------------------
# 2. Start / reload with PM2
# ------------------------------------------------------------------
APP_NAME="ADC-app"
if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
  pm2 reload "$APP_NAME"
else
  pm2 start app.js --name "$APP_NAME" --time
fi
pm2 save

# ------------------------------------------------------------------
# 3. Register PM2 with systemd (one call is enough)
# ------------------------------------------------------------------
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu
sudo systemctl enable pm2-ubuntu
sudo systemctl start  pm2-ubuntu

# ------------------------------------------------------------------
# 4. Wait until the app is alive
# ------------------------------------------------------------------
echo "⏳ Esperando al servidor en :3000..."
for i in $(seq 1 15); do
  if curl --silent --fail http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Servidor arriba en ${i}s"
    break
  fi
  sleep 1
  if [ "$i" -eq 15 ]; then
    echo "❌ Timeout de 15 s"
    exit 1
  fi
done

respuesta=$(curl --silent http://localhost:3000)
echo "Respuesta del servidor: $respuesta"
echo "📜 Logs en: ~/.pm2/logs/${APP_NAME}-out.log"