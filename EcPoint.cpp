#include "EcPoint.h"

#include <cstdint>
#include <cstring>
#include "Defs.h"
#include "Ec.h"
#include "Utils.h"

bool EcPoint::IsEqual(EcPoint& pnt)
{
	return this->x.IsEqual(pnt.x) && this->y.IsEqual(pnt.y);
}

void EcPoint::LoadFromBuffer64(u8* buffer)
{
	std::memcpy(x.data, buffer, 32);
	x.data[4] = 0;
	std::memcpy(y.data, buffer + 32, 32);
	y.data[4] = 0;
}

void EcPoint::SaveToBuffer64(u8* buffer)
{
	std::memcpy(buffer, x.data, 32);
	std::memcpy(buffer + 32, y.data, 32);
}

bool EcPoint::SetHexStr(const char* str)
{
	EcPoint res;
	int len = (int)strlen(str);
	if (len < 66)
		return false;
	u8 type, b;
	if (!parse_u8(str, &type))
		return false;
	if ((type < 2) || (type > 4))
		return false;
	if (((type == 2) || (type == 3)) && (len != 66))
		return false;
	if ((type == 4) && (len != 130))
		return false;

	if (len == 66) //compressed
	{
		str += 2;
		for (int i = 0; i < 32; i++)
		{
			if (!parse_u8(str + 2 * i, &b))
				return false;
			((u8*)res.x.data)[31 - i] = b;
		}
		res.y = Ec::CalcY(res.x, type == 2);
		if (!Ec::IsValidPoint(res))
			return false;		
		*this = res;
		return true;
	}
	//uncompressed
	str += 2;
	for (int i = 0; i < 32; i++)
	{
		if (!parse_u8(str + 2 * i, &b))
			return false;
		((u8*)res.x.data)[31 - i] = b;

		if (!parse_u8(str + 2 * i + 64, &b))
			return false;
		((u8*)res.y.data)[31 - i] = b;
	}
	if (!Ec::IsValidPoint(res))
		return false;
	*this = res;
	return true;
}

