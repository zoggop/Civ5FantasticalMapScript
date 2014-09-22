require "common"
require "point"

PointSet = class(function(a, climate, parentPointSet, isSub)
	a.climate = climate
	a.isSub = isSub
	a.points = {}
	a.grid = {}
	a.latitudes = {}
	a.generation = 0
	if parentPointSet then
		-- mutation
		a.isSub = parentPointSet.isSub
		a.generation = parentPointSet.generation + 1
		for i, parentPoint in pairs(parentPointSet.points) do
			local point = Point(parentPoint.region, nil, nil, parentPoint)
			tInsert(a.points, point)
			point:ResetFillState()
			point.pointSet = a
		end
	end
end)

function PointSet:AddPoint(point)
	tInsert(self.points, point)
	point:ResetFillState()
	point.pointSet = self
	point.isSub = self.isSub
end

function PointSet:NearestPoint(t, r)
	local nearestDist = 20000
	local nearestPoint
	for i, point in pairs(self.points) do
		local dist = point:Dist(t, r)
		if dist < nearestDist then
			nearestDist = dist
			nearestPoint = point
		end
	end
	if self.isSub then
		local superPoint = self.climate.pointSet.grid[t][r]
		if not superPoint.region.subRegions[nearestPoint.region] then
			nearestPoint = self.points[1]
		end
	end
	return nearestPoint
end

function PointSet:Fill()
	if self.filled then return false end
	self:FillLatitudes()
	self:FillGrid()
	self.filled = true
	return true
end

function PointSet:FillGrid()
	-- for i, point in pairs(self.points) do point:ResetFillState() end
	self.grid = {}
	for t = 0, 100 do
		self.grid[t] = {}
		for r = 0, 100 do
			local point = self:NearestPoint(t, r)
			if self.isSub then
				local superPoint = self.climate.pointSet.grid[t][r]
				if point.superRegionAreas[superPoint.region] == nil then
					point.superRegionAreas[superPoint.region] = 0
				end
				point.superRegionAreas[superPoint.region] = point.superRegionAreas[superPoint.region] + 1
			end
			self.grid[t][r] = point
			point.region.area = point.region.area + 1
			point.area = point.area + 1
			if t == 0 then point.lowT = true end
			if t == 100 then point.highT = true end
			if r == 0 then point.lowR = true end
			if r == 100 then point.highR = true end
			if self.grid[t][r-1] and self.grid[t][r-1] ~= point then
				point.neighbors[self.grid[t][r-1]] = true
				self.grid[t][r-1].neighbors[point] = true
			end
			if self.grid[t-1] then
				if self.grid[t-1][r+1] and self.grid[t-1][r+1] ~= point then
					point.neighbors[self.grid[t-1][r+1]] = true
					self.grid[t-1][r+1].neighbors[point] = true
				end
				if self.grid[t-1][r] and self.grid[t-1][r] ~= point then
					point.neighbors[self.grid[t-1][r]] = true
					self.grid[t-1][r].neighbors[point] = true
				end
				if self.grid[t-1][r-1] and self.grid[t-1][r-1] ~= point then
					point.neighbors[self.grid[t-1][r-1]] = true
					self.grid[t-1][r-1].neighbors[point] = true
				end
			end
		end
	end
end

function PointSet:FillLatitudes()
	self.latitudes = {}
	local drawCurve = false
	if not self.climate.latitudePoints then
		self.climate.latitudePoints = {}
		drawCurve = true
	end
	for l = 0, 90 do
		local t, r = self.climate:GetTemperature(l), self.climate:GetRainfall(l)
		if drawCurve then self.climate.latitudePoints[mFloor(t) .. " " .. mFloor(r)] = true end
		local point = self:NearestPoint(t, r)
		if self.isSub then
			local superPoint = self.climate.pointSet.latitudes[l]
			if point.superRegionLatitudeAreas[superPoint.region] == nil then
				point.superRegionLatitudeAreas[superPoint.region] = 0
			end
			point.superRegionLatitudeAreas[superPoint.region] = point.superRegionLatitudeAreas[superPoint.region] + 1
		end
		self.latitudes[l] = point
		point.region.latitudeArea = point.region.latitudeArea + 1
		point.latitudeArea = point.latitudeArea + 1
	end
end

function PointSet:GiveAdjustments()
	if self.haveAdjustments then return end
	for i, point in pairs(self.points) do
		point:GiveAdjustment()
	end
	self.haveAdjustments = true
end

function PointSet:Okay()
	for i, point in pairs(self.points) do
		if not point:Okay() then return end
	end
	return true
end

function PointSet:FillOkay()
	for i, point in pairs(self.points) do
		if not point:FillOkay() then return end
	end
	return true
end

function PointSet:GiveDistance()
	self.distance = 0
	local haveRegion = {}
	local regions = {}
	for i, point in pairs(self.points) do
		if point.region.highT then
			self.distance = self.distance + (100-point.t)
		elseif point.region.lowT then
			self.distance = self.distance + point.t
		end
		if point.region.highR then
			self.distance = self.distance + (100-point.r)
		elseif point.region.lowR then
			self.distance = self.distance + point.r
		end
		if not haveRegion[point.region] then
			if self.isSub then
				point.region.superRegionAreas = {}
				point.region.superRegionLatitudeAreas = {}
			end
			tInsert(regions, point.region)
		end
		if self.isSub then
			for region, area in pairs(point.superRegionAreas) do
				point.region.superRegionAreas[region] = (point.region.superRegionAreas[region] or 0) + area
			end
			for region, area in pairs(point.superRegionLatitudeAreas) do
				point.region.superRegionLatitudeAreas[region] = (point.region.superRegionLatitudeAreas[region] or 0) + area
			end
		end
	end
	for i, region in pairs(regions) do
		self.distance = self.distance + mAbs(region.excessLatitudeArea) * latitudeAreaMutationDistMult
		self.distance = self.distance + mAbs(region.excessArea) * areaMutationDistMult
		if self.isSub then
			local areaAvg, latitudeAreaAvg = 0, 0
			for i, regionName in pairs(region.containedBy) do
				local superRegion = self.climate.regionsByName[regionName]
				areaAvg = areaAvg + region.superRegionAreas[superRegion]
				latitudeAreaAvg = latitudeAreaAvg + region.superRegionLatitudeAreas[superRegion]
			end
			areaAvg = areaAvg / #region.containedBy
			latitudeAreaAvg = latitudeAreaAvg / #region.containedBy
			for i, regionName in pairs(region.containedBy) do
				local superRegion = self.climate.regionsByName[regionName]
				-- print(mAbs(region.superRegionAreas[superRegion] - areaAvg) * areaMutationDistMult, mAbs(region.superRegionLatitudeAreas[superRegion] - latitudeAreaAvg) * latitudeAreaMutationDistMult)
				self.distance = self.distance + mAbs(region.superRegionAreas[superRegion] - areaAvg) * areaMutationDistMult
				self.distance = self.distance + mAbs(region.superRegionLatitudeAreas[superRegion] - latitudeAreaAvg) * latitudeAreaMutationDistMult
			end
		end
	end
end