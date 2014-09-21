require "class"
require "config"

mCeil = math.ceil
mFloor = math.floor
mMin = math.min
mMax = math.max
mAbs = math.abs
mSqrt = math.sqrt
mSin = math.sin
mCos = math.cos
mPi = math.pi
mTwicePi = math.pi * 2
mAtan2 = math.atan2
tInsert = table.insert
tRemove = table.remove

function TempRainDist(t1, r1, t2, r2)
	local tdist = mAbs(t2 - t1)
	local rdist = mAbs(r2 - r1)
	return tdist^2 + rdist^2
end