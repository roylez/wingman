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
      MATTERMOST_TOKEN: xxxxx
      MATTERMOST_API_URL: https://mattermost.com
      WINGMAN_WEBHOOK:  https://example.com/webhook
      WINGMAN_HIGHLIHGHTS:  hello|world
```

### Manual

```
mix deps.get
MIX_ENV=prod mix release
_build/prod/rel/wingman/bin/wingman start
```

## Environment Variables

```
MATTERMOST_TOKEN:    # Profile -> Security -> Personal Access Token
MATTERMOST_API_URL:  # Custom API endpoint
WINGMAN_HIGHLIHGHTS: # only messages matching highlights are forwarded, regex allowed.
WINGMAN_WEBHOOK:     # optional, if messages are to be sent to a webhook address
WINGMAN_DEBUG:       # optional set to 1 for debugging
```
