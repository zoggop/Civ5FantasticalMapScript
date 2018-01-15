require "common"

Point = class(function(a, region, t, r, parentPoint, cloneParent)
	a.region = region
	a.t = t
	a.r = r
	a.generation = 0
	a.tMove, a.rMove, a.tMoveCount, a.rMoveCount = 0, 0, 0, 0
	a.neighCount = 0
	if parentPoint then
		-- mutation
		if parentPoint.region.fixed or cloneParent then
			a.t = parentPoint.t + 0
			a.r = parentPoint.r + 0
			a.generation = parentPoint.generation + 0
		else
			local strength = parentPoint.pointSet.climate.mutationStrength
			a.t = mFloor( parentPoint.t + parentPoint.tMove + math.random(-strength, strength) )
			a.r = mFloor( parentPoint.r + parentPoint.rMove + math.random(-strength, strength) )
			a.t = mMax(0, mMin(100, a.t))
			a.r = mMax(0, mMin(100, a.r))
			a.generation = parentPoint.generation + 1
		end
	end
	a.superRegionAreas, a.superRegionLatitudeAreas = {}, {}
end)

function Point:ResetFillState()
	self.region.latitudeArea = 0
	self.latitudeArea = 0
	self.region.area = 0
	self.area = 0
	self.minT, self.maxT, self.minR, self.maxR = 100, 0, 100, 0
	self.neighbors = {}
	self.lowT, self.highT, self.lowR, self.highR = nil, nil, nil, nil
	self.superRegionAreas, self.superRegionLatitudeAreas = {}, {}
	self.region.superRegionAreas, self.region.superRegionLatitudeAreas = {}, {}
end

function Point:GiveAdjustment()
	local areaAvg, latitudeAreaAvg = 0, 0
	-- precalculate average area for equalizing subregion area within regions
	if self.isSub and #self.region.containedBy > 0 then
		for i, regionName in pairs(self.region.containedBy) do
			local superRegion = self.pointSet.climate.regionsByName[regionName]
			areaAvg = areaAvg + (self.region.superRegionAreas[superRegion] or 0)
			latitudeAreaAvg = latitudeAreaAvg + (self.region.superRegionLatitudeAreas[superRegion] or 0)
		end
		if areaAvg > 0 and #self.region.containedBy > 0 then
			areaAvg = areaAvg / #self.region.containedBy
		else
			latitudeAreaAvg = 0
		end
		if latitudeAreaAvg > 0 and #self.region.containedBy > 0 then
			latitudeAreaAvg = latitudeAreaAvg / #self.region.containedBy
		else
			latitudeAreaAvg = 0
		end
	end
	-- reset adjustments
	self.tMove, self.rMove, self.tMoveCount, self.rMoveCount = 0, 0, 0, 0
	self.neighCount = 0
	-- adjust for missing/excessive areas of neighbors
	for neighbor, yes in pairs(self.neighbors) do
		if neighbor.region ~= self.region then
			local dt = neighbor.t - self.t
			local dr = neighbor.r - self.r
			local da = (neighbor.region.excessLatitudeArea) / self.pointSet.climate.totalLatitudes
			if neighbor.region.excessLatitudeArea > 0 and neighbor.latitudeArea > 0 then 
				da = da * (neighbor.latitudeArea / neighbor.region.latitudeArea)
			elseif neighbor.region.excessLatitudeArea < 0 or neighbor.latitudeArea == 0 then
				da = da * ((neighbor.region.latitudeArea - neighbor.latitudeArea) / neighbor.region.latitudeArea)
			end
			self:TempMove((dt * latitudeAreaAdjustmentMultiplier) * da)
			self:RainMove((dr * latitudeAreaAdjustmentMultiplier) * da)
			da = (neighbor.region.excessArea) / 10000
			if neighbor.region.excessArea > 0 and neighbor.area > 0 then 
				da = da * (neighbor.area / neighbor.region.area)
			elseif neighbor.region.excessArea < 0 or neighbor.area == 0 then
				da = da * ((neighbor.region.area - neighbor.area) / neighbor.region.area)
			end
			self:TempMove((dt * areaAdjustmentMultiplier) * da)
			self:RainMove((dr * areaAdjustmentMultiplier) * da)
			self.neighCount = self.neighCount + 1
		end
	end
	if self.isSub then
		-- adjust for unequal area across superregions
		for i, regionName in pairs(self.region.containedBy) do
			local superRegion = self.pointSet.climate.regionsByName[regionName]
			local da = areaAvg - (self.superRegionAreas[superRegion] or 0)
			local lda = latitudeAreaAvg - (self.superRegionLatitudeAreas[superRegion] or 0)
			for ii, point in pairs(self.pointSet.points) do
				if point.region == superRegion then
					local dt = superPoint.t - self.t
					local dr = superPoint.r - self.r
					self:TempMove((dt * areaAdjustmentMultiplier) * da)
					self:RainMove((dr * areaAdjustmentMultiplier) * da)
					self:TempMove((dt * latitudeAreaAdjustmentMultiplier) * lda)
					self:RainMove((dr * latitudeAreaAdjustmentMultiplier) * lda)
				end
			end
		end
	end
	-- adjust for high and low rain and temp
	if self.region.highT then
		self:TempMove((100-self.t)*highLowMultiplier)
	elseif self.region.lowT then
		self:TempMove((0-self.t)*highLowMultiplier)
	end
	if self.region.highR then
		self:RainMove((100-self.r)*highLowMultiplier)
	elseif self.region.lowR then
		self:RainMove((0-self.r)*highLowMultiplier)
	end
	-- print(self.tMove, self.rMove, tostring(self.isSub), self.t, self.r)
	-- average all adjustment moves
	if mAbs(self.tMove) > 0 and self.tMoveCount > 0 then
		self.tMove = (self.tMove / self.tMoveCount) * adjustmentIntensity
	end
	if mAbs(self.rMove) > 0 and self.rMoveCount > 0 then
		self.rMove = (self.rMove / self.rMoveCount) * adjustmentIntensity
	end
end

function Point:Dist(t, r)
	return TempRainDist(self.t, self.r, t, r)
end

function Point:TempMove(tempMove)
	if tempMove ~= tempMove then return end
	self.tMove = self.tMove + tempMove
	self.tMoveCount = self.tMoveCount + 1
end

function Point:RainMove(rainMove)
	if rainMove ~= rainMove then return end
	self.rMove = self.rMove + rainMove
	self.rMoveCount = self.rMoveCount + 1
end

function Point:Okay()
	for regionName, relation in pairs(self.region.relations) do
		local relatedRegion = self.pointSet.climate.regionsByName[regionName]
		if relatedRegion then
			for ii, rPoint in pairs(self.pointSet.points) do
				if rPoint.region == relatedRegion then
					if relation.t == -1 then
						if self.t >= rPoint.t then return false, "t above " .. rPoint.region.name end
					elseif relation.t == 1 then
						if self.t <= rPoint.t then return false, "t below " .. rPoint.region.name end
					end
					if relation.r == -1 then
						if self.r >= rPoint.r then return false, "r above " .. rPoint.region.name end
					elseif relation.r == 1 then
						if self.r <= rPoint.r then return false, "r below " .. rPoint.region.name end
					end
				end
			end
		end
	end
	return true
end

function Point:FillOkay()
	if self.region.noLowT and self.lowT then return false, "lowT" end
	if self.region.noHighT and self.highT then return false, "highT" end
	if self.region.noLowR and self.lowR then return false, "lowR" end
	if self.region.noHighR and self.highR then return false, "highR" end

	if self.region.lowT and not self.lowT then return false, "no lowT" end
	if self.region.highT and not self.highT then return false, "no highT" end
	if self.region.lowR and not self.lowR then return false, "no lowR" end
	if self.region.highR and not self.highR then return false, "no highR" end

	if self.region.maxR and self.maxR > self.region.maxR then return false, "maxR" end
	if self.region.minR and self.minR < self.region.minR then return false, "minR" end
	if self.region.maxT and self.maxT > self.region.maxT then return false, "maxT" end
	if self.region.minT and self.minT < self.region.minT then return false, "minT" end
	for regionName, relation in pairs(self.region.relations) do
		local relatedRegion = self.pointSet.climate.regionsByName[regionName]
		if relatedRegion then
			for ii, rPoint in pairs(self.pointSet.points) do
				if rPoint.region == relatedRegion then
					if relation.n == -1 then
						if self.neighbors[rPoint] then return false, "bad neighbor: " .. rPoint.region.name end
					end
				end
			end
		end
	end
	if self.region.contiguous then
		for i, point in pairs(self.pointSet.points) do
			if point ~= self and point.region == self.region then
 				if not point.neighbors[self] then return false, "not contiguous" end
			end
		end
	end
	if self.pointSet.isSub then
		for i, regionName in pairs(self.region.containedBy) do
			local region = self.pointSet.climate.regionsByName[regionName]
			if (not self.region.superRegionAreas[region] and (self.region.stableArea or 0) > 0) or (not self.region.superRegionLatitudeAreas[region] and (self.region.stableLatitudeArea or 0) > 0) then
				return false, "out of container region: " .. region.name
			end
		end
	end
	return true
end