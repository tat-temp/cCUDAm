# RCAsm probe — does the driver accept a hand-assembled cubin?

One question, one command. Everything up to `cuModuleLoad` has been measured on the dev machine
(see the RCAsm section of `../DEVPLAN.md`); this is the step that needs a GPU.

```
cd rcasm_test
nvcc -o rcasm_load_test rcasm_load_test.cpp -lcuda
./rcasm_load_test kernel_sm120.cubin mulKernel
```

Expected on success: the device name, `OK cuModuleLoad`, `OK cuModuleGetFunction`, an attribute
dump showing `NUM_REGS 255`, and `VERDICT: the driver ACCEPTED the RCAsm cubin`. Exit code 0.
A rejection exits 2 and names the `CUresult`; a load that resolves no function exits 3.

The probe stops at `cuModuleGetFunction` and deliberately does **not** launch. `mulKernel` takes a
by-value parameter struct, and launching it with the wrong argument buffer is a hang rather than an
error message — which would tell you nothing about the question being asked.

## The files

| File | What it is |
|---|---|
| `rcasm_load_test.cpp` | The probe. `cuInit` → `cuDevicePrimaryCtxRetain` → `cuModuleLoad` → `cuModuleGetFunction` → attribute dump. |
| `kernel_sm120.cubin` | RCAsm's Kernel01 sample assembled for sm_120 on CUDA 13.0.88 — hand-written SASS injected into an nvcc template. **This is the subject of the test.** |
| `ctrl_patched.cubin` | The **control**: the same template round-tripped through cuAssembler with *no* injection, notes patched back. |
| `kernel_sm89.cubin` | The same sample built for sm_89. Only useful on Ada hardware. |

## If `kernel_sm120.cubin` is rejected

Run the control next — it is the whole reason it is committed here:

```
./rcasm_load_test ctrl_patched.cubin mulKernel
```

- **Control loads, injected one doesn't** → the problem is the injected instruction stream, not
  the assembler. Hand-written SASS is still viable; that specific body isn't.
- **Neither loads** → the problem is cuAssembler's ELF writing under CUDA 13.0, and nothing about
  hand-written SASS matters until that is fixed.

That split is the only reason a GPU is needed at all, and it is why the control ships alongside.

## Do not use nvdisasm to sanity-check these

`nvdisasm` refuses `kernel_sm120.cubin` with `Could not establish the target of 'BRXU' branch
operation`. `BRXU` is an indirect branch through a uniform register and is RCAsm's own loop idiom —
it appears three times in the Kernel01 sources. The refusal is a disassembler limitation, not a
malformed cubin: `cuobjdump -sass` reads all 144 instructions, and `ctrl_patched.cubin` (no `BRXU`)
is accepted by `nvdisasm` and reproduces the original template's SASS exactly.

Use `cuobjdump -sass` and `cuobjdump -res-usage` for eyeballing RCAsm output.

## Provenance

The three cubins were built from the Kernel01 sample shipped with RCAsm
(<https://github.com/RetiredC/RCAsm>) — `kernel.cu` as the nvcc template, `main.asm` and `mul.asm`
as the injected bodies — using CUDA 13.0.88. RCAsm targets 12.8; three one-line fixes were needed
to get it through 13.0, all recorded in `../DEVPLAN.md`. Nothing here is generated from this
project's own sources, and nothing here is built by the `Makefile` — these are committed fixtures,
which is why `.gitignore`'s `*.cubin` rule carries an exception for this directory.
