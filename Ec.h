#pragma once

#include "EcPoint.h"
#include "EcInt.h"

class Ec
{
public:
	static EcPoint AddPoints(EcPoint& pnt1, EcPoint& pnt2);
	static EcPoint DoublePoint(EcPoint& pnt);
	static EcPoint MultiplyG(EcInt& k);

	static EcInt CalcY(EcInt& x, bool is_even);
	static bool IsValidPoint(EcPoint& pnt);
	static void InitEc();
	static void DeInitEc();
};

extern EcPoint g_G; //Generator point