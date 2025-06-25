#!/bin/bash

# Pterodactyl Panel & Wings Docker Installation Script
# Optimized for CodeSandbox environments

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}" 
    exit 1
fi

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# Install Docker Compose if not exists
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose not found. Installing...${NC}"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Create project directory
echo -e "${BLUE}Creating project directory...${NC}"
mkdir -p /opt/pterodactyl
cd /opt/pterodactyl || exit

# Create docker-compose.yml
echo -e "${BLUE}Creating docker-compose.yml...${NC}"
cat > docker-compose.yml << 'EOL'
version: '3'

services:
  panel:
    image: ghcr.io/pterodactyl/panel:latest
    container_name: pterodactyl-panel
    restart: unless-stopped
    environment:
      - APP_URL=http://localhost
      - DB_HOST=pterodactyl-db
      - DB_PORT=3306
      - DB_DATABASE=pterodactyl
      - DB_USERNAME=pterodactyl
      - DB_PASSWORD=pterodactyl
    volumes:
      - ./panel:/var/www/html
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - pterodactyl-db

  pterodactyl-db:
    image: mariadb:10.8
    container_name: pterodactyl-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=rootpassword
      - MYSQL_DATABASE=pterodactyl
      - MYSQL_USER=pterodactyl
      - MYSQL_PASSWORD=pterodactyl
    volumes:
      - ./db:/var/lib/mysql

  redis:
    image: redis:alpine
    container_name: pterodactyl-redis
    restart: unless-stopped
    volumes:
      - ./redis:/data
EOL

# Start containers
echo -e "${BLUE}Starting containers...${NC}"
docker-compose up -d

# Wait for MySQL to be ready
echo -e "${BLUE}Waiting for database to initialize...${NC}"
while ! docker-compose exec pterodactyl-db mysqladmin ping -h"127.0.0.1" -u"pterodactyl" -p"pterodactyl" --silent; do
    sleep 5
done

# Initialize panel
echo -e "${BLUE}Initializing panel...${NC}"
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
echo -e "${YELLOW}Panel URL: http://localhost${NC}"
echo -e "${YELLOW}To stop: docker-compose down${NC}"
echo -e "${YELLOW}To start: docker-compose up -d${NC}"
