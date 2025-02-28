---
layout: post
title: How to setup local network domains with dockerized Traefik and Pihole
---

If you're running a reverse proxy, you might want to setup easy local domains to access your applications. For example:
* **http://pihole.home/** for PiHole
* **http://matomo.home/** for Matomo
* **http://n8n.home/** for N8N

etc.

It's quite easy to do with Traefik as a Reverse Proxy and Pihole as a DNS provider

Note: I won't be explaining installation of Traefik and Pihole, as I already have separate posts on that:
* [Traefik Reverse Proxy for containerized applications](/traefik-reverse-proxy-with-containers)
* [Self-host Pi-hole behind a reverse proxy](/selfhost-pihole-on-reverse-proxy)

---

## Setting up custom DNS domains

With the Reverse Proxy setup, we want to create some custom DNS entries (like `pihole.home`, for example) and point them to our Raspberry Pi (or other machine) - then let *Traefik* route the traffic based on the hostname.

You can manually setup the DNS entries in Pi-Hole's UI, but I'd suggest making it more permanent. With Pi-hole being installed as a Docker container, all you need to do is provide a `/etc/pihole/custom.list` file.

My *docker-compose.yml* file for Pi-hole looks like this:

```yaml
services:
    pihole:
        container_name: pihole
        image: pihole/pihole:latest
        ports:
            - 53:53/tcp
            - 53:53/udp
        environment:
            TZ: Europe/Warsaw
            WEBPASSWORD: PasswordHere
        volumes:
            - ./etc-pihole:/etc/pihole
            - ./custom.list:/etc/pihole/custom.list
        restart: unless-stopped
        networks:
            - raspberry-pi-network
networks:
    raspberry-pi-network:
        name: raspberry-pi-network
```

Notice how `./custom.list` is mounted to `/etc/pihole/custom.list`.

The `custom.list` is just a mapping of IPs to domains:

```
192.168.0.15   pihole.home
192.168.0.15   matomo.home
192.168.0.15   n8n.home
```

I point them all to the IP address of the Raspberry Pi - *Traefik* will sort out the traffic based on the hostname.

---

## Making Traefik aware of the hostnames

Here's an example dynamic config file for Traefik to handle `n8n.home`:

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

Simple as that! Setup similar files for other services and Traefik will be able to tell where to direct you based on the hostname itself.

With this in place, going to `http://n8n.home/` will now direct my traffic to the Raspberry Pi (as the DNS instructs), then to the `n8n` container (as configured on Traefik).

Note: If you want more details on setting up Traefik and its Dynamic Configuration, see [here](/traefik-reverse-proxy-with-containers#dynamic-config-files)