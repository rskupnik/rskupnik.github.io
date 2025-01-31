build:
    docker run --rm -v "$PWD":/srv/jekyll -w /srv/jekyll jekyll/jekyll jekyll build

start:
    docker run -d --name blog --rm -v "$PWD":/usr/src/app -p "4000:4000" starefossen/github-pages

stop:
    docker stop blog

open:
    open "http://localhost:4000"