#pragma once

static uint64_t num_256_1[4] = { 1, 0, 0, 0 };

static void div_256_u64(const uint64_t* value, uint64_t divisor, uint64_t* quotient, uint64_t *remainder) {
    *remainder = 0;
    { __uint128_t cur = (__uint128_t(*remainder) << 64) | value[3]; quotient[3] = (uint64_t)(cur / divisor); *remainder = (uint64_t)(cur % divisor); }
    { __uint128_t cur = (__uint128_t(*remainder) << 64) | value[2]; quotient[2] = (uint64_t)(cur / divisor); *remainder = (uint64_t)(cur % divisor); }
    { __uint128_t cur = (__uint128_t(*remainder) << 64) | value[1]; quotient[1] = (uint64_t)(cur / divisor); *remainder = (uint64_t)(cur % divisor); }
    { __uint128_t cur = (__uint128_t(*remainder) << 64) | value[0]; quotient[0] = (uint64_t)(cur / divisor); *remainder = (uint64_t)(cur % divisor); }
}

static bool add_256(const uint64_t* a, const uint64_t* b, uint64_t* r) {
	uint64_t carry = 0ULL;
	
	{ __uint128_t t = (__uint128_t)a[0] + b[0] + carry; r[0] = (uint64_t)t; carry = uint64_t(t >> 64); }
	{ __uint128_t t = (__uint128_t)a[1] + b[1] + carry; r[1] = (uint64_t)t; carry = uint64_t(t >> 64); }
	{ __uint128_t t = (__uint128_t)a[2] + b[2] + carry; r[2] = (uint64_t)t; carry = uint64_t(t >> 64); }
	{ __uint128_t t = (__uint128_t)a[3] + b[3] + carry; r[3] = (uint64_t)t; carry = uint64_t(t >> 64); }
	
	return carry != 0;
}

static bool add_256_u64(const uint64_t* a, uint64_t b, uint64_t* r) {
	__uint128_t sum = (__uint128_t)a[0] + b;
    r[0] = (uint64_t)sum;
    
	uint64_t carry = (uint64_t)(sum >> 64);
    sum = (__uint128_t)a[1] + carry; r[1] = (uint64_t)sum; carry = (uint64_t)(sum >> 64);
    sum = (__uint128_t)a[2] + carry; r[2] = (uint64_t)sum; carry = (uint64_t)(sum >> 64);
    sum = (__uint128_t)a[3] + carry; r[3] = (uint64_t)sum; carry = (uint64_t)(sum >> 64);
	
	return carry != 0;
}

// r = a * b (mod 2^256). Returns true if the product did not fit in 256 bits.
static bool mul_256_u64(const uint64_t* a, uint64_t b, uint64_t* r) {
	__uint128_t t;

	{ t = (__uint128_t)a[0] * b;                            r[0] = (uint64_t)t; }
	{ t = (__uint128_t)a[1] * b + (uint64_t)(t >> 64);      r[1] = (uint64_t)t; }
	{ t = (__uint128_t)a[2] * b + (uint64_t)(t >> 64);      r[2] = (uint64_t)t; }
	{ t = (__uint128_t)a[3] * b + (uint64_t)(t >> 64);      r[3] = (uint64_t)t; }

	return (uint64_t)(t >> 64) != 0;
}

// The borrow must come from comparing a[i] against b[i] directly. Folding it in first
// (bi = b[i] + borrow) wraps to 0 when b[i] is 0xFFFFFFFFFFFFFFFF and drops the outgoing borrow:
// the limb stays right, but the difference is 2^(64*(i+1)) too large and the return says "no borrow".
static bool sub_256(const uint64_t* a, const uint64_t* b, uint64_t* r) {
	uint64_t borrow = 0ULL;

    { __uint128_t t = (__uint128_t)a[0] - b[0] - borrow; r[0] = (uint64_t)t; borrow = (uint64_t)(t >> 64) & 1ULL; }
    { __uint128_t t = (__uint128_t)a[1] - b[1] - borrow; r[1] = (uint64_t)t; borrow = (uint64_t)(t >> 64) & 1ULL; }
    { __uint128_t t = (__uint128_t)a[2] - b[2] - borrow; r[2] = (uint64_t)t; borrow = (uint64_t)(t >> 64) & 1ULL; }
    { __uint128_t t = (__uint128_t)a[3] - b[3] - borrow; r[3] = (uint64_t)t; borrow = (uint64_t)(t >> 64) & 1ULL; }

	return borrow != 0;
}
