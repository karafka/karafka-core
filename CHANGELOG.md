# Karafka core changelog

## 2.0.1
- Fix a case where setting would match a method monkey-patched on an object (#1) causing initializers not to build proper accessors on nodes. This is not the core bug, but still worth handling this case.

## 2.0.0
- Initial extraction of common components used in the Karafka ecosystem from WaterDrop.
