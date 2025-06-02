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

# Limpiar cloud-init para evitar reconfiguraciones al arrancar la instancia
echo "🧹  Limpiando cloud-init..."
sudo cloud-init clean --logs --seed

# ------------------------------------------------------------
# Crea un vhost que haga de proxy a la app Node en 127.0.0.1:3000
# ------------------------------------------------------------
cat > /etc/nginx/sites-available/adc-app.conf <<'EOF'
server {
    listen 80;
    server_name _;

    server_tokens off;
    access_log  /var/log/nginx/adc-app.access.log;
    error_log   /var/log/nginx/adc-app.error.log;

    location / {
        proxy_pass         http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
EOF

# Habilitar el vhost y recargar Nginx
sudo ln -sf /etc/nginx/sites-available/adc-app.conf /etc/nginx/sites-enabled/adc-app.conf
sudo nginx -t
sudo systemctl reload nginx