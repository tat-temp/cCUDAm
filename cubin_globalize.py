#!/usr/bin/env python3
"""Give named cubin symbols GLOBAL binding, in place.

WHY THIS EXISTS. `cuModuleGetGlobal` only resolves global symbols, and nvcc gives every
__device__/__constant__ variable internal linkage unless the cubin is built with -rdc=true
(CallCubin.cpp:102 says so in the error path). That is why `make cubin` device-links: it is
the only supported way to get c_Gx/c_Gy/c_Jx/c_Jy/c_target_words exported so the host can
fill them.

But -rdc is not free -- it changes registers, instruction count and section layout -- and
until now that cost could not be MEASURED, because the cheaper build was the one abtest
could not load. This script removes that circularity: build plain, flip five bytes, and the
A/B harness can hold a plain cubin against an -rdc one with nothing else different.

WHAT IT CHANGES. One byte per symbol: st_info's high nibble, STB_LOCAL(0) -> STB_GLOBAL(1).
Type, visibility, st_other, value, size and section index are all left exactly as nvcc wrote
them -- which is the whole delta between the two builds' symbol entries, verified by dumping
both:

    plain  c_Gx  st_info=0x01 (bind=0 type=1)  st_other=0x00  shndx=13  size=16384
    -rdc   c_Gx  st_info=0x11 (bind=1 type=1)  st_other=0x00  shndx=16  size=16384

WHAT IT DELIBERATELY DOES NOT DO: reorder symbols or touch sh_info. ELF wants every local
symbol to precede every global one, with sh_info naming the first global -- and nvcc's own
cubins do not honour it. Measured on CUDA 13.0.88: the plain cubin has 18 symbols and
sh_info=18, the -rdc cubin has 20 and sh_info=20, yet the -rdc file carries GLOBAL symbols
at indices 10..18 and is the build that proof.py passed 592/592 through. So the driver does
not read the partition, reordering would mean renumbering every relocation for no benefit,
and leaving sh_info alone keeps this file exactly as conformant as the one nvcc ships.

Every symbol-table-shaped section is patched, not just .symtab: cubins also carry
.nv.merc.symtab with the same 24-byte entry shape and the same strtab, and which of the two
the driver reads is not documented. Patching both costs nothing and removes the question.

A REQUESTED SYMBOL THAT IS NOT FOUND IS AN ERROR (exit 2). The failure this guards against is
the quiet one: a cubin that looks patched, loads fine, and runs the whole kernel against a
zeroed constant bank.

    python3 cubin_globalize.py <file.cubin> <sym> [sym ...]
    python3 cubin_globalize.py --check <file.cubin> <sym> [sym ...]   # report, do not write
"""
import struct
import sys

SHT_SYMTAB = 2
SYMENT = 24


def sections(d):
    if d[:4] != b"\x7fELF" or d[4] != 2 or d[5] != 1:
        raise SystemExit("not a little-endian ELF64 file")
    (shoff,) = struct.unpack_from("<Q", d, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from("<HHH", d, 0x3A)
    out = []
    for i in range(shnum):
        o = shoff + i * shentsize
        name, typ, flags, addr, off, size, link, info, align, entsize = \
            struct.unpack_from("<IIQQQQIIQQ", d, o)
        out.append(dict(i=i, name=name, typ=typ, off=off, size=size,
                        link=link, info=info, entsize=entsize))
    shstr = out[shstrndx]
    for s in out:
        e = d.index(b"\0", shstr["off"] + s["name"])
        s["sname"] = d[shstr["off"] + s["name"]:e].decode("utf-8", "replace")
    return out


def symtabs(d, secs):
    """Every section shaped like a symbol table: 24-byte entries, link to a real strtab.

    Matched by SHAPE rather than by SHT_SYMTAB, so .nv.merc.symtab -- which is
    processor-specific (LOPROC+0x85) and would be skipped by a type test -- is included."""
    for s in secs:
        if s["entsize"] != SYMENT or s["size"] == 0 or s["size"] % SYMENT:
            continue
        if not (0 < s["link"] < len(secs)):
            continue
        if s["typ"] != SHT_SYMTAB and not s["sname"].endswith("symtab"):
            continue
        yield s, secs[s["link"]]


def main(argv):
    check = argv and argv[0] == "--check"
    if check:
        argv = argv[1:]
    if len(argv) < 2:
        raise SystemExit(__doc__.rstrip().rsplit("\n\n", 1)[-1])
    path, wanted = argv[0], set(argv[1:])

    d = bytearray(open(path, "rb").read())
    secs = sections(d)
    seen, changed = set(), 0

    for st, strt in symtabs(d, secs):
        for k in range(st["size"] // SYMENT):
            o = st["off"] + k * SYMENT
            nameoff, info, other, shndx, val, size = struct.unpack_from("<IBBHQQ", d, o)
            e = d.index(b"\0", strt["off"] + nameoff)
            name = d[strt["off"] + nameoff:e].decode("utf-8", "replace")
            if name not in wanted:
                continue
            seen.add(name)
            bind, typ = info >> 4, info & 0xF
            if shndx == 0:
                raise SystemExit("%s: %s is undefined (shndx=0) -- wrong cubin?"
                                 % (path, name))
            if bind == 1:
                print("  %-18s %-16s already GLOBAL" % (st["sname"], name))
                continue
            print("  %-18s %-16s st_info 0x%02x -> 0x%02x   (bind %d->1, type %d, "
                  "%d bytes)" % (st["sname"], name, info, 0x10 | typ, bind, typ, size))
            if not check:
                d[o + 4] = 0x10 | typ
            changed += 1

    missing = sorted(wanted - seen)
    if missing:
        # Loud on purpose. The failure mode this prevents is a cubin that loads and runs the
        # whole kernel against an empty constant bank -- fast, silent and finding nothing.
        raise SystemExit("%s: symbol(s) not present: %s" % (path, ", ".join(missing)))

    if check:
        print("check only, %s left unmodified (%d entries would change)" % (path, changed))
        return 0
    if changed:
        open(path, "wb").write(d)
    print("%s: %d symbol entries now GLOBAL" % (path, changed))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
