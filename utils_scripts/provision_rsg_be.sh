#!/bin/bash
### Author: Nico J. (nico.javelaud@protonmail.com)###
### Notes: 
###	1/ Unless required use base Debian 12 template - 
###	2/ Make sure the VM/container firewall is configured to allow port 8000
###  
### STARTER script plaid container ###
# Define variables
read -p 'CLOUDFLARE_TOKEN: ' CLOUDFLARE_TOKEN
read -p 'PLAID_ENV_TYPE: ' PLAID_ENV_TYPE
read -p 'PLAID_CLIENT_ID: ' PLAID_CLIENT_ID
read -p 'PLAID_CLIENT_SECRET: ' PLAID_CLIENT_SECRET
read -p 'PORT: ' PORT

# Update the container
apt-get update && apt-get upgrade -y

# Install dependencies
apt-get install -y ca-certificates curl gnupg git

# Download and import the Nodesource GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

# Download and import Docker's official GPG key:
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Nodejs repository to Apt sources:
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# Add Docker repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Download & Install Cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb &&  dpkg -i cloudflared.deb

# Create Cloudflare tunnel
cloudflared service install $CLOUDFLARE_TOKEN

# Run Update and Install
apt-get update
apt-get install nodejs -y
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Install PM2 and enable at startup
npm install -g pm2
pm2 startup

# Download Plaid's quickstart image
git clone https://github.com/nic0-javelaud/rootstonegroup-plaid-be.git
cd rootstonegroup-plaid-be

# Configure .env file before building the docker container
echo "PLAID_CLIENT_ID=$PLAID_CLIENT_ID" | tee -a .env
echo "PLAID_SECRET=$PLAID_CLIENT_SECRET" | tee -a .env
echo "PLAID_ENV=$PLAID_ENV_TYPE" | tee -a .env
echo "PLAID_COUNTRY_CODES=US,CA" | tee -a .env
echo "PLAID_PRODUCTS=auth,transactions" | tee -a .env
echo "PLAID_REDIRECT_URI=" | tee -a .env
echo "PORT=$PORT" | tee -a .env

# Start the daemon running on the server code
pm2 start src/server.ts --exp-backoff-restart-delay=100
