FROM jekyll/jekyll:4.2.2 AS builder

# Switch to root so we can set up permissions correctly
USER root

WORKDIR /site

# Copy site source files into the image
COPY . .

# Fix permissions for the jekyll user
RUN chown -R jekyll:jekyll /site

# Use environment variables to avoid permission issues with gems/cache
ENV GEM_HOME=/tmp/gems \
    BUNDLE_PATH=/tmp/gems \
    JEKYLL_CACHE_DIR=/tmp/.jekyll-cache

# Drop back to the jekyll user
USER jekyll

# Install dependencies and build the site
RUN bundle install && bundle exec jekyll build

# Stage 2: Nginx to serve the static site
FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /site/_site/public /usr/share/nginx/html/public
COPY --from=builder /site/_site/about /usr/share/nginx/html/about
COPY --from=builder /site/_site/*.html /usr/share/nginx/html

EXPOSE 80
