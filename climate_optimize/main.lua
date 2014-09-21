local mCeil = math.ceil
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local mAbs = math.abs
local mSqrt = math.sqrt
local mSin = math.sin
local mCos = math.cos
local mPi = math.pi
local mTwicePi = math.pi * 2
local mAtan2 = math.atan2
local tInsert = table.insert
local tRemove = table.remove

local mutationsPerIteration = 1
local mutationSize = 8
local adjustmentIntensity = 2
local areaAdjustmentMultiplier = 1
local highLowMultiplier = 0.01
local areaMutationDistMultiplier = 10

local temperatureMax, temperatureMin = 100, 0
local polarExponent = 1.2
local polarExponentMultiplier = 90 ^ polarExponent
local rainfallMidpoint = 50

local rainfallPlusMinus
if rainfallMidpoint > 50 then
	rainfallPlusMinus = 100 - rainfallMidpoint
else
	rainfallPlusMinus = rainfallMidpoint
end

local nearestString = ""


function GetTemperature(latitude)
	local rise = temperatureMax - temperatureMin
	local distFromPole = (90 - latitude) ^ polarExponent
	temp = (rise / polarExponentMultiplier) * distFromPole + temperatureMin
	return mFloor(temp)
end

function GetRainfall(latitude)
	if latitude > 75 then -- polar
		rain = (rainfallMidpoint/4) + ( (rainfallPlusMinus/4) * (mCos((mPi/15) * (latitude+15))) )
	elseif latitude > 37.5 then -- temperate
		rain = rainfallMidpoint + ((rainfallPlusMinus/2) * mCos(latitude * (mPi/25)))
	else -- tropics and desert
		rain = rainfallMidpoint + (rainfallPlusMinus * mCos(latitude * (mPi/25)))
	end
	return mFloor(rain)
end

local terrainRegions = {
	{ name = "grassland", targetArea = 0.28, highT = true, highR = true,
		points = {
			{t = 100, r = 75},
			{t = 75, r = 100}
		},
		relations = {
			plains = {t = 1, r = 1},
			desert = {n = -1},
			tundra = {n = -1},
		},
		color = {0, 127, 0}
	},
	{ name = "plains", targetArea = 0.25,
		points = {
			{t = 75, r = 50},
			{t = 50, r = 75}
		},
		relations = {
			grassland = {t = -1, r = -1},
			desert = {r = 1},
			tundra = {t = 1} 
		},
		color = {127, 127, 0}
	},
	{ name = "desert", targetArea = 0.2, lowR = true,
		points = {
			{t = 25, r = 0},
			{t = 75, r = 0}
		},
		relations = {
			plains = {r = -1},
			tundra = {t = 1} 
		},
		color = {127, 127, 63}
	},
	{ name = "tundra", targetArea = 0.17, lowT = true,
		points = {
			{t = 0, r = 25},
			{t = 0, r = 75}
		},
		relations = {
			desert = {t = -1},
			plains = {t = -1} 
		},
		color = {63, 63, 63}
	},
	{ name = "snow", targetArea = 0.1, fixed = true, lowT = true, lowR = true,
		points = {
			{t = 0, r = 0}
		},
		relations = {},
		color = {127, 127, 127}
	},
}

local function TempRainDist(t1, r1, t2, r2)
	local tdist = mAbs(t2 - t1)
	local rdist = mAbs(r2 - r1)
	return mSqrt( tdist^2 + rdist^2 )
end

local function NearestRegion(t, r, regions)
	local nearestDist = 20000
	local nearestPoint, nearestRegion
	for i, region in pairs(regions) do
		for ii, point in pairs(region.points) do
			local dist = TempRainDist(point.t, point.r, t, r)
			if dist < nearestDist then
				nearestDist = dist
				nearestRegion = region
				nearestPoint = point
			end
		end
	end
	return nearestRegion, nearestPoint
end

local function FillRegions(regions)
	for i, region in pairs(regions) do
		region.area = 0
		for ii, point in pairs(region.points) do
			point.area = 0
			point.neighbors = {}
			point.lowT, point.highT, point.lowR, point.highR = nil, nil, nil, nil
		end
	end
	local grid = {}
	for t = 0, 100 do
		grid[t] = {}
		for r = 0, 100 do
			local region, point = NearestRegion(t, r, regions)
			grid[t][r] = point
			region.area = region.area + 1
			point.area = point.area + 1
			if t == 0 then point.lowT = true end
			if t == 100 then point.highT = true end
			if r == 0 then point.lowR = true end
			if r == 100 then point.highR = true end
			if grid[t][r-1] and grid[t][r-1] ~= point then
				point.neighbors[grid[t][r-1]] = true
				grid[t][r-1].neighbors[point] = true
			end
			if grid[t-1] then
				if grid[t-1][r+1] and grid[t-1][r+1] ~= point then
					point.neighbors[grid[t-1][r+1]] = true
					grid[t-1][r+1].neighbors[point] = true
				end
				if grid[t-1][r] and grid[t-1][r] ~= point then
					point.neighbors[grid[t-1][r]] = true
					grid[t-1][r].neighbors[point] = true
				end
				if grid[t-1][r-1] and grid[t-1][r-1] ~= point then
					point.neighbors[grid[t-1][r-1]] = true
					grid[t-1][r-1].neighbors[point] = true
				end
			end
		end
	end
	return regions, grid
end

local optLatitudePoints

local function FillRegionsLatitudes(regions)
	for i, region in pairs(regions) do
		region.latitudeArea = 0
		for ii, point in pairs(region.points) do
			point.latitudeArea = 0
		end
	end
	local latitudes = {}
	optLatitudePoints = {}
	for l = 0, 90 do
		local t, r = GetTemperature(l), GetRainfall(l)
		optLatitudePoints[mFloor(t) .. " " .. mFloor(r)] = true
		local region, point = NearestRegion(t, r, regions)
		latitudes[l] = point
		region.latitudeArea = region.latitudeArea + 1
		point.latitudeArea = point.latitudeArea + 1
	end
	return regions, latitudes
end

local function MutateRegions(regions)
	local mutations = {}
	for m = 1, mutationsPerIteration do
		local mRegions = {}
		for i, region in pairs(regions) do
			if region.fixed then
				tInsert(mRegions, region)
			else
				local mRegion = { name = region.name, targetArea = region.targetArea, highT = region.highT, lowT = region.lowT, highR = region.highR, lowR = region.lowR, relations = region.relations, color = region.color, points = {} }
				for ii, point in pairs(region.points) do
					local mPoint = {}
					mPoint.t = mFloor( point.t + point.tMove + math.random(-mutationSize, mutationSize) )
					mPoint.r = mFloor( point.r + point.rMove + math.random(-mutationSize, mutationSize) )
					mPoint.t = mMax(0, mMin(100, mPoint.t))
					mPoint.r = mMax(0, mMin(100, mPoint.r))
					tInsert(mRegion.points, mPoint)
				end
				tInsert(mRegions, mRegion)
			end
		end
		tInsert(mutations, mRegions)
	end
	return mutations
end

local function CheckPoints(region, regionsByName)
	for i, point in pairs(region.points) do
		if not region.lowT and point.lowT then return end
		-- if not region.highT and point.highT then return end
		-- if not region.lowR and point.lowR then return end
		-- if not region.highR and point.highR then return end
		for regionName, relation in pairs(region.relations) do
			local relatedRegion = regionsByName[regionName]
			if relatedRegion then
				for ii, rPoint in pairs(relatedRegion.points) do
					if relation.t == -1 then
						if point.t >= rPoint.t then return end
					elseif relation.t == 1 then
						if point.t <= rPoint.t then return end
					end
					if relation.r == -1 then
						if point.r >= rPoint.r then return end
					elseif relation.r == 1 then
						if point.r <= rPoint.r then return end
					end
					if relation.n == -1 then
						if point.neighbors[rPoint] then return end
					elseif relation.n == 1 then
						if not point.neighbors[rPoint] then return end
					end
				end
			end
		end
	end
	return true
end

local function CheckRegionsPoints(regions, regionsByName)
	for i, region in pairs(regions) do
		if not CheckPoints(region, regionsByName) then
			return false
		end	
	end
	return true
end

local function TempMovePoint(point, tempMove)
	point.tMove = point.tMove + tempMove
	point.tMoveCount = point.tMoveCount + 1
	return point
end

local function RainMovePoint(point, rainMove)
	point.rMove = point.rMove + rainMove
	point.rMoveCount = point.rMoveCount + 1
	return point
end

local function MutationDistance(regions)
	local dist = 0
	for i, region in pairs(regions) do
		region.excessArea = region.latitudeArea - (region.targetArea * 90)
		dist = dist + mAbs(region.excessArea) * areaMutationDistMultiplier
		for ii, point in pairs(region.points) do
			if region.highT then
				dist = dist + (100-point.t)
			elseif region.lowT then
				dist = dist + point.t
			end
			if region.highR then
				dist = dist + (100-point.r)
			elseif region.lowR then
				dist = dist + point.r
			end
		end
	end
	return dist
end

local function PrepareRegions(regions)
	local regionsByName = {}
	for i, region in pairs(regions) do
		for ii, point in pairs(region.points) do
			point.region = region
		end
		regionsByName[region.name] = region
	end
	return regions, regionsByName
end

local function OptimizeRegions(regions, iterations)
	for i = 1, iterations do
		local grid, latitudes
		regions, regionsByName = PrepareRegions(regions)
		regions, grid = FillRegions(regions)
		regions, latitudes = FillRegionsLatitudes(regions)
		for ii, region in pairs(regions) do
			region.excessArea = region.latitudeArea - (region.targetArea * 90)
		end
		for ii, region in pairs(regions) do
			if not region.fixed then
				for iii, point in pairs(region.points) do
					point.tMove, point.rMove, point.tMoveCount, point.rMoveCount = 0, 0, 0, 0
					local neighCount = 0
					for neighbor, yes in pairs(point.neighbors) do
						if neighbor.region ~= region then
							local dt = neighbor.t - point.t
							local dr = neighbor.r - point.r
							local da = (neighbor.region.excessArea) / 90
							if neighbor.region.excessArea > 0 and neighbor.latitudeArea > 0 then 
								da = da * (neighbor.latitudeArea / neighbor.region.latitudeArea)
							elseif neighbor.region.excessArea < 0 or neighbor.latitudeArea == 0 then
								da = da * ((neighbor.region.latitudeArea - neighbor.latitudeArea) / neighbor.region.latitudeArea)
							end
							point = TempMovePoint(point, (dt * areaAdjustmentMultiplier) * da)
							point = RainMovePoint(point, (dr * areaAdjustmentMultiplier) * da)
							neighCount = neighCount + 1
						end
					end
					if region.highT then
						point = TempMovePoint(point, (100-point.t)*highLowMultiplier)
					elseif region.lowT then
						point = TempMovePoint(point, (0-point.t)*highLowMultiplier)
					end
					if region.highR then
						point = RainMovePoint(point, (100-point.r)*highLowMultiplier)
					elseif region.lowR then
						point = RainMovePoint(point, (0-point.r)*highLowMultiplier)
					end
					point.tMove = (point.tMove / point.tMoveCount) * adjustmentIntensity
					point.rMove = (point.rMove / point.rMoveCount) * adjustmentIntensity
				end
			end
		end
		local regionsMutations = MutateRegions(regions)
		local okayMutations = {}
		for ii, mRegions in pairs(regionsMutations) do
			local mGrid, mLatitudes, regionsByName
			mRegions, regionsByName = PrepareRegions(mRegions)
			mRegions, mGrid = FillRegions(mRegions)
			mRegions, mLatitudes = FillRegionsLatitudes(mRegions)
			if CheckRegionsPoints(mRegions, regionsByName) then
				tInsert(okayMutations, mRegions)
			end
		end
		local nearestDist = lastDist
		local nearest
		for ii, mRegions in pairs(okayMutations) do
			local dist = MutationDistance(mRegions)
			if not nearestDist or dist < nearestDist then
				nearestDist = dist
				nearest = mRegions
			end
		end
		nearestString = tostring(#okayMutations) .. " " .. tostring(#regionsMutations) .. " " .. tostring(nearest) .. " " .. tostring(nearestDist) .. " " .. tostring(lastDist)
		lastDist = nearestDist or lastDist
		regions = nearest or regions
	end
	return regions
end

local optGrid = {}
local optRegions = PrepareRegions(terrainRegions)
optRegions, optGrid = FillRegions(optRegions)
local iterations = 0
local lastDist

function love.load()
    love.window.setMode(600, 600, {resizable=false, vsync=false})
end

function love.mousereleased(x, y, button)
   if button == 'l' then
   		local output = ""
	   for i, region in pairs(optRegions) do
	   		output = output .. region.name .. "\n"
	   		for ii, point in pairs(region.points) do
	   			output = output .. point.t .. "," .. point.r .. "\n"
	   		end
	   		output = output .. "\n"
	   end
	   love.system.setClipboardText( output )
   elseif button == 'r' then
   		optRegions = OptimizeRegions(terrainRegions, 1)
   		iterations = 1
   		lastDist = nil
   end
   optRegions = PrepareRegions(optRegions)
   optRegions, optGrid = FillRegions(optRegions)
   love.window.setTitle( tostring(iterations) )
end

function love.draw()
	for t, rains in pairs(optGrid) do
		for r, point in pairs(rains) do
			if optLatitudePoints[t .. " " .. r] then
				love.graphics.setColor( 127, 0, 0 )
				love.graphics.rectangle("fill", t*5, 500-r*5, 5, 5)
			else
				love.graphics.setColor( point.region.color )
				love.graphics.rectangle("fill", t*5, 500-r*5, 5, 5)
			end
		end
	end
	love.graphics.setColor( 255, 255, 255 )
	for i, region in pairs(optRegions) do
		for ii, point in pairs(region.points) do
			love.graphics.print(region.name .. "\n" .. (region.latitudeArea or "nil") .. "/" .. mFloor(region.targetArea*90) .. ", " .. (point.latitudeArea or "nil") .. "\n" .. (region.area or "nil") .. ", " .. (point.area or "nil") .. "\n" .. point.t .. "," .. point.r .. "\n" .. mFloor(point.tMove or 0) .. "," .. mFloor(point.rMove or 0), point.t*5, 500-point.r*5)
		end
	end
	love.graphics.setColor(255, 0, 0)
	love.graphics.print(nearestString, 10, 570)
end

function love.update(dt)
	optRegions = OptimizeRegions(optRegions, 1)
   	iterations = iterations + 1
   	optRegions = PrepareRegions(optRegions)
   optRegions, optGrid = FillRegions(optRegions)
   optRegions, optLatitudes = FillRegionsLatitudes(optRegions)
   love.window.setTitle( tostring(iterations) )
end