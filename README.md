# mytest

## Native build

```powershell
stack build
stack exec mytest
```

## WebAssembly/WASI build

Install a Haskell WASI toolchain that provides these commands on `PATH`:

- `wasm32-wasi-ghc`
- `wasm32-wasi-ghc-pkg`

Then build with Cabal:

```powershell
.\scripts\build-wasm.ps1
```

If Windows blocks local PowerShell scripts, run the same build as:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-wasm.ps1
```

To build and run with Wasmtime:

```powershell
.\scripts\build-wasm.ps1 -Run
```

The project is a good WASM candidate because it only depends on `base`.
