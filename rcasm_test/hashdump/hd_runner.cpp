// hd_runner.cpp -- minimal driver-API runner to VERIFY a manual hashdump cubin executes.
// Loads <cubin>, launches TestKernel over N points, checks output.
//
// Reuses the 7-param TestKernel template ABI:
//   arg0 Px = input  X (u64[N*4], v[0]=LSB per point)
//   arg1 Py = prefix (u64[N], low byte 0x02/0x03)   [unused by the stub]
//   arg2 Scal = output (u32[N])
//   arg3 find_result (dummy)
//   arg4 threadsTotal (u64) = N
//   arg5 batch_size (u32), arg6 batches_per_launch (u32)  [unused here]
//
// Modes:
//   stub   : expect out[i] == (u32)X[i].v[0] + 0x1234   (native-call round-trip test)
//   golden : compare out[] against hashgolden.bin's hw2[]  (real lifted-hash test)
//
// Build (host): g++ -O2 hd_runner.cpp -o hd_runner -I$CUDA/include -L$CUDA/lib64/stubs -lcuda

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <cuda.h>

#define CK(x) do{ CUresult r=(x); if(r!=CUDA_SUCCESS){ const char*s; cuGetErrorString(r,&s); \
    fprintf(stderr,"%s:%d %s -> %s\n",__FILE__,__LINE__,#x,s); exit(1);} }while(0)

int main(int argc,char**argv){
    const char* cubin = (argc>1)? argv[1] : "hd_test.cubin";
    const char* mode  = (argc>2)? argv[2] : "stub";
    const char* golden= (argc>3)? argv[3] : "hashgolden.bin";

    // inputs
    std::vector<uint64_t> X; std::vector<uint8_t> P; std::vector<uint32_t> REF; uint32_t N;
    if(strcmp(mode,"golden")==0){
        FILE* f=fopen(golden,"rb"); if(!f){perror("golden");return 1;}
        fread(&N,4,1,f); X.resize((size_t)N*4); P.resize(N); REF.resize(N);
        fread(X.data(),8,(size_t)N*4,f); fread(P.data(),1,N,f); fread(REF.data(),4,N,f); fclose(f);
    } else {
        N=256; X.resize((size_t)N*4); P.resize(N);
        uint64_t s=0x1234567890abcdefull;
        for(uint32_t i=0;i<N;i++){ for(int k=0;k<4;k++){ s=s*6364136223846793005ull+1; X[i*4+k]=s; } P[i]=(X[i*4]&1)?3:2; }
    }

    CK(cuInit(0));
    CUdevice dev; CK(cuDeviceGet(&dev,0));
    CUcontext ctx; CK(cuCtxCreate(&ctx,nullptr,0,dev));
    CUmodule mod; CK(cuModuleLoad(&mod,cubin));
    CUfunction fn; CK(cuModuleGetFunction(&fn,mod,"TestKernel"));

    CUdeviceptr dX,dP,dO,dFR;
    CK(cuMemAlloc(&dX,(size_t)N*4*8));
    CK(cuMemAlloc(&dP,(size_t)N*8));
    CK(cuMemAlloc(&dO,(size_t)N*4));
    CK(cuMemAlloc(&dFR,256));
    CK(cuMemcpyHtoD(dX,X.data(),(size_t)N*4*8));
    std::vector<uint64_t> Pw(N); for(uint32_t i=0;i<N;i++) Pw[i]=P[i];
    CK(cuMemcpyHtoD(dP,Pw.data(),(size_t)N*8));
    CK(cuMemsetD8(dO,0,(size_t)N*4));
    CK(cuMemsetD8(dFR,0,256));

    uint64_t nT=N; uint32_t batch=1024, bpl=1;
    void* args[7]={&dX,&dP,&dO,&dFR,&nT,&batch,&bpl};
    int block=256, grid=(N+block-1)/block;
    CK(cuLaunchKernel(fn,grid,1,1, block,1,1, 0,0,args,0));
    CK(cuCtxSynchronize());

    std::vector<uint32_t> out(N);
    CK(cuMemcpyDtoH(out.data(),dO,(size_t)N*4));

    uint32_t bad=0, shown=0;
    for(uint32_t i=0;i<N;i++){
        uint32_t exp = (strcmp(mode,"golden")==0)? REF[i] : ((uint32_t)X[i*4]+0x1234u);
        if(out[i]!=exp){ bad++; if(shown<8){ printf("  [%u] got %08x exp %08x\n",i,out[i],exp); shown++; } }
    }
    printf("%s: N=%u  mismatches=%u  %s\n", mode, N, bad, bad? "*** FAIL ***":"PASS");
    return bad?1:0;
}
