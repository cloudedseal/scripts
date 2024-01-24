#!/bin/bash
set -e

/bin/cp -f redis-6380.conf.bak redis-6380.conf
/bin/cp -f redis-6381.conf.bak redis-6381.conf
/bin/cp -f redis-6382.conf.bak redis-6382.conf

pidof redis-server

redis-server redis-6380.conf
redis-server redis-6381.conf
redis-server redis-6382.conf

pidof redis-server

#redis-cli -p 6381 slaveof 127.0.0.1 6380
#redis-cli -p 6382 slaveof 127.0.0.1 6380

# deploy on remote machine 192.168.6.40
redis-cli -p 6381 slaveof 192.168.6.40 6380
redis-cli -p 6382 slaveof 192.168.6.40 6380

/bin/cp -f sentinel-26380.conf.bak sentinel-26380.conf
/bin/cp -f sentinel-26381.conf.bak sentinel-26381.conf
/bin/cp -f sentinel-26382.conf.bak sentinel-26382.conf

redis-sentinel sentinel-26380.conf
redis-sentinel sentinel-26381.conf
redis-sentinel sentinel-26382.conf

pidof redis-sentinel
