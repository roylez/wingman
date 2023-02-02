# Wingman

Mattermost message forwarding agent

## Installation

### Docker

```
version: "3"

services:
  wingman:
    image: roylez/wingman
    restart: unless-stopped
    environment:
      WINGMAN_MATTERMOST_TOKEN: xxxxx
      WINGMAN_MATTERMOST_URL: https://mattermost.com
      WINGMAN_WEBHOOK:  https://example.com/webhook
      WINGMAN_HIGHLIHGHTS:  hello|world
      WINGMAN_CHANNELS: channel1,channel2
```

### Manual

```
mix deps.get
MIX_ENV=prod mix release
_build/prod/rel/wingman/bin/wingman start
```

## Environment Variables

```
TZ:                       # timezone, default to UTC
WINGMAN_MATTERMOST_TOKEN: # Profile -> Security -> Personal Access Token
WINGMAN_MATTERMOST_URL:   # Custom API endpoint
WINGMAN_HIGHLIHGHTS:      # only messages matching highlights are forwarded, regex allowed.
WINGMAN_CHANNELS:         # optional, list of channels that all messge will be forwarded without notification
WINGMAN_WEBHOOK:          # optional, if messages are to be sent to a webhook address
WINGMAN_DEBUG:            # optional set to 1 for debugging
WINGMAN_TELEGRAM_TOKEN:   # optional, only if telegram bot is used
WINGMAN_TELEGRAM_CHAT_ID: # optional, only if telegram bot is used
WINGMAN_ENABLE_AT:        # optional, cron expression
WINGMAN_DISABLE_AT:       # optional, cron expression
```
