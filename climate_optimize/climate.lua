require "common"
require "pointset"
require "point"

Climate = class(function(a, regions)
	a.temperatureMin = 0
	a.temperatureMax = 100
	a.polarExponent = 1.2
	a.rainfallMidpoint = 50

	a.polarExponentMultiplier = 90 ^ a.polarExponent
	if a.rainfallMidpoint > 50 then
		a.rainfallPlusMinus = 100 - a.rainfallMidpoint
	else
		a.rainfallPlusMinus = a.rainfallMidpoint
	end

	a.iterations = 0
	a.generations = 0
	a.nearestString = ""
	a.regions = regions
	a.regionsByName = {}
	a.pointSet = PointSet(a)
	for i, region in pairs(regions) do
		for ii, p in pairs(region.points) do
			local point = Point(region, p.t, p.r)
			a.pointSet:AddPoint(point)
		end
		a.regionsByName[region.name] = region
	end
end)

function Climate:Fill()
	local didSomething = self.pointSet:Fill()
	if didSomething then
		self:GiveRegionExcessAreas()
	end
end

function Climate:GiveRegionExcessAreas()
	for ii, region in pairs(self.regions) do
		region.excessLatitudeArea = region.latitudeArea - region.targetLatitudeArea
		region.excessArea = region.area - region.targetArea
	end
end

-- get one mutation and use it if it's better
function Climate:Optimize()
	self:Fill()
	self.pointSet:GiveAdjustments()
	local mutation = PointSet(self, self.pointSet)
	if mutation:Okay() then
		mutation:Fill()
		self:GiveRegionExcessAreas()
		mutation:GiveDistance()
		if not self.pointSet.distance or mutation.distance < self.pointSet.distance then
			self.pointSet = mutation
			for i, region in pairs(self.regions) do
				region.stableArea = region.area + 0
				region.stableLatitudeArea = region.latitudeArea + 0
			end
			self.generations = self.generations + 1
		end
	end
	self.nearestString = tostring(mFloor(self.pointSet.distance))
	self.iterations = self.iterations + 1
end

function Climate:GetTemperature(latitude)
	local rise = self.temperatureMax - self.temperatureMin
	local distFromPole = (90 - latitude) ^ self.polarExponent
	temp = (rise / self.polarExponentMultiplier) * distFromPole + self.temperatureMin
	return mFloor(temp)
end

function Climate:GetRainfall(latitude)
	if latitude > 75 then -- polar
		rain = (self.rainfallMidpoint/4) + ( (self.rainfallPlusMinus/4) * (mCos((mPi/15) * (latitude+15))) )
	elseif latitude > 37.5 then -- temperate
		rain = self.rainfallMidpoint + ((self.rainfallPlusMinus/2) * mCos(latitude * (mPi/25)))
	else -- tropics and desert
		rain = self.rainfallMidpoint + (self.rainfallPlusMinus * mCos(latitude * (mPi/25)))
	end
	return mFloor(rain)
end