---
layout: post
title: How to self-host a simple, static blog on a Raspberry Pi with Jekyll, Docker and a Cloudflare
published: false
---

---

When I first created this blog, I settled on using Jekyll and decided to use [GitHub Pages](https://pages.github.com/) as a cost-free hosting solution. That served me well for many years, but once I started playing around with my Raspberry Pi, I really wanted to also use it for hosting my own blog! This is what this post will be about - **how to host your blog on a Raspberry Pi**, using **Jekyll** for *content generation*, **Docker** for *containerization* and **Cloudflare** for *exposing it to the world*!

By the way - this blog post that you're reading **is hosted on a Raspberry Pi**, right next to my desk. If you need to see a real-world scenario on how that looks like - you are on one right now, just have a look around :)

---

## What to expect

I want to show you how to:
* Use Jekyll for generating a static website from a bunch of Markdown files
* Host it on Raspberry Pi as a Docker container
* Use Cloudflare to expose it to the world (without doing anything to your router) cost-free!
* Setup some basic automation using [Just](https://github.com/casey/just)

Note: If you want to expose it to the world, as described in this post, **you need a domain**.

What I will **not** explain (out of scope):
* How to get a DNS domain
* How to setup a DNS domain in Cloudflare
* Advanced Jekyll features

---

## TLDR

If you don't want to go through the whole blog post and just want to see the files, go to this repository on my GitHub: [selhosted-blog-example](https://github.com/rskupnik/selfhosted-blog-example)

---

## Jekyll - generating a website from static Markdown files

[Jekyll](https://jekyllrb.com/) is a Ruby-based solution that allows you to generate a simple static website from a bunch of Markdown files.

I love it because, as a programmer, I find Markdown files very intuitive and easy to maintain. Jekyll is also quite simple, so it's not difficult to add, for example, custom CSS or additional features if you just know a bit of HTML and CSS. It also supports **Themes**, so it's easy to setup a good-looking blog and do some minor (or major) modifications to match your taste.

The generated website is **static**, meaning you can just use a simple server to host it. It's great for simple blogs that just want to deliver their contents to an audience and don't need any *interactive* features, such as comments (although there are solutions for that as well!). Because the website is static, it is also **lightweight**.

### How to start with Jekyll

You can certainly just follow the [Quickstart](https://jekyllrb.com/docs/) on Jekyll's webpage, but I dislike permanently installing software that I only need occasionally (to generate the website) so I will show you how to do that with Docker.

To create a folder called `myblog` with a basic structure we just need to run this:

```bash
docker run --rm -v "$PWD:/srv/jekyll" -it jekyll/jekyll:4.2.2 sh -c "chown -R jekyll /usr/gem/ && jekyll new myblog"
```

Once this passes, you should get a nice `myblog` folder with a bunch of files inside. Normally at this point you should be able to serve your blog, but it seems there is a small **manual change required**: open the `Gemfile` and add this at the very bottom: `gem 'webrick', '~> 1.8', '>= 1.8.1'`

If you now `cd myblog`, you can then run your blog locally to see how it looks like:

```bash
docker run --rm -p 4000:4000 -v "$PWD:/srv/jekyll:Z" jekyll/jekyll:4.2.2 jekyll serve
```

If everything is ok, your blog should be accessible at `localhost:4000`. While the command is running, it will autodiscover any file changes and rebuild the blog on the fly, so you can use it for development.

Note: if you are getting "permission errors", just delete the `_site` and `.jekyll-cache` folders before running the command

I won't got into details of Jekyll's feature, as that's out of scope of this post - but I find it very intuitive. You have a `_posts` folder and any Markdown file you add there will be turned into a post on your blog. For more details on how to work with Jekyll, see [their docs](https://jekyllrb.com/docs/posts/)

### Automation and building

Okay, we can locally run the blog but that's not how we will host it on our Raspberry Pi. Before we can host it though, we need to first learn how to build it (meaning: transform the Markdown files into a static website) - and while we're at it, let's create a `justfile` to automate some of the things.

If you don't yet know [Just](https://github.com/casey/just) - it's a great automation tool, a modern version of Make. You can use it to create simple *recipes* that can then be launched by calling `just something`. These *recipes* are created in a file simply named `justfile`.

Let's see how that file would look like if we wanted to create three simple recipes:
* `just build` to build a static website from our Markdown files
* `just run` to start a local server (useful for development)
* `just open` to open a web browser at `localhost:4000`, just for fun (tested on Mac)

{% raw %}
```bash
build:
    rm -rf _site
    rm -rf .jekyll-cache
    docker run --rm -v "$PWD":/srv/jekyll jekyll/jekyll:4.2.2 sh -c "bundle install && bundle exec jekyll build"

run:
    rm -rf _site
    rm -rf .jekyll-cache
    docker run --rm -p 4000:4000 -v "$PWD:/srv/jekyll:Z" jekyll/jekyll:4.2.2 jekyll serve

open:
    open "http://localhost:4000"
```
{% endraw %}

It's quite self-explanatory. You already know the command in the **run** recipe. The one in **build** is similar, but the output of that command is a `_site` folder - that folder contains your website!; and that is the folder that we will want to move to our Raspberry Pi and serve using Nginx.

---

## Hosting on Raspberry Pi

We can use `just build` to generate static files for our website (the `_site` folder) - we now want to move that folder to Raspberry Pi and host it with an *Nginx* container.

Note: You could just serve the website with the `jekyll/jekyll` container in the same way we did in the **run** recipe - but I prefer to keep Jekyll constrained to a build tool only, and do the serving using a tool specialized to do just that - **Nginx**.

Okay, so to get `myblog` up and running on Raspberry Pi we need to do three things:
* Get **nginx** up and running (with Docker, of course!)
* Configure **nginx** so it knows which files to serve
* Copy our generated website to Raspberry Pi (contents of the `_site` folder which is the result of `just build`)

### Setting up Nginx

Here's a *docker-compose* file for **nginx**:

```yaml
services:
  blog:
    image: nginx:alpine
    container_name: myblog
    restart: unless-stopped
    volumes:
      - /home/pi/myblog/site:/usr/share/nginx/html:ro
      - /home/pi/myblog/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - your-network

networks:
  your-network:
    name: your-network
```

The `your-network` part is a Docker network and it's important to set it up and to make sure that both **nginx** and **cloudflared** (explained further in this post) both belong to it - otherwise they won't be able to see each other!

We also setup two volumes:
* `/home/pi/myblog/site` will contain the website files
* `/home/pi/myblog/nginx.conf` will contain a config file for nginx

Alright, let's now set up **nginx.conf**:

```conf
server {
    listen 80;
    server_name yourcustomdomain.com;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri.html $uri/ =404;
    }

    location /public/ {
        root /usr/share/nginx/html;
    }
}
```

This is a basic configuration that will serve the files in `/usr/share/nginx/html` inside the container (which we bound to `/home/pi/myblog/site` on Raspberry Pi) under `yourcustomdomain.com` on port 80.

Note: We want to use Cloudflare to expose this to the world, which is why we are using `yourcustomdomain.com` and we are not exposing port 80 from nginx container. If you want to be able to access your page from your local network at this stage - expose the port 80 on the nginx container (assuming nothing else on Raspberry Pi claimed that port yet) and delete the `server_name` line from *nginx.conf*.

---

## Pushing all of this to Raspberry Pi

We got our **nginx** docker-compose file and a *nginx.conf* file, let's now create a `justfile` that will push all of this to Raspberry Pi, along with the static website files.

I am assuming the folder structure that is shown in my repository linked in TLDR ([this one](https://github.com/rskupnik/selfhosted-blog-example)) - consult that in case you get lost on what goes where :)

{% raw %}
```bash
rpi_user := "your_rpi_user"
rpi_hostname := "your_rpi_hostname_or_ip"

# Deploy the files
deploy:
    rm -rf site
    cd "../myblog" && just build && cd -
    cp -R "../myblog/_site" site
    rsync -ah --inplace --info=progress2 --no-perms --exclude 'justfile' ./* {{rpi_user}}@{{rpi_hostname}}:/home/pi/myblog/

# Start the service
start:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd myblog && docker compose up -d --build'

# Stop the service
stop:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd myblog && docker compose down'

# Display Docker logs for service
log service:
    ssh {{rpi_user}}@{{rpi_hostname}} 'docker logs -f myblog'
```
{% endraw %}

With this `justfile`:
* `just deploy` will build the website using the `just build` command defined in `myblog` and copy the contents over, then send it to Raspberry Pi using `rsync` (you might need to install it if you don't have it)
* `just start` will start the container
* `just stop` will stop it
* `just log` will show you the logs

---

## Exposing it to the world with Cloudflare

Cloudflare is great! We can use a **Cloudflare Tunnel** to expose `myblog` to the world with little hassle and cost-free (except for getting a domain I guess, but that's not with Cloudflare).

Cloudflare Tunnel works by running a `cloudflared` agent on our Raspberry Pi which directs the traffic where it needs to go. We will set it up as a Docker container, of course, but before we do that you need to **register an account** with [Cloudflare](https://www.cloudflare.com/).

Next step would be to **register a domain**. It is out of scope of this post to go through this, but it's an easy process and Cloudflare will guide you.

After that, go to Cloudflare Dashboard -> Zero Trust -> Networks -> Tunnels.

Then click "create a tunnel", choose "Cloudflared" and name your tunnel. Leave this page open and continue with starting a `cloudflared` service. **Take note of the token**, you will need to provide it soon!

### Installing cloudflared

Here is a *docker-compose* file for getting `cloudflared` runnin on Raspberry Pi:

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel --config /etc/cloudflared/config.yml run
    environment:
      TUNNEL_TOKEN: <your_tunnel_token_here>
    volumes:
      - ./config.yml:/etc/cloudflared/config.yml:ro
    networks:
      - your-network
      
networks:
  your-network:
    name: your-network
```

You need to provide the token that you can see on Cloudflare's Dashboard under the `TUNNEL_TOKEN` environment variable. **DO NOT COMMIT THIS TOKEN AS OPEN TEXT TO YOUR REPO!**. If you need to encrypt it, I suggest using SOPS in combination with a GPG key (a post on this coming up soon).

Now we need a simple `config.yaml` file:

```yaml
ingress:
  - hostname: yourcustomdomain.com
    service: http://myblog:80
  - service: http_status:404  # Default catch-all
```

This will direct traffic for `yourcustomdomain.com` to the `myblog` container we created earlier (that's the one with nginx and your website)

Let's add a `justfile`:

{% raw %}
```bash
rpi_user := "your_rpi_user"
rpi_hostname := "your_rpi_hostname_or_ip"

# Deploy the files
deploy:
    rsync -ah --inplace --no-perms --exclude 'justfile' ./* {{rpi_user}}@{{rpi_hostname}}:/home/pi/cloudflared/

# Start the service
start:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd cloudflared && docker compose up -d --build'

# Stop the service
stop:
    ssh {{rpi_user}}@{{rpi_hostname}} 'cd cloudflared && docker compose down'

# Display Docker logs for service
log service:
    ssh {{rpi_user}}@{{rpi_hostname}} 'docker logs -f cloudflared'
```
{% endraw %}

Now you can run `just deploy && just start && just log` to deploy, start and view the logs of `cloudflared`.

Observe both the logs and the website you have open to see if they connect.

The website should show a Connector once a connection is established and allow you to finish the tunnel setup.

---

Once this is done and you give it a bit of time, accessing **yourcustomdomain.com** should result in viewing the contents of your blog on the Raspberry Pi!