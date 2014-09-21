require "common"
require "pointset"
require "point"

Climate = class(function(a, regions, subRegions)
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
	a.subRegions = subRegions
	a.regionsByName = {}
	a.allRegions = {}
	a.pointSet = PointSet(a)
	for i, region in pairs(regions) do
		region.targetLatitudeArea = region.targetArea * 90
		region.targetArea = region.targetArea * 10000
		for ii, p in pairs(region.points) do
			local point = Point(region, p.t, p.r)
			a.pointSet:AddPoint(point)
		end
		a.regionsByName[region.name] = region
	end
	a.subPointSet = PointSet(a, nil, true)
	for i, region in pairs(subRegions) do
		region.targetLatitudeArea = region.targetArea * 90
		region.targetArea = region.targetArea * 10000
		for ii, p in pairs(region.points) do
			local point = Point(region, p.t, p.r)
			a.subPointSet:AddPoint(point)
		end
		a.regionsByName[region.name] = region
	end
	for i, region in pairs(regions) do
		region.subRegions = {}
		for ii, subRegionName in pairs(region.subRegionNames) do
			region.subRegions[a.regionsByName[subRegionName]] = true
		end
	end
end)

function Climate:Fill()
	if self.pointSet:Fill() then
		self:GiveRegionsExcessAreas(self.regions)
	end
	if self.subPointSet:Fill() then
		self:GiveRegionsExcessAreas(self.subRegions)
	end
end

function Climate:GiveRegionsExcessAreas(regions)
	for i, region in pairs(regions) do
		region.excessLatitudeArea = region.latitudeArea - region.targetLatitudeArea
		region.excessArea = region.area - region.targetArea
	end
end

function Climate:MutatePointSet(pointSet)
	local mutation = PointSet(self, pointSet)
	if mutation:Okay() then
		mutation:Fill()
		if mutation:FillOkay() then
			local regions
			if pointSet.isSub then
				regions = self.subRegions
			else
				regions = self.regions
			end
			self:GiveRegionsExcessAreas(regions)
			mutation:GiveDistance()
			if not pointSet.distance or mutation.distance < pointSet.distance then
				pointSet = mutation
				for i, region in pairs(regions) do
					region.stableArea = region.area + 0
					region.stableLatitudeArea = region.latitudeArea + 0
				end
			end
		end
	end
	return pointSet
end

-- get one mutation and use it if it's better
function Climate:Optimize()
	self:Fill()
	self.pointSet:GiveAdjustments()
	self.subPointSet:GiveAdjustments()
	self.pointSet = self:MutatePointSet(self.pointSet)
	self.subPointSet = self:MutatePointSet(self.subPointSet)
	self.nearestString = tostring(mFloor(self.pointSet.distance or 0) .. " " .. mFloor(self.subPointSet.distance or 0))
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