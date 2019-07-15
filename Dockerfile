FROM python:3-alpine

RUN apk add --no-cache curl && \
    curl --fail --silent -L https://github.com/just-containers/s6-overlay/releases/download/v1.21.8.0/s6-overlay-amd64.tar.gz | \
    tar xzvf - -C /

COPY ./services /etc/services.d/
ENTRYPOINT [ "/init" ]
