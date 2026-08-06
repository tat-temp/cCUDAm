#pragma once

#include <cstdint>
#include "Defs.h"

class EcInt
{
public:
	EcInt();

	void Assign(EcInt& val);
	void LoadFromBuffer32(u8* buffer);
	void LoadFromBuffer64(u64* buffer);
	void Set(u64 val);
	void SetZero();
	bool SetHexStr(const char* str);
	void GetHexStr(char* str);
	uint16_t GetU16(int index);

	bool Add(EcInt& val); //returns true if carry
	bool Sub(EcInt& val); //returns true if carry
	void Neg();
	void Neg256();
	void ShiftRight(int nbits);
	void ShiftLeft(int nbits);
	bool IsLessThanU(EcInt& val);
	bool IsLessThanI(EcInt& val);
	bool IsEqual(EcInt& val);
	bool IsZero();

	void Mul_u64(EcInt& val, u64 multiplier);
	void Mul_i64(EcInt& val, i64 multiplier);

	void AddModP(EcInt& val);
	void SubModP(EcInt& val);
	void NegModP();
	void MulModP(EcInt& val);
	void InvModP();
	void SqrtModP();

	//void RndBits(int nbits);
	//void RndMax(EcInt& max);

	u64 data[4 + 1];
};

extern EcInt g_P; //FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFE FFFFFC2F
