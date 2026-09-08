// High-register-pressure CAS microbench: keep a large live set across the atomicCAS_system calls
// so ptxas allocates HIGH register indices (R64+) for the CAS operands, giving the encoder basis
// the high-index bits my publish's R74..R78 need.
extern "C" __global__ __launch_bounds__(64,1) void cas_train2(unsigned long long* p, unsigned s)
{
    unsigned* q = (unsigned*)p;
    unsigned a[40];
    #pragma unroll
    for (int i = 0; i < 40; i++) a[i] = q[(threadIdx.x + i) & 4095] + s * (i + 1);
    #pragma unroll
    for (int i = 0; i < 40; i++)
        a[i] = atomicCAS_system(&q[(a[(i + 7) % 40] & 4095)], a[(i + 13) % 40], a[(i + 23) % 40]);
    unsigned acc = 0;
    #pragma unroll
    for (int i = 0; i < 40; i++) acc ^= a[i];
    q[0] = acc;
}
