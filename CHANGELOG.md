# Karafka core changelog

# Unreleased
- Disallow publishing events that were not registered.
- Fix a potential race condition when subscribing adding listeners concurrently from multiple threads.

## 2.0.3 (2022-10-13)
- Maintenance release. Cert chain update. No code changes.

## 2.0.2 (2022-08-01)
- Add extracted statistics decorator (#932)

## 2.0.1 (2022-07-30)
- Fix a case where setting would match a method monkey-patched on an object (#1) causing initializers not to build proper accessors on nodes. This is not the core bug, but still worth handling this case.

## 2.0.0 (2022-07-28)
- Initial extraction of common components used in the Karafka ecosystem from WaterDrop.
