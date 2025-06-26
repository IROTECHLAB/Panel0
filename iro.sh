#!/bin/bash

# Pterodactyl Panel Installation Script
# Fully working in CodeSandbox environment

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Install required system packages
echo -e "${BLUE}Installing system dependencies...${NC}"
apt-get update > /dev/null
apt-get install -y --no-install-recommends \
    php-cli \
    php-mbstring \
    php-curl \
    php-zip \
    unzip \
    git \
    docker.io \
    docker-compose > /dev/null

# Verify Docker installation
if ! systemctl is-active --quiet docker; then
    echo -e "${BLUE}Starting Docker service...${NC}"
    systemctl start docker
    sleep 5
fi

# Create project directory
echo -e "${BLUE}Setting up project directory...${NC}"
mkdir -p /workspace/pterodactyl
cd /workspace/pterodactyl || exit

# Download panel files (using direct download instead of git clone for speed)
echo -e "${BLUE}Downloading Pterodactyl Panel...${NC}"
curl -sSL https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xzv
mv panel-* panel_files
cd panel_files || exit

# Install Composer (standalone version)
echo -e "${BLUE}Installing Composer...${NC}"
EXPECTED_CHECKSUM="$(curl -s https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    echo -e "${RED}Composer installer checksum verification failed!${NC}"
    exit 1
fi

php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

# Install PHP dependencies
echo -e "${BLUE}Installing PHP dependencies...${NC}"
composer install --no-dev --optimize-autoloader --no-interaction > /dev/null

# Return to project root
cd ..

# Create docker-compose.yml
echo -e "${BLUE}Creating docker-compose configuration...${NC}"
cat > docker-compose.yml << 'EOL'
version: '3'

services:
  panel:
    image: ghcr.io/pterodactyl/panel:latest
    container_name: pterodactyl-panel
    restart: unless-stopped
    volumes:
      - ./panel_files:/var/www/html
    environment:
      - APP_URL=http://localhost
      - DB_HOST=db
      - DB_PORT=3306
      - DB_DATABASE=pterodactyl
      - DB_USERNAME=pterodactyl
      - DB_PASSWORD=pterodactyl
    ports:
      - "80:80"
    depends_on:
      - db

  db:
    image: mariadb:10.8
    container_name: pterodactyl-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=rootpassword
      - MYSQL_DATABASE=pterodactyl
      - MYSQL_USER=pterodactyl
      - MYSQL_PASSWORD=pterodactyl

  redis:
    image: redis:alpine
    container_name: pterodactyl-redis
    restart: unless-stopped
EOL

# Start containers
echo -e "${BLUE}Starting Docker containers...${NC}"
docker-compose up -d

# Wait for services to initialize
echo -e "${BLUE}Waiting for services to start (30 seconds)...${NC}"
sleep 30

# Initialize panel
echo -e "${BLUE}Configuring Pterodactyl Panel...${NC}"
docker-compose exec panel php artisan key:generate --force
docker-compose exec panel php artisan migrate --seed --force

# Create admin user
echo -e "${GREEN}Create first admin user${NC}"
echo -e "${YELLOW}Please provide the following details:${NC}"
read -p "Email: " email
read -p "Username: " username
read -sp "Password: " password
echo

docker-compose exec panel php artisan p:user:make \
    --email="$email" \
    --username="$username" \
    --name-first="Admin" \
    --name-last="User" \
    --password="$password" \
    --admin=1

# Display completion message
echo -e "${GREEN}\nPterodactyl Panel installation complete!${NC}"
echo -e "${YELLOW}Access the panel at: http://localhost${NC}"
echo -e "${YELLOW}To stop: docker-compose down${NC}"
echo -e "${YELLOW}To start: docker-compose up -d${NC}"
