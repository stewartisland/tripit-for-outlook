#!/usr/bin/env bash
# Build the Outlook subscription URL for this Worker from a TripIt .ics URL,
# WITHOUT deploying. It looks up your account's workers.dev subdomain via the
# Cloudflare API, using the OAuth token that `npx wrangler login` already stored
# (or $CLOUDFLARE_API_TOKEN if you set one).
#
# Usage:
#   ./subscribe.sh <tripit-ics-url>
#
# Env (all optional):
#   CLOUDFLARE_API_TOKEN    use this token instead of the wrangler OAuth token
#   CLOUDFLARE_ACCOUNT_ID   use this account instead of your first account

set -euo pipefail

UPSTREAM_HOST="www.tripit.com"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "Error: $*" >&2; exit 1; }

[ $# -ge 1 ] || die "missing TripIt URL.
Usage: ./subscribe.sh <tripit-ics-url>"

tripit="$1"
case "$tripit" in
  http://*|https://*) ;;
  *) tripit="https://$tripit" ;;
esac

# Split scheme://host/path?query
rest="${tripit#*://}"
host="${rest%%/*}"
if [ "$host" = "$rest" ]; then
  path="/"
else
  path="/${rest#*/}"
fi
[ "$host" = "$UPSTREAM_HOST" ] || \
  echo "Warning: expected host $UPSTREAM_HOST, got $host (the Worker only proxies $UPSTREAM_HOST)." >&2

# Worker name from wrangler.toml
name="$(sed -nE 's/^name *= *"?([^"]+)"?.*/\1/p' "$DIR/wrangler.toml" | head -1)"
[ -n "$name" ] || die "could not read 'name' from wrangler.toml"

# Auth token: prefer CLOUDFLARE_API_TOKEN, else wrangler's stored OAuth token.
token="${CLOUDFLARE_API_TOKEN:-}"
if [ -z "$token" ]; then
  for cfg in "$HOME/.wrangler/config/default.toml" \
             "${XDG_CONFIG_HOME:-$HOME/.config}/.wrangler/config/default.toml" \
             "$HOME/Library/Preferences/.wrangler/config/default.toml"; do
    if [ -f "$cfg" ]; then
      token="$(sed -nE 's/^oauth_token *= *"?([^"]+)"?.*/\1/p' "$cfg" | head -1)"
      [ -n "$token" ] && break
    fi
  done
fi
[ -n "$token" ] || die "no Cloudflare token found. Run 'npx wrangler login' or set CLOUDFLARE_API_TOKEN."

api() { curl -fsS -H "Authorization: Bearer $token" "https://api.cloudflare.com/client/v4$1"; }
json_str() { sed -nE "s/.*\"$1\" *: *\"([^\"]*)\".*/\1/p" | head -1; }

# Account id: env, else first account from the API.
acct="${CLOUDFLARE_ACCOUNT_ID:-}"
if [ -z "$acct" ]; then
  acct="$(api "/accounts" | json_str id)"
  [ -n "$acct" ] || die "could not determine account id. Set CLOUDFLARE_ACCOUNT_ID."
fi

# workers.dev subdomain for the account.
sub="$(api "/accounts/$acct/workers/subdomain" | json_str subdomain)"
[ -n "$sub" ] || die "could not read workers.dev subdomain.
If your token expired, run 'npx wrangler whoami' (refreshes it) or 'npx wrangler login'."

echo
echo "Subscribe to this URL in Outlook (Add calendar -> Subscribe from web):"
echo
echo "https://${name}.${sub}.workers.dev${path}"
