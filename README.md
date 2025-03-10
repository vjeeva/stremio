# Stremio Configuration

This repository contains the configuration files to run a Stremio Add-On Server, so you can run a Netflix-like service with basically ANY TV Show or Movie for everyone in your household, from wherever you are in the world!

## Features

- Hosts [AIOStreams](https://github.com/Viren070/AIOStreams) as your main add-on for Stremio
    - Allows you to scrape content from Real-Debrid (a premium service that provides VERY high-speed access to a LARGE amount of Torrent Content)
        - Does this using Torrentio, a key scraper for Real-Debrid content
    - Allows you to proxy the streams through your chosen MediaFlow Proxy (below)
    - Note: we host this instead of using AIOStreams' public server because they remove Torrentio from that instance, the other ones just don't scrape nearly as much content as Torrentio.
- Hosts [MediaFlow Proxy](https://github.com/mhdzumair/mediaflow-proxy)
    - Allows you to proxy the streams from your server so external services only see your server's IP address
    - **This is important to avoid getting banned from Real-Debrid for multiple IP address simultaneous usage, so all your devices and users appear to be coming from the same IP address!**
- Installing TailScale so you can access your server from anywhere in the world, as long as you have the TailScale client installed on your device!
    - The server will NOT be accessible from the public internet, only through TailScale!

## Requirements for this Server

- A server with at least 8GB of RAM and Probably 4 Cores and 1.8GHz or more.
    - I ran this on 3.6GHz, 4 cores and 12GB of RAM. My server ran with 2.6GB used, 6GB ish in cache and the rest free, and I saw spikes of up to 30% CPU usage.

Summary of what will be installed on your server:
- Tailscale
- Docker
- AIOStreams as a Docker web service
- MediaFlow Proxy as a Docker web service

## Setup Instructions

This setup has a few steps. It's not too hard. Also, lots of this stuff is automated if you use the script in this repository (requires Ubuntu or Debian-based OSes).

### I. Service Registrations

Before setting up Stremio, We need to set up the following accounts:
1. [Real-Debrid](https://real-debrid.com/)
3. [Cloudflare](https://cloudflare.com/)
2. [Tailscale](https://tailscale.com/)
4. [NextDNS](https://nextdns.io/)

Do the following:
1. Go to [Real-Debrid](https://real-debrid.com/) and sign up for an account, and pay for a subscription. You can pay for one month to test it out, or just pay the 6 month subscription for the most savings.
2. Go to [Cloudflare](https://cloudflare.com/) and sign up for an account.
3. In Cloudflare, buy a `.stream` domain. This will cost you $4.16 initially and $5.16 for yearly renewal.
4. Go to [Tailscale](https://tailscale.com/) and sign up for an account.
5. Go to [NextDNS](https://nextdns.io/) and sign up for an account.

### II. Automated Setup with Ubuntu/Debian

If you are NOT using Ubuntu or Debian, skip to the next section for manual instructions.

Using the automated setup will ensure your server is set up correctly and all the setup bits are automated. It will also create a startup script to ensure your LAN IP and Tailscale IP are always in sync with the entire setup.

Simply run the following command on your server:

```bash
curl -s https://raw.githubusercontent.com/vjeeva/stremio/main/setup.sh > setup.sh && chmod +x setup.sh && ./setup.sh
```

Now you should see your Stremio Add-On Servers running on your browser by going to the following URLs:
- AIOStreams: `https://aiostreams.yourdomain.stream/`
- MediaFlow Proxy: `https://mediaflow-proxy.yourdomain.stream/`

Great! Everything should be set up on the server side now. Go set up your clients in Section IV and skip the next section!

### III. Manual Setup Instructions

These will give you the high level steps, you will need to figure them out accordingly.

#### A. Initial Server Setup

1. Install Docker on your server. You can follow the instructions [here](https://docs.docker.com/engine/install/).
2. Install Tailscale on your server. You can follow the instructions [here](https://tailscale.com/download/).
3. Make sure your Tailscale is up and running and signed into your account.

#### B. Domain Setup

Yes you need this. even though you're not hosting publicly. Stremio requires SSL termination, and we use Traefik to do this. Unless you go installing certs on all your devices, you need a publicly secure domain, even though we are using it for private-only IPs.

1. Make appropriate DNS Records:
    - A subdomain A record for AIOStreams (e.g. `aiostreams.yourdomain.stream`) pointing to your server's LAN IP address.
    - A subdomain A record for MediaFlow Proxy (e.g. `mediaflow-proxy.yourdomain.stream`) pointing to your server's LAN IP address.

To ensure your server is accessible while on Tailscale and not your LAN, we need to set up NextDNS for TailScale to rewrite the above DNS records to your Tailscale IP.

1. Go to https://my.nextdns.io/ and sign up for an account.
2. Go to Settings at the top.
3. Scroll down to Rewrites.
4. Add a rewrite rule for each of the above subdomains:
    - `aiostreams.yourdomain.stream` -> `Your Tailscale IP`
    - `mediaflow-proxy.yourdomain.stream` -> `Your Tailscale IP`
    - Your Tailscale IP can be found by running `tailscale status` on your server, or on any Tailscale client EG your phone (shown in the app on the main page).
5. Go to Setup, then copy one of the IPv6 addresses for your DNS server.
6. Go to your Tailscale Admin Console on a computer browser, click DNS.
7. Add your IPv6 address from NextDNS as a Global nameserver and ensure to check off `Override local DNS`.

Great! Now your domain is set up and accessible from anywhere in the world while your device is connected to Tailscale!

#### C. Stremio Add-On Setup

1. Edit the `.env` file in this repository with the missing values.
2. Transfer the `docker-compose.yml` and `.env` files to your server, into a folder called for example `stremio-server`.
3. Start up Docker Compose on that folder. EG for Ubuntu, you can run `sudo docker compose up -d`.
4. Wait for the services to start up. You can check the Docker logs to see status. You can also just go on a browser in your network and check if the services are running:
    - AIOStreams: `https://aiostreams.yourdomain.stream/`
    - MediaFlow Proxy: `https://mediaflow-proxy.yourdomain.stream/`

Great! Everything should be set up on the server side now. Go set up your clients!

### IV. Client Account Setup

1. Go to `https://web.stremio.com/`, sign up for an account and log in.
2. Open `https://aiostreams.yourdomain.stream/`
3. Configure AIOStreams as follows:
    - Add Real-Debrid and your API Key (find it on Real-Debrid by going to Useful Links -> My Devices)
    - Add Torrentio as your Scraper
    - Add MediaFlow Proxy as your Proxy. Ensure to add the `https://` URL, and the API Password you set in the `.env` file.
    - Click "Generate Manifest URL", and click to open **Stremio Web**. It will open Stremio web on your browser, and just add the addon!
4. Add CyberFlix for Stremio Catalogging: https://cyberflix.elfhosted.com/.
    - Install it by `click to copy to clipboard`, then go to Stremio Web -> Addons -> `+ Add addon`, then paste the URL and install!

Great! Your Stremio account is set up!

### V. Any Other Clients!

All you have to do now is sign into your Stremio account on any other device, and you should be able to access the same content! It should be downloadable from the Stremio Website, your App Store, etc! Just log in and you're good!

THIS IS EXCEPT iPHONE. iPHONE SETUP IS BELOW.

### VI. iPhone Setup

1. Add `https://web.stremio.com` to your Home Screen.
2. Download OutPlayer from the App Store.
3. Open Stremio from your Home Screen and log in.
4. In the Stremio Settings, set the Default Player to OutPlayer.

Done, easy!

### VII. Remote Access

To stream from your server anywhere, we need to set up Tailscale. This is a VPN that connects your server to your devices, and vice versa. It's a zero-config fast ass VPN that just works, based on WireGuard.

On each client, all you have to do is install Tailscale (including iPhone), log in and connect! Your server is already on there!

Once you do that, try playing something on Stremio to see it work! Also, watch it not work when you get off of Tailscale and you are not on your LAN!

