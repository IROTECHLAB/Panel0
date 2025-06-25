#!/bin/bash

# Pterodactyl Panel & Wings (Docker) Installation Script
# For use in CodeSandbox Linux environments

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

# Check if running in CodeSandbox
if [[ ! -f /.codesandbox/sandbox ]]; then
    echo -e "${YELLOW}Warning: This script is designed for CodeSandbox environments${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
echo -e "${BLUE}Updating system packages...${NC}"
apt-get update
apt-get upgrade -y
apt-get install -y curl git docker.io docker-compose

# Start Docker
echo -e "${BLUE}Starting Docker...${NC}"
systemctl enable docker
systemctl start docker

# Clone Pterodactyl Docker project
echo -e "${BLUE}Downloading Pterodactyl Docker setup...${NC}"
git clone https://github.com/pterodactyl/standalone /var/www/pterodactyl
cd /var/www/pterodactyl || exit

# Setup environment variables
echo -e "${BLUE}Configuring Pterodactyl...${NC}"
cp .env.example .env

# Generate a random key for the panel
echo -e "${BLUE}Generating application key...${NC}"
sed -i 's/APP_KEY=.*/APP_KEY=base64:'$(openssl rand -base64 32)'/' .env

# Set panel URL (CodeSandbox uses a dynamic URL)
echo -e "${BLUE}Setting up panel URL...${NC}"
sed -i 's/APP_URL=.*/APP_URL=http:\/\/localhost/' .env

# Build and start containers
echo -e "${BLUE}Starting Docker containers...${NC}"
docker-compose up -d --build

# Wait for MySQL to be ready
echo -e "${BLUE}Waiting for MySQL to start...${NC}"
sleep 30

# Run migrations and seed database
echo -e "${BLUE}Setting up database...${NC}"
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
echo -e "${GREEN}\nPterodactyl Panel & Wings (Docker) installation complete!${NC}"
echo -e "${YELLOW}You can access the panel at: http://localhost${NC}"
echo -e "${YELLOW}To stop the containers, run: docker-compose down${NC}"
