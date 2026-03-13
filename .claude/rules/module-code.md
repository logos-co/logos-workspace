---
paths:
  - "repos/logos-cpp-sdk/**"
  - "repos/logos-liblogos/**"
  - "repos/logos-module/**"
  - "repos/logos-module-builder/**"
  - "repos/logos-app/**"
  - "repos/**/module.yaml"
  - "repos/**/*_plugin.cpp"
  - "repos/**/*_plugin.h"
  - "repos/**/*_interface.h"
---

# Module Code Rules

- Read `repos/logos-tutorial/logos-developer-guide.md` before making significant changes.
- Modules are Qt 6 plugins (C++17). Public API = Q_INVOKABLE methods on the interface class.
- Build with `ws build <repo>` or `ws test <repo>`, not raw cmake.
- Use `ws build <downstream> --auto-local` to test changes in downstream consumers.
- `ws watch test <repo>` for live feedback during development.
- Inter-module calls use LogosAPI::callModule() returning LogosResult. Check result.success().
- module.yaml is the source of truth for module config. metadata.json is auto-generated at build time.
- CLI tools (`lm`, `logoscore`, `lgx`, `lgpm`, `logos-cpp-generator`) are available directly and auto-build/rebuild from local repos. Use them or `ws <tool>` — no manual build step needed.
