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

static bool sub_256(const uint64_t* a, const uint64_t* b, uint64_t* r) {
	uint64_t borrow = 0ULL;
	
    { uint64_t bi = b[0] + borrow; if (a[0] < bi) { r[0] = (uint64_t)(((__uint128_t(1) << 64) + a[0]) - bi); borrow = 1; } else { r[0] = a[0] - bi; borrow = 0; } }
    { uint64_t bi = b[1] + borrow; if (a[1] < bi) { r[1] = (uint64_t)(((__uint128_t(1) << 64) + a[1]) - bi); borrow = 1; } else { r[1] = a[1] - bi; borrow = 0; } }
    { uint64_t bi = b[2] + borrow; if (a[2] < bi) { r[2] = (uint64_t)(((__uint128_t(1) << 64) + a[2]) - bi); borrow = 1; } else { r[2] = a[2] - bi; borrow = 0; } }
    { uint64_t bi = b[3] + borrow; if (a[3] < bi) { r[3] = (uint64_t)(((__uint128_t(1) << 64) + a[3]) - bi); borrow = 1; } else { r[3] = a[3] - bi; borrow = 0; } }
	
	return borrow != 0;
}
