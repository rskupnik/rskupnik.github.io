---
layout: post
title: Self-hosting Pi-hole behind a reverse proxy
---

When self-hosting my Pi-hole I wanted to put it behind my reverse proxy on a subpath, like this: **https://raspberrypi5.local/pihole**. Sounds simple enough but it was suprisingly complex to set up in a way for all the static assets and redirects to still work properly.

These issues also apply when trying to host under a custom domain, such as **https://pihole.home/**

Note: I am using **Traefik** as my reverse proxy (with Dynamic Config)

---

## The problem

There are several problems with hosting Pi-hole on a sub-path reverse proxy:
* Pi-hole want the dashboard to be accessed under `/admin/` - it will keep redirecting there
* Pi-hole does some redirections using the `Location` header - which will be invalid if you don't handle it properly
* It will not be able to find static assets (CSS files, JS scripts, etc.)

---

## The solution

To solve these, I have setup two *middlewares* in my *traefik* config file for Pi-hole:
* Rewrite `/pihole/` to `/admin/` so Pi-hole can handle those properly
* Replace `admin` in the `Location` header with `pihole`

Here's how the config file looks like:

```yaml
http:
  routers:
    pihole-path:
      rule: "Host(`raspberrypi5.local`) && PathPrefix(`/pihole`)"
      service: "pihole-service"
      middlewares:
        - "pihole-rewrite"
        - "pihole-location-rewrite"

  middlewares:
    # Rewrite requests from /pihole to /admin
    pihole-rewrite:
      replacePathRegex:
        regex: "^/pihole(/.*)?$"
        replacement: "/admin$1"

    # Rewrite Location headers in responses from /admin to /pihole
    pihole-location-rewrite:
      plugin:
        rewriteheaders:
          rewrites:
              - header: Location
                regex: ^/admin/$
                replacement: /pihole/

  services:
    pihole-service:
      loadBalancer:
        servers:
          - url: "http://pihole:80"

```

Note: The `rewriteheaders` middleware is not available by default, it's a plugin, see [github page](https://github.com/virtualzone/rewriteheaders)

I installed that plugin by adding these two flags to my **traefik** setup:
* `--experimental.plugins.rewriteheaders.modulename=github.com/virtualzone/rewriteheaders`
* `--experimental.plugins.rewriteheaders.version=v0.2.0`

With this in place, Pi-hole should work under the `/pihole` path without any issues

---

## Make it work for a custom domain instead

You can also make it work for a custom domain, such as `https://pihole.home`:

```yaml
http:
  routers:
    # Router for host-based access (pihole.home)
    pihole-host:
      rule: "Host(`pihole.home`)"
      service: "pihole-service"
      middlewares:
        - "pihole-rewrite-for-host"
        - "pihole-location-rewrite-for-host"

  middlewares:
    # Rewrite requests from / to /admin
    pihole-rewrite-for-host:
      replacePathRegex:
        regex: "^(/.*)?$"
        replacement: "/admin$1"
    
    # Rewrite Location headers in responses from /admin to /
    pihole-location-rewrite-for-host:
      plugin:
        rewriteheaders:
          rewrites:
              - header: Location
                regex: ^/admin/$
                replacement: /

  services:
    pihole-service:
      loadBalancer:
        servers:
          - url: "http://pihole:80"

```

Hope this helps!