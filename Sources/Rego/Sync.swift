/// Generates a synchronous peer of the annotated `async` function.
///
/// The generated peer has the same name but without `async` in the signature.
/// All `await` keywords are stripped from the body.
///
/// Swift's overload resolution automatically picks the correct variant:
/// - `try await fn(...)` dispatches to the original async version
/// - `try fn(...)` (no `await`) dispatches to the generated sync version
///
/// ### Identifier substitution
///
/// When the generated sync body needs to reference a different symbol than the async
/// version (e.g. a sync registry instead of an async one), use the optional
/// `replacing:with:` parameters:
///
/// ```swift
/// @sync(replacing: "asyncLookup", with: "syncLookup")
/// func execCall(...) async throws -> BlockResult { ... }
/// ```
///
/// Every member access whose name equals `replacing` is renamed to `with` in the
/// generated function body.
@attached(peer, names: overloaded)
macro sync(replacing: String = "", with: String = "") = #externalMacro(module: "SyncMacroPlugin", type: "SyncMacro")
