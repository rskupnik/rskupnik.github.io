build-old:
    rm -rf _site
    rm -rf .jekyll-cache
    docker run --rm -v "$PWD":/srv/jekyll jekyll/jekyll:4.2.2 sh -c "bundle install && bundle exec jekyll build"

run:
    rm -rf _site
    rm -rf .jekyll-cache
    docker run --rm -p 4000:4000 -v "$PWD:/srv/jekyll:Z" jekyll/jekyll:4.2.2 jekyll serve

build:
    docker buildx create --use
    docker buildx build --platform linux/arm64 -t myzopotamia-blog --load .

push:
    docker tag myzopotamia-blog rskupnik/myzopotamia-blog
    docker push rskupnik/myzopotamia-blog

open:
    open "http://localhost:4000"