FROM alpine:3.10

RUN apk add --no-cache curl jq bash git

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]