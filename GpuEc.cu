#include "Math.cuh"
#include "Defs.h"

static __device__ const uint64_t SECP_GX_LE[4] = {
    0x59f2815b16f81798ULL,
    0x029bfcdb2dce28d9ULL,
    0x55a06295ce870b07ULL,
    0x79be667ef9dcbbacULL
};
static __device__ const uint64_t SECP_GY_LE[4] = {
    0x9c47d08ffb10d4b8ULL,
    0xfd17b448a6855419ULL,
    0x5da4fbfc0e1108a8ULL,
    0x483ada7726a3c465ULL
};

struct ECPointA {
    uint64_t X[4];
    uint64_t Y[4];
    bool infinity;
};

__device__ __forceinline__ void fieldCopy(const uint64_t a[4], uint64_t out[4]) {
    out[0] = a[0];
    out[1] = a[1];
    out[2] = a[2];
    out[3] = a[3];
}

__device__ __forceinline__ bool fieldIsZero(const uint64_t a[4]) {
    return ( (a[0] | a[1] | a[2] | a[3]) == 0ULL );
}

__device__ void fieldAdd(const uint64_t a[4], const uint64_t b[4], uint64_t out[4]) {
	add_mod(out, a, b);
}

__device__ void fieldSub(const uint64_t a[4], const uint64_t b[4], uint64_t out[4]) {
	sub_mod(out, a, b);
}

__device__ __forceinline__ void fieldMul(const uint64_t a[4], const uint64_t b[4], uint64_t out[4]) {
    mul_mod(out, (uint64_t*)a, (uint64_t*)b);
}
__device__ __forceinline__ void fieldSqr(const uint64_t a[4], uint64_t out[4]) {
    sqr_mod(out, (uint64_t*)a);
}

__device__ void fieldInv(const uint64_t in[4], uint64_t out[4]) {
    uint64_t t[5];
    
	fieldCopy(in, t);
	
	inv_mod((uint32_t*)&t[0]);
	
	fieldCopy(t, out);
}


__device__ __forceinline__ void pointSetInfinity(ECPointA &P) {
    P.infinity = true;
    P.X[0]=P.X[1]=P.X[2]=P.X[3]=0ULL;
    P.Y[0]=P.Y[1]=P.Y[2]=P.Y[3]=0ULL;
}

__device__ __forceinline__ void pointSetG(ECPointA &P) {
    pointSetInfinity(P); 
    P.infinity = false;
    P.X[0] = SECP_GX_LE[0];
    P.X[1] = SECP_GX_LE[1];
    P.X[2] = SECP_GX_LE[2];
    P.X[3] = SECP_GX_LE[3];
    P.Y[0] = SECP_GY_LE[0];
    P.Y[1] = SECP_GY_LE[1];
    P.Y[2] = SECP_GY_LE[2];
    P.Y[3] = SECP_GY_LE[3];
}

__device__ void pointDoubleAffine(const ECPointA &P, ECPointA &R) {
    if (P.infinity) { pointSetInfinity(R); return; }

    uint64_t x2[4], two_x2[4], three_x2[4];
    uint64_t denom[4], invDen[4], lambda[4];

    fieldSqr(P.X, x2);
    fieldAdd(x2, x2, two_x2);
    fieldAdd(two_x2, x2, three_x2);

    fieldAdd(P.Y, P.Y, denom);
    fieldInv(denom, invDen);

    fieldMul(three_x2, invDen, lambda);

    uint64_t lambda2[4], twoX[4], newX[4];
    fieldSqr(lambda, lambda2);
    fieldAdd(P.X, P.X, twoX);
    fieldSub(lambda2, twoX, newX);

    uint64_t tmp[4], prod[4], newY[4];
    fieldSub(P.X, newX, tmp);
    fieldMul(lambda, tmp, prod);
    fieldSub(prod, P.Y, newY);

    fieldCopy(newX, R.X);
    fieldCopy(newY, R.Y);
    R.infinity = false;
}

__device__ void pointAddAffine(const ECPointA &P, const ECPointA &Q, ECPointA &R) {
    if (P.infinity) { R = Q; return; }
    if (Q.infinity) { R = P; return; }

    bool sameX = (P.X[0]==Q.X[0] && P.X[1]==Q.X[1] && P.X[2]==Q.X[2] && P.X[3]==Q.X[3]);
    bool sameY = (P.Y[0]==Q.Y[0] && P.Y[1]==Q.Y[1] && P.Y[2]==Q.Y[2] && P.Y[3]==Q.Y[3]);

    if (sameX && sameY) {
        pointDoubleAffine(P, R);
        return;
    }

    if (sameX && !sameY) {
        pointSetInfinity(R);
        return;
    }

    uint64_t dx[4], dy[4], invdx[4], lambda[4], lambda2[4];
    uint64_t tmp1[4], prod[4], newX[4], newY[4];

    fieldSub(Q.X, P.X, dx);     // dx = x2 - x1
    fieldSub(Q.Y, P.Y, dy);     // dy = y2 - y1

    fieldInv(dx, invdx);        // invdx = 1/dx
    fieldMul(dy, invdx, lambda);// lambda = dy * invdx = (y2 - y1) / (x2 - x1)

    // x3 = lambda^2 - x1 - x2
    fieldSqr(lambda, lambda2);
    fieldSub(lambda2, P.X, tmp1);   // tmp1 = lambda^2 - x1
    fieldSub(tmp1, Q.X, newX);      // newX = lambda^2 - x1 - x2

    // y3 = lambda*(x1 - x3) - y1
    fieldSub(P.X, newX, tmp1);      // tmp1 = x1 - x3
    fieldMul(lambda, tmp1, prod);   // prod = lambda * (x1 - x3)
    fieldSub(prod, P.Y, newY);      // newY = prod - y1

    fieldCopy(newX, R.X);
    fieldCopy(newY, R.Y);
    R.infinity = false;
}

__device__ void scalarMulBaseAffine(const uint64_t scalar_le[4], uint64_t outX[4], uint64_t outY[4]) {
    ECPointA R;
    pointSetInfinity(R);

    int msb = -1;
    if      (scalar_le[3] != 0) msb = 3 * 64 + 63 - __clzll(scalar_le[3]);
    else if (scalar_le[2] != 0) msb = 2 * 64 + 63 - __clzll(scalar_le[2]);
    else if (scalar_le[1] != 0) msb = 1 * 64 + 63 - __clzll(scalar_le[1]);
    else if (scalar_le[0] != 0) msb = 0 * 64 + 63 - __clzll(scalar_le[0]);

    if (msb == -1) {
        // scalar == 0 -> infinity
        outX[0]=outX[1]=outX[2]=outX[3]=0ULL;
        outY[0]=outY[1]=outY[2]=outY[3]=0ULL;
        return;
    }

    for (int bi = msb; bi >= 0; --bi) {
        // R = 2*R
        if (!R.infinity) {
            ECPointA tmpD;
            pointDoubleAffine(R, tmpD);
            R = tmpD;
        }
        // if bit == 1, R = R + G
        int limb = bi >> 6;
        int shift = bi & 63;
        uint64_t bit = (scalar_le[limb] >> shift) & 1ULL;
        if (bit) {
            ECPointA Gp;
            pointSetG(Gp);
            if (R.infinity) {
                R = Gp;
            } else {
                ECPointA tmpA;
                pointAddAffine(R, Gp, tmpA);
                R = tmpA;
            }
        }
    }

    if (R.infinity) {
        outX[0]=outX[1]=outX[2]=outX[3]=0ULL;
        outY[0]=outY[1]=outY[2]=outY[3]=0ULL;
    } else {
        fieldCopy(R.X, outX);
        fieldCopy(R.Y, outY);
    }
}

extern "C" __global__ void scalarMulKernelBase(const uint64_t* scalars_in, uint64_t* outX, uint64_t* outY, uint32_t N) {
    uint32_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= N) return;

    const uint64_t* scalar = scalars_in + idx*4;
    uint64_t* outx = outX + idx*4;
    uint64_t* outy = outY + idx*4;

    scalarMulBaseAffine(scalar, outx, outy);
}

void CallGpuMulKernel(
	uint64_t blocks,
	uint64_t blockSize,
	const uint64_t* scalars,
	uint64_t* x,
	uint64_t* y,
	uint32_t count) {
	scalarMulKernelBase <<< blocks, blockSize, 0 >>> (
		scalars,
		x,
		y,
		count
	);
}