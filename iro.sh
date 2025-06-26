#!/bin/bash

# Pterodactyl Panel & Wings Docker Installation Script
# With Panel Files Cloning - Optimized for CodeSandbox

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not available in this environment${NC}"
    echo -e "${YELLOW}Please use a CodeSandbox template with Docker support${NC}"
    exit 1
fi

# Create project directory in /workspace (CodeSandbox writable location)
echo -e "${BLUE}Creating project directory...${NC}"
mkdir -p /workspace/pterodactyl
cd /workspace/pterodactyl || exit

# Clone panel files
echo -e "${BLUE}Cloning Pterodactyl Panel files...${NC}"
git clone https://github.com/pterodactyl/panel.git panel_files
cd panel_files || exit

# Install PHP dependencies (needed for artisan commands)
echo -e "${BLUE}Installing PHP dependencies...${NC}"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
composer install --no-dev --optimize-autoloader

# Return to project root
cd ..

# Create docker-compose.yml with volume mount for panel files
echo -e "${BLUE}Creating docker-compose.yml...${NC}"
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
      - "443:443"
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

  wings:
    image: ghcr.io/pterodactyl/wings:latest
    container_name: pterodactyl-wings
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./wings:/etc/pterodactyl
    depends_on:
      - panel
EOL

# Start containers
echo -e "${BLUE}Starting containers...${NC}"
docker-compose up -d

# Wait for containers to start
echo -e "${BLUE}Waiting for services to initialize (this may take a few minutes)...${NC}"
sleep 30

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

# Generate wings configuration
echo -e "${BLUE}Generating Wings configuration...${NC}"
docker-compose exec panel php artisan p:node:configuration 1 > /workspace/pterodactyl/wings/config.yml

# Start wings service
echo -e "${BLUE}Starting Wings service...${NC}"
docker-compose up -d wings

# Display completion message
echo -e "${GREEN}\nPterodactyl installation complete!${NC}"
echo -e "${YELLOW}Panel URL: http://localhost${NC}"
echo -e "${YELLOW}Wings configuration saved to: /workspace/pterodactyl/wings/config.yml${NC}"
echo -e "${YELLOW}To stop: docker-compose down${NC}"
echo -e "${YELLOW}To start: docker-compose up -d${NC}"
