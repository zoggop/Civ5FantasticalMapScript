require "common"
require "point"

PointSet = class(function(a, climate, parentPointSet)
	a.climate = climate
	a.points = {}
	a.grid = {}
	a.latitudes = {}
	if parentPointSet then
		-- mutation
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
end

function PointSet:NearestPoint(t, r)
	local nearestDist = 20000
	local nearestPoint
	for i, point in pairs(self.points) do
		local dist = point:Dist(t, r)
		if dist < nearestDist then
			nearestDist = dist
			nearestRegion = region
			nearestPoint = point
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

function PointSet:GiveDistance()
	self.distance = 0
	local haveRegion = {}
	local regions = {}
	for i, point in pairs(self.points) do
		if not haveRegion[point.region] then
			tInsert(regions, point.region)
		end
	end
	for i, region in pairs(regions) do
		self.distance = self.distance + mAbs(region.excessLatitudeArea) * latitudeAreaMutationDistMult
		self.distance = self.distance + mAbs(region.excessArea) * areaMutationDistMult
		for ii, point in pairs(region.points) do
			if region.highT then
				self.distance = self.distance + (100-point.t)
			elseif region.lowT then
				self.distance = self.distance + point.t
			end
			if region.highR then
				self.distance = self.distance + (100-point.r)
			elseif region.lowR then
				self.distance = self.distance + point.r
			end
		end
	end
end