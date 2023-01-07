# Karafka core changelog

## 2.0.8 (Unreleased)
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
