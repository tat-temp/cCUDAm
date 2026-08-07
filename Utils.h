#pragma once

#include <cstdint>
#include <cstring>
#include <string>
#include <sstream>
#include <iostream>
#include <iomanip>
#include <vector>

namespace host_sha256 {
    static constexpr uint32_t K[64] = {
        0x428A2F98u,0x71374491u,0xB5C0FBCFu,0xE9B5DBA5u,0x3956C25Bu,0x59F111F1u,0x923F82A4u,0xAB1C5ED5u,
        0xD807AA98u,0x12835B01u,0x243185BEu,0x550C7DC3u,0x72BE5D74u,0x80DEB1FEu,0x9BDC06A7u,0xC19BF174u,
        0xE49B69C1u,0xEFBE4786u,0x0FC19DC6u,0x240CA1CCu,0x2DE92C6Fu,0x4A7484AAu,0x5CB0A9DCu,0x76F988DAu,
        0x983E5152u,0xA831C66Du,0xB00327C8u,0xBF597FC7u,0xC6E00BF3u,0xD5A79147u,0x06CA6351u,0x14292967u,
        0x27B70A85u,0x2E1B2138u,0x4D2C6DFCu,0x53380D13u,0x650A7354u,0x766A0ABBu,0x81C2C92Eu,0x92722C85u,
        0xA2BFE8A1u,0xA81A664Bu,0xC24B8B70u,0xC76C51A3u,0xD192E819u,0xD6990624u,0xF40E3585u,0x106AA070u,
        0x19A4C116u,0x1E376C08u,0x2748774Cu,0x34B0BCB5u,0x391C0CB3u,0x4ED8AA4Au,0x5B9CCA4Fu,0x682E6FF3u,
        0x748F82EEu,0x78A5636Fu,0x84C87814u,0x8CC70208u,0x90BEFFFAu,0xA4506CEBu,0xBEF9A3F7u,0xC67178F2u
    };
    static inline uint32_t rotr(uint32_t x, uint32_t n){ return (x>>n) | (x<<(32u-n)); }
    static inline uint32_t Ch  (uint32_t x,uint32_t y,uint32_t z){ return (x & y) ^ (~x & z); }
    static inline uint32_t Maj (uint32_t x,uint32_t y,uint32_t z){ return (x & y) ^ (x & z) ^ (y & z); }
    static inline uint32_t BSIG0(uint32_t x){ return rotr(x,2) ^ rotr(x,13) ^ rotr(x,22); }
    static inline uint32_t BSIG1(uint32_t x){ return rotr(x,6) ^ rotr(x,11) ^ rotr(x,25); }
    static inline uint32_t SSIG0(uint32_t x){ return rotr(x,7) ^ rotr(x,18) ^ (x>>3); }
    static inline uint32_t SSIG1(uint32_t x){ return rotr(x,17)^ rotr(x,19) ^ (x>>10); }

    static void sha256(const uint8_t* data, size_t len, uint8_t out[32]) {
        uint32_t H[8] = {
            0x6a09e667u,0xbb67ae85u,0x3c6ef372u,0xa54ff53au,
            0x510e527fu,0x9b05688cu,0x1f83d9abu,0x5be0cd19u
        };

        uint8_t block[64] = {0};
        size_t n = len;

        auto process = [&](const uint8_t b[64]){
            uint32_t W[64];
#define WLD(i) W[i] = ((uint32_t)b[4*(i)+0]<<24)|((uint32_t)b[4*(i)+1]<<16)|((uint32_t)b[4*(i)+2]<<8)|((uint32_t)b[4*(i)+3]<<0)
            WLD( 0); WLD( 1); WLD( 2); WLD( 3); WLD( 4); WLD( 5); WLD( 6); WLD( 7);
            WLD( 8); WLD( 9); WLD(10); WLD(11); WLD(12); WLD(13); WLD(14); WLD(15);
#undef WLD
#define SCH(t) W[t] = SSIG1(W[(t)-2]) + W[(t)-7] + SSIG0(W[(t)-15]) + W[(t)-16]
            SCH(16); SCH(17); SCH(18); SCH(19); SCH(20); SCH(21); SCH(22); SCH(23);
            SCH(24); SCH(25); SCH(26); SCH(27); SCH(28); SCH(29); SCH(30); SCH(31);
            SCH(32); SCH(33); SCH(34); SCH(35); SCH(36); SCH(37); SCH(38); SCH(39);
            SCH(40); SCH(41); SCH(42); SCH(43); SCH(44); SCH(45); SCH(46); SCH(47);
            SCH(48); SCH(49); SCH(50); SCH(51); SCH(52); SCH(53); SCH(54); SCH(55);
            SCH(56); SCH(57); SCH(58); SCH(59); SCH(60); SCH(61); SCH(62); SCH(63);
#undef SCH
            uint32_t a=H[0],b_=H[1],c=H[2],d=H[3],e=H[4],f=H[5],g=H[6],h=H[7];
#define RND(t) do { \
                uint32_t T1 = h + BSIG1(e) + Ch(e,f,g) + K[t] + W[t]; \
                uint32_t T2 = BSIG0(a) + Maj(a,b_,c); \
                h=g; g=f; f=e; e=d+T1; d=c; c=b_; b_=a; a=T1+T2; \
            } while(0)
            RND( 0); RND( 1); RND( 2); RND( 3); RND( 4); RND( 5); RND( 6); RND( 7);
            RND( 8); RND( 9); RND(10); RND(11); RND(12); RND(13); RND(14); RND(15);
            RND(16); RND(17); RND(18); RND(19); RND(20); RND(21); RND(22); RND(23);
            RND(24); RND(25); RND(26); RND(27); RND(28); RND(29); RND(30); RND(31);
            RND(32); RND(33); RND(34); RND(35); RND(36); RND(37); RND(38); RND(39);
            RND(40); RND(41); RND(42); RND(43); RND(44); RND(45); RND(46); RND(47);
            RND(48); RND(49); RND(50); RND(51); RND(52); RND(53); RND(54); RND(55);
            RND(56); RND(57); RND(58); RND(59); RND(60); RND(61); RND(62); RND(63);
#undef RND
            H[0]+=a; H[1]+=b_; H[2]+=c; H[3]+=d; H[4]+=e; H[5]+=f; H[6]+=g; H[7]+=h;
        };

        std::memset(block, 0, 64);
        if (n) std::memcpy(block, data, n);
        block[n] = 0x80;
        uint64_t bitlen = (uint64_t)len * 8ull;
        block[63] = (uint8_t)(bitlen      );
        block[62] = (uint8_t)(bitlen >> 8 );
        block[61] = (uint8_t)(bitlen >> 16);
        block[60] = (uint8_t)(bitlen >> 24);
        block[59] = (uint8_t)(bitlen >> 32);
        block[58] = (uint8_t)(bitlen >> 40);
        block[57] = (uint8_t)(bitlen >> 48);
        block[56] = (uint8_t)(bitlen >> 56);
        process(block);

        out[ 0]=(uint8_t)(H[0]>>24); out[ 1]=(uint8_t)(H[0]>>16); out[ 2]=(uint8_t)(H[0]>>8); out[ 3]=(uint8_t)(H[0]>>0);
        out[ 4]=(uint8_t)(H[1]>>24); out[ 5]=(uint8_t)(H[1]>>16); out[ 6]=(uint8_t)(H[1]>>8); out[ 7]=(uint8_t)(H[1]>>0);
        out[ 8]=(uint8_t)(H[2]>>24); out[ 9]=(uint8_t)(H[2]>>16); out[10]=(uint8_t)(H[2]>>8); out[11]=(uint8_t)(H[2]>>0);
        out[12]=(uint8_t)(H[3]>>24); out[13]=(uint8_t)(H[3]>>16); out[14]=(uint8_t)(H[3]>>8); out[15]=(uint8_t)(H[3]>>0);
        out[16]=(uint8_t)(H[4]>>24); out[17]=(uint8_t)(H[4]>>16); out[18]=(uint8_t)(H[4]>>8); out[19]=(uint8_t)(H[4]>>0);
        out[20]=(uint8_t)(H[5]>>24); out[21]=(uint8_t)(H[5]>>16); out[22]=(uint8_t)(H[5]>>8); out[23]=(uint8_t)(H[5]>>0);
        out[24]=(uint8_t)(H[6]>>24); out[25]=(uint8_t)(H[6]>>16); out[26]=(uint8_t)(H[6]>>8); out[27]=(uint8_t)(H[6]>>0);
        out[28]=(uint8_t)(H[7]>>24); out[29]=(uint8_t)(H[7]>>16); out[30]=(uint8_t)(H[7]>>8); out[31]=(uint8_t)(H[7]>>0);
    }

    static void sha256d(const uint8_t* data, size_t len, uint8_t out[32]){
        uint8_t tmp[32];
        sha256(data, len, tmp);
        sha256(tmp, 32, out);
    }
}

// -1 for anything that is not a hex digit.
static int hex_digit_val(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

// Parses exactly len hex digits at s. Rejects any non-hex character rather than stopping at it.
// std::stoull is deliberately not used here: with pos = nullptr it silently truncates at the
// first bad character ("1z" -> 1), and it throws std::invalid_argument when a group has no
// leading digit at all -- and nothing in this program catches that.
static bool hex_to_u64(const char* s, size_t len, uint64_t* out) {
    uint64_t v = 0ULL;
    for (size_t i = 0; i < len; ++i) {
        int d = hex_digit_val(s[i]);
        if (d < 0) return false;
        v = (v << 4) | (uint64_t)d;
    }
    *out = v;
    return true;
}

static bool hexToLE64(const std::string& h_in, uint64_t w[4]) {
    std::string h = h_in;
    if (h.size() >= 2 && (h[0] == '0') && (h[1] == 'x' || h[1] == 'X')) h = h.substr(2);
    if (h.empty() || h.size() > 64) return false;
    if (h.size() < 64) h = std::string(64 - h.size(), '0') + h;
    if (!hex_to_u64(h.data() +  0, 16, &w[3])) return false;
    if (!hex_to_u64(h.data() + 16, 16, &w[2])) return false;
    if (!hex_to_u64(h.data() + 32, 16, &w[1])) return false;
    if (!hex_to_u64(h.data() + 48, 16, &w[0])) return false;
    return true;
}

static bool hexToHash160(const std::string& h, uint8_t hash160[20]) {
    if (h.size() != 40) return false;
    for (int i = 0; i < 20; ++i) {
        int hi = hex_digit_val(h[2 * i]);
        int lo = hex_digit_val(h[2 * i + 1]);
        if (hi < 0 || lo < 0) return false;
        hash160[i] = (uint8_t)((hi << 4) | lo);
    }
    return true;
}

static std::string formatHex256(const uint64_t limbs[4]) {
    std::ostringstream oss;
    oss << std::hex << std::uppercase << std::setfill('0');
    oss << std::setw(16) << limbs[3];
    oss << std::setw(16) << limbs[2];
    oss << std::setw(16) << limbs[1];
    oss << std::setw(16) << limbs[0];
    return oss.str();
}

static bool base58_decode(const std::string& in, std::vector<uint8_t>& out) {
    static const char* ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    static int8_t map[128];
    static bool inited=false;
    if (!inited){
        std::fill(std::begin(map), std::end(map), (int8_t)-1);
        for (int i=0;i<58;++i) map[(unsigned char)ALPH[i]] = (int8_t)i;
        inited=true;
    }
    if (in.empty()) return false;
    size_t zeros = 0;
    while (zeros < in.size() && in[zeros] == '1') ++zeros;

    std::vector<uint8_t> b256; b256.reserve(in.size()*733/1000 + 1); 
    for (char ch : in) {
        unsigned char uc = (unsigned char)ch;
        if (uc >= 128 || map[uc] == -1) return false;
        int carry = map[uc];
        for (size_t j=0;j<b256.size();++j) {
            int x = (int)b256[j] * 58 + carry;
            b256[j] = (uint8_t)(x & 0xFF);
            carry = x >> 8;
        }
        while (carry) {
            b256.push_back((uint8_t)(carry & 0xFF));
            carry >>= 8;
        }
    }
    out.clear();
    out.resize(zeros, 0u);
    for (auto it=b256.rbegin(); it!=b256.rend(); ++it) out.push_back(*it);
    return true;
}

static bool decode_p2pkh_address(const std::string& addr, uint8_t out_hash160[20]) {
    if (addr.empty() || addr[0] != '1') return false;

    std::vector<uint8_t> raw;
    if (!base58_decode(addr, raw)) return false;
    if (raw.size() != 25) return false;
    if (raw[0] != 0x00) return false;

    uint8_t check[32];
    host_sha256::sha256d(raw.data(), 21, check);
    if ( !std::equal(check, check+4, raw.data()+21) ) return false;

    std::memcpy(out_hash160, raw.data()+1, 20);
    return true;
}

static bool parse_u8(const char* s, u8* res) {
	char cl = toupper(s[1]);
	char ch = toupper(s[0]);
	if (((cl < '0') || (cl > '9')) && ((cl < 'A') || (cl > 'F')))
		return false;
	if (((ch < '0') || (ch > '9')) && ((ch < 'A') || (ch > 'F')))
		return false;
	u8 l = ((cl >= '0') && (cl <= '9')) ? (cl - '0') : (cl - 'A' + 10);
	u8 h = ((ch >= '0') && (ch <= '9')) ? (ch - '0') : (ch - 'A' + 10);
	*res = l + (h << 4);
	return true;
}

static std::string formatCompressedPubHex(const uint64_t Rx[4], const uint64_t Ry[4]) {
    uint8_t out[33];
    out[0] = (Ry[0] & 1ULL) ? 0x03 : 0x02;
    { uint64_t v = Rx[3]; out[ 1]=(uint8_t)(v>>56); out[ 2]=(uint8_t)(v>>48); out[ 3]=(uint8_t)(v>>40); out[ 4]=(uint8_t)(v>>32); out[ 5]=(uint8_t)(v>>24); out[ 6]=(uint8_t)(v>>16); out[ 7]=(uint8_t)(v>>8); out[ 8]=(uint8_t)(v>>0); }
    { uint64_t v = Rx[2]; out[ 9]=(uint8_t)(v>>56); out[10]=(uint8_t)(v>>48); out[11]=(uint8_t)(v>>40); out[12]=(uint8_t)(v>>32); out[13]=(uint8_t)(v>>24); out[14]=(uint8_t)(v>>16); out[15]=(uint8_t)(v>>8); out[16]=(uint8_t)(v>>0); }
    { uint64_t v = Rx[1]; out[17]=(uint8_t)(v>>56); out[18]=(uint8_t)(v>>48); out[19]=(uint8_t)(v>>40); out[20]=(uint8_t)(v>>32); out[21]=(uint8_t)(v>>24); out[22]=(uint8_t)(v>>16); out[23]=(uint8_t)(v>>8); out[24]=(uint8_t)(v>>0); }
    { uint64_t v = Rx[0]; out[25]=(uint8_t)(v>>56); out[26]=(uint8_t)(v>>48); out[27]=(uint8_t)(v>>40); out[28]=(uint8_t)(v>>32); out[29]=(uint8_t)(v>>24); out[30]=(uint8_t)(v>>16); out[31]=(uint8_t)(v>>8); out[32]=(uint8_t)(v>>0); }
    static const char* hexd="0123456789ABCDEF";
    std::string s; s.resize(66);
    s[ 0]=hexd[(out[ 0]>>4)&0xF]; s[ 1]=hexd[out[ 0]&0xF];
    s[ 2]=hexd[(out[ 1]>>4)&0xF]; s[ 3]=hexd[out[ 1]&0xF];
    s[ 4]=hexd[(out[ 2]>>4)&0xF]; s[ 5]=hexd[out[ 2]&0xF];
    s[ 6]=hexd[(out[ 3]>>4)&0xF]; s[ 7]=hexd[out[ 3]&0xF];
    s[ 8]=hexd[(out[ 4]>>4)&0xF]; s[ 9]=hexd[out[ 4]&0xF];
    s[10]=hexd[(out[ 5]>>4)&0xF]; s[11]=hexd[out[ 5]&0xF];
    s[12]=hexd[(out[ 6]>>4)&0xF]; s[13]=hexd[out[ 6]&0xF];
    s[14]=hexd[(out[ 7]>>4)&0xF]; s[15]=hexd[out[ 7]&0xF];
    s[16]=hexd[(out[ 8]>>4)&0xF]; s[17]=hexd[out[ 8]&0xF];
    s[18]=hexd[(out[ 9]>>4)&0xF]; s[19]=hexd[out[ 9]&0xF];
    s[20]=hexd[(out[10]>>4)&0xF]; s[21]=hexd[out[10]&0xF];
    s[22]=hexd[(out[11]>>4)&0xF]; s[23]=hexd[out[11]&0xF];
    s[24]=hexd[(out[12]>>4)&0xF]; s[25]=hexd[out[12]&0xF];
    s[26]=hexd[(out[13]>>4)&0xF]; s[27]=hexd[out[13]&0xF];
    s[28]=hexd[(out[14]>>4)&0xF]; s[29]=hexd[out[14]&0xF];
    s[30]=hexd[(out[15]>>4)&0xF]; s[31]=hexd[out[15]&0xF];
    s[32]=hexd[(out[16]>>4)&0xF]; s[33]=hexd[out[16]&0xF];
    s[34]=hexd[(out[17]>>4)&0xF]; s[35]=hexd[out[17]&0xF];
    s[36]=hexd[(out[18]>>4)&0xF]; s[37]=hexd[out[18]&0xF];
    s[38]=hexd[(out[19]>>4)&0xF]; s[39]=hexd[out[19]&0xF];
    s[40]=hexd[(out[20]>>4)&0xF]; s[41]=hexd[out[20]&0xF];
    s[42]=hexd[(out[21]>>4)&0xF]; s[43]=hexd[out[21]&0xF];
    s[44]=hexd[(out[22]>>4)&0xF]; s[45]=hexd[out[22]&0xF];
    s[46]=hexd[(out[23]>>4)&0xF]; s[47]=hexd[out[23]&0xF];
    s[48]=hexd[(out[24]>>4)&0xF]; s[49]=hexd[out[24]&0xF];
    s[50]=hexd[(out[25]>>4)&0xF]; s[51]=hexd[out[25]&0xF];
    s[52]=hexd[(out[26]>>4)&0xF]; s[53]=hexd[out[26]&0xF];
    s[54]=hexd[(out[27]>>4)&0xF]; s[55]=hexd[out[27]&0xF];
    s[56]=hexd[(out[28]>>4)&0xF]; s[57]=hexd[out[28]&0xF];
    s[58]=hexd[(out[29]>>4)&0xF]; s[59]=hexd[out[29]&0xF];
    s[60]=hexd[(out[30]>>4)&0xF]; s[61]=hexd[out[30]&0xF];
    s[62]=hexd[(out[31]>>4)&0xF]; s[63]=hexd[out[31]&0xF];
    s[64]=hexd[(out[32]>>4)&0xF]; s[65]=hexd[out[32]&0xF];
    return s;
}

