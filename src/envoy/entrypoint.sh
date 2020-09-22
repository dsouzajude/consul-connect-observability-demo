#!/bin/bash
# Inspired from https://github.com/nicholasjackson/docker-consul-envoy

set -e

# Location of service config
SERVICE_CONFIG_FILE=/consul/config/service.json

# Wait until Consul can be contacted
waitForConsul() {
    log "INFO" "CONSUL_HTTP_ADDR=${CONSUL_HTTP_ADDR}"
    until curl -s ${CONSUL_HTTP_ADDR}/v1/status/leader | grep 8300; do
    log "INFO" "Waiting for Consul to start"
    sleep 1
    done
}

# Re-Generate service config and save to file
generateServiceConfig() {
    export SERVICE_CONFIG=$(echo ${SERVICE_CONFIG_B64} | base64 -d)
    /usr/bin/python3 /service_configurator.py -saveto ${SERVICE_CONFIG_FILE}
    if [ $? -ne 0 ]; then
        log "ERROR" "### Error generating service config ###"
        exit 1
    fi
    log "INFO" "Generated service config at ${SERVICE_CONFIG_FILE}"
}

# Register the service with consul
registerService() {
    # Register the service with consul
    consul services register ${SERVICE_CONFIG_FILE}

    if [ $? -ne 0 ]; then
        log "ERROR" "### Error registering service ###"
        exit 1
    fi
    log "INFO" "Registered service with consul"
}

# Deregister the service from consul
deregisterService() {
    consul services deregister ${SERVICE_CONFIG_FILE}

    if [ $? -ne 0 ]; then
        log "ERROR" "### Error deregistering service ###"
        exit 1
    fi
    log "INFO" "Deregistered service from consul"
}

# Log messages to stdout
log() {
    logLevel="${1:-INFO}"
    message="$2"
    timestamp=`date "+%Y-%m-%d %H:%M:%S"`
    echo "$timestamp $logLevel [configurator] $message"
}


waitForConsul
generateServiceConfig
registerService

# Make sure the service deregisters when exit
trap deregisterService SIGINT SIGTERM EXIT

# Run sidecar proxy for service
service_id=$(cat ${SERVICE_CONFIG_FILE} | jq -r .service.id)
log "INFO" "service_id=${service_id}"
log "INFO" "Running proxy: $@"
set -x
exec consul connect envoy -sidecar-for ${service_id} "$@" &

# Block using tail so the trap will fire
tail -f /dev/null &
PID=$!

# Dump the config
sleep 10
curl localhost:19000/config_dump | jq -r --compact-output

wait $PID
log "INFO" "Done!"
