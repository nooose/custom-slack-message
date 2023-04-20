FROM public.ecr.aws/docker/library/alpine:3.10

RUN apk add --no-cache curl jq bash git

COPY entrypoint.sh /entrypoint.sh
COPY build_payload.json /build_payload.json

ENTRYPOINT [ "/entrypoint.sh" ]
