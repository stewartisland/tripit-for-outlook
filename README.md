# TripIt for Outlook

> A simple Cloudflare Worker that allows [Microsoft Outlook 365 / Outlook Web](https://outlook.office.com) to subscribe to [TripIt](https://www.tripit.com) calendars

**Problem:** Microsoft Outlook 365 currently (as of June 2026) fails to subscribe to TripIt ICS calendar feeds. This is because TripIt uses Akamai Bot Manager, which seems to block the IP ranges used by Microsoft when it fetches the calendar feed. It also uses a few special iCal features that might confuse Outlook.

**Solution:** This Cloudflare worker acts as transparent proxy that forwards the request to TripIt with browser-like headers and fixes the ICS on the fly. You simply subscribe Outlook to a proxy URL instead:

* Original TripIt: `https://www.tripit.com/<feed>.ics`
* Cloudflare Proxy: `https://tripit-for-outlook.<domain>.workers.dev/<feed>.ics`

## Setup

### Prerequisite

You'll need
* [Node.js](https://nodejs.org) installed on your machine (provides `npx`)
* A free [Cloudflare account](https://dash.cloudflare.com/sign-up)

### Deploy Cloudflare worker

1. Get the repo onto your local machine

   ```sh
   git clone https://github.com/alexkli/tripit-for-outlook.git
   cd tripit-for-outlook
   ```

2. Login to your Cloudflare account

   ```sh
   # login with the right account
   npx wrangler login

   # print account id
   npx wrangler whoami

   # copy the "Account ID" from the table above
   # alternatively get it from https://dash.cloudflare.com
   export CLOUDFLARE_ACCOUNT_ID=<your-account-id>
   ```

3. Deploy the Worker

   ```sh
   npx wrangler deploy
   ```


### Subscribe to a TripIt Calendar

1. Get the proxy URL for your TripIt calendar URL (which ends in `.ics`)

   ```sh
   ./subscribe.sh "https://www.tripit.com/<feed>.ics"
   ```

2. Subscribe in Outlook

   1. Go to outlook.office.com → Calendar → Add calendar → Subscribe from web
   2. Paste the URL printed from the script in step 1
   3. Give it a name/color/icon and Save.
   4. Subscribing once on the web propagates to new Outlook on Mac + iOS

You can do this with multiple calendars. Note that the owner of the Cloudflare account would technically be able to see all the events from all calendars using this proxy, so be aware if you share that with people.


## Local development

You can debug the worker locally using:
```sh
npx wrangler dev
curl "http://localhost:8787/feed/ical/private/<TOKEN>/tripit.ics"
```

## License

[Apache License 2.0](LICENSE).
