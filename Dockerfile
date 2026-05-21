FROM alpine:latest

RUN apk add --no-cache bash findutils curl jq

COPY check_configs.sh /usr/local/bin/check_configs.sh
RUN chmod +x /usr/local/bin/check_configs.sh

ENTRYPOINT ["/usr/local/bin/check_configs.sh"]
