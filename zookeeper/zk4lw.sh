#!/usr/bin/env bash

if [ $# -ne 3 ] ; then
echo "USAGE:"
echo " e.g.: $0 4lw zkServerIp zkClientPort"
echo " example: $0 conf 10.10.10.10 2181"
exit 1;
fi
echo $1 | (exec 3<>/dev/tcp/$2/$3; cat >&3; cat <&3; exec 3<&-) #| grep "Node count" | cut -d : -f 2