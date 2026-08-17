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
#include <algorithm>
#include <chrono>

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
	// %-6s, not %-5s: "delta" is exactly five characters, so the narrower field left it the
	// one tag with no space before its colon -- and bisect_run.sh's filter matches ` +:`, so
	// the delta line was silently dropped from every run that printed one.
	printf("        %-6s: %016llx %016llx %016llx %016llx\n", tag,
	       (unsigned long long)v[3], (unsigned long long)v[2],
	       (unsigned long long)v[1], (unsigned long long)v[0]);
}

// want, got, and the 256-bit difference. The difference is the part that has actually paid:
// the tail's px3 came back 2^224 + 0x7A1 from correct, and "carry-sized, limbs 1 and 2
// untouched" is a different diagnosis from "wrong operand" -- which is not visible at all
// while staring at two 64-hex-digit numbers.
static void dump_delta(const uint64_t got[4], const uint64_t want[4])
{
	uint64_t d[4];
	bool bw = false;
	for (int k = 0; k < 4; k++) {
		const uint64_t g = got[k], w = want[k];
		d[k] = g - w - (bw ? 1 : 0);
		bw = bw ? (g <= w) : (g < w);
	}
	dump256("want", want);
	dump256("got", got);
	dump256("delta", d);
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
                          uint64_t last[4] = nullptr,
                          uint64_t lastlam[4] = nullptr, uint64_t lastsqr[4] = nullptr)
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
				uint64_t py[4], s[4], lam[4], px3[4], t[4], sq[4];
				memcpy(py, &gy[(size_t)i * 4], sizeof(py));
				if (neg) {
					const uint64_t zero[4] = {0, 0, 0, 0};
					submodP(zero, py, py);                 // -py mod P
				}
				submodP(py, y1, s);
				mulmodP(s, dinv, lam);
				mulmodP(lam, lam, sq);                     // lam^2
				submodP(sq, x1, t);
				submodP(t, &gx[(size_t)i * 4], px3);       // - px_i
				mulmodP(acc, px3, acc);
				if (last) memcpy(last, px3, 4 * sizeof(uint64_t));
				// The two intermediates behind px3, kept so the harness can bisect the
				// tail's chain in one launch instead of one launch per link.
				if (lastlam) memcpy(lastlam, lam, 4 * sizeof(uint64_t));
				if (lastsqr) memcpy(lastsqr, sq, 4 * sizeof(uint64_t));
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

// Stage 2d's oracle, and the thing to notice about it is how little it has to compute.
//
// After the walk's last chain update the kernel's `inverse` is 1/(Jx - x1) -- every factor
// the ladder multiplied in has been multiplied back out again. So the point jump is one
// affine addition of the jump constant J = half*G, and the oracle states it directly:
//
//     lam = (Jy - y1)/(Jx - x1);  x3 = lam^2 - x1 - Jx;  y3 = (x1 - x3)*lam - y1
//
// ONE inversion per batch, and no suffix products anywhere -- the oracle does not run the
// algorithm it is judging, which is the property stages 2a-2c-i were built around and the
// one H14 lost. It is also why this rung is worth having even though `walk` passed: the walk
// accumulates dx_inv_i, and an `inverse` that is wrong only at the very end would leave every
// accumulated value right and this one wrong.
//
// `bump` is the difference between the two rungs. `jump` runs one batch and leaves s1/rem
// alone, which is exactly what the SASS does without its LOOPTOP/LOOPEND regions; `loop`
// runs the real guard and advances both.
static void wantJump(const uint64_t jx[4], const uint64_t jy[4],
                     const uint64_t x1in[4], const uint64_t y1in[4],
                     const uint64_t s1in[4], const uint64_t remin[4],
                     uint64_t B, unsigned batches, bool bump,
                     uint64_t outX[4], uint64_t outY[4],
                     uint64_t outS[4], uint64_t outC[4])
{
	uint64_t x1[4], y1[4], s1[4], rem[4];
	memcpy(x1, x1in, 32); memcpy(y1, y1in, 32);
	memcpy(s1, s1in, 32); memcpy(rem, remin, 32);

	for (unsigned n = 0; n < batches; n++) {
		if (bump && !(rem[3] | rem[2] | rem[1]) && rem[0] < B) break;   // ge256_u64
		uint64_t d[4], dinv[4], s[4], lam[4], sq[4], t[4], x3[4], y3[4];
		submodP(jx, x1, d);
		invmodP(d, dinv);
		submodP(jy, y1, s);
		mulmodP(s, dinv, lam);
		mulmodP(lam, lam, sq);
		submodP(sq, x1, t);
		submodP(t, jx, x3);
		submodP(x1, x3, t);
		mulmodP(t, lam, y3);
		submodP(y3, y1, y3);
		memcpy(x1, x3, 32); memcpy(y1, y3, 32);
		if (!bump) continue;
		// s1 += B and rem -= B, 256-bit against a value that fits in one limb. rem >= B is
		// guaranteed by the guard above, so no borrow escapes limb 3.
		uint64_t c = (s1[0] + B < s1[0]) ? 1ull : 0ull;
		s1[0] += B;
		for (int k = 1; k < 4 && c; k++) { s1[k] += 1; c = (s1[k] == 0) ? 1ull : 0ull; }
		uint64_t bw = (rem[0] < B) ? 1ull : 0ull;
		rem[0] -= B;
		for (int k = 1; k < 4 && bw; k++) { bw = (rem[k] == 0) ? 1ull : 0ull; rem[k] -= 1; }
	}
	memcpy(outX, x1, 32); memcpy(outY, y1, 32);
	memcpy(outS, s1, 32); memcpy(outC, rem, 32);
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
		printf("usage: %s <cubinA> <cubinB> [threads] [iters|Ns] [mode] [batch]\n", argv[0]);
		printf("       iters = launch count, or `180s` for 180 seconds PER SIDE\n");
		printf("       launches are INTERLEAVED A,B,A,B so both sides see one thermal envelope\n");
		printf("       mode = mul (1b) | sufp (2a) | inv (2b) | walk (2c-i) | pts (2c-ii)\n");
		printf("              | jump (2d, the point jump) | loop (2d, the batch loop)\n");
		printf("       batch = keys per batch, even, 2..1024 (default 1024). BOTH sides get the\n");
		printf("               same value -- P2 compares two FRAME sizes at one batch size, and\n");
		printf("               a per-side batch would make the A/B limb diff meaningless.\n");
		printf("       %s --selftest        (oracle only, no GPU needed)\n", argv[0]);
		return 1;
	}
	const char* pathA = argv[1];
	const char* pathB = argv[2];
	const unsigned threads = (argc > 3) ? (unsigned)strtoul(argv[3], nullptr, 0) : 256u;
	// `iters` is a launch count, or `Ns` for N seconds PER SIDE.
	//
	// Duration mode exists because "run each side longer to average out throttling" is the
	// obvious idea and, with the launches ordered A-then-B, it makes the bias WORSE rather than
	// better: side A runs on a cool card and side B on one that A just spent minutes heating.
	// The longer the run, the larger that gap. So duration mode comes with interleaving -- see
	// the timing loop -- and the two are one change, not two.
	const char* itArg = (argc > 4) ? argv[4] : "1";
	const size_t itLen = strlen(itArg);
	const bool durMode = itLen > 1 && (itArg[itLen - 1] == 's' || itArg[itLen - 1] == 'S');
	const double durSecs = durMode ? atof(itArg) : 0.0;
	const int iters = durMode ? INT32_MAX : atoi(itArg);
	// `inv` is a superset of `sufp`: it runs the same ladder and then inverts, so every
	// place that asks "is the ladder active" asks for sufp, and only the final expected
	// value differs. Keeping them as two flags rather than one enum is what makes that
	// relationship visible at each use.
	const bool ptsm = (argc > 5) && !strcmp(argv[5], "pts");
	const bool walkm = ptsm || ((argc > 5) && !strcmp(argv[5], "walk"));
	const bool invm = walkm || ((argc > 5) && !strcmp(argv[5], "inv"));
	// jump and loop are stage 2d and they are NOT supersets of ptsm here, deliberately. They
	// run the same kernel path, but their oracle is the affine addition below rather than the
	// per-point product -- pts costs 512 Fermat inversions per thread and answers a question
	// these two do not ask.
	const bool loopm = (argc > 5) && !strcmp(argv[5], "loop");
	const bool jumpm = loopm || ((argc > 5) && !strcmp(argv[5], "jump"));
	const bool sufp = invm || jumpm || ((argc > 5) && !strcmp(argv[5], "sufp"));
	if (argc > 5 && !sufp && strcmp(argv[5], "mul")) {
		printf("unknown mode '%s' -- expected mul, sufp, inv, walk, pts, jump or loop\n",
		       argv[5]);
		return 1;
	}
	// P2's variable. The kernel's subp[] frame is sized by the COMPILE-time MAX_BATCH_SIZE while
	// the work is done at the RUN-time batch, so the two can be moved independently -- which is
	// the only way to ask whether the frame costs anything on its own. Give both sides the same
	// value and vary only which cubin they are: a per-side batch would have the two kernels
	// computing different points, and the A-vs-B limb diff is worth more than that comparison.
	//
	// 1024 is the cap because it is the default MAX_BATCH_SIZE; a larger value makes every
	// kernel bail at `B > MAX_BATCH_SIZE` and report a clean pass over two kernels that did
	// nothing, which is this project's signature failure.
	const unsigned batchArg = (argc > 6) ? (unsigned)strtoul(argv[6], nullptr, 0) : 1024u;
	if (batchArg < 2 || batchArg > 1024 || (batchArg & 1)) {
		printf("batch must be even and in 2..1024 (got %u)\n", batchArg);
		return 1;
	}
	printf("mode   : %s\n", loopm ? "loop (stage 2d -- the outer batch loop)"
	                      : jumpm ? "jump (stage 2d -- the point jump)"
	                       : ptsm ? "pts  (stage 2c-ii -- the +/- point arithmetic)"
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
	int smCount = 0;
	cuDeviceGetAttribute(&smCount, CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT, dev);
	printf("device : %s (sm_%d%d, %d SMs)\n", nm, cc_maj, cc_min, smCount);
	if (durMode)
		printf("threads: %u  (grid %u x block %u)   %.0fs per side, INTERLEAVED\n",
		       threads, grid, block, durSecs);
	else
		printf("threads: %u  (grid %u x block %u)   iters %d%s\n", threads, grid, block, iters,
		       iters > 1 ? ", INTERLEAVED" : "");
	// The batch size is a property of the run, not of either cubin, and the whole of P2 is that
	// it can differ from the frame the cubin was compiled for. Print it beside the threads so no
	// result can be quoted without it.
	printf("batch  : %u keys/batch  (half %u)   subp[] TOUCHED per batch: %u B/thread\n",
	       batchArg, batchArg >> 1, (batchArg >> 1) * 32u);
	// Every run before this one was a single block, so gid == threadIdx.x and the BlockID term
	// of `IMAD gID, BlockID, 0x100, ThrID` was multiplied by zero. Say so when it stops being.
	if (grid == 1)
		printf("         ONE BLOCK -- BlockID is 0, so gid arithmetic is only half exercised\n");
	printf("\n");

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
	const unsigned BATCH = batchArg;
	const unsigned half = BATCH >> 1;
	// Four batches on the loop rung, one everywhere else. rem is seeded at 0x4000 keys, which is
	// 16 batches at the largest permitted batch and more at any smaller one, so the guard is
	// exercised without ever being the limiter -- four is comfortably inside the range at every
	// batch size this harness accepts, and still exercises the guard, the back edge and
	// three re-entries into the ladder with a point the previous batch produced. One would
	// run the loop body once and prove only that the branch was taken. Declared beside BATCH
	// because the oracle and the launch must agree on it -- the same reason BATCH is.
	const unsigned BPL = loopm ? 4u : 1u;

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

	// Hoisted out of the per-module loop so both argument blocks are alive at once: the timing
	// loop alternates between them, and each holds pointers into its own module's allocations.
	// thrTotal/batch/bpl are shared by both sides by definition.
	unsigned long long thrTotal = threads;
	unsigned batch = BATCH, bpl = BPL;
	void* args[2][8];

	for (int m = 0; m < 2; m++) {
		printf("---- %s : %s\n", M[m].name, paths[m]);
		CK(cuModuleLoad(&M[m].mod, paths[m]), "cuModuleLoad");
		CK(cuModuleGetFunction(&M[m].fn, M[m].mod, "TestKernel"), "cuModuleGetFunction");

		int regs = 0, lmem = 0, maxthr = 0;
		cuFuncGetAttribute(&regs, CU_FUNC_ATTRIBUTE_NUM_REGS, M[m].fn);
		cuFuncGetAttribute(&lmem, CU_FUNC_ATTRIBUTE_LOCAL_SIZE_BYTES, M[m].fn);
		cuFuncGetAttribute(&maxthr, CU_FUNC_ATTRIBUTE_MAX_THREADS_PER_BLOCK, M[m].fn);
		// Occupancy, because a wall-clock ratio between these two kernels is uninterpretable
		// without it. The hand-written side runs at REG 255 and the compiled one at REG 128,
		// and at a 256-thread block that is 1 resident block per SM against 2 -- so a raw B/A
		// carries a 2x latency-hiding handicap that has nothing to do with instruction count.
		// Ask the driver rather than deriving it from the register file size, which varies.
		int blocksPerSM = 0;
		cuOccupancyMaxActiveBlocksPerMultiprocessor(&blocksPerSM, M[m].fn, (int)block, 0);
		printf("       REG %d   LOCAL %d   MAX_THREADS %d   BLOCKS/SM %d"
		       "   (%d SMs -> %d resident blocks, %d waves for this grid)\n",
		       regs, lmem, maxthr, blocksPerSM, smCount, blocksPerSM * smCount,
		       (blocksPerSM * smCount) > 0 ? (int)((grid + blocksPerSM * smCount - 1)
		                                           / (blocksPerSM * smCount)) : 0);

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

		args[m][0] = &M[m].px; args[m][1] = &M[m].py; args[m][2] = &M[m].sc;
		args[m][3] = &M[m].ct; args[m][4] = &M[m].fr;
		args[m][5] = &thrTotal; args[m][6] = &batch; args[m][7] = &bpl;
		printf("\n");
	}

	// TIMING -- INTERLEAVED, ONE LAUNCH OF A THEN ONE OF B, REPEATED.
	//
	// It used to run every launch of A, then every launch of B, and that is a thermal ramp
	// pointed at exactly one side: A measures a cool card and B measures the card A just
	// heated. At `iters 5` the effect is small; the moment anyone runs longer to "average out
	// throttling" -- the obvious and correct instinct -- it grows without bound, and it grows
	// against B. The two sides now sit in the same thermal envelope by construction, which is
	// what makes a long run worth more than a short one instead of less.
	//
	// This does NOT make the absolute numbers throttle-proof, and nothing here can. It makes
	// the RATIO fair, which is the thing being read. Compare the absolute A column against its
	// own history (see the throttle note in DEVPLAN) to decide whether the session is clean.
	CUevent e0, e1; cuEventCreate(&e0, 0); cuEventCreate(&e1, 0);
	std::vector<float> tv[2];
	const auto wall0 = std::chrono::steady_clock::now();
	auto elapsed = [&] {
		return std::chrono::duration<double>(std::chrono::steady_clock::now() - wall0).count();
	};
	for (int it = 0; it < iters; it++) {
		// Checked at the TOP of a round, never mid-round: a round that launches A and not B
		// would put one extra A sample into the pool and skew the very comparison this exists
		// to protect. Both sides always have the same number of samples.
		if (durMode && elapsed() >= durSecs * 2.0) break;
		for (int m = 0; m < 2; m++) {
			CK(cuMemcpyHtoD(M[m].px, hx.data(), bytes), "H2D px");
			CK(cuMemcpyHtoD(M[m].py, hy.data(), bytes), "H2D py");
			CK(cuMemcpyHtoD(M[m].sc, hs.data(), bytes), "H2D sc");
			CK(cuMemcpyHtoD(M[m].ct, hc.data(), bytes), "H2D ct");
			CK(cuCtxSynchronize(), "sync before");
			cuEventRecord(e0, 0);
			CK(cuLaunchKernel(M[m].fn, grid, 1, 1, block, 1, 1, 0, 0, args[m], nullptr),
			   "cuLaunchKernel");
			cuEventRecord(e1, 0);
			CUresult sr = cuCtxSynchronize();
			if (!chk(sr, "cuCtxSynchronize (kernel)")) return 1;
			float t = 0; cuEventElapsedTime(&t, e0, e1);
			tv[m].push_back(t);
		}
	}

	// BEST **AND** MEDIAN. Best-of-N is the right statistic for "how fast can this kernel go",
	// and it is the wrong one for "is this card throttling": it reports the single least-throttled
	// launch and hides everything else, so a long run and a short one give the same answer and the
	// spread that would have shown the problem never appears. The median moves when the card
	// slows down. Print both and the disagreement between them is the diagnostic.
	float med[2] = {0, 0};
	for (int m = 0; m < 2; m++) {
		if (tv[m].empty()) { printf("no launches timed\n"); return 1; }
		std::vector<float> s = tv[m];
		std::sort(s.begin(), s.end());
		ms[m] = s.front();
		med[m] = s[s.size() / 2];
		printf("---- %s : %zu launches   best %.4f ms   median %.4f ms   worst %.4f ms"
		       "   spread %.1f%%\n", M[m].name, s.size(), ms[m], med[m], s.back(),
		       100.0 * (s.back() - s.front()) / s.front());
	}
	printf("\n");

	for (int m = 0; m < 2; m++) {
		outPx[m].resize(nlimb); outPy[m].resize(nlimb);
		outSc[m].resize(nlimb); outCt[m].resize(nlimb);
		CK(cuMemcpyDtoH(outPx[m].data(), M[m].px, bytes), "D2H px");
		CK(cuMemcpyDtoH(outPy[m].data(), M[m].py, bytes), "D2H py");
		CK(cuMemcpyDtoH(outSc[m].data(), M[m].sc, bytes), "D2H sc");
		CK(cuMemcpyDtoH(outCt[m].data(), M[m].ct, bytes), "D2H ct");
	}

	// counts256 IS NO LONGER A COMPARABLE OUTPUT, except on the pts rung.
	//
	// The hand-written kernel stopped tracking and writing rem: it costs 8 registers held live
	// straight through the inversion, which is the difference between 127 registers and 135,
	// i.e. between two resident blocks per SM and one. The compiled reference still writes it,
	// so comparing the array would report a disagreement that is a deliberate contract change
	// rather than a defect.
	//
	// pts is the exception and keeps its check: that rung spends counts256 on SqrMod256's
	// output via STORELAM, so the array carries a field element there and both sides write it.
	//
	// This IS a reduction in what the harness proves, and it is worth naming rather than
	// burying: rem was an identity copy plus a 256-bit subtract, and what carried the walk, the
	// jump and the back edge was always Px and Py after the batch completes. Those are
	// untouched. The bookkeeping that leaves is the host's now -- see DEVPLAN.
	const bool cmpCt = ptsm;

	//---- 1. A vs B ------------------------------------------------------------------
	size_t dPx = 0, dPy = 0, dSc = 0, dCt = 0, firstAB = (size_t)-1;
	for (size_t i = 0; i < nlimb; i++) {
		if (outPx[0][i] != outPx[1][i]) { dPx++; if (firstAB == (size_t)-1) firstAB = i / 4; }
		if (outPy[0][i] != outPy[1][i]) dPy++;
		if (outSc[0][i] != outSc[1][i]) dSc++;
		if (cmpCt && outCt[0][i] != outCt[1][i]) dCt++;
	}
	printf("==== A vs B ====\n");
	if (cmpCt)
		printf("  differing limbs:  Px %zu   Py %zu   scalars %zu   counts %zu   (of %zu each)\n",
		       dPx, dPy, dSc, dCt, nlimb);
	else
		printf("  differing limbs:  Px %zu   Py %zu   scalars %zu   (of %zu each)"
		       "   [counts256 not written by this kernel]\n", dPx, dPy, dSc, nlimb);
	const bool abSame = !(dPx | dPy | dSc | dCt);
	printf("  %s\n\n", abSame ? "A and B agree on every output limb."
	                          : "A and B DISAGREE.");

	//---- 2. each vs the oracle ------------------------------------------------------
	printf(jumpm ? "==== each vs the canonical point after the jump ====\n"
	     : ptsm ? "==== each vs the canonical product of every px3 ====\n"
	     : walkm ? "==== each vs the canonical product of 1/(Gx[i]-x1) ====\n"
	     : invm ? "==== each vs the canonical inverse ====\n"
	     : sufp ? "==== each vs the canonical suffix product ====\n"
	            : "==== each vs canonical (a*b) mod P ====\n");

	// Computed ONCE per thread rather than once per side. It used to sit inside the m loop,
	// which was free when the expectation was a few hundred multiplies; pts mode inverts
	// every (Gx[i] - x1) by Fermat, and paying that twice for an identical answer is the
	// kind of waste that turns a check people run into one they skip.
	std::vector<uint64_t> wantPxAll(nlimb), wantPyAll(nlimb);
	// start_scalars and counts256 are identity everywhere except pts, which spends them on
	// the tail point's lam and lam^2.
	std::vector<uint64_t> wantScAll(hs), wantCtAll(hc);
	for (size_t t = 0; t < threads; t++) {
		uint64_t a[4], b[4];
		for (int k = 0; k < 4; k++) { a[k] = hx[t * 4 + k]; b[k] = hy[t * 4 + k]; }
		if (jumpm) {
			// All four arrays carry real results on this rung, so all four are filled here.
			wantJump(jx, jy, a, b, &hs[t * 4], &hc[t * 4], (uint64_t)BATCH, BPL, loopm,
			         &wantPxAll[t * 4], &wantPyAll[t * 4],
			         &wantScAll[t * 4], &wantCtAll[t * 4]);
		} else if (sufp) {
			// subp[half-1] is the ladder's first factor on its own -- the value stored
			// before the loop, at the top of the frame, so reading it back says the ladder
			// stored where it meant to rather than merely computing the right product. It
			// is the same in every ladder mode on purpose: a failure in the newest stage
			// that is really a stage-2a regression lands on Py, not on Px.
			submodP(jx, a, &wantPyAll[t * 4]);
			// In pts mode Py is the tail's px3, not subp[half-1] -- the value that says
			// WHICH point is wrong rather than only that the product is.
			wantPx_ladder(jx, gx.data(), gy.data(), half, a, b, invm, walkm, ptsm,
			              &wantPxAll[t * 4], ptsm ? &wantPyAll[t * 4] : nullptr,
			              ptsm ? &wantScAll[t * 4] : nullptr,
			              ptsm ? &wantCtAll[t * 4] : nullptr);
		} else {
			mulmodP(a, b, &wantPxAll[t * 4]);
			memcpy(&wantPyAll[t * 4], b, 4 * sizeof(uint64_t));   // Py is identity in mul mode
		}
	}

	int bad = 0;
	for (int m = 0; m < 2; m++) {
		size_t exact = 0, noncanon = 0, wrong = 0, firstWrong = (size_t)-1;
		size_t idPy = 0, idSc = 0, idCt = 0;
		size_t firstPy = (size_t)-1, firstSc = (size_t)-1, firstCt = (size_t)-1;
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
			if (jumpm) {
				// y1 comes off the end of MulMod256 -> SubMod256, so it is congruent but not
				// guaranteed canonical -- C8 reaches the point jump exactly as it reaches
				// everything else. An equality test here would report a correct kernel as
				// broken on a value that is arithmetically right.
				int ky = 0;
				if (classify(&outPy[m][t * 4], wantPy, &ky) > 1) {
					idPy++;
					if (firstPy == (size_t)-1) firstPy = t;
				}
			} else {
				for (int k = 0; k < 4; k++) {
					if (outPy[m][t * 4 + k] != wantPy[k]) {
						idPy++;
						if (firstPy == (size_t)-1) firstPy = t;
					}
				}
			}
			if (jumpm) {
				// s1 and rem are integer bookkeeping, not field elements: exact or wrong,
				// with no congruence to allow for. On the `jump` rung they are still the
				// inputs unchanged, which is the check that the point jump did not scribble
				// on them.
				for (int k = 0; k < 4; k++) {
					if (outSc[m][t * 4 + k] != wantScAll[t * 4 + k]) {
						idSc++;
						if (firstSc == (size_t)-1) firstSc = t;
					}
					if (cmpCt && outCt[m][t * 4 + k] != wantCtAll[t * 4 + k]) {
						idCt++;
						if (firstCt == (size_t)-1) firstCt = t;
					}
				}
			} else if (ptsm) {
				// Lam and Sqr come straight out of MulMod256 and SqrMod256, so they are
				// congruent but not necessarily canonical -- C8 again. Comparing them for
				// equality would report the two links as broken on a value that is
				// arithmetically right, which is the one thing this bisect must not do.
				int kk = 0;
				uint64_t g[4];
				for (int k = 0; k < 4; k++) g[k] = outSc[m][t * 4 + k];
				if (classify(g, &wantScAll[t * 4], &kk) > 1) {
					idSc++;
					if (firstSc == (size_t)-1) firstSc = t;
				}
				for (int k = 0; k < 4; k++) g[k] = outCt[m][t * 4 + k];
				if (classify(g, &wantCtAll[t * 4], &kk) > 1) {
					idCt++;
					if (firstCt == (size_t)-1) firstCt = t;
				}
			} else {
				for (int k = 0; k < 4; k++) {
					if (outSc[m][t * 4 + k] != hs[t * 4 + k]) idSc++;
					if (cmpCt && outCt[m][t * 4 + k] != hc[t * 4 + k]) idCt++;
				}
			}
		}
		printf("  %s:  EXACT %zu   NON-CANON %zu   WRONG %zu   (of %u)\n",
		       M[m].name, exact, noncanon, wrong, threads);
		if (jumpm)
			printf("      jumped point -- x1 above, y1 %s  s1 %s%s\n",
			       idPy ? "WRONG" : "ok", idSc ? "WRONG" : "ok",
			       loopm ? "   (4 batches)" : "   (s1 must be UNCHANGED on this rung)");
		else if (ptsm)
			printf("      tail chain -- lam %s  lam^2 %s  px3 %s   (scalars/counts spent"
			       " on the bisect, so no identity guard on this rung)\n",
			       idSc ? "WRONG" : "ok", idCt ? "WRONG" : "ok", idPy ? "WRONG" : "ok");
		else
			printf("      %s -- Py %s  scalars %s\n",
			       sufp ? "subp[half-1] + identity" : "identity check",
			       idPy ? "BROKEN" : "ok", idSc ? "BROKEN" : "ok");
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
			       jumpm ? "   (y1 after the jump)"
			       : ptsm ? "   (px3 of the tail point: i = half-1, minus branch)"
			       : sufp ? "   (subp[half-1] = Jx - x1, stored before the loop)" : "");
			dump256("x1", a);
			if (sufp && !ptsm && !jumpm) dump256("Jx", jx);
			dump_delta(&outPy[m][firstPy * 4], wp);
			if (sufp && !ptsm && !jumpm) explain_py(&outPy[m][firstPy * 4], a, jx);
		}
		// The two links BEHIND px3. Reported in chain order -- lam, then lam^2, then px3
		// above -- so the first one marked wrong is the call that diverges. If all three
		// are wrong the divergence is at or before MulMod256(s, dx_inv); if only px3 is,
		// it is SubMod256_3; and if none are while Px still is, the point arithmetic is
		// right and the accumulation is not.
		if (ptsm && idSc) {
			printf("      first wrong lam at thread %zu"
			       "   (MulMod256(-c_Gy[511] - y1, dx_inv), tail)\n", firstSc);
			dump_delta(&outSc[m][firstSc * 4], &wantScAll[firstSc * 4]);
		}
		if (ptsm && idCt) {
			printf("      first wrong lam^2 at thread %zu"
			       "   (SqrMod256(lam), tail)\n", firstCt);
			dump_delta(&outCt[m][firstCt * 4], &wantCtAll[firstCt * 4]);
		}
		// The bookkeeping halves of stage 2d. A wrong s1 with a right rem (or the reverse)
		// says the carry chain is wrong in one of the two and not that the loop miscounted;
		// both wrong by the same multiple of B says it ran the wrong number of batches.
		if (jumpm && idSc) {
			printf("      first wrong s1 at thread %zu   (%s)\n", firstSc,
			       loopm ? "s1 += B, once per batch" : "must be unchanged");
			dump_delta(&outSc[m][firstSc * 4], &wantScAll[firstSc * 4]);
		}
		// The matching "first wrong rem" dump is gone with rem itself: idCt can only be
		// non-zero on the pts rung now, which has its own dump above.
		if (idPy || idSc || idCt) bad = 1;
	}

	printf("\n==== timing ====\n");
	printf("  best    A %.4f ms    B %.4f ms    B/A %.3fx\n", ms[0], ms[1],
	       ms[0] > 0 ? ms[1] / ms[0] : 0.0f);
	printf("  median  A %.4f ms    B %.4f ms    B/A %.3fx\n", med[0], med[1],
	       med[0] > 0 ? med[1] / med[0] : 0.0f);
	// The two ratios agreeing is the evidence that the run is thermally clean. Best-of-N picks
	// each side's least-throttled launch and the median picks its typical one; if throttling
	// were falling unevenly on the two sides -- which is what the interleave exists to prevent
	// -- the two ratios would part company. A gap here means read the absolute columns and the
	// spread before believing anything else in this block.
	if (ms[0] > 0 && med[0] > 0) {
		const double rb = ms[1] / ms[0], rm = med[1] / med[0];
		const double gap = 100.0 * (rb > rm ? rb - rm : rm - rb) / rm;
		printf("  the two ratios differ by %.1f%%%s\n", gap,
		       gap > 2.0 ? "   <<< READ THE SPREAD ABOVE; this run is not thermally clean"
		                 : "   (agreement here is what says the run is thermally clean)");
	}
	// This used to read "meaningless until both kernels do the same amount of work". On the
	// lower rungs that was the whole truth; on jump and loop they demonstrably DO the same work
	// -- every output limb agrees and every thread is EXACT -- so the ratio is now real, and
	// the caveats are the two below rather than a blanket refusal to interpret it.
	//
	// OCCUPANCY FIRST, because it is the larger of the two and it is not a property of the code
	// being compared. Read the BLOCKS/SM line above: if the two sides differ there, part of this
	// ratio is latency hiding rather than instruction count. A grid equal to the SM count gives
	// both sides one resident block and takes that term out.
	if (ms[0] > 0 && ms[1] > 0)
		printf("  B is %.1f%% %s than A%s\n",
		       100.0 * (ms[1] < ms[0] ? ms[0] - ms[1] : ms[1] - ms[0]) / ms[0],
		       ms[1] < ms[0] ? "FASTER" : "slower",
		       "   (check BLOCKS/SM above before reading anything into this)");
	// And the residual asymmetry, stated as a rule rather than as a side, because which side
	// carries it depends on what was passed in. A cubin built NO_HASH folds every candidate point
	// into a sink so nvcc cannot delete the walk -- a handful of XORs per point. That escape is
	// what makes a points-only build a valid reference at all (without it there is no walk left to
	// compare against), so it cannot simply be removed. It used to say "A runs the sink", which was
	// true of every configuration this harness had been used in and became exactly backwards the
	// first time a full-hash cubin was passed as A to measure the hash/field split.
	printf("  NOTE: a NO_HASH cubin carries the sink (a few XOR per point); a full one does not.\n"
	       "        Whichever side that is, it biases the ratio slightly against it.\n");

	for (int m = 0; m < 2; m++) {
		cuMemFree(M[m].px); cuMemFree(M[m].py); cuMemFree(M[m].sc);
		cuMemFree(M[m].ct); cuMemFree(M[m].fr); cuModuleUnload(M[m].mod);
	}
	cuDevicePrimaryCtxRelease(dev);

	printf("\nVERDICT: %s\n", (abSame && !bad) ? "A and B agree, and neither is WRONG."
	                                           : "see above -- NOT a clean pass.");
	return (abSame && !bad) ? 0 : 2;
}
