[![Build Status](https://github.com/karafka/karafka-core/actions/workflows/ci.yml/badge.svg)](https://github.com/karafka/karafka-core/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/karafka.svg)](http://badge.fury.io/rb/karafka-core)
[![Join the chat at https://slack.karafka.io](https://raw.githubusercontent.com/karafka/misc/master/slack.svg)](https://slack.karafka.io)

## Karafka-Core

Karafka-Core contains toolset of small support modules used throughout the Karafka ecosystem.

It includes

- `Karafka::Core::Monitoring` - default instrumentation and abstraction that allows to use either itself, `dry-monitor` or `ActiveSupport::Notifications`.
- `Karafka::Core::Configurable` - configurator inspired by `dry-config` with similar but simplified API.
- `Karafka::Core::Contractable` - contracts inspired by `dry-validation` but with simplified API.

## Note on contributions

First, thank you for considering contributing to the Karafka ecosystem! It's people like you that make the open source community such a great community!

Each pull request must pass all the RSpec specs, integration tests and meet our quality requirements.

Fork it, update and wait for the Github Actions results.
