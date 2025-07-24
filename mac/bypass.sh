#!/bin/bash

# networkconfig
# /Library/Preferences/SystemConfiguration/preferences.plist

# Script to add a domain to the proxy bypass list for a specific network interface on macOS

NIC="AX88179A"
echo "Current proxy bypass domains for $NIC:"
networksetup -getproxybypassdomains $NIC

sudo networksetup -getproxybypassdomains $NIC  | grep -x '.zhixuan.com' > /dev/null || sudo networksetup -setproxybypassdomains $NIC "$(sudo networksetup -getproxybypassdomains $NIC | tr '\n' ','  | xargs) *.zhixuan.com"
echo "Updated proxy bypass domains for $NIC"

networksetup -getproxybypassdomains $NIC 
