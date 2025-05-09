#!/bin/bash
# https://github.com/static-web-server/static-web-server/
# https://github.com/brona/iproute2mac
port=9898
ip=$(ip addr show en0 | grep inet | grep -v inet6 | awk -F " " '{print $2}' | awk -F "/" '{print $1}')
echo "static web server listening on $ip:$port"

static-web-server --host $ip --port $port --directory-listing true --root ~/Downloads/shared