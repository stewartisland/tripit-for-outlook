// Copyright 2026 Alexander Klimetschek
// SPDX-License-Identifier: Apache-2.0
//
// TripIt -> Outlook ICS cleaning proxy.
// Transparently forwards the request path to www.tripit.com (which sits behind
// Akamai Bot Manager) using browser-like headers, normalizes ICS responses,
// and re-serves clean text/calendar so Microsoft's cloud fetcher can subscribe.
//
//   https://<worker>.workers.dev/feed/ical/private/<TOKEN>/tripit.ics
//     -> https://www.tripit.com/feed/ical/private/<TOKEN>/tripit.ics

const UPSTREAM_HOST = "www.tripit.com";

const BROWSER_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  Accept: "text/calendar, text/html, */*",
  "Accept-Language": "en-US,en;q=0.9",
};

function normalize(ics) {
  // Ensure CRLF line endings.
  let out = ics.replace(/\r\n/g, "\n").replace(/\n/g, "\r\n");
  // Inject METHOD/CALSCALE after VERSION:2.0 if absent (helps Microsoft's parser).
  if (!/^METHOD:/m.test(out)) {
    out = out.replace(/(VERSION:2\.0\r\n)/, "$1METHOD:PUBLISH\r\n");
  }
  if (!/^CALSCALE:/m.test(out)) {
    out = out.replace(/(VERSION:2\.0\r\n)/, "$1CALSCALE:GREGORIAN\r\n");
  }
  return out;
}

function icsResponse(body) {
  return new Response(body, {
    status: 200,
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Cache-Control": "max-age=900",
      "Content-Disposition": 'inline; filename="tripit.ics"',
    },
  });
}

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "") {
      return new Response("Not found", { status: 404 });
    }

    const target = `https://${UPSTREAM_HOST}${url.pathname}${url.search}`;
    const upstream = await fetch(target, {
      headers: BROWSER_HEADERS,
      cf: { cacheTtl: 600, cacheEverything: true },
    });

    const text = await upstream.text();
    if (upstream.ok && text.trimStart().startsWith("BEGIN:VCALENDAR")) {
      return icsResponse(normalize(text));
    }

    // Upstream failed or returned something that isn't a calendar (e.g. an
    // Akamai challenge page). Microsoft keeps the last-synced events on a
    // failed refresh, so a 502 here just leaves the calendar stale.
    return new Response("Upstream did not return a calendar", { status: 502 });
  },
};
