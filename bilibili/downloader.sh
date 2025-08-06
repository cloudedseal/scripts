#!/usr/bin/env bash

# https://www.bilibili.com/video/BV1YR9AY3EyS

firefox_profile=$(find ~/Library/Application\ Support/Firefox/Profiles/ -name "*.default-release" -o -name "*.cookies.sqlite" 2>/dev/null | head -n 1)
firefox_cookie="$firefox_profile/cookies.sqlite"

echo "Using cookie file: $firefox_cookie"
URL=$1
you-get -c "$firefox_cookie" --playlist "$URL"