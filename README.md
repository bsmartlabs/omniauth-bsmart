# omniauth-bsmart

[![Test](https://github.com/bsmartlabs/omniauth-bsmart/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/bsmartlabs/omniauth-bsmart/actions/workflows/test.yml)
[![Release](https://github.com/bsmartlabs/omniauth-bsmart/actions/workflows/release.yml/badge.svg)](https://github.com/bsmartlabs/omniauth-bsmart/actions/workflows/release.yml)
[![Gem Version](https://badge.fury.io/rb/omniauth-bsmart.svg)](https://badge.fury.io/rb/omniauth-bsmart)

🔌 OmniAuth OAuth2 strategy for bSmart accounts.

## Features

- OAuth2 Authorization Code flow using bSmart Doorkeeper endpoints
- User profile fetch from `GET /api/v6/user`
- Automatic fallback to `GET /api/v6/me` when `/user` is unavailable
- Auth hash with normalized `uid`, `info`, `credentials`, and `extra.raw_info`

## Requirements

- Ruby `>= 3.2`
- OmniAuth `~> 2.0`
- `omniauth-oauth2` `>= 1.8`, `< 1.9`

## Installation

```ruby
gem 'omniauth-bsmart'
```

## Basic Usage

```ruby
use OmniAuth::Builder do
  provider :bsmart,
           ENV.fetch('BSMART_CLIENT_ID'),
           ENV.fetch('BSMART_CLIENT_SECRET'),
           scope: 'public'
end
```

### Endpoint Defaults

- Site: `https://www.bsmart.it`
- Authorize URL: `/oauth/authorize`
- Token URL: `/oauth/token`
- User Info URL: `/api/v6/user`
- Fallback User Info URL: `/api/v6/me`

### Optional Overrides

```ruby
provider :bsmart,
         ENV.fetch('BSMART_CLIENT_ID'),
         ENV.fetch('BSMART_CLIENT_SECRET'),
         client_options: {
           site: 'https://www.bsmart.it',
           authorize_url: '/oauth/authorize',
           token_url: '/oauth/token'
         },
         user_info_url: '/api/v6/user',
         me_url: '/api/v6/me'
```

## bSmart OAuth App Setup

Create an OAuth application in bSmart (Doorkeeper) and configure your callback URL:

- Production OAuth base: `https://www.bsmart.it/oauth`
- Production API base: `https://www.bsmart.it/api/v6`

Typical callback path:

- `/auth/bsmart/callback`

## Auth Hash

```json
{
  "uid": "42",
  "info": {
    "name": "Ada Lovelace",
    "email": "teacher@example.test",
    "first_name": "Ada",
    "last_name": "Lovelace",
    "nickname": "teacher@example.test",
    "image": "https://www.bsmart.it/avatar/42.png",
    "roles": ["teacher"]
  },
  "credentials": {
    "token": "access-token",
    "refresh_token": "refresh-token",
    "expires_at": 1773000000,
    "expires": true,
    "scope": "public"
  },
  "extra": {
    "raw_info": {
      "id": 42,
      "email": "teacher@example.test",
      "name": "Ada",
      "surname": "Lovelace",
      "avatar_url": "https://www.bsmart.it/avatar/42.png",
      "roles": ["teacher"]
    }
  }
}
```

## Development

```bash
bundle install
bundle exec rake lint
bundle exec rake test_unit
bundle exec rake test_rails_integration
```

## CI Matrix

- Ruby: `3.2`, `3.3`, `3.4`, `4.0`
- Rails integration lanes: `~> 7.1.0`, `~> 7.2.0`, `~> 8.0.0`, `~> 8.1.0`
- `omniauth-oauth2`: `1.8.x`

## Release

Tag a release:

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

The GitHub `Release` workflow publishes the gem through RubyGems Trusted Publishing.

## License

MIT
