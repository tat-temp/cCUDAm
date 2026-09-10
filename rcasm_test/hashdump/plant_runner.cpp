// plant_runner.cpp -- verify the manual full pipeline's found/publish path with a PLANTED target.
// (branch f2m, Stage 3b.) The seed point is hashed at the TOP of the batch loop, BEFORE the walk,
// so we can force a hit with NO valid EC tables: pick thread 0's seed (X[0], prefix from Y[0]),
// compute its hw2 on the host, set c_target_words[2] to it, launch, and expect find_result to carry
// found=1 and scalar == start_scalars[0]. The walk still runs (on zero tables) but publish-and-
// continue keeps it harmless, and the seed already published.
//
// Build (host): g++ -O2 -w -I ../hashdump/shim -I ../.. plant_runner.cpp -o plant_runner \
//                   -I$CUDA/include -L$CUDA/lib64/stubs -lcuda
// Run:   ./plant_runner ../../asm/tk/TestKernel_hash.cubin [N] [batch]

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <cuda.h>                  // driver API first, before the device->host shims

// ---- device -> host shims (same as hashcheck.cpp) so GpuHash.cu computes the host hash ----
#define __device__
#define __forceinline__ inline
#define __noinline__
#define __global__
#define __constant__
#define __restrict__
static inline uint32_t __byte_perm(uint32_t x, uint32_t y, uint32_t s){
    unsigned char b[8];
    b[0]=x&0xff; b[1]=(x>>8)&0xff; b[2]=(x>>16)&0xff; b[3]=(x>>24)&0xff;
    b[4]=y&0xff; b[5]=(y>>8)&0xff; b[6]=(y>>16)&0xff; b[7]=(y>>24)&0xff;
    uint32_t r=0;
    for(int i=0;i<4;i++){ uint32_t nib=(s>>(4*i))&0xf, sel=nib&0x7; unsigned char v=b[sel];
        if(nib&0x8) v=(v&0x80)?0xff:0x00; r |= (uint32_t)v << (8*i); }
    return r;
}
static inline uint32_t __funnelshift_r(uint32_t lo, uint32_t hi, uint32_t n){ n&=31; return n?((lo>>n)|(hi<<(32-n))):lo; }
#include "GpuHash.cu"             // getHash160_w2_from_limbs(prefix, U256)

#define CK(x) do{ CUresult r=(x); if(r!=CUDA_SUCCESS){ const char*s; cuGetErrorString(r,&s); \
    fprintf(stderr,"%s:%d %s -> %s\n",__FILE__,__LINE__,#x,s); exit(1);} }while(0)

int main(int argc,char**argv){
    const char* cubin = (argc>1)? argv[1] : "../../asm/tk/TestKernel_hash.cubin";
    uint32_t N     = (argc>2)? (uint32_t)strtoul(argv[2],0,0) : 256;
    uint32_t batch = (argc>3)? (uint32_t)strtoul(argv[3],0,0) : 1024;

    // deterministic inputs
    std::vector<uint64_t> X((size_t)N*4), Y((size_t)N*4), S((size_t)N*4);
    uint64_t r=0x1234567890abcdefull;
    auto rnd=[&](){ r=r*6364136223846793005ull+1442695040888963407ull; return r; };
    for(size_t i=0;i<(size_t)N*4;i++){ X[i]=rnd(); Y[i]=rnd(); S[i]=rnd(); }

    // planted target = seed hash160 of thread 0: prefix = 0x02 | (Y[0].v[0] & 1); x = X[0..3].
    // The kernel's publish gate is a FULL 5-word match (GpuCore.cu:198 hash160_full_match), so a
    // word-2-only plant never publishes -- even on the known-correct compiled kernel. Plant all 5.
    U256 x0; x0.v[0]=X[0]; x0.v[1]=X[1]; x0.v[2]=X[2]; x0.v[3]=X[3];
    uint8_t pf0 = 0x02u | (uint8_t)(Y[0] & 1ull);
    H160 h0 = getHash160_33_from_limbs(pf0, x0);
    uint32_t tw[5]={h0.w[0],h0.w[1],h0.w[2],h0.w[3],h0.w[4]};
    uint32_t planted = h0.w[2];
    printf("planted: thread0 prefix=%02x  hash160=%08x %08x %08x %08x %08x  (w2=%08x)\n",
           pf0, h0.w[0],h0.w[1],h0.w[2],h0.w[3],h0.w[4], planted);
    printf("DEBUG: X[0].lo32=%08x  X[3].hi32=%08x  Y[0].lo32=%08x  (prefix exp %d)\n",
           (uint32_t)X[0], (uint32_t)(X[3]>>32), (uint32_t)Y[0], pf0);
    printf("expected scalar = %016llx %016llx %016llx %016llx\n",
           (unsigned long long)S[0],(unsigned long long)S[1],(unsigned long long)S[2],(unsigned long long)S[3]);

    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev,0));
    CUcontext ctx; CK(cuCtxCreate(&ctx,nullptr,0,dev));
    CUmodule mod; CK(cuModuleLoad(&mod,cubin));
    CUfunction fn; CK(cuModuleGetFunction(&fn,mod,"TestKernel"));

    // upload c_target_words[2] = planted
    CUdeviceptr dTW; size_t twsz;
    CK(cuModuleGetGlobal(&dTW,&twsz,mod,"c_target_words"));
    CK(cuMemcpyHtoD(dTW,tw,sizeof(tw)));

    CUdeviceptr dX,dY,dS,dFR;
    CK(cuMemAlloc(&dX,(size_t)N*4*8));
    CK(cuMemAlloc(&dY,(size_t)N*4*8));
    CK(cuMemAlloc(&dS,(size_t)N*4*8));
    CK(cuMemAlloc(&dFR,128));
    CK(cuMemcpyHtoD(dX,X.data(),(size_t)N*4*8));
    CK(cuMemcpyHtoD(dY,Y.data(),(size_t)N*4*8));
    CK(cuMemcpyHtoD(dS,S.data(),(size_t)N*4*8));
    CK(cuMemsetD8(dFR,0,128));

    uint64_t nT=N; uint32_t bpl=1;
    void* args[7]={&dX,&dY,&dS,&dFR,&nT,&batch,&bpl};
    int block=256, grid=(N+block-1)/block;
    CK(cuLaunchKernel(fn,grid,1,1, block,1,1, 0,0,args,0));
    CK(cuCtxSynchronize());

    // read find_result: scalar[4]@0, claimed@96, found@100
    uint8_t fr[128]; CK(cuMemcpyDtoH(fr,dFR,128));
    uint32_t claimed=*(uint32_t*)(fr+96), found=*(uint32_t*)(fr+100);
    uint64_t* sc=(uint64_t*)fr;
    printf("find_result: claimed=%u found=%u  scalar=%016llx %016llx %016llx %016llx\n",
           claimed, found, (unsigned long long)sc[0],(unsigned long long)sc[1],
           (unsigned long long)sc[2],(unsigned long long)sc[3]);
    bool ok = found==1 && sc[0]==S[0] && sc[1]==S[1] && sc[2]==S[2] && sc[3]==S[3];
    printf("PLANTED-TARGET: %s\n", ok? "PASS" : "*** FAIL ***");
    return ok?0:1;
}
