#!/bin/bash
set -e

USER_NAME="${SUDO_USER:-$USER}"
echo "=== CONFIGURACIÓN PROYECTO FINAL (WSL) ==="

# =============================
# 1. SISTEMA BASE
# =============================
echo "[1/11] Actualizando sistema..."
sudo apt update && sudo apt-get full-upgrade -y

echo "[2/11] Instalando dependencias base..."
sudo apt install -y apache2 mariadb-server curl git unzip

# =============================
# 2. NODE.JS
# =============================
echo "[3/11] Instalando Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs

node -v
npm -v

# =============================
# 3. APACHE
# =============================
echo "[4/11] Configurando Apache..."
sudo a2enmod proxy proxy_http headers rewrite
sudo systemctl enable apache2 || true
sudo systemctl start apache2 || true

# =============================
# 4. MARIADB
# =============================
echo "[5/11] Configurando MariaDB..."
sudo systemctl enable mariadb || true
sudo systemctl start mariadb || true

sudo mariadb <<EOF
$(cat db.sql)
EOF

# =============================
# 5. ESTRUCTURA DE PROYECTO
# =============================
echo "[6/11] Creando estructura de proyecto..."

STARTER_PATH=$PWD
PROJECT_BASENAME="ProyectoFinal"
PROJECT_ROOT="/var/www/html/${PROJECT_BASENAME}"
LOGS_DIR="$PROJECT_ROOT/backend/logs"

sudo mkdir -p $PROJECT_ROOT/{frontend,backend}
sudo chown -R $USER_NAME:$USER_NAME $PROJECT_ROOT
sudo chmod -R 755 $PROJECT_ROOT

sudo mkdir -p $LOGS_DIR
sudo chmod 755 $LOGS_DIR

mkdir -p $PROJECT_ROOT/backend/projects
sudo chown -R $USER_NAME:$USER_NAME $PROJECT_ROOT/backend
sudo chmod -R 755 $PROJECT_ROOT/backend

# =============================
# 6. BACKEND NODE (SIN ROOT)
# =============================
echo "[7/11] Inicializando backend Node..."

cd $PROJECT_ROOT/backend

npm init -y
npm install express mariadb cookie-parser cors
# -----------------------------
# binding.js
# -----------------------------
sudo cp "$STARTER_PATH"/styles.css $PROJECT_ROOT/frontend/styles.css 
sudo cp "$STARTER_PATH"/binding.js $PROJECT_ROOT/frontend/binding.js
sudo chmod 644 ${PROJECT_ROOT}/frontend/binding.js
sudo chmod 644 ${PROJECT_ROOT}/frontend/styles.css

# -----------------------------
# db.js
# -----------------------------
cp "$STARTER_PATH"/db.js $PROJECT_ROOT/backend/

# -----------------------------
# crypto.js
# -----------------------------
cp "$STARTER_PATH"/crypto.js $PROJECT_ROOT/backend/

# -----------------------------
# server.js (completo con sistema de archivos por sesión)
# -----------------------------
cp "$STARTER_PATH"/server.js $PROJECT_ROOT/backend/

# =============================
# 7. FRONTEND (index.html COMPLETO)
# =============================
echo "[8/11] Creando index.html..."
sudo cp "$STARTER_PATH"/index.html $PROJECT_ROOT/frontend/index.html

# =============================
# 8. APACHE VHOST
# =============================
echo "[9/11] Configurando Apache..."

sudo tee /etc/apache2/sites-available/proyectofinal.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html/${PROJECT_BASENAME}/frontend

    <Directory /var/www/html/${PROJECT_BASENAME}/frontend>
        Require all granted
        AllowOverride All
    </Directory>

    ProxyPreserveHost On

    ProxyPass /api http://localhost:3000/api
    ProxyPassReverse /api http://localhost:3000/api
</VirtualHost>
EOF
#sudo tee /etc/apache2/sites-available/proyectofinal.conf > /dev/null <<EOF
#<VirtualHost *:80>
#    ServerName localhost
#    DocumentRoot /var/www/html/${PROJECT_BASENAME}/frontend
#
#    <Directory /var/www/html/${PROJECT_BASENAME}/frontend>
#        Require all granted
#        AllowOverride All
#    </Directory>
#
#    ProxyPreserveHost On
#
#    ProxyPass /api http://localhost:3000/api
#    ProxyPassReverse /api http://localhost:3000/api
#
#    # Añadimos cabeceras para pasar información de la conexión original
#    RequestHeader set X-Forwarded-Proto "http"
#    RequestHeader set X-Forwarded-For %{REMOTE_ADDR}s
#</VirtualHost>
#EOF

sudo a2ensite proyectofinal
sudo a2dissite 000-default
sudo systemctl restart apache2 || true

# =============================
# 9. NGROK
# =============================
echo "[10/11] Instalando y configurando ngrok..."

# Descargar ngrok para Linux
if [ -f /usr/local/bin/ngrok ]; then
    echo "ngrok ya se encuentra instalado."
else
    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
    cd /tmp
    curl -LO $NGROK_URL
    tar xzf ngrok-v3-stable-linux-amd64.tgz
    sudo mv ngrok /usr/local/bin/ngrok
    sudo chmod +x /usr/local/bin/ngrok
    ngrok config add-authtoken 3AAL6c0gfQiILZruAg0eV484EEl_5Xycrgxd7CxGnZ9zPM1wq
fi

# Crear un script de arranque rápido de ngrok para Node
NGROK_SCRIPT="$PROJECT_ROOT/start-ngrok.sh"
cat <<'EOL' > $NGROK_SCRIPT
#!/bin/bash
echo "Iniciando ngrok en el puerto 80..."
ngrok http 80
EOL
chmod +x $NGROK_SCRIPT

echo "[11/11] CONFIGURACIÓN COMPLETADA"
echo "Tu sitio está listo en http://localhost y puedes exponerlo con:"
echo "$NGROK_SCRIPT"