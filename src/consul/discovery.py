#!/usr/bin/env python
# -*- coding: utf-8 -*-

# ------------------------------------------------------------------------------
# To run the discovery script:
#
# python /discovery.py -mode <client|server> \
#                      -ecs-cluster <ECS_CLUSTER> \
#                      -ecs-family <ECS_FAMILY> \
#                      -saveto <FILENAME>
# ------------------------------------------------------------------------------

import os
import sys
import time
import json
import logging
from logging.config import dictConfig

import requests
import boto3
import argparse


log_levels = {
    'DEBUG': logging.DEBUG,
    'INFO': logging.INFO,
    'WARNING': logging.WARNING,
    'ERROR': logging.ERROR,
    'CRITICAL': logging.CRITICAL
}

# Constants via environment variables
AWS_REGION = os.environ["AWS_REGION"]
BOOTSTRAP_EXPECT = int(os.environ.get("BOOTSTRAP_EXPECT", 1))

MODE_SERVER = "server"
MODE_CLIENT = "client"


def setup_logging(log_level):
    logging_config = dict(
        version = 1,
        formatters = {
            'simple': {
                'format': '%(asctime)s %(levelname)-8s %(message)s'
            }
        },
        handlers = {
            'console': {
                'class': 'logging.StreamHandler',
                'formatter': 'simple',
                'level': log_level,
                'stream': 'ext://sys.stdout'
            }
        },
        root = {
            'handlers': ['console'],
            'level': log_level,
        },
    )
    dictConfig(logging_config)
    return logging.getLogger(__name__)

log = setup_logging(log_levels.get(os.environ.get("LOG_LEVEL", "INFO")))


def generate_node_name(mode, task_metadata):
    return "{}-{}-{}-{}".format(
        mode,
        task_metadata['family'],
        task_metadata['ip'].replace(".", "-"),
        task_metadata['task_id']
    )


def get_task_metadata():
    metadata_uri = os.environ["ECS_CONTAINER_METADATA_URI"]
    resp = requests.get("{}/task".format(metadata_uri))
    log.info("Original Task Metadata \n%s" % resp.text)
    resp = json.loads(resp.text)
    ip = resp["Containers"][0]["Networks"][0]["IPv4Addresses"][0]
    task_id =  resp['TaskARN'].split("/")[2]
    return {"task_id": task_id, "family": resp['Family'], "ip": ip}


def discover_server_ips(consul_cluster_name,
                        consul_family_name,
                        max_ips=BOOTSTRAP_EXPECT):
    """ Gets the ECS tasks for all consul server services and extracts the
    private IP from it and return it.

    Since during bootstrap containers may take a bit of time to start, the logic
    needs to wait for a minimum of `max_ips` to get in the RUNNING state.
    """
    sleep_time_s = 30
    task_ips = []
    while True:
        ecs = boto3.client("ecs", AWS_REGION)
        resp = ecs.list_tasks(
            maxResults=max_ips,
            cluster=consul_cluster_name,
            family=consul_family_name,
            desiredStatus='RUNNING'
        )
        task_arns = resp["taskArns"]
        log.info("Got task_arns=%s" % task_arns)
        if (max_ips-len(task_arns)) != 0:
            log.info("Waiting %s(s) for %s tasks more to bootstrap" % (sleep_time_s, (max_ips-len(task_arns))))
            time.sleep(sleep_time_s)
        else:
            break

    resp = ecs.describe_tasks(cluster=consul_cluster_name, tasks=task_arns)
    task_containers = [t['containers'][0] for t in resp['tasks']]
    task_ips = [
        c['networkInterfaces'][0]['privateIpv4Address'] for c in task_containers
    ]
    log.info("Got task_ips=%s" % task_ips)
    return task_ips


def generate_config(mode,
                    task_metadata,
                    consul_cluster_name,
                    consul_family_name):
    """ Generates client or server specific Consul configs depending on the mode """
    if mode == MODE_SERVER:
        return json.dumps({
            "bind_addr": task_metadata["ip"],
            "advertise_addr": task_metadata["ip"],
            "bootstrap_expect": BOOTSTRAP_EXPECT,
            "datacenter": AWS_REGION,
            "node_name": generate_node_name(mode, task_metadata),
            "retry_join": discover_server_ips(
                consul_cluster_name,
                consul_family_name
            )
        })
    return json.dumps({
        "bind_addr": task_metadata["ip"],
        "datacenter": AWS_REGION,
        "node_name": generate_node_name(mode, task_metadata),
        "retry_join": discover_server_ips(
            consul_cluster_name,
            consul_family_name
        )
    })


def dump_config(config, filename):
    log.info("Saving config to file, filename==%s" % filename)
    with open(filename, "w") as f:
        f.write(config)


def _parse_args():
    parser = argparse.ArgumentParser(
        prog='consul_discovery',
        usage='%(prog)s [options]',
        description='Discovers consul servers and generates a discovery configuration file.'
    )
    parser.add_argument(
        '-mode',
        type=str,
        nargs=1,
        metavar=("mode"),
        required=True,
        default="client",
        help='Run script for "client" or "server" mode.'
    )
    parser.add_argument(
        '-ecs-cluster',
        type=str,
        nargs=1,
        metavar=("ecs-cluster"),
        required=True,
        help='ECS Cluster name where Consul servers run'
    )
    parser.add_argument(
        '-ecs-family',
        type=str,
        nargs=1,
        metavar=("ecs-family"),
        required=True,
        help='ECS Task Family name for Consul server task'
    )
    parser.add_argument(
        '-saveto',
        type=str,
        nargs=1,
        metavar=("saveto"),
        required=True,
        default="/consul/config/server-discovery.json",
        help='Absolute path of (JSON) filename to store the consul configuration.'
    )
    return parser


def main():
    """ Generates a consul config and dumps it to a specified file

    To run:
        python /discovery.py -mode <client|server> \
                             -ecs-cluster <ECS_CLUSTER> \
                             -ecs-family <ECS_FAMILY> \
                             -saveto <FILENAME>
    """
    try:
        parser = _parse_args()
        args = vars(parser.parse_args())
        mode = args['mode'][0]
        consul_cluster_name = args['ecs_cluster'][0]
        consul_family_name = args['ecs_family'][0]
        filename = args['saveto'][0]
    except SystemExit:
        parser.print_help()
        exit(1)

    log.info("Running script.")
    metadata = get_task_metadata()
    log.info("Got Task Metadata \n%s " % json.dumps(metadata))
    config = generate_config(mode,
                             metadata,
                             consul_cluster_name,
                             consul_family_name)
    log.info("Generated config \n%s " % config)
    dump_config(config, filename)
    log.info("Saved to file, filename==%s" % filename)


if __name__=='__main__':
    main()
