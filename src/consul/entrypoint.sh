#!/bin/sh
set -xe

# Script to generate necessary Consul configuration so
# that Consul can bootstrap seamlessly.

set -e

DATA_DIR=/consul/data
CONFIG_DIR=/consul/config

# Defaults
MODE=${MODE:-client}

# In Operator mode, you consul commands
if [ "$MODE" == "operator"  ]; then
    # Write config entries
    for fname in /usr/share/consul/config/operator/config-entries/*.hcl; do
        consul config write $fname
    done
    set -- "$@"
else
    # In non-operator mode, you run either as client or server
    # Copy agent configurations based on the mode
    cp /usr/share/consul/config/$MODE/*.json $CONFIG_DIR/

    # Generate additional configuration for autodiscovery
    /scripts/discovery.py -mode $MODE \
                          -saveto $CONFIG_DIR/discovery.json \
                          -ecs-cluster $CONSUL_ECS_CLUSTER \
                          -ecs-family $CONSUL_ECS_SERVICE

    set -- consul agent \
                -config-dir $CONFIG_DIR \
                -data-dir="$DATA_DIR" \
                "$@"
fi

# Let the process run as PID=1
exec "$@"
