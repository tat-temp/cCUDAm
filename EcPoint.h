#pragma once

#include "EcInt.h"

class EcPoint
{
public:
	bool IsEqual(EcPoint& pnt);
	void LoadFromBuffer64(u8* buffer);
	void SaveToBuffer64(u8* buffer);
	bool SetHexStr(const char* str);
	EcInt x;
	EcInt y;
};