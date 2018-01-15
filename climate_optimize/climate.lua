require "common"
require "pointset"
require "point"

Climate = class(function(a, regions, subRegions, parentClimate)
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
	local protoLatitudes = {}
	for l = 0, mFloor(90/latitudeResolution) do
		local latitude = l * latitudeResolution
		local t, r = a:GetTemperature(latitude, true), a:GetRainfall(latitude, true)
		tInsert(protoLatitudes, { latitude = latitude, t = t, r = r })
	end
	local currentLtr
	local goodLtrs = {}
	local pseudoLatitudes = {}
	local pseudoLatitude = 90
	while #protoLatitudes > 0 do
		local ltr = tRemove(protoLatitudes)
		if not currentLtr then
			currentLtr = ltr
		else
			local dist = mSqrt(TempRainDist(currentLtr.t, currentLtr.r, ltr.t, ltr.r))
			if dist > 3.33 then currentLtr = ltr end
		end
		if not goodLtrs[currentLtr] then
			goodLtrs[currentLtr] = true
			pseudoLatitudes[pseudoLatitude] = { temperature = mFloor(currentLtr.t), rainfall = mFloor(currentLtr.r) }
			pseudoLatitude = pseudoLatitude - 1
		end
	end
	print(pseudoLatitude)
	a.pseudoLatitudes = pseudoLatitudes
	a.totalLatitudes = 91
	--[[
	a.latitudePoints = {}
	a.totalLatitudes = 0
	for l = 0, 90, latitudeResolution do
		local t, r = a:GetTemperature(l), a:GetRainfall(l)
		if not a.latitudePoints[mFloor(t) .. " " .. mFloor(r)] then
			a.latitudePoints[mFloor(t) .. " " .. mFloor(r)] = {l = l, t = t, r = r}
			a.totalLatitudes = a.totalLatitudes + 1
		end
	end
	]]--
	-- latitudeAreaMutationDistMult = latitudeAreaMutationDistMult * (90 / a.totalLatitudes)
	-- print(a.totalLatitudes, latitudeAreaMutationDistMult)

	a.mutationStrength = mutationStrength + 0
	a.iterations = 0
	a.barrenIterations = 0
	a.nearestString = ""
	a.regions = regions
	a.subRegions = subRegions
	a.regionsByName = {}
	a.subRegionsByName = {}
	a.superRegionsByName = {}
	if regions then
		a.pointSet = PointSet(a)
		for i, region in pairs(regions) do
			region.targetLatitudeArea = region.targetArea * a.totalLatitudes
			region.targetArea = region.targetArea * 10000
			region.isSub = false
			for ii, p in pairs(region.points) do
				local point = Point(region, p.t, p.r)
				a.pointSet:AddPoint(point)
			end
			a.regionsByName[region.name] = region
			a.superRegionsByName[region.name] = region
		end
	elseif parentClimate then
		a.pointSet = parentClimate.pointSet
		a.regions = parentClimate.regions
		a.superRegionsByName = parentClimate.superRegionsByName
		for i, region in pairs(parentClimate.regions) do
			a.regionsByName[region.name] = region
		end
	end
	if subRegions then
		a.subPointSet = PointSet(a, nil, true)
		for i, region in pairs(subRegions) do
			region.isSub = true
			region.targetLatitudeArea = region.targetArea * a.totalLatitudes
			region.targetArea = region.targetArea * 10000
			for ii, p in pairs(region.points) do
				local point = Point(region, p.t, p.r)
				a.subPointSet:AddPoint(point)
			end
			a.regionsByName[region.name] = region
			a.subRegionsByName[region.name] = region
		end
	elseif parentClimate then
		a.subPointSet = parentClimate.subPointSet
	end
	for i, region in pairs(a.regions) do
		region.subRegions = {}
		for ii, subRegionName in pairs(region.subRegionNames) do
			if a.regionsByName[subRegionName] then
				region.subRegions[a.regionsByName[subRegionName]] = true
			end
		end
	end
end)

function Climate:ReloadRegions(regions, isSub)
	if isSub then
		self.subPointSet = PointSet(self, nil, true)
	else
		self.pointSet = PointSet(self)
	end
	for i, region in pairs(regions) do
		for ii, p in pairs(region.points) do
			local point = Point(region, p.t, p.r)
			if isSub then
				self.subPointSet:AddPoint(point)
			else
				self.pointSet:AddPoint(point)
			end
		end
	end
end

function Climate:Fill()
	if self.pointSet:Fill() then
		self:GiveRegionsExcessAreas(self.regions)
		self.pointSet:GiveDistance()
	end
	if self.subPointSet:Fill() then
		self:GiveRegionsExcessAreas(self.subRegions)
		self.subPointSet:GiveDistance()
	end
	for i, region in pairs(self.regions) do
		region.stableArea = region.area + 0
		region.stableLatitudeArea = region.latitudeArea + 0
	end
	for i, region in pairs(self.subRegions) do
		region.stableArea = region.area + 0
		region.stableLatitudeArea = region.latitudeArea + 0
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
	local regions
	if pointSet.isSub then
		regions = self.subRegions
	else
		regions = self.regions
	end
	if mutation:Okay() then
		mutation:Fill()
		if mutation:FillOkay() then
			self:GiveRegionsExcessAreas(regions)
			mutation:GiveDistance()
			if not pointSet.distance or mutation.distance < pointSet.distance then
				print("accept mutation", mCeil(pointSet.distance), mCeil(mutation.distance))
				for i, region in pairs(regions) do
					region.stableArea = region.area + 0
					region.stableLatitudeArea = region.latitudeArea + 0
				end
				return mutation, true
			end
		end
	end
	pointSet:Fill()
	self:GiveRegionsExcessAreas(regions)
	return pointSet, false
end

-- get one mutation and use it if it's better
function Climate:Optimize()
	self:Fill()
	self.pointSet:GiveAdjustments()
	self.subPointSet:GiveAdjustments()
	local oldPointSet = self.pointSet
	local mutated, subMutated
	self.pointSet, mutated = self:MutatePointSet(self.pointSet)
	-- if mutated then
	-- 	local oldDist = self.leastSubPointSetDistance or 999999
	-- 	self.subPointSet:Fill()
	-- 	self:GiveRegionsExcessAreas(self.subRegions)
		-- self.subPointSet:GiveDistance()
		-- print(oldDist, self.subPointSet.distance, oldPointSet, self.pointSet)
		-- if self.subPointSet.distance > oldDist + (oldDist * subPointSetDistanceIncreaseTolerance) then
		-- 	self.pointSet = oldPointSet
		-- 	self.subPointSet:Fill()
		-- 	self:GiveRegionsExcessAreas(self.subRegions)
		-- 	self.subPointSet:GiveDistance()
		-- 	mutated = false
		-- end
		-- print(self.subPointSet.distance)
	-- end
	self.subPointSet, subMutated = self:MutatePointSet(self.subPointSet)
	if self.subPointSet.distance and self.subPointSet.distance < (self.leastSubPointSetDistance or 999999) then
		self.leastSubPointSetDistance = self.subPointSet.distance
	end
	self.nearestString = tostring(mFloor(self.pointSet.distance or 0) .. " " .. mFloor(self.subPointSet.distance or 0))
	self.iterations = self.iterations + 1
	if not mutated and not subMutated then
		self.barrenIterations = self.barrenIterations + 1
		if self.barrenIterations > maxBarrenIterations then
			if self.mutationStrength == maxMutationStrength then
				self.mutationStrength = mutationStrength + 0
			else
				self.mutationStrength = mMin(self.mutationStrength + 1, maxMutationStrength)
			end
			self.barrenIterations = 0
		end
	else
		self.barrenIterations = 0
		self.mutationStrength = mutationStrength
	end
end

function Climate:GetTemperature(latitude, noFloor)
	local temp
	if self.pseudoLatitudes and self.pseudoLatitudes[latitude] then
		temp = self.pseudoLatitudes[latitude].temperature
	else
		local rise = self.temperatureMax - self.temperatureMin
		local distFromPole = (90 - latitude) ^ self.polarExponent
		temp = (rise / self.polarExponentMultiplier) * distFromPole + self.temperatureMin
	end
	if noFloor then return temp end
	return mFloor(temp)
end

function Climate:GetRainfall(latitude, noFloor)
	local rain
	if self.pseudoLatitudes and self.pseudoLatitudes[latitude] then
		rain = self.pseudoLatitudes[latitude].rainfall
	else
		rain = self.rainfallMidpoint + (self.rainfallPlusMinus * mCos(latitude * (mPi/29)))
	end
	if noFloor then return rain end
	return mFloor(rain)
end

function Climate:SetPolarExponent(pExponent)
	self.polarExponent = pExponent
	self.polarExponentMultiplier = 90 ^ pExponent
	self:ResetLatitudes()
end

function Climate:SetRainfallMidpoint(rMidpoint)
	self.rainfallMidpoint = rMidpoint
	if self.rainfallMidpoint > 50 then
		self.rainfallPlusMinus = 100 - self.rainfallMidpoint
	else
		self.rainfallPlusMinus = self.rainfallMidpoint
	end
	self:ResetLatitudes()
end

function Climate:ResetLatitudes()
	self.pseudoLatitudes = nil
	local pseudoLatitudes
	local minDist = 3.33
	local iterations = 0
	repeat
		local protoLatitudes = {}
		for l = 0, mFloor(90/latitudeResolution) do
			local latitude = l * latitudeResolution
			local t, r = self:GetTemperature(latitude, true), self:GetRainfall(latitude, true)
			tInsert(protoLatitudes, { latitude = latitude, t = t, r = r })
		end
		local currentLtr
		local goodLtrs = {}
		pseudoLatitudes = {}
		local pseudoLatitude = 90
		while #protoLatitudes > 0 do
			local ltr = tRemove(protoLatitudes)
			if not currentLtr then
				currentLtr = ltr
			else
				local dist = mSqrt(TempRainDist(currentLtr.t, currentLtr.r, ltr.t, ltr.r))
				if dist > minDist then currentLtr = ltr end
			end
			if not goodLtrs[currentLtr] then
				goodLtrs[currentLtr] = true
				pseudoLatitudes[pseudoLatitude] = { temperature = mFloor(currentLtr.t), rainfall = mFloor(currentLtr.r) }
				pseudoLatitude = pseudoLatitude - 1
			end
		end
		print(pseudoLatitude)
		local change = mAbs(pseudoLatitude+1)^1.5 * 0.005
		if pseudoLatitude < -1 then
			minDist = minDist + change
		elseif pseudoLatitude > -1 then
			minDist = minDist - change
		end
		iterations = iterations + 1
	until pseudoLatitude == -1 or iterations > 100
	self.pseudoLatitudes = pseudoLatitudes
	self.totalLatitudes = 91
end