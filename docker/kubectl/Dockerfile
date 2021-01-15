FROM docker:dind

LABEL maintainer="sunsky <sunsky303@qq.com>"

ARG TZ="Asia/Shanghai"

ENV TZ ${TZ}

ENV KUBE_VERSION v1.9.0

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
RUN apk upgrade --update \
    && apk add bash tzdata wget ca-certificates\
    && wget https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && rm -rf /var/cache/apk/*

CMD ["/bin/bash"]