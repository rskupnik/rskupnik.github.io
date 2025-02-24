---
layout: post
title: How to self-host n8n but expose the path for OAuth2 authentication
published: false
---

TODOS:
* TLDR (embedd a gist?)
* Replace myzopotamia.dev with `<your_custom_domain>`
* Some diagram
* Info panels

Might be useful to describe how to setup traefik beforehand to link to that (or at least a gist)

---

I tried self-hosting n8n and I love it, but there was one problem I was facing - I could not create Credentials for Google integrations (Drive, Gmail, etc.) because it required my n8n instance to be reachable from the internet.

I solved it by exposing only that one particular path that Google needs to reach on my reverse proxy setup and keeping the rest hidden.

This is a known issue and there are many solutions, this is just one of them. It includes:
* A Cloudflare Tunnel
* A custom domain (not entirely sure if it is required, but I already had one)
* Reverse proxy (I use traefik)

---

## TLDR

TODO

---

## My setup and what I want to achieve

I am currently self-hosting all of my apps on my **Raspberry Pi 5** using **Docker**.

One of the containers is **traefik** which serves as a reverse proxy.

What I want to show you in this post:
1. How to create a `docker-compose.yml` file to deploy n8n to RPi
2. How to configure an existing **traefik** reverse proxy to reach **n8n** from within home network (NOT the internet)
3. How to expose Google's expected OAuth path to the internet so that Google integrations work

Prerequisites - what I will **NOT** describe here (out of scope):
* How to setup a Raspberry Pi
* How to create an OAuth client on Google
* How to setup your DNS
* How to setup traefik reverse proxy from the grounds up (only how to **configure** an existing installation)

---

## Installing n8n as a Docker container on Raspberry Pi 5

The first step is to actually get n8n installed. I use `docker-compose.yml` combined with some simple `just` recipes to get it deployed to RPi.

Here's the `docker-compose.yml` for **n8n**:

```yaml
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    environment:
      N8N_HOST: n8n.home
      N8N_PORT: 5678
      N8N_PROTOCOL: http
      N8N_SECURE_COOKIE: false
      NODE_ENV: production
      WEBHOOK_URL: https://n8n.myzopotamia.dev/
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - raspberry-pi-network

volumes:
  n8n_data:

networks:
  raspberry-pi-network:
    name: raspberry-pi-network
```

It is quite self-explanatory, but let me explain a few important items here:
* The `n8n.home` value of `N8N_HOST` is my internal domain, it will only work from within my local network
* `WEBHOOK_URL` is set to my DNS domain (with a subdomain of `n8n` for clarity) so that n8n produces a properly formatted OAuth URL
* The `raspberry-pi-network` Docker network needs to be the same network that **traefik** container also connects to - so that it is able to redirect traffic to **n8n**

### How to deploy this to Raspberry Pi

I have quite an elaborate `justfile` system for deploying my Docker containers to Raspberry Pi, but it can be simplified to this:

{% raw %}
```bash
# Copy all the files (excluding MD, png) to /home/pi/n8n
deploy:
    rsync -avh --inplace --no-perms --exclude '*.MD' --exclude '*.png' * {{rpi_user}}@{{rpi_hostname}}:/home/pi/n8n/

# Start the service
start:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd n8n && docker compose up -d --build'

# Stop the service
stop:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd n8n && docker compose down'

# Display Docker logs for service
log:
    ssh {{rpi_user}}@{{rpi_hostname}} 'docker logs -f n8n'
```
{% endraw %}

Now I can simply run `just deploy && just start` to get n8n running and inspect it with `just log`

If you don't know what `just` and `justfiles` are - [Just](https://github.com/casey/just) is like a modern version of Make. You can create simple recipes like those described above and execute them. It's a great tool, I use it all the time!

---

## Plugging in to traefik reverse proxy

At this point you should have **n8n** up and running, but we want to be able to access it from within the home network. In my case, I want it to be available under `n8n.home/`. This is **not** something that will work by default, if you want that particular domain to work for your internal network you need to configure it in your DNS (**pihole** in my case) - just point it at the IP address of your Raspberry Pi

I prefer working with Dynamic Configurations in **traefik** instead of using labels, here's my initial configuration for **n8n**:

```yaml
http:
  routers:
    n8n:
      rule: "Host(`n8n.home`)"
      entrypoints:
        - "web"
      service: "n8n"

  services:
    n8n:
      loadBalancer:
        servers:
          - url: "http://n8n:5678"

```

It's as simple as they come - we want traffic from the host **n8n.home** to be directed to **http://n8n:5678**. This weird URL is constructed from the **container_name** param in n8n's docker-compose file and the port n8n expects to be reached on (`N8N_PORT`). Traefik will be able to reach n8n through this URL **only if they live in the same Docker network**.

After restarting **traefik** with this new configuration you should now be able to reach **n8n** from within my local network on `n8n.home/` (or whatever domain you want to use internally)

---

## Allowing access from the internet to Google's expected OAuth URL

Alright, we have a working n8n installation reachable from local network, so now we can move to the gist of this post - exposing a single URL to the outside world so that OAuth-based integration with Google's services can be done successfully.

I accomplished that by leveraging two things I already had:
* A Cloudflare Tunnel (which is used to host this exact blog you are reading right now)
* A custom domain

The URL that Google needs to be able to reach is: `<base_url>/rest/oauth2-credential`, where `<base_url>` is constructed based on the `WEBHOOK_URL` environment variable passed to **n8n**.

Let's start by modifying **traefik**'s configuration (the same one created in the previous step).

Apart from accessing from `n8n.home` internally, we want that specific `/rest/oauth2-credential` URL to also be reachable from the internet - but only for the `n8n.myzopotamia.dev` host (which is my custom domain).

To do that I added modified the Dynamic Configuration for **traefik** to look like this:

```yaml
http:
  routers:
    n8n:
      rule: "Host(`n8n.home`)"
      entrypoints:
        - "web"
      service: "n8n"

    n8n_myzopotamia:
      rule: "Host(`n8n.myzopotamia.dev`) && PathPrefix(`/rest/oauth2-credential`)"
      entrypoints:
        - "web"
      service: "n8n"
      
    n8n_myzopotamia_deny:
      rule: "Host(`n8n.myzopotamia.dev`)"
      entrypoints:
        - "web"
      service: "deny-all"

  services:
    n8n:
      loadBalancer:
        servers:
          - url: "http://n8n:5678"

    deny-all:
      loadBalancer:
        servers:
          - url: "http://0.0.0.0"  # A dummy service that always fails
```

Notice two additional *routers*:
* *n8n_myzopotamia* router will direct traffic to **n8n** container if it comes from `n8n.myzopotamia.dev` host and only for the `/rest/oauth2-credential` path
* *n8n_myzopotamia_deny* router will **deny** all other traffic on the host `n8n.myzopotamia.dev` (by directing it to `http://0.0.0.0`, which will not resolve) (not sure if there is a better way to do it, let me know a better solution!)

Great! All that is left to be done is to let `cloudflared` (setting up of which is outside the scope for this post) know about my `n8n.myzoptamia.dev` domain and tell it to direct traffic for it to `traefik`. I add this to `cloudflared`'s config (again, it is able to reach `http://traefik:80` because those containers connect to the same network)

```yaml
(...)
- hostname: n8n.myzopotamia.dev
    service: http://traefik:80
(...)
```

---

That's it! At this point you should be able to:
* Reach **n8n** in it's entirety from `n8n.home` (or whatever internal domain you use)
* Be able to setup OAuth Credentials for Google because `https://n8n.myzopotamia.dev/rest/oauth2-credential` will resolve and reach the destination
* No other part of **n8n** will be reachable from `https://n8n.myzopotamia.dev`