# Karafka Core Changelog

## 2.5.4 (2025-08-04)
- [Fix] Fix old regression on misbehaviour when Object methods are overwritten.

## 2.5.3 (2025-08-04)
- [Enhancement] Optimize code to mitigate the Ruby performance warning from `Karafka::Core::Configurable::Node` (#208)
- [Enhancement] Raise errors on detected Ruby warnings.
- [Change] Remove unused Ruby 2.7 code.
- [Change] Remove `funding_uri` from the gemspec to minimize double-funding info.

## 2.5.2 (2025-06-11)
- [Enhancement] Support `#unsubscribe`.
- [Enhancement] Allow for providing a root scope path for error keys.
- [Fix] Fix a bug where on no errors the result would be an array instead of a hash.
- [Fix] Fix spec hanging when Kafka cluster on 9092 is running.

## 2.5.1 (2025-05-23)
- [Change] Move to trusted-publishers and remove signing since no longer needed.

## 2.5.0 (2025-05-21)
- [Change] Set minimum `karafka-rdkafka` on `0.19.2` to support new features.

## 2.4.11 (2025-03-20)
- [Enhancement] Rename internal node `#name` method to `#node_name` so we can use `#name` as the attribute name.

## 2.4.10 (2025-03-14)
- [Fix] Relax lock on `karafka-rdkafka`

## 2.4.9 (2025-03-03)
- [Enhancement] Remove `RspecLocator` dependency on `activesupport`.

## 2.4.8 (2024-12-26)
- [Maintenance] Declare `logger` as a dependency.

## 2.4.7 (2024-11-26)
- [Fix] Make sure that `karafka-core` works with older versions of `karafka-rdkafka` that do not support macos fork mitigation.

## 2.4.6 (2024-11-26)
- [Enhancement] Mitigate macos forking issues when librdkafka is not loaded to memory.
- [Change] Allow `karafka-rdkafka` `0.18.0`.

## 2.4.5 (2024-11-19)
- **[Breaking]** Drop Ruby `3.0` support according to the EOL schedule.
- [Enhancement] Support listeners inspection via `#listeners`.
- [Fix] Restore `#available_events` notifications bus method.
- [Change] Set minimum `karafka-rdkafka` on `0.17.6` to support new features.

## 2.4.4 (2024-07-20)
- [Change] Set minimum `karafka-rdkafka` on `0.16.0` to support new features and allow for `0.17.0`.

## 2.4.3 (2024-06-18)
- [Fix] Use `Object` instead of `BasicObject` for rule result comparison because of Time mismatch with BasicObject.

## 2.4.2 (2024-06-17)
- [Enhancement] Allow `karafka-rdkafka` `0.16.x` to be used since API compatible.

## 2.4.1 (2024-06-17)
- [Enhancement] Provide fast-track for events without subscriptions to save on allocations.
- [Enhancement] Save memory allocation on each contract rule validation execution.
- [Enhancement] Save one allocation per `float_now` + 2-3x performance by using the Posix clock instead of `Time.now.utc.to_f`.
- [Enhancement] Use direct `float_millisecond` precision in `monotonic_now` not to multiply by 1000 (allocations and CPU savings).
- [Enhancement] Save one array allocation on one instrumentation.
- [Enhancement] Allow clearing one event type (dorner).

## 2.4.0 (2024-04-26)
- **[Breaking]** Drop Ruby `2.7` support.
- [Enhancement] Provide necessary alterations for custom oauth token callbacks to operate.
- [Change] Set minimum `karafka-rdkafka` on `0.15.0` to support new features.

## 2.3.0 (2024-01-26)
- [Change] Set minimum `karafka-rdkafka` on `0.14.8` to support new features.
- [Change] Remove `concurrent-ruby` usage.

## 2.2.7 (2023-11-07)
- [Change] Set minimum `karafka-rdkafka` on `0.13.9` to support alternative consumer builder.

## 2.2.6 (2023-11-03)
- [Enhancement] Set backtrace for errors propagated via the errors callbacks.

## 2.2.5 (2023-10-31)
- [Change] Drop support for Ruby 2.6 due to incompatibilities in usage of `ObjectSpace::WeakMap`
- [Change] Set minimum `karafka-rdkafka` on `0.13.8` to support consumer `#position`.

## 2.2.4 (2023-10-25)
- [Enhancement] Allow for `lazy` evaluated constructors.
- [Enhancement] Allow no-arg constructors.

## 2.2.3 (2023-10-17)
- [Change] Set minimum `karafka-rdkafka` on `0.13.6`.

## 2.2.2 (2023-09-11)
- [Fix] Reuse previous frozen duration as a base for incoming computation.

## 2.2.1 (2023-09-10)
- Optimize statistics decorator by minimizing number of new objects created.
- Expand the decoration to include new value `_fd` providing freeze duration in milliseconds. This value informs us for how many consecutive ms the given value did not change. It can be useful for detecting values that should change once in a while but are stale.

## 2.2.0 (2023-09-01)
- [Maintenance] Update the signing cert (old expired)

## 2.1.1 (2023-06-28)
- [Change] Set minimum `karafka-rdkafka` on `0.13.1`.

## 2.1.0 (2023-06-19)
- [Change] Set `karafka-rdkafka` requirement from `>= 0.13.0` to `<= 0.14.0`.
- [Change] Remove no longer needed patch.

## 2.0.13 (2023-05-26)
- Set minimum `karafka-rdkafka` on `0.12.3`.

## 2.0.12 (2023-02-23)
- Introduce ability to tag certain objects by including the `Karafka::Core::Taggable` module.

## 2.0.11 (2023-02-12)
- Set minimum `karafka-rdkafka` on `0.12.1`.

## 2.0.10 (2023-02-01)
- Move `RspecLocator` to core.

## 2.0.9 (2023-01-11)
- Use `karafka-rdkafka` instead of `rdkafka`. This change is needed to ensure that all consecutive releases are stable and compatible.
- Relax Ruby requirement to `2.6`. It does not mean we officially support it but it may work. Go to [Versions Lifecycle and EOL](https://karafka.io/docs/Versions-Lifecycle-and-EOL/) for more details.

## 2.0.8 (2023-01-07)
- Add `Karafka::Core::Helpers::Time` utility for time reporting.

## 2.0.7 (2022-12-18)
- Allow for recompilation of config upon injecting new config nodes.
- Compile given config scope automatically after it is defined.
- Support sub-config merging via their nested definitions.

## 2.0.6 (2022-12-07)
- Reverse node compilation state tracking removal.

## 2.0.5 (2022-12-07)
- Move `librdkafka` generic (producer and consumer) patches from WaterDrop here.
- Move dependency on `librdkafka` here from both Karafka and WaterDrop to unify management.
- Move `CallbacksManager` from WaterDrop because it's shared.

## 2.0.4 (2022-11-20)
- Disallow publishing events that were not registered.
- Fix a potential race condition when adding listeners concurrently from multiple threads.

## 2.0.3 (2022-10-13)
- Maintenance release. Cert chain update. No code changes.

## 2.0.2 (2022-08-01)
- Add extracted statistics decorator (#932)

## 2.0.1 (2022-07-30)
- Fix a case where setting would match a method monkey-patched on an object (#1) causing initializers not to build proper accessors on nodes. This is not the core bug, but still worth handling this case.

## 2.0.0 (2022-07-28)
- Initial extraction of common components used in the Karafka ecosystem from WaterDrop.
