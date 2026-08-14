"""Execute a vendored RCAsm FUNCTION body on the host, 32-bit word by 32-bit word.

The point is to be able to ask "is this routine correct?" without a GPU. MulMod256 is the
control: it is verified correct on hardware (the `call` rung matched the compiled kernel
exactly), so a simulator that cannot reproduce ITS behaviour has no standing to convict
anything else.

Semantics:

  IADD3[.X] Rd, [Pc0, [Pc1,]] Ra, Rb, Rc [, Pi0, Pi1]
      s = Ra + Rb + Rc + Pi0 + Pi1        (one 3-input adder, carry 0..2)
      Rd = s & M32 ;  Pc0 = [carry >= 1] ;  Pc1 = [carry >= 2]
      The two carry-outs are the carry COUNT in thermometer form, which is why every
      routine here feeds both back as carry-ins: Pc0 + Pc1 restores the count exactly.

      This was got wrong first. Reading them as two chained adders with a carry-out each
      preserves every SUM -- so MulMod256, SqrMod256, SubMod256 and AddMod256 all still
      come out correct -- and only diverges where a routine consumes the two predicates
      INDIVIDUALLY. SubMod256_3 does, as the selector between adding P and adding 2P, and
      under the chained reading it looks broken on a third of all inputs. It is not. Any
      model has to be chosen against routines whose behaviour is already known, not
      against the one under suspicion.

  IMAD.WIDE.U32[.X] Rd, [Pc,] Ra, Rb, Rc [, Pi]
      Rd:Rd+1 = Ra*Rb + Rc:Rc+1 + Pi ;  Pc = carry out of bit 64
"""
import re
import sys

M32 = 0xFFFFFFFF
M64 = (1 << 64) - 1
P = (1 << 256) - 0x1000003D1


def load(path):
    """name -> list of instruction operand-strings, in order."""
    src = open(path).read().split("\n")
    out, cur = {}, None
    for line in src:
        m = re.match(r"\s*FUNCTION\s+(\w+)", line)
        if m:
            cur, out[cur] = m.group(1), []
            continue
        if cur and line.strip() == "}":
            cur = None
            continue
        if cur and "]" in line and line.strip().startswith("["):
            out[cur].append(line.split("]", 1)[1].strip().rstrip(";"))
    return out


class Sim:
    def __init__(self):
        self.r = {}
        self.p = {}

    def rd(self, tok):
        neg = tok.startswith("~")
        if neg:
            tok = tok[1:]
        if tok.endswith(".reuse"):          # operand-reuse cache flag, no semantics
            tok = tok[:-6]
        if tok == "RZ":
            v = 0
        elif re.match(r"^-?0[xX][0-9a-fA-F]+$", tok) or re.match(r"^-?\d+$", tok):
            v = int(tok, 0) & M32
        elif tok in self.r:
            v = self.r[tok]
        else:
            raise KeyError("unbound operand %r -- a silent 0 here is how a simulator "
                           "reports a clean run on code it never modelled" % tok)
        return (~v) & M32 if neg else v

    def pr(self, tok):
        if tok == "PT":
            return 1
        if tok == "!PT":
            return 0
        if tok.startswith("!"):
            return 1 - self.p.get(tok[1:], 0)
        return self.p.get(tok, 0)

    @staticmethod
    def ispred(tok):
        t = tok.lstrip("!")
        return t == "PT" or re.match(r"^Pt\d+$", t) is not None

    def step(self, text):
        text = re.sub(r"//.*$", "", text).strip()
        if not text:
            return
        guard = None
        m = re.match(r"^(@!?\w+)\s+", text)
        if m:
            guard = m.group(1)[1:]
            text = text[m.end():]
        if guard is not None:
            g = self.pr(guard) if not guard.startswith("!") else 1 - self.p.get(guard[1:], 0)
            if not g:
                return
        op, rest = text.split(None, 1)
        ops = [o.strip() for o in rest.split(",")]
        dst = ops[0]
        rem = ops[1:]
        cout = []
        while rem and self.ispred(rem[0]):
            cout.append(rem.pop(0))
        cin = []
        while rem and self.ispred(rem[-1]):
            cin.insert(0, rem.pop())

        if op.startswith("IADD3"):
            # One 3-input adder. The sum carries 0, 1 or 2, and the two carry-out
            # predicates report that count in THERMOMETER form: (carry>=1, carry>=2).
            # Established by elimination in models.py: of the candidate semantics, this is
            # the only one under which all six vendored routines are correct. The two
            # split-chain readings each convict two shipped routines, and they disagree
            # with hardware about SubMod256_3 -- which is what sent this investigation
            # down a false trail once already.
            s = (self.rd(rem[0]) + self.rd(rem[1]) + self.rd(rem[2])
                 + sum(self.pr(c) for c in cin))
            self.r[dst] = s & M32
            c = s >> 32
            for k, name in enumerate(cout):
                if name != "PT":
                    self.p[name] = 1 if c >= k + 1 else 0
        elif op.startswith("IMAD.WIDE.U32"):
            ra, rb, rc = rem[0], rem[1], rem[2]
            lo = self.rd(rc)
            hi = self.rd(self._pair(rc))
            acc = (hi << 32) | lo
            v = self.rd(ra) * self.rd(rb) + acc + sum(self.pr(c) for c in cin)
            self.r[dst] = v & M32
            self.r[self._pair(dst)] = (v >> 32) & M32
            if cout and cout[0] != "PT":
                self.p[cout[0]] = (v >> 64) & 1
        elif op == "MOV":
            self.r[dst] = self._imm(rem[0])
        elif op == "SEL":
            # SEL Rd, Ra, Rb, P  ->  Rd = P ? Ra : Rb.  The predicate is the trailing
            # operand, so it has already been peeled into cin.
            self.r[dst] = self._imm(rem[0]) if self.pr(cin[0]) else self._imm(rem[1])
        else:
            raise NotImplementedError(op + "  |  " + text)

    def _imm(self, tok):
        if re.match(r"^0[xX][0-9a-fA-F]+$", tok):
            return int(tok, 16) & M32
        if re.match(r"^-?\d+$", tok):
            return int(tok) & M32
        return self.rd(tok)

    @staticmethod
    def _pair(name):
        m = re.match(r"^(\D+)(\d+)$", name)
        return name if not m else "%s%d" % (m.group(1), int(m.group(2)) + 1)


def words(v):
    return [(v >> (32 * i)) & M32 for i in range(8)]


def unwords(get):
    return sum(get(i) << (32 * i) for i in range(8))


def run(body, binds, nregs):
    s = Sim()
    for pfx, val in binds.items():
        for i, w in enumerate(words(val)):
            s.r["%s%d" % (pfx, i)] = w
    for pfx, n in nregs.items():
        for i in range(n):
            s.r.setdefault("%s%d" % (pfx, i), 0)
    for ins in body:
        s.step(ins)
    return s


NREG = {"MulMod256": {"Ro": 8, "Rt": 20}, "SqrMod256": {"Ro": 8, "Rt": 26},
        "SubMod256": {"Ro": 8}, "SubMod256_3": {"Ro": 8, "Rt": 2},
        "AddMod256": {"Ro": 8}, "NegMod256": {"Rio": 8}}
ARITY = {"MulMod256": 2, "SqrMod256": 1, "SubMod256": 2, "SubMod256_3": 3,
         "AddMod256": 2, "NegMod256": 1}


def call(F, fn, *v):
    b = ({"RFirst": v[0], "RSecond": v[1]} if fn in ("MulMod256", "SubMod256", "AddMod256")
         else {"RFirst": v[0], "RSecond": v[1], "RThird": v[2]} if fn == "SubMod256_3"
         else {"Rio": v[0]} if fn == "NegMod256" else {"First": v[0]})
    s = run(F[fn], b, NREG[fn])
    key = "Rio" if fn == "NegMod256" else "Ro"
    return unwords(lambda k: s.r["%s%d" % (key, k)])


def expect(fn, v):
    return {"MulMod256": lambda: v[0] * v[1] % P,
            "SqrMod256": lambda: v[0] * v[0] % P,
            "SubMod256": lambda: (v[0] - v[1]) % P,
            "AddMod256": lambda: (v[0] + v[1]) % P,
            "NegMod256": lambda: (-v[0]) % P,
            "SubMod256_3": lambda: (v[0] - v[1] - v[2]) % P}[fn]()


if __name__ == "__main__":
    import random, os
    here = os.path.dirname(os.path.abspath(__file__))
    F = load(os.path.join(here, "..", "mod_mul.asm"))
    F.update(load(os.path.join(here, "..", "mod_sub.asm")))

    # Edge operands first. C8 was found by exactly these and missed by 238 random ones:
    # a product only lands in [P, 2^256) with probability ~2^-224 by chance.
    EDGE = [P - 1, 1, 0, 2, (P + 1) // 2, P - 2, (1 << 255), (1 << 256) - 0x1000003D2]
    rc = 0
    for fn in sorted(ARITY):
        ar = ARITY[fn]
        cases = [tuple(EDGE[(i + j) % len(EDGE)] for j in range(ar))
                 for i in range(len(EDGE))]
        random.seed(7)
        cases += [tuple(random.randrange(0, P) for _ in range(ar)) for _ in range(500)]
        bad = None
        n = 0
        for v in cases:
            got = call(F, fn, *v)
            if got % P != expect(fn, v):
                n += 1
                if bad is None:
                    bad = (v, got, expect(fn, v))
        print("%-12s %s  (%d cases)" % (fn, "OK " if not n else "BAD %d" % n, len(cases)))
        if bad:
            rc = 1
            v, got, want = bad
            for k, x in enumerate(v):
                print("    in%d  %064x" % (k, x))
            print("    got  %064x" % got)
            print("    want %064x" % want)
            print("    diff 0x%x" % ((got - want) % (1 << 256)))
    print("\nNote: every routine here is CONGRUENT-checked, not equality-checked. C8 is the"
          "\nmissing final conditional subtract and it is shared by both sides; this file"
          "\nasks whether the arithmetic is right, not whether it is canonical.")
    sys.exit(rc)
