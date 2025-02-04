build:
    rm -rf _site
    rm -rf .jekyll-cache
    docker run --rm -v "$PWD":/srv/jekyll jekyll/jekyll:4.2.2 sh -c "bundle install && bundle exec jekyll build"

start:
    docker run -d --name blog --rm -v "$PWD":/usr/src/app -p "4000:4000" starefossen/github-pages

stop:
    docker stop blog

open:
    open "http://localhost:4000"