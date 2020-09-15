#FROM consul:1.8.3
FROM hashicorpdev/consul:4223d4f83

FROM python:3.8-alpine
COPY --from=0 /bin/consul /bin/consul

# Required to discover Consul servers and generate configs
ENV MODE=client
ENV AWS_REGION=eu-west-1
ENV CONSUL_ECS_CLUSTER=consul
ENV CONSUL_ECS_SERVICE=consul
ENV BOOTSTRAP_EXPECT=1

# Prerequisites
RUN apk update && apk add curl && \
    pip install botocore boto3 requests && \
    mkdir -p /usr/share/consul/config/server /usr/share/consul/config/client /usr/share/consul/config/operator /scripts

COPY config/server/*.json /usr/share/consul/config/server/
COPY config/client/*.json /usr/share/consul/config/client/
COPY config/operator/ /usr/share/consul/config/operator/

# Add scripts to configure and bootstrap Consul
ADD discovery.py entrypoint.sh /scripts/
RUN chmod oug+x /scripts/discovery.py /scripts/entrypoint.sh

# Expose Consul necessary ports
EXPOSE 8300 8301 8302 8500 8600
EXPOSE 8301/udp 8302/udp 8600/udp

# Volume to be shared with other containers for bootstrapping
VOLUME /consul/config

# Expose the consul data directory as a volume since there's mutable state in there.
VOLUME /consul/data

ENTRYPOINT ["/scripts/entrypoint.sh"]

CMD ["-dev", "-client", "0.0.0.0"]
