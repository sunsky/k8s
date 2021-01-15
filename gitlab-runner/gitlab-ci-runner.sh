#!/usr/bin/env bash

rm -rf /srv/gitlab-runner/config/

docker run -d --name gitlab-runner --restart always \
   -v /srv/gitlab-runner/config:/etc/gitlab-runner \
   -v /var/run/docker.sock:/var/run/docker.sock \
   gitlab/gitlab-runner:latest



docker run --rm -t -i -v /srv/gitlab-runner/config:/etc/gitlab-runner gitlab/gitlab-runner register \
  --non-interactive \
  --executor "docker" \
  --docker-image alpine:stable \
  --url "https://git.staff.sina.com.cn/" \
  --registration-token "cfBdj_Y4jWbwDfxMqXvJ" \
  --description "cms-runner" \
  --tag-list "docker,cms,runner" \
  --run-untagged="true" \
  --locked="false" \
  --docker-privileged

#'http://cmsdev:!!Yhb6sqt!!@gitlab/sinacms/APIServer.git'


docker login -u cmsdev  registry.api.weibo.com --password '!!Yhb6sqt!!'