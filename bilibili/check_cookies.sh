#!/bin/bash

echo "🔍 Checking browser cookie files on macOS..."
echo "⚠️  Close browsers before running this script to avoid lock errors."
echo "-----------------------------------------------"

# Function to check SQLite cookies
check_sqlite_cookies() {
  local browser_name=$1
  local cookie_path=$2

  if [ -f "$cookie_path" ]; then
    echo "✅ $browser_name cookie database found:"
    echo "   $cookie_path"
    echo "   Example cookie entry:"
    sqlite3 "$cookie_path" "SELECT host_key, name, value FROM cookies LIMIT 1;" 2>/dev/null | head -n 1
    echo "-----------------------------------------------"
  else
    echo "❌ $browser_name cookie file not found. Is the browser installed?"
    echo "   Tried path: $cookie_path"
    echo "-----------------------------------------------"
  fi
}

# Safari (binary format - requires special handling)
SafariCookiePath=~/Library/Cookies/Cookies.binarycookies
if [ -f "$SafariCookiePath" ]; then
  echo "✅ Safari binary cookie file found:"
  echo "   $SafariCookiePath"
  echo "   Note: Safari uses a proprietary binary format. Use tools like:"
  echo "   - cookie-cutter (https://github.com/rogeriopvl/cookie-cutter)"
  echo "   - Safari's Develop > JavaScript Console > Application tab"
  echo "-----------------------------------------------"
else
  echo "❌ Safari cookie file not found."
  echo "-----------------------------------------------"
fi

# Firefox (SQLite)

firefox_profile=$(find ~/Library/Application\ Support/Firefox/Profiles/ -name "*.default-release" -o -name "*.cookies.sqlite" 2>/dev/null | head -n 1)
firefox_cookie="$firefox_profile/cookies.sqlite"
check_sqlite_cookies "Firefox" "$firefox_cookie"

# Chrome (SQLite)
chrome_cookie=~/Library/Application\ Support/Google/Chrome/Default/Cookies
check_sqlite_cookies "Chrome" "$chrome_cookie"

# Edge (SQLite)
edge_cookie=~/Library/Application\ Support/Microsoft\ Edge/Default/Cookies
check_sqlite_cookies "Edge" "$edge_cookie"

# Brave (SQLite)
brave_cookie=~/Library/Application\ Support/BraveSoftware/Brave-Browser/Default/Cookies
check_sqlite_cookies "Brave" "$brave_cookie"

echo "💡 Tips:"
echo "   - Use 'sqlite3 <path> .dump' to view full SQLite databases"
echo "   - Safari cookies require third-party tools or browser developer tools"
echo "   - Files may be locked if browser is running"