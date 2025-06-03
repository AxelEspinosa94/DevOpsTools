#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive


APP_DIR="/opt/myapp"
APP_NAME="ADC-app"
PORT=3000

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
install -d -m 755 "$APP_DIR"

cat > "$APP_DIR/app.js" <<'JS'
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

pm2 start "$APP_DIR/app.js" --name "$APP_NAME" --time
pm2 save

# ------------------------------------------------------------------
# 3. Register PM2 with systemd (one call is enough)
# ------------------------------------------------------------------
pm2 startup systemd *--skip-env-check
systemctl enable pm2-root

# ------------------------------------------------------------------
# 4. Wait until the app is alive
# ------------------------------------------------------------------
echo "⏳ Esperando al servidor en :${PORT}..."
for i in $(seq 1 15); do
  if curl --silent --fail http://localhost:${PORT} >/dev/null 2>&1; then
    echo "✅ Servidor arriba en ${i}s"
    break
  fi
  sleep 1
  if [ "$i" -eq 15 ]; then
    echo "❌ Timeout de 15 s"
    exit 1
  fi
done

respuesta=$(curl --silent http://localhost:${PORT})
echo "Respuesta del servidor: $respuesta"
