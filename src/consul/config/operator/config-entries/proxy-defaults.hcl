Kind = "proxy-defaults"
Name = "global"
Config {
    local_connect_timeout_ms = 1000
    handshake_timeout_ms = 10000
    protocol = "http"
    bind_address = "0.0.0.0"
    bind_port = 21000
    envoy_stats_flush_interval = "60s"
    envoy_extra_static_clusters_json = <<EOL
        {
            "name": "xray",
            "type": "STRICT_DNS",
            "connect_timeout": "1s",
            "dns_lookup_family": "V4_ONLY",
            "lb_policy": "ROUND_ROBIN",
            "load_assignment": {
                "cluster_name": "xray",
                "endpoints": [
                    {
                        "lb_endpoints": [
                            {
                                "endpoint": {
                                    "address": {
                                        "socket_address": {
                                            "address": "127.0.0.1",
                                            "port_value": 2000,
                                            "protocol": "UDP"
                                        }
                                    }
                                }
                            }
                        ]
                    }
                ]
            }
        }
    EOL

    envoy_public_listener_json = <<EOL
        {
            "name": "public_listener:0.0.0.0:21000",
            "address": {
                "socket_address": {
                    "address": "0.0.0.0",
                    "port_value": 21000
                }
            },
            "filter_chains": [
                {
                    "filters": [
                        {
                            "name": "envoy.http_connection_manager",
                            "typed_config": {
                                "@type": "type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager",
                                "tracing": {},
                                "add_user_agent": true,
                                "codec_type": "AUTO",
                                "use_remote_address": true,
                                "upgrade_configs": [
                                    {
                                        "enabled": true,
                                        "upgrade_type": "websocket"
                                    }
                                ],
                                "access_log": [
                                    {
                                        "name": "envoy.file_access_log",
                                        "config": {
                                            "path": "/dev/stdout",
                                            "json_format": {
                                                "start_time": "%START_TIME%",
                                                "method": "%REQ(:METHOD)%",
                                                "origin_path": "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
                                                "protocol": "%PROTOCOL%",
                                                "response_code": "%RESPONSE_CODE%",
                                                "response_flags": "%RESPONSE_FLAGS%",
                                                "bytes_recv": "%BYTES_RECEIVED%",
                                                "bytes_sent": "%BYTES_SENT%",
                                                "duration": "%DURATION%",
                                                "upstream_service_time": "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%",
                                                "x_forward_for": "%REQ(X-FORWARDED-FOR)%",
                                                "user_agent": "%REQ(USER-AGENT)%",
                                                "request_id": "%REQ(X-REQUEST-ID)%",
                                                "authority": "%REQ(:AUTHORITY)%",
                                                "upstream": "%UPSTREAM_HOST%",
                                                "downstream_remote_addr_without_port": "%DOWNSTREAM_REMOTE_ADDRESS_WITHOUT_PORT%"
                                            }
                                        }
                                    }
                                ],
                                "route_config": {
                                    "name": "public_listener",
                                    "virtual_hosts": [
                                        {
                                            "routes": [
                                                {
                                                    "match": {
                                                        "prefix": "/"
                                                    },
                                                    "route": {
                                                        "cluster": "local_app"
                                                    }
                                                }
                                            ],
                                            "domains": [
                                                "*"
                                            ],
                                            "name": "public_listener"
                                        }
                                    ]
                                },
                                "http_filters": [
                                    {
                                        "name": "envoy.router"
                                    }
                                ],
                                "stat_prefix": "public_listener_http"
                            }
                        }
                    ]
                }
            ]
        }
    EOL

    envoy_tracing_json = <<EOL
        {
            "http": {
                "name": "envoy.tracers.xray",
                "typed_config": {
                    "@type": "type.googleapis.com/envoy.config.trace.v3.XRayConfig",
                    "segment_name": "ingress-gw",
                    "daemon_endpoint": {
                        "protocol": "UDP",
                        "address": "127.0.0.1",
                        "port_value": 2000
                    }
                }
            }
        }
    EOL
}
