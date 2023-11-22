#!/bin/bash

redis-cli -p 26380 shutdown
redis-cli -p 26381 shutdown
redis-cli -p 26382 shutdown

redis-cli -p 6380 shutdown
redis-cli -p 6381 shutdown
redis-cli -p 6382 shutdown

ps -aux | grep redis
