#!/bin/bash

# networkconfig
# /Library/Preferences/SystemConfiguration/preferences.plist

# Script to add a domain to the proxy bypass list for a specific network interface on macOS

NIC="AX88179A"
DOMAIN="*.zhixuan.com"
echo "Current proxy bypass domains for $NIC:"
networksetup -getproxybypassdomains $NIC

networksetup -getproxybypassdomains $NIC  | grep -x "$DOMAIN" > /dev/null || sudo networksetup -setproxybypassdomains $NIC "$(sudo networksetup -getproxybypassdomains $NIC | tr '\n' ','  | xargs) $DOMAIN"
echo "Updated proxy bypass domains for $NIC"

networksetup -getproxybypassdomains $NIC 
