// A/B: hand-written SASS TestKernel vs the ptxas-compiled one.
//
//   ./abtest <cubinA> <cubinB> [threads] [iters]
//
// Loads both cubins through the driver API, seeds one set of inputs, launches each into
// its own buffers, and answers two questions that must not be conflated:
//
//   1. Do A and B agree with each other?            -- the A/B question
//   2. Is each of them right?                       -- against an independent oracle
//
// (2) matters because both sides can be wrong in the same way. This project's own
// mul_mod is "almost reduced" (DEVPLAN C8) and RCAsm's MulMod256 has been measured to
// have the identical defect, returning p+1 where 1 is correct. A harness that only
// compared the two would print a clean pass over two non-canonical implementations --
// which is the H14 lesson restated. So results are classified three ways:
//
//   EXACT       bit-identical to the canonical (a*b) mod P
//   NON-CANON   congruent but >= P, i.e. canonical + k*P  (C8's signature)
//   WRONG       not congruent to (a*b) mod P at all
//
// The oracle is a plain schoolbook 256x256 -> 512 multiply and a fold-by-K reduction
// written here from the field definition, sharing no code with either device side.
#include <cuda.h>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cstdint>
#include <vector>

typedef unsigned __int128 u128;

// secp256k1: P = 2^256 - 2^32 - 977, so 2^256 == K (mod P) with K = 2^32 + 977.
static const uint64_t P[4] = {0xFFFFFFFEFFFFFC2Full, 0xFFFFFFFFFFFFFFFFull,
                              0xFFFFFFFFFFFFFFFFull, 0xFFFFFFFFFFFFFFFFull};
static const uint64_t K = 0x1000003D1ull;

static bool chk(CUresult r, const char* what)
{
	if (r == CUDA_SUCCESS) return true;
	const char *nm = nullptr, *ds = nullptr;
	cuGetErrorName(r, &nm); cuGetErrorString(r, &ds);
	printf("  FAIL  %-28s %s (%d): %s\n", what, nm ? nm : "?", (int)r, ds ? ds : "?");
	return false;
}
#define CK(x, w) do { if (!chk((x), (w))) return 1; } while (0)

//---- the oracle -------------------------------------------------------------------
static void mul256(const uint64_t a[4], const uint64_t b[4], uint64_t r[8])
{
	memset(r, 0, 8 * sizeof(uint64_t));
	for (int i = 0; i < 4; i++) {
		u128 carry = 0;
		for (int j = 0; j < 4; j++) {
			u128 t = (u128)a[i] * b[j] + r[i + j] + carry;
			r[i + j] = (uint64_t)t;
			carry = t >> 64;
		}
		int k = i + 4;
		while (carry) { u128 t = (u128)r[k] + carry; r[k] = (uint64_t)t; carry = t >> 64; k++; }
	}
}

static int cmp256(const uint64_t a[4], const uint64_t b[4])
{
	for (int i = 3; i >= 0; i--) { if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1; }
	return 0;
}

static uint64_t sub256(uint64_t r[4], const uint64_t a[4], const uint64_t b[4])
{
	uint64_t borrow = 0;
	for (int i = 0; i < 4; i++) {
		u128 t = (u128)a[i] - b[i] - borrow;
		r[i] = (uint64_t)t;
		borrow = (t >> 64) ? 1 : 0;
	}
	return borrow;
}

// acc[0..3] += m * K, returning the carry out of limb 3.
static uint64_t add_mulK(uint64_t acc[4], const uint64_t m[4])
{
	u128 carry = 0;
	for (int i = 0; i < 4; i++) {
		u128 t = (u128)m[i] * K + acc[i] + carry;
		acc[i] = (uint64_t)t;
		carry = t >> 64;
	}
	return (uint64_t)carry;
}

static void mulmodP(const uint64_t a[4], const uint64_t b[4], uint64_t out[4])
{
	uint64_t full[8];
	mul256(a, b, full);

	uint64_t lo[4] = {full[0], full[1], full[2], full[3]};
	uint64_t hi[4] = {full[4], full[5], full[6], full[7]};
	uint64_t c = add_mulK(lo, hi);            // 2^256 == K (mod P)

	uint64_t c2[4] = {c, 0, 0, 0};            // fold the carry once more
	c = add_mulK(lo, c2);
	uint64_t c3[4] = {c, 0, 0, 0};
	add_mulK(lo, c3);                         // cannot carry again

	while (cmp256(lo, P) >= 0) { uint64_t t[4]; sub256(t, lo, P); memcpy(lo, t, sizeof(t)); }
	memcpy(out, lo, 4 * sizeof(uint64_t));
}

// 1/a mod P by Fermat: a^(P-2). Deliberately NOT a copy of inv_mod's binary algorithm --
// the whole value of an oracle is that it shares no structure with the thing it judges, and
// inv_mod is the routine with a known canonicalization defect (C9). Square-and-multiply
// over the exponent's bits costs ~380 mulmodP, which against the ladder's 511 per thread is
// noise. a == 0 has no inverse and is C7; it cannot arise from the harness's operands, and
// if it ever did this would return 0 and every thread would be reported WRONG, which is the
// right outcome for an input the kernel has no defined answer for.
static void invmodP(const uint64_t a[4], uint64_t out[4])
{
	uint64_t e[4] = {P[0] - 2, P[1], P[2], P[3]};       // P[0] is 0xFFFFFFFEFFFFFC2F, no borrow
	uint64_t r[4] = {1, 0, 0, 0}, base[4];
	memcpy(base, a, sizeof(base));
	for (int i = 0; i < 256; i++) {
		if ((e[i >> 6] >> (i & 63)) & 1) mulmodP(r, base, r);
		mulmodP(base, base, base);
	}
	memcpy(out, r, 4 * sizeof(uint64_t));
}

// Reduce into [0, P). One conditional subtract is enough for any 256-bit input:
// (2^256 - 1) - P = 2^32 + 976, which is far below P.
static void canonP(uint64_t a[4])
{
	while (cmp256(a, P) >= 0) { uint64_t t[4]; sub256(t, a, P); memcpy(a, t, sizeof(t)); }
}

// Canonical (a - b) mod P. Only equals what sub_mod/SubMod256 compute when a and b are
// both already < P -- those do one subtract and one conditional add of P, which is a
// modular subtraction only on canonical inputs. That is why the sufp mode canonicalises
// c_Gx, c_Jx and x1 before upload: it keeps this oracle an INDEPENDENT statement of what
// the answer should be, rather than a second copy of the implementation being tested.
static void submodP(const uint64_t a[4], const uint64_t b[4], uint64_t out[4])
{
	uint64_t r[4];
	if (sub256(r, a, b)) {                    // borrow -> a < b
		u128 carry = 0;
		for (int i = 0; i < 4; i++) { u128 t = (u128)r[i] + P[i] + carry; r[i] = (uint64_t)t; carry = t >> 64; }
	}
	memcpy(out, r, 4 * sizeof(uint64_t));
}

// 0 = exact, 1 = congruent but not reduced (canonical + k*P), 2 = wrong
static int classify(const uint64_t got[4], const uint64_t want[4], int* kOut)
{
	if (!memcmp(got, want, 4 * sizeof(uint64_t))) { *kOut = 0; return 0; }
	uint64_t cur[4]; memcpy(cur, want, sizeof(cur));
	for (int k = 1; k <= 4; k++) {
		uint64_t nxt[4];
		u128 carry = 0;
		for (int i = 0; i < 4; i++) { u128 t = (u128)cur[i] + P[i] + carry; nxt[i] = (uint64_t)t; carry = t >> 64; }
		if (carry) break;                      // wrapped past 2^256; no more candidates
		memcpy(cur, nxt, sizeof(cur));
		if (!memcmp(got, cur, sizeof(cur))) { *kOut = k; return 1; }
	}
	return 2;
}

// (P+1)/2. Its double is exactly P+1, which is the deterministic witness for a missing
// final conditional subtract. Derived by shifting P+1 right one bit, and note limb 0
// carries the bit shifted down out of limb 1 -- getting that wrong yields a value whose
// double is not P+1 and the whole edge case silently stops testing anything.
static const uint64_t HALF[4] = {0xFFFFFFFF7FFFFE18ull, 0xFFFFFFFFFFFFFFFFull,
                                 0xFFFFFFFFFFFFFFFFull, 0x7FFFFFFFFFFFFFFFull};

// The oracle is the only thing here that decides right from wrong, so it gets checked
// before anything touches a GPU. Two of these are the exact cases C8 turns on.
static int selftest()
{
	struct { const char* what; uint64_t a[4], b[4], want[4]; } T[] = {
		{"1*1",            {1,0,0,0}, {1,0,0,0}, {1,0,0,0}},
		{"0*x",            {0,0,0,0}, {7,0,0,0}, {0,0,0,0}},
		{"(P-1)^2",        {P[0]-1,P[1],P[2],P[3]}, {P[0]-1,P[1],P[2],P[3]}, {1,0,0,0}},
		{"2*(P+1)/2",      {2,0,0,0}, {HALF[0],HALF[1],HALF[2],HALF[3]}, {1,0,0,0}},
		{"(P-1)*1",        {P[0]-1,P[1],P[2],P[3]}, {1,0,0,0}, {P[0]-1,P[1],P[2],P[3]}},
	};
	int bad = 0;
	for (auto& t : T) {
		uint64_t got[4];
		mulmodP(t.a, t.b, got);
		if (memcmp(got, t.want, sizeof(got))) {
			printf("  ORACLE SELFTEST FAILED: %s\n", t.what);
			printf("    want %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)t.want[3], (unsigned long long)t.want[2],
			       (unsigned long long)t.want[1], (unsigned long long)t.want[0]);
			printf("    got  %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)got[3], (unsigned long long)got[2],
			       (unsigned long long)got[1], (unsigned long long)got[0]);
			bad = 1;
		}
	}
	// submodP, which the sufp mode leans on as heavily as it leans on mulmodP. The
	// borrow case is the whole point: a-b with a < b must come back as a-b+P.
	struct { const char* what; uint64_t a[4], b[4], want[4]; } S[] = {
		{"5-3",            {5,0,0,0}, {3,0,0,0}, {2,0,0,0}},
		{"3-5 (borrow)",   {3,0,0,0}, {5,0,0,0}, {P[0]-2,P[1],P[2],P[3]}},
		{"0-1 (borrow)",   {0,0,0,0}, {1,0,0,0}, {P[0]-1,P[1],P[2],P[3]}},
		{"x-x",            {P[0]-1,P[1],P[2],P[3]}, {P[0]-1,P[1],P[2],P[3]}, {0,0,0,0}},
		{"(P-1)-0",        {P[0]-1,P[1],P[2],P[3]}, {0,0,0,0}, {P[0]-1,P[1],P[2],P[3]}},
	};
	for (auto& t : S) {
		uint64_t got[4];
		submodP(t.a, t.b, got);
		if (memcmp(got, t.want, sizeof(got))) {
			printf("  ORACLE SELFTEST FAILED: submodP %s\n", t.what);
			printf("    want %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)t.want[3], (unsigned long long)t.want[2],
			       (unsigned long long)t.want[1], (unsigned long long)t.want[0]);
			printf("    got  %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)got[3], (unsigned long long)got[2],
			       (unsigned long long)got[1], (unsigned long long)got[0]);
			bad = 1;
		}
	}
	// invmodP. The round-trip case is the one that matters: a * (1/a) == 1 for an operand
	// with no structure, which a wrong exponent or a wrong bit order would not survive.
	struct { const char* what; uint64_t a[4], want[4]; } I[] = {
		{"1/1",     {1,0,0,0}, {1,0,0,0}},
		{"1/2",     {2,0,0,0}, {HALF[0],HALF[1],HALF[2],HALF[3]}},
		{"1/(P-1)", {P[0]-1,P[1],P[2],P[3]}, {P[0]-1,P[1],P[2],P[3]}},   // (P-1)^2 == 1
	};
	for (auto& t : I) {
		uint64_t got[4];
		invmodP(t.a, got);
		if (memcmp(got, t.want, sizeof(got))) {
			printf("  ORACLE SELFTEST FAILED: invmodP %s\n", t.what);
			printf("    want %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)t.want[3], (unsigned long long)t.want[2],
			       (unsigned long long)t.want[1], (unsigned long long)t.want[0]);
			printf("    got  %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)got[3], (unsigned long long)got[2],
			       (unsigned long long)got[1], (unsigned long long)got[0]);
			bad = 1;
		}
	}
	{
		const uint64_t a[4] = {0x9E3779B97F4A7C15ull, 0xBB67AE8584CAA73Bull,
		                       0x3C6EF372FE94F82Bull, 0x510E527FADE682D1ull};
		uint64_t inv[4], back[4];
		invmodP(a, inv);
		mulmodP(a, inv, back);
		const uint64_t one[4] = {1, 0, 0, 0};
		if (memcmp(back, one, sizeof(back))) {
			printf("  ORACLE SELFTEST FAILED: invmodP round trip a*(1/a) != 1\n");
			bad = 1;
		}
	}
	const size_t ncase = sizeof(T) / sizeof(T[0]) + sizeof(S) / sizeof(S[0])
	                   + sizeof(I) / sizeof(I[0]) + 1;
	if (!bad) printf("oracle : selftest passed (%zu cases)\n", ncase);
	return bad;
}

//---- deterministic inputs ----------------------------------------------------------
static uint64_t rngState = 0x243F6A8885A308D3ull;
static uint64_t rnd64()
{
	rngState ^= rngState << 13; rngState ^= rngState >> 7; rngState ^= rngState << 17;
	return rngState;
}

struct Mod {
	CUmodule mod = nullptr;
	CUfunction fn = nullptr;
	CUdeviceptr px = 0, py = 0, sc = 0, ct = 0, fr = 0;
	const char* name;
};

static int upload_const(CUmodule m, const char* sym, const void* src, size_t n)
{
	CUdeviceptr d = 0; size_t sz = 0;
	CUresult r = cuModuleGetGlobal(&d, &sz, m, sym);
	if (r != CUDA_SUCCESS) {
		printf("  FAIL  cuModuleGetGlobal(%s) -- the cubin needs -rdc=true for GLOBAL binding\n", sym);
		return 1;
	}
	if (sz < n) { printf("  FAIL  %s is %zu bytes, wanted %zu\n", sym, sz, n); return 1; }
	if (!chk(cuMemcpyHtoD(d, src, n), sym)) return 1;

	// Read it straight back through the same pointer. This does NOT prove the kernel sees
	// it -- an sm_120 cubin carries the user constant bank twice, as .nv.constant3 and as
	// .nv.merc.nv.constant.user, and this only checks whichever one the symbol names -- but
	// it separates "the upload failed" from "the upload landed somewhere the kernel does
	// not read". Those are different bugs with different fixes, and neither is visible to
	// any check that stops at cuModuleGetGlobal returning success.
	std::vector<unsigned char> back(n);
	if (!chk(cuMemcpyDtoH(back.data(), d, n), sym)) return 1;
	if (memcmp(back.data(), src, n)) {
		printf("  FAIL  %s does not read back as uploaded\n", sym);
		return 1;
	}
	return 0;
}

static void dump256(const char* tag, const uint64_t v[4])
{
	printf("        %-5s: %016llx %016llx %016llx %016llx\n", tag,
	       (unsigned long long)v[3], (unsigned long long)v[2],
	       (unsigned long long)v[1], (unsigned long long)v[0]);
}

// Py in sufp mode is subp[half-1] = (Jx - x1), the value stored BEFORE the ladder's loop.
// It depends on three mechanisms and nothing else -- the constant-bank read, the modular
// subtract, and the local round trip at the top of the frame -- so a wrong value here says
// far more than a wrong count does. Each hypothesis below is a specific way one of those
// three fails, and they produce arithmetically distinct results.
//
// "Jx read as zero" is the one worth naming: stage 2a is the first hand-written code in
// this project to touch constant bank 3 at all, so "the tables never reached this module"
// is untested rather than unlikely -- and it is invisible to every check that does not
// launch, because the symbols resolve and the bank is the right size either way.
// The expected Px for the two ladder modes, in one place. It was written out twice -- once
// for the tally and once for the failure dump -- and a mode added to one and not the other
// is a harness that reports a mismatch against a stale expectation, which is the H14 shape:
// a test whose answer drifted from what it is testing.
//
//   sufp:  acc = (Jx - x1) * prod_{j=1..half-1}(Gx[j] - x1)          <- GpuCore.cu:224-233
//   inv:   1 / (acc * (Gx[0] - x1))                                  <- GpuCore.cu:236-239
//   walk:  prod_{i=0..half-1} dx_inv_i                               <- GpuCore.cu:240-331
//   pts:   prod over all 2*half-1 points of px3                      <- GpuCore.cu:244-378
static void wantPx_ladder(const uint64_t jx[4], const uint64_t* gx, const uint64_t* gy,
                          unsigned half, const uint64_t x1[4], const uint64_t y1[4],
                          bool invm, bool walkm, bool ptsm, uint64_t out[4],
                          uint64_t last[4] = nullptr)
{
	if (ptsm) {
		// The point arithmetic, from the group law rather than from GpuCore.cu's shape:
		//     lam = (py_i - y1) / (px_i - x1);  px3 = lam^2 - x1 - px_i
		// with the minus branch using -py_i, which is the whole of x(-Q) == x(Q). The
		// accumulator is the product of every px3, so one wrong point moves it -- and a
		// product is safe under C8 where the parity is not, because a non-canonical factor
		// is still congruent.
		//
		// This inverts EACH (px_i - x1) by Fermat rather than deriving them all from one
		// inversion. That is 512 exponentiations per thread and it is the point: deriving
		// them cheaply means running the suffix-product ladder, which is the thing stages
		// 2a-2c-i were verifying. The cost is why the caller hoists this out of the A/B
		// loop -- it is computed once per thread, not once per side.
		uint64_t acc[4] = {1, 0, 0, 0};
		for (unsigned i = 0; i < half; ++i) {
			uint64_t d[4], dinv[4];
			submodP(&gx[(size_t)i * 4], x1, d);
			invmodP(d, dinv);
			for (int neg = 0; neg < 2; ++neg) {
				if (i == half - 1 && neg == 0) continue;   // the tail is minus only
				uint64_t py[4], s[4], lam[4], px3[4], t[4];
				memcpy(py, &gy[(size_t)i * 4], sizeof(py));
				if (neg) {
					const uint64_t zero[4] = {0, 0, 0, 0};
					submodP(zero, py, py);                 // -py mod P
				}
				submodP(py, y1, s);
				mulmodP(s, dinv, lam);
				mulmodP(lam, lam, px3);                    // lam^2
				submodP(px3, x1, t);
				submodP(t, &gx[(size_t)i * 4], px3);       // - px_i
				mulmodP(acc, px3, acc);
				if (last) memcpy(last, px3, 4 * sizeof(uint64_t));
			}
		}
		memcpy(out, acc, 4 * sizeof(uint64_t));
		return;
	}
	if (walkm) {
		// The identity the batch inversion exists for is dx_inv_i == 1/(Gx[i] - x1) at
		// every i, so their product is 1 / prod_i (Gx[i] - x1). That costs ONE inversion
		// and 512 multiplies here and -- the point -- involves no suffix products at all:
		// the oracle never runs the algorithm it is judging. Recomputing each inverse
		// separately would be 512 Fermat exponentiations per thread, and getting them
		// cheaply would mean reimplementing the ladder, which is the H14 shape.
		uint64_t prod[4] = {1, 0, 0, 0};
		for (unsigned i = 0; i < half; ++i) {
			uint64_t d[4];
			submodP(&gx[(size_t)i * 4], x1, d);
			mulmodP(prod, d, prod);
		}
		invmodP(prod, out);
		return;
	}
	submodP(jx, x1, out);
	for (unsigned j = half - 1; j >= 1; --j) {
		uint64_t d[4];
		submodP(&gx[(size_t)j * 4], x1, d);
		mulmodP(out, d, out);
	}
	if (invm) {
		uint64_t d0[4];
		submodP(&gx[0], x1, d0);
		mulmodP(out, d0, out);
		invmodP(out, out);
	}
}

static void explain_py(const uint64_t got[4], const uint64_t x1[4], const uint64_t jx[4])
{
	const uint64_t zero[4] = {0, 0, 0, 0};
	struct { const char* why; uint64_t v[4]; } h[5];
	int n = 0;
	submodP(zero, x1, h[n].v); h[n++].why = "Jx READ AS ZERO (0 - x1) -- constant bank 3 never reached this module";
	submodP(x1, jx, h[n].v);   h[n++].why = "operands swapped (x1 - Jx) -- SubMod256 argument order";
	memcpy(h[n].v, jx, 32);    h[n++].why = "raw Jx -- the subtract did not happen";
	memcpy(h[n].v, x1, 32);    h[n++].why = "raw x1 -- Ro aliased RSecond, or nothing was written";
	memcpy(h[n].v, zero, 32);  h[n++].why = "all zero -- nothing stored, or the readback missed the slot";
	for (int i = 0; i < n; i++)
		if (!memcmp(got, h[i].v, 32)) { printf("        ==> %s\n", h[i].why); return; }
	printf("        ==> matches no simple hypothesis\n");
}

int main(int argc, char** argv)
{
	if (selftest()) return 1;

	if (argc == 2 && !strcmp(argv[1], "--selftest")) return 0;
	if (argc < 3) {
		printf("usage: %s <cubinA> <cubinB> [threads] [iters] [mode]\n", argv[0]);
		printf("       mode = mul (1b) | sufp (2a) | inv (2b) | walk (2c-i) | pts (2c-ii)\n");
		printf("       %s --selftest        (oracle only, no GPU needed)\n", argv[0]);
		return 1;
	}
	const char* pathA = argv[1];
	const char* pathB = argv[2];
	const unsigned threads = (argc > 3) ? (unsigned)strtoul(argv[3], nullptr, 0) : 256u;
	const int iters = (argc > 4) ? atoi(argv[4]) : 1;
	// `inv` is a superset of `sufp`: it runs the same ladder and then inverts, so every
	// place that asks "is the ladder active" asks for sufp, and only the final expected
	// value differs. Keeping them as two flags rather than one enum is what makes that
	// relationship visible at each use.
	const bool ptsm = (argc > 5) && !strcmp(argv[5], "pts");
	const bool walkm = ptsm || ((argc > 5) && !strcmp(argv[5], "walk"));
	const bool invm = walkm || ((argc > 5) && !strcmp(argv[5], "inv"));
	const bool sufp = invm || ((argc > 5) && !strcmp(argv[5], "sufp"));
	if (argc > 5 && !sufp && strcmp(argv[5], "mul")) {
		printf("unknown mode '%s' -- expected mul, sufp, inv, walk or pts\n", argv[5]);
		return 1;
	}
	printf("mode   : %s\n", ptsm ? "pts  (stage 2c-ii -- the +/- point arithmetic)"
	                      : walkm ? "walk (stage 2c-i -- the inverse chain over every subp[i])"
	                       : invm ? "inv  (stage 2b -- the ladder plus one InvMod256)"
	                       : sufp ? "sufp (stage 2a -- the suffix-product ladder)"
	                              : "mul  (stage 1b -- one MulMod256)");
	const unsigned block = 256;
	if (threads % block) { printf("threads must be a multiple of %u\n", block); return 1; }
	const unsigned grid = threads / block;

	CK(cuInit(0), "cuInit");
	CUdevice dev; CK(cuDeviceGet(&dev, 0), "cuDeviceGet");
	char nm[128]; cuDeviceGetName(nm, sizeof(nm), dev);
	int cc_maj = 0, cc_min = 0;
	cuDeviceGetAttribute(&cc_maj, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, dev);
	cuDeviceGetAttribute(&cc_min, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, dev);
	printf("device : %s (sm_%d%d)\n", nm, cc_maj, cc_min);
	printf("threads: %u  (grid %u x block %u)   iters %d\n\n", threads, grid, block, iters);

	CUcontext ctx; CK(cuDevicePrimaryCtxRetain(&ctx, dev), "cuDevicePrimaryCtxRetain");
	CK(cuCtxSetCurrent(ctx), "cuCtxSetCurrent");

	//---- inputs, identical for both -------------------------------------------------
	const size_t nlimb = (size_t)threads * 4;
	std::vector<uint64_t> hx(nlimb), hy(nlimb), hs(nlimb), hc(nlimb);
	for (size_t i = 0; i < nlimb; i++) { hx[i] = rnd64(); hy[i] = rnd64(); hs[i] = rnd64(); }
	// rem must be non-zero or both kernels bail before writing anything.
	for (size_t i = 0; i < nlimb; i++) hc[i] = (i % 4 == 0) ? 0x4000ull : 0ull;

	// A handful of deliberately awkward operands. Random 256-bit values never land on
	// the edge cases: a product in [P, 2^256) has probability ~2^-224, which is exactly
	// how C8 stayed invisible for so long.
	if (threads >= 4) {
		auto set = [&](size_t t, const uint64_t a[4], const uint64_t b[4]) {
			for (int k = 0; k < 4; k++) { hx[t * 4 + k] = a[k]; hy[t * 4 + k] = b[k]; }
		};
		const uint64_t Pm1[4] = {P[0] - 1, P[1], P[2], P[3]};
		const uint64_t two[4] = {2, 0, 0, 0};
		const uint64_t one[4] = {1, 0, 0, 0};
		set(0, Pm1, Pm1);     // (P-1)^2 == 1, lands on P+1 without the final subtract
		set(1, two, HALF);    // 2*(P+1)/2 == 1, same
		set(2, HALF, two);
		set(3, one, one);
	}

	const size_t bytes = nlimb * sizeof(uint64_t);
	Mod M[2]; M[0].name = "A"; M[1].name = "B";
	const char* paths[2] = {pathA, pathB};

	std::vector<uint64_t> outPx[2], outPy[2], outSc[2], outCt[2];
	float ms[2] = {0, 0};

	// Constant tables: not read at stage 1b, but uploaded anyway so the same harness
	// works unchanged once the walk lands, and so a missing GLOBAL binding fails here
	// rather than silently later.
	// One definition. The kernels derive half = batch_size >> 1 and index subp[] and
	// c_Gx[] by it, the oracle's trip count is half-1, and the tables are sized half*4 --
	// three places that silently produce a plausible wrong answer if they disagree.
	const unsigned BATCH = 1024;
	const unsigned half = BATCH >> 1;

	std::vector<uint64_t> gx(half * 4), gy(half * 4);
	for (size_t i = 0; i < gx.size(); i++) { gx[i] = rnd64(); gy[i] = rnd64(); }
	uint64_t jx[4], jy[4]; uint32_t tw[5];
	for (int i = 0; i < 4; i++) { jx[i] = rnd64(); jy[i] = rnd64(); }
	for (int i = 0; i < 5; i++) tw[i] = (uint32_t)rnd64();

	// sufp mode canonicalises every operand the ladder consumes. sub_mod/SubMod256 do one
	// subtract and one conditional add of P, which is a modular subtraction only when both
	// operands are already < P -- and the real c_Gx holds curve x-coordinates, so this is
	// the faithful input domain, not a convenience. Without it the oracle would have to
	// model the implementation instead of stating the answer, and a harness that shares
	// its subject's convention proves nothing (the lesson C8 taught twice).
	if (sufp) {
		for (size_t i = 0; i < gx.size(); i += 4) { canonP(&gx[i]); canonP(&gy[i]); }
		canonP(jx); canonP(jy);
		for (size_t i = 0; i < nlimb; i += 4) canonP(&hx[i]);
	}

	for (int m = 0; m < 2; m++) {
		printf("---- %s : %s\n", M[m].name, paths[m]);
		CK(cuModuleLoad(&M[m].mod, paths[m]), "cuModuleLoad");
		CK(cuModuleGetFunction(&M[m].fn, M[m].mod, "TestKernel"), "cuModuleGetFunction");

		int regs = 0, lmem = 0, maxthr = 0;
		cuFuncGetAttribute(&regs, CU_FUNC_ATTRIBUTE_NUM_REGS, M[m].fn);
		cuFuncGetAttribute(&lmem, CU_FUNC_ATTRIBUTE_LOCAL_SIZE_BYTES, M[m].fn);
		cuFuncGetAttribute(&maxthr, CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK, M[m].fn);
		printf("       REG %d   LOCAL %d   MAX_THREADS %d\n", regs, lmem, maxthr);

		if (upload_const(M[m].mod, "c_Gx", gx.data(), gx.size() * 8)) return 1;
		if (upload_const(M[m].mod, "c_Gy", gy.data(), gy.size() * 8)) return 1;
		if (upload_const(M[m].mod, "c_Jx", jx, sizeof(jx))) return 1;
		if (upload_const(M[m].mod, "c_Jy", jy, sizeof(jy))) return 1;
		if (upload_const(M[m].mod, "c_target_words", tw, sizeof(tw))) return 1;

		CK(cuMemAlloc(&M[m].px, bytes), "cuMemAlloc px");
		CK(cuMemAlloc(&M[m].py, bytes), "cuMemAlloc py");
		CK(cuMemAlloc(&M[m].sc, bytes), "cuMemAlloc sc");
		CK(cuMemAlloc(&M[m].ct, bytes), "cuMemAlloc ct");
		CK(cuMemAlloc(&M[m].fr, 128), "cuMemAlloc fr");
		CK(cuMemsetD8(M[m].fr, 0, 128), "memset fr");

		unsigned long long thrTotal = threads;
		unsigned batch = BATCH, bpl = 1;
		void* args[8] = {&M[m].px, &M[m].py, &M[m].sc, &M[m].ct, &M[m].fr,
		                 &thrTotal, &batch, &bpl};

		CUevent e0, e1; cuEventCreate(&e0, 0); cuEventCreate(&e1, 0);
		for (int it = 0; it < iters; it++) {
			CK(cuMemcpyHtoD(M[m].px, hx.data(), bytes), "H2D px");
			CK(cuMemcpyHtoD(M[m].py, hy.data(), bytes), "H2D py");
			CK(cuMemcpyHtoD(M[m].sc, hs.data(), bytes), "H2D sc");
			CK(cuMemcpyHtoD(M[m].ct, hc.data(), bytes), "H2D ct");
			CK(cuCtxSynchronize(), "sync before");
			cuEventRecord(e0, 0);
			CK(cuLaunchKernel(M[m].fn, grid, 1, 1, block, 1, 1, 0, 0, args, nullptr), "cuLaunchKernel");
			cuEventRecord(e1, 0);
			CUresult sr = cuCtxSynchronize();
			if (!chk(sr, "cuCtxSynchronize (kernel)")) return 1;
			float t = 0; cuEventElapsedTime(&t, e0, e1);
			if (it == 0 || t < ms[m]) ms[m] = t;
		}
		printf("       launch OK, best of %d: %.4f ms\n", iters, ms[m]);

		outPx[m].resize(nlimb); outPy[m].resize(nlimb);
		outSc[m].resize(nlimb); outCt[m].resize(nlimb);
		CK(cuMemcpyDtoH(outPx[m].data(), M[m].px, bytes), "D2H px");
		CK(cuMemcpyDtoH(outPy[m].data(), M[m].py, bytes), "D2H py");
		CK(cuMemcpyDtoH(outSc[m].data(), M[m].sc, bytes), "D2H sc");
		CK(cuMemcpyDtoH(outCt[m].data(), M[m].ct, bytes), "D2H ct");
		printf("\n");
	}

	//---- 1. A vs B ------------------------------------------------------------------
	size_t dPx = 0, dPy = 0, dSc = 0, dCt = 0, firstAB = (size_t)-1;
	for (size_t i = 0; i < nlimb; i++) {
		if (outPx[0][i] != outPx[1][i]) { dPx++; if (firstAB == (size_t)-1) firstAB = i / 4; }
		if (outPy[0][i] != outPy[1][i]) dPy++;
		if (outSc[0][i] != outSc[1][i]) dSc++;
		if (outCt[0][i] != outCt[1][i]) dCt++;
	}
	printf("==== A vs B ====\n");
	printf("  differing limbs:  Px %zu   Py %zu   scalars %zu   counts %zu   (of %zu each)\n",
	       dPx, dPy, dSc, dCt, nlimb);
	const bool abSame = !(dPx | dPy | dSc | dCt);
	printf("  %s\n\n", abSame ? "A and B agree on every output limb."
	                          : "A and B DISAGREE.");

	//---- 2. each vs the oracle ------------------------------------------------------
	printf(ptsm ? "==== each vs the canonical product of every px3 ====\n"
	     : walkm ? "==== each vs the canonical product of 1/(Gx[i]-x1) ====\n"
	     : invm ? "==== each vs the canonical inverse ====\n"
	     : sufp ? "==== each vs the canonical suffix product ====\n"
	            : "==== each vs canonical (a*b) mod P ====\n");

	// Computed ONCE per thread rather than once per side. It used to sit inside the m loop,
	// which was free when the expectation was a few hundred multiplies; pts mode inverts
	// every (Gx[i] - x1) by Fermat, and paying that twice for an identical answer is the
	// kind of waste that turns a check people run into one they skip.
	std::vector<uint64_t> wantPxAll(nlimb), wantPyAll(nlimb);
	for (size_t t = 0; t < threads; t++) {
		uint64_t a[4], b[4];
		for (int k = 0; k < 4; k++) { a[k] = hx[t * 4 + k]; b[k] = hy[t * 4 + k]; }
		if (sufp) {
			// subp[half-1] is the ladder's first factor on its own -- the value stored
			// before the loop, at the top of the frame, so reading it back says the ladder
			// stored where it meant to rather than merely computing the right product. It
			// is the same in every ladder mode on purpose: a failure in the newest stage
			// that is really a stage-2a regression lands on Py, not on Px.
			submodP(jx, a, &wantPyAll[t * 4]);
			// In pts mode Py is the tail's px3, not subp[half-1] -- the value that says
			// WHICH point is wrong rather than only that the product is.
			wantPx_ladder(jx, gx.data(), gy.data(), half, a, b, invm, walkm, ptsm,
			              &wantPxAll[t * 4], ptsm ? &wantPyAll[t * 4] : nullptr);
		} else {
			mulmodP(a, b, &wantPxAll[t * 4]);
			memcpy(&wantPyAll[t * 4], b, 4 * sizeof(uint64_t));   // Py is identity in mul mode
		}
	}

	int bad = 0;
	for (int m = 0; m < 2; m++) {
		size_t exact = 0, noncanon = 0, wrong = 0, firstWrong = (size_t)-1;
		size_t idPy = 0, idSc = 0, idCt = 0, firstPy = (size_t)-1;
		for (size_t t = 0; t < threads; t++) {
			uint64_t want[4], got[4], wantPy[4];
			for (int k = 0; k < 4; k++) got[k] = outPx[m][t * 4 + k];
			memcpy(want, &wantPxAll[t * 4], sizeof(want));
			memcpy(wantPy, &wantPyAll[t * 4], sizeof(wantPy));
			int kk = 0;
			switch (classify(got, want, &kk)) {
				case 0: exact++; break;
				case 1: noncanon++; break;
				default: wrong++; if (firstWrong == (size_t)-1) firstWrong = t; break;
			}
			for (int k = 0; k < 4; k++) {
				if (outPy[m][t * 4 + k] != wantPy[k]) {
					idPy++;
					if (firstPy == (size_t)-1) firstPy = t;
				}
				if (outSc[m][t * 4 + k] != hs[t * 4 + k]) idSc++;
				if (outCt[m][t * 4 + k] != hc[t * 4 + k]) idCt++;
			}
		}
		printf("  %s:  EXACT %zu   NON-CANON %zu   WRONG %zu   (of %u)\n",
		       M[m].name, exact, noncanon, wrong, threads);
		printf("      %s -- Py %s  scalars %s  counts %s\n",
		       ptsm ? "last px3 + identity" : sufp ? "subp[half-1] + identity" : "identity check",
		       idPy ? "BROKEN" : "ok", idSc ? "BROKEN" : "ok", idCt ? "BROKEN" : "ok");
		if (wrong) {
			bad = 1;
			uint64_t want[4], a[4], b[4];
			for (int k = 0; k < 4; k++) { a[k] = hx[firstWrong * 4 + k]; b[k] = hy[firstWrong * 4 + k]; }
			memcpy(want, &wantPxAll[firstWrong * 4], sizeof(want));
			printf("      first wrong at thread %zu\n", firstWrong);
			printf("        a    : %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)a[3], (unsigned long long)a[2],
			       (unsigned long long)a[1], (unsigned long long)a[0]);
			printf("        b    : %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)b[3], (unsigned long long)b[2],
			       (unsigned long long)b[1], (unsigned long long)b[0]);
			printf("        want : %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)want[3], (unsigned long long)want[2],
			       (unsigned long long)want[1], (unsigned long long)want[0]);
			printf("        got  : %016llx %016llx %016llx %016llx\n",
			       (unsigned long long)outPx[m][firstWrong * 4 + 3],
			       (unsigned long long)outPx[m][firstWrong * 4 + 2],
			       (unsigned long long)outPx[m][firstWrong * 4 + 1],
			       (unsigned long long)outPx[m][firstWrong * 4 + 0]);
		}
		// Py is dumped even though Px already is: in sufp mode Py is the FIRST step of the
		// ladder and Px is the last, so when both are wrong Py is the one that names the
		// cause. Px inherits any error Py has.
		if (idPy) {
			uint64_t a[4], wp[4];
			for (int k = 0; k < 4; k++) a[k] = hx[firstPy * 4 + k];
			// Print the value that was actually COMPARED. This used to recompute
			// Jx - x1 whenever sufp was set -- which pts mode implies -- so in pts mode
			// it printed the stage-2a expectation next to a stage-2c value. The two are
			// unrelated, explain_py() then reported "matches no simple hypothesis" about
			// a hypothesis nobody had made, and the dump read as a deep mystery when the
			// only thing wrong with it was the line that produced it.
			memcpy(wp, &wantPyAll[firstPy * 4], sizeof(wp));
			printf("      first wrong Py at thread %zu%s\n", firstPy,
			       ptsm ? "   (px3 of the tail point: i = half-1, minus branch)"
			       : sufp ? "   (subp[half-1] = Jx - x1, stored before the loop)" : "");
			dump256("x1", a);
			if (sufp && !ptsm) dump256("Jx", jx);
			dump256("want", wp);
			dump256("got", &outPy[m][firstPy * 4]);
			{
				uint64_t d[4]; bool bw = false;
				for (int k = 0; k < 4; k++) {
					uint64_t g = outPy[m][firstPy * 4 + k];
					uint64_t t = g - wp[k] - (bw ? 1 : 0);
					bw = bw ? (g <= wp[k]) : (g < wp[k]);
					d[k] = t;
				}
				dump256("got-want", d);
			}
			if (sufp && !ptsm) explain_py(&outPy[m][firstPy * 4], a, jx);
		}
		if (idPy || idSc || idCt) bad = 1;
	}

	printf("\n==== timing ====\n");
	printf("  A %.4f ms    B %.4f ms    B/A %.3fx\n", ms[0], ms[1],
	       ms[0] > 0 ? ms[1] / ms[0] : 0.0f);
	printf("  (meaningless until both kernels do the same amount of work)\n");

	for (int m = 0; m < 2; m++) {
		cuMemFree(M[m].px); cuMemFree(M[m].py); cuMemFree(M[m].sc);
		cuMemFree(M[m].ct); cuMemFree(M[m].fr); cuModuleUnload(M[m].mod);
	}
	cuDevicePrimaryCtxRelease(dev);

	printf("\nVERDICT: %s\n", (abSame && !bad) ? "A and B agree, and neither is WRONG."
	                                           : "see above -- NOT a clean pass.");
	return (abSame && !bad) ? 0 : 2;
}
