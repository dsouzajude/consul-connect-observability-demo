# FROM consul:1.8.0
# FROM envoyproxy/envoy-alpine:v1.14.4
FROM hashicorpdev/consul:4223d4f83
FROM envoyproxy/envoy-alpine:v1.15.0
COPY --from=0 /bin/consul /bin/consul

ENV CONSUL_HTTP_ADDR=http://localhost:8500 \
    CONSUL_GRPC_ADDR=http://localhost:8502

RUN apk update && \
    apk add -u bash curl netcat-openbsd jq && \
    mkdir -p /consul/config

ADD ingress-gateway.json /consul/config/
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

