#!/bin/bash

# Exit on error
set -e

# Stremio Install Script
# ----------------------

GIT_REPO=vjeeva/stremio

echo -e "\e[1;32mWelcome to the Stremio Server Install Script!\e[0m"

# Echo and prompt for the following (brackets are for env vars to save as):
# Before we begin, we need to obtain the following values from you:
# 1. Your Cloudflare DNS API Token (CF_DNS_API_TOKEN)
# 2. Your Domain Name eg 'yourdomain.stream' (DOMAIN)
# 3. Your NextDNS Profile ID (NEXTDNS_PROFILE_ID)
# 4. Your NextDNS API Key (NEXTDNS_API_KEY)
# 5. Your Tailscale API Key (TAILSCALE_API_KEY)
# 6. Your email address, will be used for SSL Certificate (EMAIL)
# 7. An API Password for MediaFlow (can be whatever) (MEDIAFLOW_API_PASSWORD)

# Prompt for the above values, first listing them all, asking if they're ready, and then asking for each one:
echo -e "\e[1;32mBefore we begin, we need to obtain the following values from you:\e[0m"
echo -e "\e[1;32m1. Your Cloudflare DNS API Token (CF_DNS_API_TOKEN)\e[0m"
echo -e "\e[1;32m2. Your Domain Name eg 'yourdomain.stream' (DOMAIN)\e[0m"
echo -e "\e[1;32m3. Your NextDNS Profile ID (NEXTDNS_PROFILE_ID)\e[0m"
echo -e "\e[1;32m4. Your NextDNS API Key (NEXTDNS_API_KEY)\e[0m"
echo -e "\e[1;32m5. Your Tailscale API Key (TAILSCALE_API_KEY)\e[0m"
echo -e "\e[1;32m6. Your email address, will be used for SSL Certificate (EMAIL)\e[0m"
echo -e "\e[1;32m7. An API Password for MediaFlow (can be whatever) (MEDIAFLOW_API_PASSWORD)\e[0m"

read -p "Are you ready to proceed? (y/n) (DO NOT Press Enter after): " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "\e[1;31mExiting...\e[0m"
  exit 1
fi

echo -e "\n"

# Now prompt for each value
read -p "Enter your Cloudflare DNS API Token (CF_DNS_API_TOKEN): " CF_DNS_API_TOKEN
read -p "Enter your Domain Name eg 'yourdomain.stream' (DOMAIN): " DOMAIN
read -p "Enter your NextDNS Profile ID (NEXTDNS_PROFILE_ID): " NEXTDNS_PROFILE_ID
read -p "Enter your NextDNS API Key (NEXTDNS_API_KEY): " NEXTDNS_API_KEY
read -p "Enter your Tailscale API Key (TAILSCALE_API_KEY): " TAILSCALE_API_KEY
read -p "Enter your email address, will be used for SSL Certificate (EMAIL): " EMAIL
read -p "Enter an API Password for MediaFlow (can be whatever) (MEDIAFLOW_API_PASSWORD): " MEDIAFLOW_API_PASSWORD

# Install Docker
# From https://docs.docker.com/engine/install/ubuntu/
# ----------------------------------------------------

if [ -x "$(command -v docker)" ]; then
  # Echo that Docker is already installed
  echo -e "\e[1;32mDocker is already installed!\e[0m"
else

  echo -e "\e[1;32mInstalling Docker...\e[0m"

  # Add Docker's official GPG key:
  sudo apt update
  sudo apt-get -y install tailscale ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update

  # Install Docker
  sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

fi

# ----------------------------------------------------

# Install Tailscale & Set up Tailscale
# ------------------------------------

if [ -x "$(command -v tailscale)" ]; then
  # Echo that Docker is already installed
  echo -e "\e[1;32mTailscale is already installed!\e[0m"
else

  echo -e "\e[1;32mInstalling Tailscale...\e[0m"

  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
  sudo apt-get update
  sudo apt-get -y install tailscale

fi

# Will prompt user to authenticate by showing a link in the terminal
echo -e "\e[1;32mStarting Tailscale...\e[0m"
sudo tailscale up

# ------------------------------------


# Set up Cloudflare Records
# TODO: Should be run every time the machine restarts.
# -------------------------

echo -e "\e[1;32mSetting up Cloudflare DNS Records...\e[0m"

ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
  -H "Authorization: Bearer $CF_DNS_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# Got this from ChatGPT. Filters out IPs that end in .0.1 and TailScale IPs (100.64.0.0/10)
LOCAL_IP=$(ip -4 addr show | awk '/inet / && !/127.0.0.1/ {print $2}' | cut -d/ -f1 | grep -Ev '\.0\.1$' | awk -F. '!(($1 == 100) && ($2 >= 64 && $2 <= 127))')

# If the above does not yield a single IP, bomb out
if [ $(echo $LOCAL_IP | wc -w) -ne 1 ]; then
  echo -e "\e[1;31mError: Could not determine the local IP address. Please check the output of the following commandand try again: ip -4 addr show | awk '/inet / && !/127.0.0.1/ {print \$2}' | cut -d/ -f1 | grep -Ev '\.0\.1$' | awk -F. '!((\$1 == 100) && (\$2 >= 64 && \$2 <= 127))'\e[0m"
  exit 1
fi

# DNS Record for aiostreams and mediaflow-proxy
# TODO: If the records exist, this will do nothing. Need to delete and recreate them if they change.
for PREFIX in aiostreams mediaflow-proxy; do

  curl https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $CF_DNS_API_TOKEN" \
      -d '{
        "comment": "AIOStreams Record",
        "content": "'"$LOCAL_IP"'",
        "name": "'"$PREFIX.$DOMAIN"'",
        "proxied": false,
        "ttl": 300,
        "type": "A"
      }'
  
  echo -e "\n\e[1;32mCreated DNS Record for $PREFIX.$DOMAIN\e[0m"

done

# -------------------------


# Set up NextDNS Rewrites for TailScale IPs for the above records
# TODO: Should be run every time the machine restarts.
# ---------------------------------------------------------------

# Replace these values with your own
REWRITE_IP=$(tailscale ip -4) # Get the IPv4 address of the Tailscale interface

# API endpoint
NEXTDNS_API_URL="https://api.nextdns.io/profiles/$NEXTDNS_PROFILE_ID"

echo -e "\e[1;32mSetting up NextDNS Rewrites for Tailscale...\e[0m"

# Add DNS Rewrites for aiostreams and mediaflow-proxy
# TODO: If rewrites exist for the domains, this will fail. Need to delete and recreate them.
for PREFIX in aiostreams mediaflow-proxy; do

  curl -X POST "$NEXTDNS_API_URL/rewrites" \
       -H "X-Api-Key: $NEXTDNS_API_KEY" \
       -H "Content-Type: application/json" \
       -d '{
             "name": "'"$PREFIX.$DOMAIN"'",
             "content": "'"$REWRITE_IP"'"
           }'

  echo -e "\n\e[1;32mAdded Rewrite for $PREFIX.$DOMAIN\e[0m"

done

echo -e "\e[1;32mNextDNS Rewrites for Tailscale set up successfully!\e[0m"

# Get the first IPv6 address from the NextDNS setup
NEXTDNS_IPV6=$(curl -s -X GET "$NEXTDNS_API_URL" \
     -H "X-Api-Key: $NEXTDNS_API_KEY" | jq -r '.data.setup.ipv6[0]')

echo -e "\e[1;32mNextDNS IPv6 Address: $NEXTDNS_IPV6\e[0m"

# ---------------------------------------------------------------

# Set up Tailscale to use the NextDNS server configured with the above rewrites
# ------------------------------------------------------------------------------

echo -e "\e[1;32mConfiguring Tailscale to use NextDNS Rewrites...\e[0m"

TAILSCALE_API_URL="https://api.tailscale.com/api/v2/tailnet/-"

# This sets the DNS server and by doing this, Override Local DNS is enabled automatically.
curl -s -X POST "$TAILSCALE_API_URL/dns/nameservers" \
    -H "Authorization: Bearer $TAILSCALE_API_KEY" \
    -H 'Content-Type: application/json' \
     -d '{
           "dns": ["'"$NEXTDNS_IPV6"'"]
         }'

echo -e "\e[1;32mTailscale Configured to use NextDNS Rewrites!\e[0m"

# ------------------------------------------------------------------------------

# Stand up Docker-Compose Services
# TODO: Should be run every time the machine restarts.
# --------------------------------

# First, make a directory for docker-compose
sudo mkdir -p /opt/stremio-server

# Then, echo the .env file contents piped into | sudo tee /opt/stremio-server/.env
sudo rm -f /opt/stremio-server/.env
sudo sh -c "echo MEDIAFLOW_API_PASSWORD=$MEDIAFLOW_API_PASSWORD >> /opt/stremio-server/.env"
sudo sh -c "echo CF_DNS_API_TOKEN=$CF_DNS_API_TOKEN >> /opt/stremio-server/.env"
sudo sh -c "echo DOMAIN=$DOMAIN >> /opt/stremio-server/.env"
sudo sh -c "echo EMAIL=$EMAIL >> /opt/stremio-server/.env"

# Copy the docker-compose.yml file to the directory from Github
echo -e "\e[1;32mDownloading Docker-Compose File from Github.com ${GIT_REPO}...\e[0m"
sudo curl -s -o /opt/stremio-server/docker-compose.yml https://raw.githubusercontent.com/${GIT_REPO}/main/docker-compose.yaml

# Finally, bring up the services
echo -e "\e[1;32mBringing up the Stremio Server Services...\e[0m"
sudo docker compose -f /opt/stremio-server/docker-compose.yml up -d

# Finally, unset any User-Specific Variables

CF_DNS_API_TOKEN=
EMAIL=
DOMAIN=
NEXTDNS_API_KEY=
NEXTDNS_PROFILE_ID=
TAILSCALE_API_KEY=
