FROM grafana/grafana

USER root
RUN apk update && apk add curl

USER grafana

ADD ./provisioning /etc/grafana/provisioning
ADD ./config.ini /etc/grafana/config.ini
ADD ./dashboards /var/lib/grafana/dashboards
