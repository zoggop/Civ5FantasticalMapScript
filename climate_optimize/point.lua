require "common"

Point = class(function(a, region, t, r, parentPoint)
	a.region = region
	a.t = t
	a.r = r
	if parentPoint then
		-- mutation
		a.t = mFloor( parentPoint.t + parentPoint.tMove + math.random(-mutationStrength, mutationStrength) )
		a.r = mFloor( parentPoint.r + parentPoint.rMove + math.random(-mutationStrength, mutationStrength) )
		a.t = mMax(0, mMin(100, a.t))
		a.r = mMax(0, mMin(100, a.r))
	end
end)

function Point:ResetFillState()
	self.region.latitudeArea = 0
	self.latitudeArea = 0
	self.region.area = 0
	self.area = 0
	self.neighbors = {}
	self.lowT, self.highT, self.lowR, self.highR = nil, nil, nil, nil
end

function Point:GiveAdjustment()
	self.tMove, self.rMove, self.tMoveCount, self.rMoveCount = 0, 0, 0, 0
	self.neighCount = 0
	for neighbor, yes in pairs(self.neighbors) do
		if neighbor.region ~= self.region then
			local dt = neighbor.t - self.t
			local dr = neighbor.r - self.r
			local da = (neighbor.region.excessLatitudeArea) / 90
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
	self.tMove = (self.tMove / self.tMoveCount) * adjustmentIntensity
	self.rMove = (self.rMove / self.rMoveCount) * adjustmentIntensity
end

function Point:Dist(t, r)
	return TempRainDist(self.t, self.r, t, r)
end

function Point:TempMove(tempMove)
	self.tMove = self.tMove + tempMove
	self.tMoveCount = self.tMoveCount + 1
end

function Point:RainMove(rainMove)
	self.rMove = self.rMove + rainMove
	self.rMoveCount = self.rMoveCount + 1
end

function Point:Okay()
	if not self.region.lowT and self.lowT then return end
	-- if not region.highT and self.highT then return end
	-- if not region.lowR and self.lowR then return end
	-- if not region.highR and self.highR then return end
	for regionName, relation in pairs(self.region.relations) do
		local relatedRegion = self.pointSet.climate.regionsByName[regionName]
		if relatedRegion then
			for ii, rPoint in pairs(self.pointSet) do
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