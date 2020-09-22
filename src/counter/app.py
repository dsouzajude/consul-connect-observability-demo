import os
import sys
import time
import json
import socket
import logging
from logging.config import dictConfig

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

# Maintain count in memory
count = 0


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
    xray_recorder.configure(service='counter')
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
        '''Available Headers
            [
                'Host', 'User-Agent', 'Accept-Encoding',
                'Accept', 'X-Amzn-Trace-Id',
                'X-Forwarded-Proto', 'X-Request-Id',
                'X-Envoy-Expected-Rq-Timeout-Ms',
                'Content-Length', 'X-Forwarded-For',
                'X-Envoy-Internal',
                'X-Envoy-Downstream-Service-Cluster',
                'X-Envoy-Downstream-Service-Node'
            ]
        '''
        global count
        count = count + 1
        log.info(
            "Received request, trace_id={}, req_id={}".format(
                get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                request.headers.get("X-Request-Id")
            )
        )
        return json.dumps({
            "count": count,
            "counter_service_id": socket.gethostname(),
            "trace_id": get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
            "request_id": request.headers.get("X-Request-Id")
        })

    @app.route("/fail")
    def fail():
        code = int(request.args.get('code'))
        if code == 504:
            # Simulate 504 by timeout
            time.sleep(100)
            return make_response(json.dumps({}))
        elif code == 502:
            # Simulate 502 by abrupt exit
            sys.exit(1)
        else:
            # For 503 and 500 return the code
            msg = "/fail?code={} called! Responding with {}, trace_id={}, req_id={}".format(
                code, code,
                get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                request.headers.get("X-Request-Id")
            )
            log.info(msg)
            resp = make_response(
                json.dumps({
                    "message": msg,
                    "trace_id": get_trace_id(request.headers.get("X-Amzn-Trace-Id")),
                    "request_id": request.headers.get("X-Request-Id")
                }), int(code)
            )
            return resp

    @app.route("/health")
    def health():
        return json.dumps({"status": "COUNTER_HEALTHY"})


    return app


if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=os.environ.get('PORT', 80))
