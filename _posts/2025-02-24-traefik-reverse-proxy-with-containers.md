---
layout: post
title: How to setup Traefik as a reverse-proxy for containerized applications
---

---

Here's how I use Traefik as a Reverse Proxy for my containerized applications hosted on Raspberry Pi.

If you already know what all of this means and you just want a quick recipe, here's a TLDR for you - otherwise, scroll past the TLDR and I will do my best to explain!

---

## TLDR

<script src="https://gist.github.com/rskupnik/5f591ad09a219a6bc4fb9f3a2dfb1cce.js"></script>

---

## What is a reverse proxy good for?

A regular proxy should really be rather called "Forward Proxy" - it's something that sits in the middle between you and **whatever it is you are trying to reach**. You router, for example, is a proxy - if you want to access a webpage, your request first goes to your router, which then proxies your request further out into the world.

A "Reverse Proxy", on the other hand, is something that sits between you and whatever it is that **wants to interact with you**. A secretary to some Very Important CEO is a reverse proxy - before you get to talk with the guy, you need to first book an appointment and get through his secretary.

If you are self-hosting a bunch of web applications on a single server, what are your options when it comes to accessing them?

One option is to use different ports for each app - but that gets difficult to manage with time. You need to remember that `PiHole`, for example, is at port `8080` and `Some other app` is at port `8081` - it's easy to forget after some time.

Reverse proxy is another option - each request that reaches your server goes through the reverse proxy software which decides which particular web applications are you trying to reach - and directs the traffic accordingly.

How does it know what you want to reach? There are many ways, but the simplest to explain is **subpaths**. Let's say your server's hostname is `raspberrypi5.local` - you can setup your reverse proxy in such a way that:
* Request to `raspberrypi5.local/pihole` directs you to **PiHole**
* Request to `raspberrypi5.local/matomo` directs you to **Matomo**
* etc.

Another solution, if you own a domain, is using subdomains:
* Request to `pihole.yourdomain.com` directs you to **PiHole**
* Request to `matomo.yourdomain.com` directs you to **Matomo**
* etc.

There are some limitations (mainly with subpaths) - the application you are directing traffic to needs to be able to be configured so that it knows it is being served under a subpath, etc. Most of the apps are able to be configured that way, and if they are not - then you can usually solve that problem by using a subdomain instead.

---

## How to set it up with Raspberry Pi and containers

I use Docker and docker-compose files to host all my apps on my Raspberry Pi. Adding a reverse proxy to this scenario is quite simple.

First, you need a Reverse Proxy Software. There are many options out there, the main ones being `Nginx` and `Traefik`. I decided to use the latter, for no particular reason other than I already hade some familiarity with it.

Here's how a **docker-compose file for Traefik** looks like in my setup:

```yaml
services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api=true"
      - "--api.insecure=true"
      - "--providers.file.directory=/etc/traefik/dynamic"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--providers.docker.exposedbydefault=false"
    ports:
      - "80:80"
      - "8080:8080" # Traefik dashboard (optional)
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./config:/etc/traefik/dynamic"
    networks:
      - your-network

networks:
  your-network:
    name: your-network
```

This will create a container named **traefik** which uses **traefik v2.10**. It claims the default port **80** and also exposes a management dashboard on port **8080**.

You also need to remember about these important details:
* It needs access to the `docker.sock`
* I also bind the `./config` folder to `/etc/traefik/dynamic` to setup what Traefik calls "Dynamic Config" files - more on that below
* It needs to be part of the same Docker network that your other web applications are - `your-network` in this example

### Dynamic Config files

The docker-compose file above will deploy a Traefik instance, but how do we configure what web applications we want to reach and how to reach them? Traefik, as far as I know, can do that either using labels - in which case you add a bunch of labels to the docker-compose files of your other web applications - or using Dynamic Configuration, where you create dedicated `yaml` config files.

I prefer using Dynamic Config because otherwise, if I add traefik-related labels to my other applications, those applications are then "polluted" by traefik details. If I decide to switch from Traefik to something else then I will have to go through each application and remove the traefik-related labels from each of them - I'd like to avoid that, so I'd much rather use separate config files.

In the `docker-compose.yml` file above we bound the `./config` folder to `/etc/traefik/dynamic` - so whatever `yaml` files we put into `./config` should be picked up by Traefik. Here's how a very basic config file for an example web application would look like:

```yaml
# This exposes an example service called "dummy" hosted as another docker container (under port 8080), with the name "dummy" under the path "raspberrypi5.local/dummy"
# It needs to be part of the same "your-network" Docker network!
# This file needs to sit in "config" folder (relative to where the docker-compose.yml is) - or modify docker-compose.yml accordingly

http:
  routers:
    dummy:
      rule: "Host(`raspberrypi5.local`) && PathPrefix(`/dummy`)"
      service: "dummy"

  services:
    dummy:
      loadBalancer:
        servers:
          - url: "http://dummy:8080"
```

It's quite simple - we define a *router* (called *dummy*) which will fish for traffic coming to the hostname `raspberrypi5.local` and the path `/dummy` - that traffic will be directed to the *service* (also called *dummy*, cause why not). That *service* is defined below the *router* and directs the traffic to `http://dummy:8080` - which will reach the **dummy** container at port `8080`.

---

That's all! If you deploy this, you should now be able to go to `http://raspberrypi5.local/dummy` and Traefik Reverse Proxy will direct you to your **dummy** service.

---

## Bonus: Deploying with just

I like to use a great tool called [Just](https://github.com/casey/just) to create some basic recipes to manage my Raspberry Pi.

Just is an automation tool, like a modern version of Make, that allows you to create those simple commands (called recipes) and then execute by simply running `just something`.

Here's what I use for Traefik:

{% raw %}
```bash
rpi_user := "your_rpi_user"
rpi_hostname := "your_rpi_hostname_or_ip"

# Copy all the files (excluding MD, png) to /home/pi/traefik
deploy:
    rsync -avh --inplace --no-perms --exclude '*.MD' --exclude '*.png' ./* {{rpi_user}}@{{rpi_hostname}}:/home/pi/traefik/

# Start the service
start:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd traefik && docker compose up -d --build'

# Stop the service
stop:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd traefik && docker compose down'

# Display Docker logs for service
log service:
    ssh {{rpi_user}}@{{rpi_hostname}} 'docker logs -f traefik'
```
{% endraw %}

With this in place you can call `just deploy && just start && just log` to launch the app and see the logs.