#include "Ec.h"
#include "EcInt.h"

#include "Utils.h"

EcPoint g_G;

// https://en.wikipedia.org/wiki/Elliptic_curve_point_multiplication#Point_addition
EcPoint Ec::AddPoints(EcPoint& pnt1, EcPoint& pnt2)
{
	EcPoint res;
	EcInt dx, dy, lambda, lambda2;

	dx = pnt2.x;
	dx.SubModP(pnt1.x);
	dx.InvModP();

	dy = pnt2.y;
	dy.SubModP(pnt1.y);

	lambda = dy;
	lambda.MulModP(dx);
	lambda2 = lambda;
	lambda2.MulModP(lambda);

	res.x = lambda2;
	res.x.SubModP(pnt1.x);
	res.x.SubModP(pnt2.x);

	res.y = pnt2.x;
	res.y.SubModP(res.x);
	res.y.MulModP(lambda);
	res.y.SubModP(pnt2.y);
	return res;
}

// https://en.wikipedia.org/wiki/Elliptic_curve_point_multiplication#Point_doubling
EcPoint Ec::DoublePoint(EcPoint& pnt)
{
	EcPoint res;
	EcInt t1, t2, lambda, lambda2;

	t1 = pnt.y;
	t1.AddModP(pnt.y);
	t1.InvModP();

	t2 = pnt.x;
	t2.MulModP(pnt.x);
	lambda = t2;
	lambda.AddModP(t2);
	lambda.AddModP(t2);
	lambda.MulModP(t1);
	lambda2 = lambda;
	lambda2.MulModP(lambda);

	res.x = lambda2;
	res.x.SubModP(pnt.x);
	res.x.SubModP(pnt.x);

	res.y = pnt.x;
	res.y.SubModP(res.x);
	res.y.MulModP(lambda);
	res.y.SubModP(pnt.y);

	return res;
}

//k up to 256 bits
EcPoint Ec::MultiplyG(EcInt& k)
{
	EcPoint res;
	EcPoint t = g_G;
	bool first = true;
	int n = 3;
	while ((n >= 0) && !k.data[n])
		n--;
	if (n < 0)
		return res; //error
	int index;                     
	_BitScanReverse64((u32*)&index, k.data[n]);
	for (int i = 0; i <= 64 * n + index; i++)
	{
		u8 v = (k.data[i / 64] >> (i % 64)) & 1;	
		if (v)
		{
			if (first)
			{
				first = false;
				res = t;
			}
			else
				res = Ec::AddPoints(res, t);
		}
		t = Ec::DoublePoint(t);
	}

	return res;
}

EcInt Ec::CalcY(EcInt& x, bool is_even)
{
	EcInt res;
	EcInt tmp;
	tmp.Set(7);
	res = x;
	res.MulModP(x);
	res.MulModP(x);
	res.AddModP(tmp);
	res.SqrtModP();
	if ((res.data[0] & 1) == is_even)
		res.NegModP();
	return res;
}

bool Ec::IsValidPoint(EcPoint& pnt)
{
	EcInt x, y, seven;
	seven.Set(7);
	x = pnt.x;
	x.MulModP(pnt.x);
	x.MulModP(pnt.x);
	x.AddModP(seven);
	y = pnt.y;
	y.MulModP(pnt.y);
	return x.IsEqual(y);
}

void Ec::InitEc()
{
	g_P.SetHexStr("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F"); //Fp
	g_G.x.SetHexStr("79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"); //G.x
	g_G.y.SetHexStr("483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8"); //G.y
};

void Ec::DeInitEc()
{
}
