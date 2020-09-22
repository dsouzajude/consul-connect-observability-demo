# FROM consul:1.8.3
# FROM envoyproxy/envoy-alpine:v1.14.4
FROM hashicorpdev/consul:4223d4f83
FROM envoyproxy/envoy-alpine:v1.15.0
COPY --from=0 /bin/consul /bin/consul

ENV CONSUL_HTTP_ADDR=http://localhost:8500
ENV CONSUL_GRPC_ADDR=http://localhost:8502

RUN apk update && \
    apk add -u bash curl netcat-openbsd python3 py-pip jq && \
    mkdir -p /consul/config && \
    pip install requests argparse

ADD service_configurator.py /service_configurator.py
RUN chmod +x /service_configurator.py

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

