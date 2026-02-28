[![Build Status](https://github.com/karafka/karafka-core/actions/workflows/ci.yml/badge.svg)](https://github.com/karafka/karafka-core/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/karafka-core.svg)](http://badge.fury.io/rb/karafka-core)
[![Join the chat at https://slack.karafka.io](https://raw.githubusercontent.com/karafka/misc/master/slack.svg)](https://slack.karafka.io)

## Karafka-Core

Karafka-Core contains toolset of small support modules used throughout the [Karafka](https://github.com/karafka/karafka/) ecosystem.

It includes:

- `Karafka::Core::Monitoring` - default instrumentation and abstraction that allows to use either itself, `dry-monitor` or `ActiveSupport::Notifications`.
- `Karafka::Core::Configurable` - configuration engine inspired by `dry-config` with similar but simplified API.
- `Karafka::Core::Contractable` - contracts inspired by `dry-validation` but with simplified API.
- `Karafka::Core::Taggable` - adds ability to attach `#tags` to objects for extra labeling.
