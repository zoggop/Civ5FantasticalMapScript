require "common"
require "point"

PointSet = class(function(a, climate, parentPointSet, isSub)
	a.climate = climate
	a.isSub = isSub
	a.points = {}
	a.grid = {}
	a.latitudes = {}
	a.generation = 0
	a.unmutatedPoints = {}
	if parentPointSet then
		-- mutation
		a.isSub = parentPointSet.isSub
		a.generation = parentPointSet.generation + 1
		-- for i, parentPoint in pairs(parentPointSet.points) do
		local parentPoint
		local i = 0
		repeat
			if #parentPointSet.unmutatedPoints == 0 then
				parentPointSet.unmutatedPoints = tDuplicate(parentPointSet.points)
			end
			parentPoint = tRemoveRandom(parentPointSet.unmutatedPoints)
			i = i + 1
		until parentPoint:Okay()
			local point = Point(parentPoint.region, nil, nil, parentPoint)
			tInsert(a.points, point)
			point:ResetFillState()
			point.pointSet = a
			point.isSub = a.isSub
			if point.region.name == "none" then a.defaultPoint = point end
		-- end
		for i, pp in pairs(parentPointSet.points) do
			if pp ~= parentPoint then
				local point = Point(pp.region, nil, nil, pp, true)
				tInsert(a.points, point)
				point:ResetFillState()
				point.pointSet = a
				point.isSub = a.isSub
				if point.region.name == "none" then a.defaultPoint = point end
			end
		end
	end
end)

function PointSet:AddPoint(point)
	tInsert(self.points, point)
	point:ResetFillState()
	point.pointSet = self
	point.isSub = self.isSub
	if point.region.name == "none" then self.defaultPoint = point end
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
			nearestPoint = self.defaultPoint
		end
	end
	return nearestPoint
end

function PointSet:Fill()
	-- if self.filled then return false end
	for i, point in pairs(self.points) do point:ResetFillState() end
	self:FillLatitudes()
	self:FillGrid()
	-- self.filled = true
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
				point.superRegionAreas[superPoint.region] = (point.superRegionAreas[superPoint.region] or 0) + 1
				point.region.superRegionAreas[superPoint.region] = (point.region.superRegionAreas[superPoint.region] or 0) + 1
			end
			self.grid[t][r] = point
			point.region.area = point.region.area + 1
			point.area = point.area + 1
			if t == 0 then point.lowT = true end
			if t == 100 then point.highT = true end
			if r == 0 then point.lowR = true end
			if r == 100 then point.highR = true end
			if t > point.maxT then point.maxT = t end
			if t < point.minT then point.minT = t end
			if r > point.maxR then point.maxR = r end
			if r < point.minR then point.minR = r end
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
	for string, values in pairs(self.climate.latitudePoints) do
		local l, t, r = values.l, values.t, values.r
		local point = self:NearestPoint(t, r)
		if self.isSub then
			local superPoint = self.climate.pointSet.latitudes[l]
			point.superRegionLatitudeAreas[superPoint.region] = (point.superRegionLatitudeAreas[superPoint.region] or 0) + 1
			point.region.superRegionLatitudeAreas[superPoint.region] = (point.region.superRegionLatitudeAreas[superPoint.region] or 0) + 1
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
		local okay, problem = point:Okay()
		if not okay then
			-- print(point.region.name, point.t, point.r, problem)
			return
		end
	end
	return true
end

function PointSet:FillOkay()
	for i, point in pairs(self.points) do
		local okay, problem = point:FillOkay()
		if not okay then
			-- print(point.region.name, point.t, point.r, problem)
			return
		end
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
			tInsert(regions, point.region)
		end
	end
	for i, region in pairs(regions) do
		self.distance = self.distance + mAbs(region.excessLatitudeArea) * latitudeAreaMutationDistMult
		self.distance = self.distance + mAbs(region.excessArea) * areaMutationDistMult
		-- penalize uneven distribution of features across multiple terrains
		if self.isSub then
			local areaAvg, latitudeAreaAvg = 0, 0
			for i, regionName in pairs(region.containedBy) do
				local superRegion = self.climate.regionsByName[regionName]
				areaAvg = areaAvg + (region.superRegionAreas[superRegion] or 0)
				latitudeAreaAvg = latitudeAreaAvg + (region.superRegionLatitudeAreas[superRegion] or 0)
			end
			if areaAvg > 0 and #region.containedBy > 0 then
				areaAvg = areaAvg / #region.containedBy
			else
				latitudeAreaAvg = 0
			end
			if latitudeAreaAvg > 0 and #region.containedBy > 0 then
				latitudeAreaAvg = latitudeAreaAvg / #region.containedBy
			else
				latitudeAreaAvg = 0
			end
			for i, regionName in pairs(region.containedBy) do
				local superRegion = self.climate.regionsByName[regionName]
				-- print(mAbs(region.superRegionAreas[superRegion] - areaAvg) * areaMutationDistMult, mAbs(region.superRegionLatitudeAreas[superRegion] - latitudeAreaAvg) * latitudeAreaMutationDistMult)
				self.distance = self.distance + mAbs((region.superRegionAreas[superRegion] or 0) - areaAvg) * areaMutationDistMult
				self.distance = self.distance + mAbs((region.superRegionLatitudeAreas[superRegion] or 0) - latitudeAreaAvg) * latitudeAreaMutationDistMult
			end
		end
	end
end