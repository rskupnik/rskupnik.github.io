FROM ruby:3.0-alpine AS builder

# Install system dependencies
RUN apk add --no-cache build-base nodejs npm git

# Create and set work directory
WORKDIR /site

# Install Jekyll and Bundler gems
RUN gem install bundler jekyll

# Cache gem dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the rest of the source files
COPY . .

# Build the Jekyll site
RUN bundle exec jekyll build

FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /site/_site/public /usr/share/nginx/html/public
COPY --from=builder /site/_site/about /usr/share/nginx/html/about
COPY --from=builder /site/_site/*.html /usr/share/nginx/html

EXPOSE 80
