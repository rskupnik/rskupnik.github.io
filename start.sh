#!/bin/bash
sudo docker run -t --rm -v /opt/workspace/blog/rskupnik.github.io:/usr/src/app -p "4001:4000" starefossen/github-pages
