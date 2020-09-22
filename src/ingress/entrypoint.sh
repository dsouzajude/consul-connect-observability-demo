#!/bin/bash

set -e

# Location of config dir
INGRESS_CONFIG=/consul/config/ingress-gateway.json

waitForConsul() {
    log "INFO" "CONSUL_HTTP_ADDR=${CONSUL_HTTP_ADDR}"
    until curl -s ${CONSUL_HTTP_ADDR}/v1/status/leader | grep 8300; do
    log "INFO" "Waiting for Consul to start"
    sleep 1
    done
}

registerIngressGateway() {
    consul config write $INGRESS_CONFIG

    if [ $? -ne 0 ]; then
        log "ERROR" "### Error registering Ingress Gateway ###"
        exit 1
    fi
    log "INFO" "Registered Ingress Gateway"
}

log() {
    logLevel="${1:-INFO}"
    message="$2"
    timestamp=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$timestamp $logLevel [configurator] $message"
}


waitForConsul
registerIngressGateway

# Start the Ingress Gateway
ingress_service=$(cat $INGRESS_CONFIG | jq -r .Name)
log "INFO" "ingress_service=${ingress_service}"
container_metadata=$(curl ${ECS_CONTAINER_METADATA_URI})
log "INFO" "Container Metadata: ${container_metadata}"
address=$(echo ${container_metadata} | jq -r .Networks[0].IPv4Addresses[0])
log "INFO" "container_ip=${address}"
log "INFO" "Running Ingress Gateway: $@"
set -x
exec consul connect envoy -gateway=ingress \
                          -register \
                          -service=${ingress_service} \
                          -address=${address}:8888 \
                          "$@" &

# Block using tail so the trap will fire
tail -f /dev/null &
PID=$!

# Dump the config
sleep 10
curl localhost:19000/config_dump | jq -r --compact-output

wait $PID
log "INFO" "Done!"
