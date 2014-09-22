require "common"

Point = class(function(a, region, t, r, parentPoint)
	a.region = region
	a.t = t
	a.r = r
	if parentPoint then
		-- mutation
		if parentPoint.region.fixed then
			a.t = parentPoint.t + 0
			a.r = parentPoint.r + 0
		else
			local strength = parentPoint.pointSet.climate.mutationStrength
			a.t = mFloor( parentPoint.t + parentPoint.tMove + math.random(-strength, strength) )
			a.r = mFloor( parentPoint.r + parentPoint.rMove + math.random(-strength, strength) )
			a.t = mMax(0, mMin(100, a.t))
			a.r = mMax(0, mMin(100, a.r))
		end
	end
	a.superRegionAreas, a.superRegionLatitudeAreas = {}, {}
end)

function Point:ResetFillState()
	self.region.latitudeArea = 0
	self.latitudeArea = 0
	self.region.area = 0
	self.area = 0
	self.neighbors = {}
	self.lowT, self.highT, self.lowR, self.highR = nil, nil, nil, nil
	self.superRegionAreas, self.superRegionLatitudeAreas = {}, {}
	self.region.superRegionAreas, self.region.superRegionLatitudeAreas = {}, {}
end

function Point:GiveAdjustment()
	self.tMove, self.rMove, self.tMoveCount, self.rMoveCount = 0, 0, 0, 0
	self.neighCount = 0
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
						if self.t >= rPoint.t then return end
					elseif relation.t == 1 then
						if self.t <= rPoint.t then return end
					end
					if relation.r == -1 then
						if self.r >= rPoint.r then return end
					elseif relation.r == 1 then
						if self.r <= rPoint.r then return end
					end
					if relation.n == -1 then
						if self.neighbors[rPoint] then return end
					end
				end
			end
		end
	end
	return true
end

function Point:FillOkay()
	if self.region.noLowT and self.lowT then return end
	if self.region.noHighT and self.highT then return end
	if self.region.noLowR and self.lowR then return end
	if self.region.noHighR and self.highR then return end
	if self.pointSet.isSub then
		for i, regionName in pairs(self.region.containedBy) do
			local region = self.pointSet.climate.regionsByName[regionName]
			if (not self.region.superRegionAreas[region] and (self.region.stableArea or 0) > 0) or (not self.region.superRegionLatitudeAreas[region] and (self.region.stableLatitudeArea or 0) > 0) then
				return
			end
		end
	end
	return true
end