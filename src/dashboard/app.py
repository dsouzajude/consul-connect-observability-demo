import os
import sys
import json
import socket
import logging
from logging.config import dictConfig

import requests
from flask import Flask, make_response, request
from aws_xray_sdk.core import xray_recorder, patch_all
from aws_xray_sdk.ext.flask.middleware import XRayMiddleware
from werkzeug.exceptions import HTTPException


log_levels = {
    'DEBUG': logging.DEBUG,
    'INFO': logging.INFO,
    'WARNING': logging.WARNING,
    'ERROR': logging.ERROR,
    'CRITICAL': logging.CRITICAL
}

COUNTER_ENDPOINT = os.environ["COUNTER_ENDPOINT"]


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


def get_trace_id(x_amzn_trace_id):
    if x_amzn_trace_id and "Root=" in x_amzn_trace_id:
        trace_id = x_amzn_trace_id.split("Root=")[1].split(";")[0]
        return trace_id


def create_app():
    app = Flask(__name__)

    # Configure xray tracing
    xray_recorder.configure(service='dashboard')
    XRayMiddleware(app, xray_recorder)
    patch_all()

    # Setup logging
    setup_logging(log_levels.get(os.environ.get("LOG_LEVEL", "INFO")))
    log = logging.getLogger(__name__)

    @app.errorhandler(HTTPException)
    def handle_error(error):
        error_dict = {
            "message": str(error) if isinstance(error, HTTPException) else '',
            "exc_type": type(error).__name__,
            "status_code": error.code
        }

        log.exception(error)
        return make_response(
            json.dumps({
                "message": "Error occured",
                "code": error.code,
                "trace_id": get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                "request_id": request.headers.get("X-Request-Id")
            }), 500
        )

    @app.route("/")
    def hello():
        try:
            resp = requests.get("{}/".format(COUNTER_ENDPOINT))
            log.info(
                "Received request, trace_id={}, req_id={}".format(
                    get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                    request.headers.get("X-Request-Id")
                )
            )
            if resp.status_code == 200:
                resp = json.loads(resp.text)
                resp = json.dumps({
                    "message": "Counter is reachable",
                    "count": resp["count"],
                    "counter_service_id": resp["counter_service_id"],
                    "dashboard_service_id": socket.gethostname(),
                    "trace_id": get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                    "request_id": request.headers.get("X-Request-Id")
                })
            else:
                log.info("Error calling {} service! code={}, service={}".format(resp.text, resp.status_code, COUNTER_ENDPOINT))
                resp = make_response(json.dumps({
                    "message": "Error calling %s service" % COUNTER_ENDPOINT,
                    "code": resp.status_code,
                    "error": resp.text,
                    "trace_id": get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                    "request_id": request.headers.get("X-Request-Id")

                }), 500)
        except requests.exceptions.RequestException as ex:
            log.info("Error connecting to counter at %s, %s" % (COUNTER_ENDPOINT, str(ex)))
            resp = make_response(json.dumps({
                "message": str(ex),
                "trace_id": get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                "request_id": request.headers.get("X-Request-Id")
            }), 500)
        return resp


    @app.route("/fail")
    def fail():
        code = request.args.get('code')
        log.info(
            "/fail?code={} called! Relaying to counter service, trace_id={}, req_id={}".format(
                code,
                get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                request.headers.get("X-Request-Id")
        ))
        resp = requests.get("{}/fail?code={}".format(COUNTER_ENDPOINT, code))
        resp = make_response(json.dumps({
            "message": "Received code={} on {}/fail?code={}".format(
                resp.status_code, COUNTER_ENDPOINT, code
                )
            }), int(resp.status_code))
        return resp


    @app.route("/health")
    def health():
        return json.dumps({"status": "DASHBOARD_HEALTHY"})


    return app


if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=os.environ.get('PORT', 80))
