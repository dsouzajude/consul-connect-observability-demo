#!/usr/bin/env python
# -*- coding: utf-8 -*-

# ------------------------------------------------------------------------------
# This script generates the "Service Definition" for the actual service along
# with its "Proxy Definition" so that it can be registered into Consul and its
# proxy can be initialized.
#
# To run the configurator script:
#
#       python /service_configurator.py -saveto <FILENAME>
#
# More about consul service configs
# https://learn.hashicorp.com/consul/developer-mesh/connect-services
# ------------------------------------------------------------------------------

import os
import sys
import json
import logging
from collections import defaultdict
from logging.config import dictConfig

import argparse
import requests


log_levels = {
    'DEBUG': logging.DEBUG,
    'INFO': logging.INFO,
    'WARNING': logging.WARNING,
    'ERROR': logging.ERROR,
    'CRITICAL': logging.CRITICAL
}

PLACEHOLDER = "<PLACEHOLDER>"


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


def generate_instance_id(task_metadata):
    return "{}-{}-{}".format(
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
    #TODO: Get AZ
    az = resp.get('AvailabilityZone', "eu-west-1a")
    return {"task_id": task_id, "family": resp['Family'], "ip": ip, "az": az}


def regenerate_service_config(task_metadata, service_config):
    service_config = json.loads(service_config)
    service_config["service"]["id"] = generate_instance_id(task_metadata)
    service_config["service"]["address"] = task_metadata["ip"]
    service_config["service"]["tags"].append("AZ:%s" % task_metadata["az"])
    return json.dumps(service_config)


def dump_config(config, filename):
    log.info("Saving config to file, filename==%s" % filename)
    with open(filename, "w") as f:
        f.write(config)


def _parse_args():
    parser = argparse.ArgumentParser(
        prog='consul_service_configurator',
        usage='%(prog)s [options]',
        description='Generates service configs for Consul.'
    )
    parser.add_argument(
        '-saveto',
        type=str,
        nargs=1,
        metavar=("saveto"),
        required=True,
        default="/consul/config/service.json",
        help='Absolute path of (JSON) filename to store the consul service configuration.'
    )
    return parser


def main():
    """ Generates a service config for Consul and dumps it to a specified file

    To run:
        python /service_configurator.py -saveto <FILENAME>
    """
    try:
        parser = _parse_args()
        args = vars(parser.parse_args())
        filename = args['saveto'][0]
    except SystemExit:
        parser.print_help()
        exit(1)

    log.info("Running script.")
    service_config = os.environ["SERVICE_CONFIG"]
    metadata = get_task_metadata()
    log.info("Got Task Metadata \n%s " % json.dumps(metadata))
    log.info("Received service_config \n%s" % service_config.replace("\n", "").replace("\r", ""))
    config = regenerate_service_config(metadata, service_config)
    log.info("Generated config \n%s " % config)
    dump_config(config, filename)
    log.info("Saved to file, filename==%s" % filename)


if __name__=='__main__':
    main()
