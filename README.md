# uniffi-dart

Dart frontend for UniFFI bindings

![License: MIT](https://img.shields.io/github/license/acterglobal/uniffi-dart?style=flat-square) ![Status: experimental](https://img.shields.io/badge/status-experimental-red?style=flat-square)

## Installation

Add uniffi-dart as a dependency in your `Cargo.toml`:

```toml
[dependencies]
uniffi-dart = "0.3.0+v0.32.0"
```

## Testing & Fixtures

uniffi-dart includes a **comprehensive test suite** with fixtures covering all major UniFFI functionality:

### **Fixture Coverage**

- **Core Types**: Primitives, collections, optionals, type limits
- **Async Patterns**: Comprehensive async/Future support with object-oriented patterns  
- **Error Handling**: Error types, large errors, exception scenarios
- **Object-Oriented**: Interfaces, constructors, methods, traits
- **Time Handling**: Timestamps, durations, ISO 8601 formatting
- **Performance**: FFI call overhead benchmarking
- **Documentation**: UDL and proc-macro documentation generation
- **External Types**: Cross-crate type sharing and custom type wrapping

### **Running Tests**

Run all fixture tests:

```bash
cargo nextest run --all --nocapture
```

### Nix Development Shells

If Nix is available, the repository provides development shells with Rust,
Dart, `cargo-nextest`, and formatting tools:

Enable flakes and the new Nix CLI if they are not already enabled:

```bash
mkdir -p ~/.config/nix
printf "experimental-features = nix-command flakes\n" >> ~/.config/nix/nix.conf
```

```bash
nix develop
nix develop .#msrv
nix develop .#stable
nix develop .#nightly
```

The default shell tracks the stable Rust toolchain. The `.#msrv` shell matches
the declared Rust MSRV, currently 1.91.0.

Run formatting through the flake:

```bash
nix fmt -- --ci
```

The flake formatter covers Nix, Rust, and Dart files. Rust formatting uses the
repository `rustfmt.toml`; Dart formatting runs with the latest language version.

Run the flake checks:

```bash
nix flake check
```

CI uses this as a formatting and toolchain smoke check. The `Testing` workflow
runs the full Rust and Dart fixture suite and lints; see [Fork CI coverage](#fork-ci-coverage).

Run the existing fixture test suite from a Nix shell:

```bash
nix develop .#msrv -c cargo nextest run --all
```

Run specific fixture tests:

```bash
cargo nextest run -p simple_fns --nocapture
cargo nextest run -p dart_async --nocapture
cargo nextest run -p time_types --nocapture
```

For nightly compiler features (`genco` whitespace detection):

```bash
cargo +nightly nextest run -p hello_world --nocapture
```

### **Identified Blockers**

Our comprehensive fixture suite has identified 3 critical blocking features:

1. **Dictionary default values** - Named parameters with defaults
2. **Trait method support** - Advanced trait functionality
3. **BigInt support** - Large integer boundary handling

## Versioning

uniffi-dart is versioned independently from uniffi-rs. We follow the
[SemVer rules from the Cargo Book](https://doc.rust-lang.org/cargo/reference/semver.html)
where versions are compatible when their left-most non-zero component
matches. A breaking change is any modification to the generated Dart
bindings that requires consumers to update their code.

Because the project is still young, the major version is 0 and most
updates bump the minor version.

To keep binding generators in sync, uniffi-dart targets a specific
uniffi-rs release. If you use multiple external binding generators, pick
versions that target the same uniffi-rs version.

Tags follow the format `vX.Y.Z+vA.B.C`, where `X.Y.Z` is the
uniffi-dart version and `A.B.C` is the targeted uniffi-rs version.

| uniffi-rs target | Latest uniffi-dart release |
|------------------|----------------------------|
| v0.32.0          | v0.3.0+v0.32.0             |
| v0.31.2          | v0.2.1+v0.31.2             |
| v0.30.0          | v0.1.1+v0.30.0             |

## License & Credits

The code is released under MIT License. See the LICENSE file in the repository root for details.

The project is building on top of the great work of Mozillas UniFFI, with inspirations from other external frontends (like Kotlin and Go) and with the help of the [ffi-gen](https://github.com/acterglobal/ffi-gen) lib. Thanks folks!

## MoQ upstream audit

Checked [Uniffi-Dart/uniffi-dart](https://github.com/Uniffi-Dart/uniffi-dart) through
[`e644a4ad`](https://github.com/Uniffi-Dart/uniffi-dart/commit/e644a4ad980f72697aba211fd30cb4fbd8fc7324)
on 2026-11-02; its head is unchanged since 2026-10-31 and its public GitHub
advisory list was empty.
The MoQ branch already carries the library-mode CLI, enum-name disambiguation,
RustBuffer/result ownership, and disposed-object guards. This port adds the
allocation-failure cleanup from
[`71dc9f8b`](https://github.com/Uniffi-Dart/uniffi-dart/commit/71dc9f8b8f54cdfa6ef5d08f24e70cd93ef11d7d)
and disposal status reservation from
[`a2751c4c`](https://github.com/Uniffi-Dart/uniffi-dart/commit/a2751c4cb0df3d28b5efab0bac1dadf439d9b163),
with their allocation-failure tests. MoQ currently exports no foreign traits,
custom types, or dollar-bearing string defaults; the remaining incoming-callback,
custom-FFI, and default-escaping fixes do not affect its generated bindings.
Dependency updates are excluded.


## Fork CI coverage

On `moq-0.32`, pull requests and branch pushes run these read-only workflows:

- **Testing** runs `cargo nextest run --all --all-features` on stable, Rust 1.91
  (MSRV), and nightly. This generates bindings, builds the Rust fixture libraries,
  and runs their Dart tests, including async functions, callbacks, object disposal,
  input-scratch ownership, library configuration, and enum name collisions. Each
  compiler runs independently; nightly remains advisory. Lints run formatting and
  Clippy with all features and targets, including the binary CLI.
- **Nix** runs `nix flake check` for formatting and verifies the tools in each dev
  shell. It does not run the fixture suite and cannot replace Testing.

The async fixture tests check results, errors, and pending-future progress without
wall-clock thresholds. A Dart `Completer` controls a foreign async callback, so
its Rust caller must remain pending while a second call completes, then resume
when released. This tests suspension and independent progress without assuming
anything about scheduler speed. A manually released Rust future also tests duplicate wakes both before and after
completion, retaining the late-wake check without a sleeping background thread.
Error assertions stay outside catch blocks so a
successful call cannot accidentally satisfy an expected-error test.

The upstream **Test Downstream** wallet jobs are removed on this fork. At the
2026-11-02 audit, rust-payjoin's wrapper called a different generator API, and
bdk-dart's patch was unused and its lockfile failed under `--locked`. Both tracked
moving default branches outside this fork's supported consumer. Adapting those
applications would test an integration MoQ does not ship.

[MoQ](https://github.com/moq-dev/moq) owns the downstream integration instead:
[`just dart check`](https://github.com/moq-dev/moq/blob/main/sh/dart/check.sh)
regenerates bindings with its pinned generator, compares both generated files,
analyzes and tests both Dart packages, and checks publish contents. Its
[cross-language interop suite](https://github.com/moq-dev/moq/tree/main/test/interop)
exercises Dart against the other bindings. A fork generator change still needs a
MoQ pin and regenerated-output review plus these downstream checks before MoQ
uses it; a green fork check alone does not establish downstream compatibility.
