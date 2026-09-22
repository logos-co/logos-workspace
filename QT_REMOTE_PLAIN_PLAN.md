# Qt-free qt_remote compatibility and liblogos migration

## Implementation status

The scoped migration is implemented across `logos-protocol`, `logos-plugin-qt`,
`logos-module-builder`, `logos-module-loader-qt`, and `logos-liblogos`.

- `logos-protocol` now provides a Qt-free Qt Remote Objects 2.0 codec, local
  transport, provider/client runtime, and C ABI under `qt_remote_plain`.
- Mixed peers have been exercised in both directions against the current Qt
  6.9.2 implementation. A plain client called an unchanged current Qt module,
  and a current Qt client called a plain provider. The plain C ABI tests cover
  token delivery, introspection, events, deferred subscriptions, disconnect,
  automatic reconnect, and manual rearming.
- `logos-module-builder` produces native `universal`/`cdylib` modules for
  `transport: "qt_remote_plain"` without Qt or moc. Existing metadata continues
  to default to `qt_remote`.
- `logos-module-loader-qt` installs a `logos_host_plain` native-library host
  beside `logos_host_qt`. The Qt host also has a metadata inspection mode so
  the parent never has to load a Qt plugin.
- `logos-liblogos` now discovers both formats and uses the plain protocol C ABI.
  Its core library and dependency closure were verified to contain no Qt.
- The Windows transport uses overlapped byte-mode named pipes and is
  plain-to-plain by design. It was built and exercised on `winvm.lan` with no
  Qt dependency: all 9 codec, transport, C ABI, event, reconnect, and manual
  rearm tests passed. The real named-pipe method/event/shutdown test also
  passed 25 consecutive runs, and the reconnect/manual-policy test passed 10.

The complete protocol suite passed all 626 cases on `framework.lan`, including
plain client to Qt host and Qt client to plain server. The Linux run exposed a
C++17 argument-evaluation-order error in nested map decoding; that bug is now
fixed and covered by the Qt-free wire test. On macOS, 625 of 626 passed; the
remaining existing TCP restart test could not establish its kernel-specific
precondition that a full accept queue drops SYN packets. The relevant failure
occurred before the behavior under test and is unrelated to this transport.

The Linux liblogos suite passed 251 cases and skipped 7 environment-dependent
process-manager cases, with no failures. Both `liblogos_core.so` and a normal
module-builder module configured with `transport: "qt_remote_plain"` were
verified to have no Qt library in their runtime dependency closure.

The Qt-based `logos-logoscore-cli` remains the separately scoped follow-on
described below. Qt is removed from `liblogos` and retained in the compatibility
host for existing Qt plugins.

## Decision and scope

This is technically feasible. Implement `qt_remote_plain` as a Qt-free implementation of the Qt Remote Objects wire behavior used by Logos today. An unchanged module built with the current module-builder should be able to call a new module, receive its events, accept calls from it, and participate in the existing capability/token flow.

The compatibility baseline is **today's module-builder, protocol, and generated glue with Qt 6.9.2 on Linux/macOS**. **All Windows binaries will be rebuilt to use `qt_remote_plain` exclusively.** Compatibility with the Windows Qt 6.11.1 transport, unchanged Windows binaries, and transport differences between Qt 6.9.2 and Qt 6.11.1 are outside scope. Very old modules and historical wire layouts are also outside scope. Bidirectional interoperability has now been demonstrated against the current Qt 6.9.2 path.

“Exact” means preserving the supported Logos wire types, interfaces, addressing, and observable call/event behavior. It does not require recreating all Qt facilities, every Qt Remote Objects feature, or implementation bugs. The initial inventory must include all types used by current modules; a working string echo alone is not proof of full compatibility.

Qt can be removed from liblogos and the new protocol/module runtime. Existing Qt plugins still require Qt throughout their lifetime inside `logos_host_qt`: plugin loading, object dispatch, timers, signals, and their existing transport. Qt cannot be discarded immediately after loading them. Qt UI applications and in-process Qt plugins remain separate consumers of Qt.

## What the current code establishes

| Finding | Consequence |
| --- | --- |
| `RemoteTransportHost` publishes a generic `ModuleProxy` using `QRemoteObjectRegistryHost::enableRemoting`. Consumers use `connectToNode` and `acquireDynamic`. | Reproduce the dynamic-source protocol for a small Logos interface, rather than each business module's Qt metaobject. |
| The interface carries `callRemoteMethod`, `informModuleToken`, introspection, and `eventResponse`; a separate `<module>__handshake` object allows token delivery during initialization. | Both the business and startup interfaces must work in mixed deployments. |
| Qt 6.9.2's source uses `QtRO 2.0` and `QDataStream::Qt_6_2` for its packet stream. | Implement one binary compatibility profile against Qt 6.9.2; the existing JSON/CBOR transport is not wire-compatible. Use that same plain implementation on Windows. |
| `logos-protocol` already has a Qt-free C ABI and a plain C++ socket/worker stack. Its implementation, transport base classes, provider interface, and token manager still use Qt. | Reuse the existing seams and infrastructure, but split the runtime; adding a socket backend alone does not remove Qt. |
| `logos_module_impl.h` already describes a common module implementation C ABI. | A native host can load the same kind of implementation library without generating a Qt plugin wrapper. |
| The parent half of `logos-module-loader-qt` is already Qt-free. | Keep that launcher and the existing compatibility host. |
| liblogos still calls Qt-backed metadata extraction, persistence helpers, token management, and `LogosAPI`; its build publicly links Qt and the Qt host runtime. | Remove these dependencies explicitly, including transitive build and runtime dependencies. |
| Runtime configuration currently selects `local`, `tcp`, or `tcp_ssl`; `qt_remote` is an implementation name. | Add an explicit backend choice without changing the legacy local endpoint or implying that old peers must understand a new protocol name. |

Record the Qt 6.9.2 reference artifacts on Linux/macOS. Windows requires plain-to-plain transport validation, named-pipe support, and rebuilt module/host/client integration; it does not require a second Qt wire profile or Qt 6.11.1 reference fixtures. Qt may still be needed for Windows UI or plugin loading, independently of the transport.

## Intended architecture

```text
Qt-free liblogos / headless client
    |
    +-- Qt-free protocol runtime
    |      +-- qt_remote_plain: existing QtRO-compatible wire
    |      +-- existing plain TCP/TLS transports
    |
    +-- subprocess loader
           +-- logos_host_plain -> native module implementation C ABI
           +-- logos_host_qt    -> unchanged current Qt module

Both module hosts expose the same Logos interface over compatible local IPC.
Module-to-module calls remain direct; the parent need not relay every call.
```

Use Qt adapters only where Qt callers/providers need them. A Qt-free build of the protocol must not include those adapters or require Qt's build tools. Keep the legacy C++ interfaces available to current binaries; do not change their layouts or vtables as part of replacing internals.

On Windows, any rebuilt Qt host or Qt-facing client adapter must also use `qt_remote_plain`. A Qt plugin format does not imply use of the Qt Remote Objects transport. Exclude the `qt_remote` backend from Windows production builds and reject attempts to select it; there must be no fallback to it.

## Implementation sequence

### 1. Freeze the current compatibility contract

Build and retain Linux/macOS Qt 6.9.2 reference modules using the current module-builder, including the actual locked inputs and any intended working-tree changes. Keep those binaries unchanged for the migration tests; recompiling both sides against the new runtime would hide compatibility failures. Windows binaries are rebuilt together against the new plain transport and do not form an unchanged-binary compatibility baseline.

Create a small Qt reference fixture that exercises exactly the current `ModuleProxy` and handshake object. Record:

- Connection handshake, object announcements, dynamic initialization, source signatures, method/signal indices, initial properties, acquisition/release, heartbeat traffic, and disconnect/reconnect behavior.
- The actual published surface, including overloads, default-argument entries, and any inherited metadata QtRO exposes.
- Local socket/named-pipe naming, `LOGOS_INSTANCE_ID`, endpoint relocation, permissions, and cleanup behavior.
- All current argument/result/event types, including null/invalid values, empty strings and bytes, integer widths/signedness, nested containers, Qt JSON types, and `LogosResult`.
- Token acquisition/delivery, identity, authorization failures, method errors, and concurrent-dispatch completion markers.

Write a short wire specification and commit binary fixtures with decoded explanations. Use Qt only in the reference/test side. Audit the Qt 6.9.2 packet, connection, source, and replica implementations; write the new implementation independently rather than copying a Qt source file and stripping includes. Reuse these fixtures to validate the plain codec on every platform, including Windows.

**Exit:** a finite compatibility profile for current modules and reproducible reference traffic. No historical `LogosResult` variants are required.

### 2. Prove interoperability in both directions

Build a standalone plain C++ client and server, before changing liblogos or the module builder. Use Boost.Asio/native local IPC support and a small event-driven connection state machine.

The client must connect to an unchanged Qt provider, acquire its dynamic definition, locate methods/signals by their signatures, invoke them, correlate replies, and receive events. Do not assume a method's numerical index is constant across all definitions.

The server must advertise a Logos-compatible source, answer dynamic acquisition with a valid class definition and property initialization, dispatch calls by index, and send replies/events that an unchanged Qt consumer accepts. Generate this description from a fixed Logos schema; it must not require Qt or moc in a production build.

Implement the packet families needed by this conversation: handshake, object list, add/remove, dynamic initialization, invocation/reply, signals, and any property/heartbeat traffic exercised by the reference. Although the implementation currently uses a registry-host class, callers connect directly to the module endpoint. Capture which registry behavior actually participates before deciding whether a fuller registry implementation is needed.

The initial demonstration must include a method call, an event, introspection, and token delivery in both directions. Then include a new module calling the current capability module and being called back during initialization. This tests the startup dependency cycle that an echo test misses.

**Exit:** Qt → plain and plain → Qt pass with unchanged reference peers, and the plain processes have no Qt dependency. If this fails, resolve the wire issue before migrating the runtime.

### 3. Complete the compatibility codec and state machine

Implement the required subset of QDataStream/QVariant serialization explicitly: byte order, framing, string encoding and lengths, null flags, built-in type identities, named custom types, and recursive values. Implement the current `LogosResult` serializer exactly, including its error field.

Use a typed internal value representation. The existing `RpcValue` is useful infrastructure, but alone it does not preserve all distinctions required here: `int` versus `qlonglong`, a Qt JSON array versus a variant list, invalid versus typed-null values, or a named `LogosResult` versus an ordinary map. Extend it or introduce a wire-specific value type. Keep ordinary JSON conversion at the existing public C ABI boundary, with the same mappings as today; use the module contract where type reconstruction is required.

Unknown custom serializers cannot be decoded generically just from a type name. Every such type found in current modules must receive a codec or an explicit support decision before calling the transport complete. Do not silently stringify it or turn it into null. Arbitrary future Qt types are not automatically covered.

Preserve the current Logos behavior for authentication, pending-result markers, completion events arriving before replies, startup readiness, subscriptions, reconnection, timeout/error delivery, and teardown. Use asynchronous I/O and a separate dispatch executor so synchronous module-to-module calls do not stop incoming token delivery or callbacks. Preserve serialized provider dispatch unless the module uses the existing concurrent-dispatch mechanism. Do not invoke user callbacks from inside packet decoding or while holding connection locks.

Validate packet lengths, counts, recursion depth, invalid type tags, and truncated messages. Add decoder fuzzing and differential tests against the Qt fixture.

**Exit:** all inventoried wire types and lifecycle behaviors pass the mixed-peer test suite.

### 4. Split logos-protocol into a Qt-free runtime and Qt adapters

Introduce Qt-free internal interfaces for client handles, providers, events, metadata, token stores, scheduling, errors, and transport factories. Replace `QObject` publication with a plain provider descriptor/dispatch interface in the core.

Implement the existing `lp_*` C ABI directly on this runtime. Preserve its ownership, error, subscription, callback cancellation, and per-identity token contracts. Retain its JSON/bytes conventions. Reuse the existing plain TCP/TLS I/O and codecs where appropriate; their Qt-facing adapters must move out of the core too.

Keep the existing Qt-facing `LogosObject`, `LogosTransport*`, provider interfaces, and host API as compatibility adapters. New internals should not change an installed interface that current plugins exchange with their host. Retain current host/plugin ABI behavior and test an unchanged current module in the updated compatibility host.

Separate CMake/Nix outputs for the plain runtime and Qt compatibility layer. Qt package discovery and AUTOMOC must be conditional or confined to the Qt target. Audit symbol ownership, especially token state and shared-library exports on Windows: avoid duplicate runtimes with separate token stores inside one process, and avoid loading two incompatible libraries under the same name.

Add the requested `qt_remote_plain` selection while preserving `local:` endpoints. A reasonable proposed runtime representation is a local protocol plus an implementation/backend selector; the final schema must be validated against existing config and ABI constraints. Do not append fields to a C++ config object exchanged with unchanged binaries without an ABI strategy. Unknown backend choices should fail clearly in the new configuration path rather than fall back silently.

**Exit:** a plain client can use the existing C ABI against an unchanged Qt module without `QCoreApplication`, Qt headers, Qt libraries, or Qt build tools.

### 5. Add the plain module host and builder path

Add a plain host/format-loader implementation using the existing container and module-loader contracts. Load native shared libraries through the common module implementation C ABI: context, initialization, dispatch, metadata, event callbacks, token/credential delivery, host-service grants, and shutdown. Preserve allocator ownership across that boundary.

Wire the current module-builder backend seam to package the native implementation and its contract/metadata without the Qt plugin wrapper. The requested `transport: "qt_remote_plain"` must select the new transport; make plugin format/host selection explicit as well, since changing transport by itself cannot remove a generated Qt wrapper. For supported universal modules, provide a straightforward configuration path selecting the plain backend and transport together.

Keep existing builder output/defaults available during the Linux/macOS rollout. A current binary stays with `logos_host_qt`; a rebuilt plain module uses the native host. On Windows, rebuild the full set of modules, hosts, and clients, including capability and other infrastructure modules, and select `qt_remote_plain` throughout. Handwritten Qt modules may retain their Qt plugin format while their rebuilt transport uses the plain backend. Reuse the current LIDL and std SDK generators rather than inventing a new authoring API.

**Exit:** a normal current-style universal module builds into a genuinely Qt-free runtime artifact and exchanges calls/events with an unchanged current Qt module, through the real capability flow.

### 6. Remove Qt from liblogos and the headless runtime

Replace liblogos's internal `LogosAPI` calls with the plain protocol/C ABI. Move token state and instance/persistence helpers to plain C++ while preserving existing names, IDs, directory layouts, and authorization behavior.

Remove the metadata dependency too. For native modules, read their package/contract metadata. For existing Qt plugins, add an inspection mode to `logos_host_qt` that returns the embedded metadata over a small plain control channel without initializing the module. Cache inspection where useful, keyed to the artifact. Preserve the current embedded-metadata validation and protocol gate; do not blindly substitute an optional sidecar for the binary's identity.

Update module discovery and descriptor construction: liblogos currently hardcodes `qt-plugin` and calls `LogosModule` metadata helpers. Select formats using the loader contract and keep Qt-specific operations in the child. Extract the plain persistence functionality from the Qt-dependent module library as needed.

Remove `Qt::Core`, `Qt::RemoteObjects`, `logos-qt-host`, and Qt-backed `logos-module` dependencies from the core target and its exported configuration. Split packaging outputs so depending on the core alone does not pull Qt into its dependency closure. A distribution supporting Qt plugins will still ship a separate Qt host and Qt libraries.

For “plain C++ everywhere else” in the headless stack, migrate `logos-logoscore-cli` as a separate follow-on: it still creates `QCoreApplication` and uses Qt in daemon control, shutdown, and event watching. Keep the GUI's independent Qt requirements outside this promise.

**Exit:** a minimal non-Qt embedding executable can initialize liblogos, discover/load both module formats, make calls, observe lifecycle changes, unload modules, and shut down without loading Qt in the parent process.

### 7. Gate rollout on compatibility and dependency checks

On Linux/macOS, run all four combinations for calls and events against the Qt 6.9.2 baseline:

| Caller | Provider |
| --- | --- |
| unchanged current Qt | unchanged current Qt |
| plain | unchanged current Qt |
| unchanged current Qt | plain |
| plain | plain |

On Windows, run plain → plain across the rebuilt fleet, including any Qt-facing adapters and Qt plugin hosts. Assert that every participant selects `qt_remote_plain` and that `qt_remote` is unavailable. Do not add Qt 6.11.1 interoperability or Qt-version comparison tests.

Cover success/error/unauthorized results; all current types; real capability-module token exchange; initialization callbacks; synchronous, asynchronous, and concurrent dispatch; multiple subscribers; completion-before-reply; absent/late providers; crash/restart/reconnect; callback cancellation; and unload during an outstanding call. Exercise partial/coalesced reads, malformed frames, and bounded resource use.

Run the platform-specific matrices on the supported Linux, macOS, and Windows targets, including Windows named pipes and library-symbol ownership. Check both direct/transitive library dependencies and the loaded libraries in the parent process. Also build the plain production targets in an environment without Qt installed; Linux/macOS reference interoperability tests may depend on Qt separately. Windows codec tests can consume the frozen Qt 6.9.2 byte fixtures without linking Qt.

On Linux/macOS, roll out by opting in a small module, then a real dependency pair, then liblogos/headless clients. Preserve a per-module rollback to the current Qt host/backend until the mixed-fleet tests pass reliably. On Windows, stage and validate the complete rebuilt set before rollout; keep the new deployment entirely on `qt_remote_plain`, with no per-module fallback to `qt_remote`. Update the developer guide, module-builder configuration, SDK/protocol documentation, packaging, and workspace dependency graph with each implemented public change. Use `ws build`/`ws test` with precise local overrides for cross-repo validation.

**Completion:** existing current Linux/macOS Qt 6.9.2 module binaries remain usable, all Windows participants are rebuilt and use `qt_remote_plain`, new plain modules need no Qt runtime, and liblogos loads no Qt into its process.

## Risks and stopping conditions

There is no fundamental protocol blocker for the scoped current-module interface. The difficult work is the dynamic source handshake, exact value serialization, and matching lifecycle/authentication behavior. The larger amount of work is removing Qt from the shared runtime and discovery/build dependencies.

The first bidirectional prototype is the decision gate. The full promise remains unproven until frozen current binaries pass the type and lifecycle matrix. A currently used custom serializer without a defined plain counterpart is a concrete compatibility gap to close, not something to hide behind an “any” JSON value.

Keeping existing Qt plugins unchanged requires keeping their Qt runtime in the compatibility host. This is compatible with a Qt-free parent and new native hosts. It is not compatible with removing Qt from every process in a mixed deployment.

## Evidence inspected

- [Current Qt transport](/Users/dlipicar/repos/logos-workspace/repos/logos-protocol/cpp/implementations/qt_remote/remote_transport.cpp)
- [Published Logos interfaces](/Users/dlipicar/repos/logos-workspace/repos/logos-protocol/cpp/module_proxy.h)
- [Transport interfaces](/Users/dlipicar/repos/logos-workspace/repos/logos-protocol/cpp/logos_transport.h), [configuration](/Users/dlipicar/repos/logos-workspace/repos/logos-protocol/cpp/logos_transport_config_json.cpp), and [protocol build](/Users/dlipicar/repos/logos-workspace/repos/logos-protocol/cpp/CMakeLists.txt)
- [Current LogosResult serialization](/Users/dlipicar/repos/logos-workspace/repos/logos-protocol/cpp/logos_types.cpp)
- [Module implementation C ABI](/Users/dlipicar/repos/logos-workspace/repos/logos-protocol/cpp/logos_module_impl.h)
- [liblogos module management](/Users/dlipicar/repos/logos-workspace/repos/logos-liblogos/src/logos_core/module_manager.cpp), [discovery](/Users/dlipicar/repos/logos-workspace/repos/logos-liblogos/src/logos_core/module_registry.cpp), and [link dependencies](/Users/dlipicar/repos/logos-workspace/repos/logos-liblogos/src/CMakeLists.txt)
- [Qt loader/host split](/Users/dlipicar/repos/logos-workspace/repos/logos-module-loader-qt/README.md), [metadata extraction](/Users/dlipicar/repos/logos-workspace/repos/logos-module/src/module_metadata.cpp), and [builder backend selection](/Users/dlipicar/repos/logos-workspace/repos/logos-module-builder/lib/mkLogosModule.nix)
- [Qt protocol versioning](https://doc.qt.io/qt-6/qtremoteobjects-compatibility.html) and [QDataStream versioning](https://doc.qt.io/qt-6/qdatastream.html)
- Qt 6.9.2 upstream source: [packet definitions](https://github.com/qt/qtremoteobjects/blob/v6.9.2/src/remoteobjects/qremoteobjectpacket_p.h), [packet implementation](https://github.com/qt/qtremoteobjects/blob/v6.9.2/src/remoteobjects/qremoteobjectpacket.cpp), and [protocol/stream versions](https://github.com/qt/qtremoteobjects/blob/v6.9.2/src/remoteobjects/qconnectionfactories_p.h)
