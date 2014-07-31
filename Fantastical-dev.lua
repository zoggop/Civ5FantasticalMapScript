-- Map Script: Fantastical
-- Author: zoggop
-- version 1

--------------------------------------------------------------
if include == nil then
	package.path = package.path..';C:\\Program Files (x86)\\Steam\\steamapps\\common\\Sid Meier\'s Civilization V\\Assets\\Gameplay\\Lua\\?.lua'
	include = require
end
include("math")
include("bit")
include("MapGenerator")
----------------------------------------------------------------------------------

local debugEnabled = true
local function EchoDebug(...)
	if debugEnabled then
		local printResult = ""
		for i,v in ipairs(arg) do
			printResult = printResult .. tostring(v) .. "\t"
		end
		print(printResult)
	end
end

------------------------------------------------------------------------------

local mCeil = math.ceil
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local mAbs = math.abs
local mSqrt = math.sqrt
local mSin = math.sin
local mCos = math.cos
local mPi = math.pi
local tInsert = table.insert
local tRemove = table.remove

------------------------------------------------------------------------------

local randomNumbers = 0

local function mRandom(lower, upper)
	local divide = false
	if lower == nil then lower = 0 end
	if upper == nil then
		divide = true
		upper = 1000
	end
	local number = 1
	if upper == lower or lower > upper then
		number = lower
	else
		randomNumbers = randomNumbers + 1
		number = Map.Rand((upper + 1) - lower, "Fantastical Map Script " .. randomNumbers) + lower
	end
	if divide then number = number / upper end
	return number
end

local function tRemoveRandom(fromTable)
	return tRemove(fromTable, mRandom(1, #fromTable))
end

local function tGetRandom(fromTable)
	return fromTable[mRandom(1, #fromTable)]
end

local function tDuplicate(sourceTable)
	local duplicate = {}
	for k, v in pairs(sourceTable) do
		tInsert(duplicate, v)
	end
	return duplicate
end

local function diceRoll(dice, maximum, invert)
	if invert == nil then invert = false end
	if maximum == nil then maximum = 1.0 end
	local n = 0
	for d = 1, dice do
		n = n + (mRandom() / dice)
	end
	if invert == true then
		if n >= 0.5 then n = n - 0.5 else n = n + 0.5 end
	end
	n = n * maximum
	return n
end

------------------------------------------------------------------------------

-- Compatible with Lua 5.1 (not 5.0).
function class(base, init)
   local c = {}    -- a new class instance
   if not init and type(base) == 'function' then
      init = base
      base = nil
   elseif type(base) == 'table' then
    -- our new class is a shallow copy of the base class!
      for i,v in pairs(base) do
         c[i] = v
      end
      c._base = base
   end
   -- the class will be the metatable for all its objects,
   -- and they will look up their methods in it.
   c.__index = c

   -- expose a constructor which can be called by <classname>(<args>)
   local mt = {}
   mt.__call = function(class_tbl, ...)
   local obj = {}
   setmetatable(obj,c)
   if init then
      init(obj,...)
   else 
      -- make sure that any stuff from the base class is initialized!
      if base and base.init then
      base.init(obj, ...)
      end
   end
   return obj
   end
   c.init = init
   c.is_a = function(self, klass)
      local m = getmetatable(self)
      while m do 
         if m == klass then return true end
         m = m._base
      end
      return false
   end
   setmetatable(c, mt)
   return c
end

------------------------------------------------------------------------------

-- so that these constants can be shorter to access and consistent
local plotOcean, plotLand, plotHills, plotMountain
local terrainOcean, terrainCoast, terrainGrass, terrainPlains, terrainDesert, terrainTundra, terrainSnow
local featureForest, featureJungle, featureIce, featureMarsh, featureOasis, featureFallout, featureAtoll
local TerrainDictionary, FeatureDictionary

local function SetConstants()
	plotOcean = PlotTypes.PLOT_OCEAN
	plotLand = PlotTypes.PLOT_LAND
	plotHills = PlotTypes.PLOT_HILLS
	plotMountain = PlotTypes.PLOT_MOUNTAIN

	terrainOcean = TerrainTypes.TERRAIN_OCEAN
	terrainCoast = TerrainTypes.TERRAIN_COAST
	terrainGrass = TerrainTypes.TERRAIN_GRASS
	terrainPlains = TerrainTypes.TERRAIN_PLAINS
	terrainDesert = TerrainTypes.TERRAIN_DESERT
	terrainTundra = TerrainTypes.TERRAIN_TUNDRA
	terrainSnow = TerrainTypes.TERRAIN_SNOW

	featureNone = FeatureTypes.NO_FEATURE
	featureForest = FeatureTypes.FEATURE_FOREST
	featureJungle = FeatureTypes.FEATURE_JUNGLE
	featureIce = FeatureTypes.FEATURE_ICE
	featureMarsh = FeatureTypes.FEATURE_MARSH
	featureOasis = FeatureTypes.FEATURE_OASIS
	featureFallout = FeatureTypes.FEATURE_FALLOUT

	for thisFeature in GameInfo.Features() do
		if thisFeature.Type == "FEATURE_ATOLL" then
			featureAtoll = thisFeature.ID
		end
	end

	-- in temperature and rainfall, first number is minimum, seecond is maximum, third is midpoint (optional: it defaults to the average of min and max)

	TerrainDictionary = {
		[terrainGrass] = { temperature = {40, 100}, rainfall = {20, 100, 60}, features = { featureNone, featureForest, featureJungle, featureMarsh, featureFallout } },
		[terrainPlains] = { temperature = {30, 60}, rainfall = {20, 100, 40}, features = { featureNone, featureForest, featureFallout } },
		[terrainDesert] = { temperature = {25, 100}, rainfall = {0, 20, 0}, features = { featureNone, featureOasis, featureFallout } },
		[terrainTundra] = { temperature = {0, 30, 5}, rainfall = {20, 100, 25}, features = { featureNone, featureForest, featureFallout } },
		[terrainSnow] = { temperature = {0, 30, 0}, rainfall = {0, 20, 0}, features = { featureNone, featureFallout } },
	}

	-- percent is how likely it is to show up in a region's collection (if it's the closest rainfall and temperature)
	-- limitRatio is what fraction of a region's hexes may have this feature (-1 is no limit)

	FeatureDictionary = {
		[featureNone] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 100, limitRatio = -1, hill = true },
		[featureForest] = { temperature = {15, 85, 35}, rainfall = {70, 100}, percent = 100, limitRatio = 0.85, hill = true },
		[featureJungle] = { temperature = {85, 100}, rainfall = {75, 100}, percent = 100, limitRatio = 0.85, hill = true, terrainType = terrainPlains },
		[featureMarsh] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 10, limitRatio = 0.33, hill = false },
		[featureOasis] = { temperature = {50, 100}, rainfall = {0, 100}, percent = 25, limitRatio = 0.02, hill = false },
		[featureFallout] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 15, limitRatio = 0.75, hill = true },
	}

	-- doing it this way just so the declarations above are shorter
	for terrainType, terrain in pairs(TerrainDictionary) do
		if terrain.terrainType == nil then terrain.terrainType = terrainType end
	end
	for featureType, feature in pairs(FeatureDictionary) do
		if feature.featureType == nil then feature.featureType = featureType end
	end
end

------------------------------------------------------------------------------

Hex = class(function(a, space, x, y, index)
	a.space = space
	a.index = index
	a.x, a.y = x, y
	a.edginess = 0
	a.adjacentPolygons = {}
	a.adjacentPolyCount = 0
	a.edgeWith = {}
end)

function Hex:Place(relax)
	local polygon = self:ClosestPolygon(relax)
	self.space.hexes[self.index] = self
	tInsert(polygon.hexes, self)
	polygon.area = polygon.area + 1
	if self.x < polygon.minX then polygon.minX = self.x end
	if self.y < polygon.minY then polygon.minY = self.y end
	if self.x > polygon.maxX then polygon.maxX = self.x end
	if self.y > polygon.maxY then polygon.maxY = self.y end
	if not relax then
		self.plot = Map.GetPlotByIndex(self.index-1)
		self.latitude = self.plot:GetLatitude()
		polygon:CheckBottomTop(self.x, self.y)
	end
	if self.polygon and not relax then
		self.subPolygon = polygon
	else
		self.polygon = polygon
	end
end

function Hex:Adjacent(direction)
	local x, y = self.x, self.y
	if direction == 0 or direction == nil then return hex end
	local nx = x
	local ny = y
	local odd = y % 2
	if direction == 1 then
		nx = x - 1
	elseif direction == 2 then
		nx = x - 1 + odd
		ny = y + 1
	elseif direction == 3 then
		nx = x + odd
		ny = y + 1
	elseif direction == 4 then
		nx = x + 1
	elseif direction == 5 then
		nx = x + odd
		ny = y - 1
	elseif direction == 6 then
		nx = x - 1 + odd
		ny = y - 1
	end
	if self.space.wrapX then
		if nx > self.space.w then nx = 0 elseif nx < 0 then nx = self.space.w end
	else
		if nx > self.space.w then nx = self.space.w elseif nx < 0 then nx = 0 end
	end
	if self.space.wrapY then
		if ny > self.space.h then ny = 0 elseif ny < 0 then ny = self.space.h end
	else
		if ny > self.space.h then ny = self.space.h elseif ny < 0 then ny = 0 end
	end
	local nhex = self.space:GetHexByXY(nx, ny)
	if nhex ~= self then return nhex end
end

function Hex:Neighbors(directions)
	if directions == nil then directions = { 1, 2, 3, 4, 5, 6 } end
	local neighbors = {}
	for i, direction in pairs(directions) do
		local nhex = self:Adjacent(direction)
		if nhex ~= nil then tInsert(neighbors, nhex) end
	end
	return neighbors
end

function Hex:ClosestPolygon(relax)
	local dists = {}
	local closest_distance = 0
	local closest_polygon
	-- find the closest point to this point
	local somePolygons
	if self.polygon and not relax then
		somePolygons = self.polygon.subPolygons
	else
		somePolygons = self.space.polygons
	end
	for i = 1, #somePolygons do
		local polygon = somePolygons[i]
		dists[i] = self.space:EucDistance(polygon.x, polygon.y, self.x, self.y)
		if i == 1 or dists[i] < closest_distance then
			closest_distance = dists[i]
			closest_polygon = polygon
		end
	end
	return closest_polygon
end

function Hex:ComputeNeighbors()
	for ni, nhex in pairs(self:Neighbors()) do -- 3 and 4 are are never there yet
		if nhex.polygon ~= self.polygon then
			self.polygon:SetNeighbor(nhex.polygon)
			if not self.edgeWith[nhex] then
				self.edginess = self.edginess + 1
				self.edgeWith[nhex] = true
			end
			if not self.adjacentPolygons[nhex.polygon] then
				self.adjacentPolyCount = self.adjacentPolyCount + 1
				self.adjacentPolygons[nhex.polygon] = true
				if self.adjacentPolyCount == 2 then tInsert(self.polygon.vertices, self) end
			end
			if self.polygon.edges[nhex.polygon] then
				tInsert(self.polygon.edges[nhex.polygon].hexes, self)
			else
				local edge = { polygons = { self.polygon, nhex.polygon }, hexes = { self }, connections = {} }
				self.polygon.edges[nhex.polygon] = edge
				nhex.polygon.edges[self.polygon] = edge
				tInsert(self.space.edges, edge)
			end
		end
		if nhex.subPolygon ~= self.subPolygon then
			self.subPolygon:SetNeighbor(nhex.subPolygon)
		end
	end
end

function Hex:ComputeAdjacentSuperPolygons()
	for ni, nhex in pairs(self:Neighbors()) do
		if nhex.polygon ~= self.polygon then
			if not self.subPolygon.adjacentSuperPolygons[nhex.polygon] then
				self.subPolygon.adjacentSuperPolygons[nhex.polygon] = true
			end
		end
	end
end

function Hex:SetPlot()
	if self.plot == nil then return end
	self.plot:SetPlotType(self.plotType)
end

function Hex:SetTerrain()
	if self.plot == nil then return end
	self.plot:SetTerrainType(self.terrainType, false, false)
end

function Hex:SetFeature()
	if self.featureType == nil then return end
	if self.plot == nil then return end
	self.plot:SetFeatureType(self.featureType)
end

------------------------------------------------------------------------------

Polygon = class(function(a, space, x, y, superPolygon)
	a.space = space
	a.x = x or Map.Rand(space.iW, "random x")
	a.y = y or Map.Rand(space.iH, "random y")
	if space.useMapLatitudes then
		local plot = Map.GetPlot(x, y)
		a.latitude = plot:GetLatitude()
	end
	a.subPolygons = {}
	a.hexes = {}
	a.edges = {}
	a.vertices = {}
	a.isNeighbor = {}
	a.area = 0
	a.minX = space.w
	a.maxX = 0
	a.minY = space.h
	a.maxY = 0
	-- randomize coastal expansion dice a bit
	a.coastExpansionDice = {}
	for i = 1, space.coastDiceAmount do
		tInsert(a.coastExpansionDice, mRandom(space.coastDiceMin, space.coastDiceMax))
	end
end)

function Polygon:FloodFillAstronomy(astronomyIndex)
	if self.oceanIndex or self.nearOcean then
		self.astronomyIndex = (self.oceanIndex or 100) + 10
		-- if self.space.astronomyBasins[self.astronomyIndex] == nil then self.space.astronomyBasins[self.astronomyIndex] = {} end
		-- tInsert(self.space.astronomyBasins[self.astronomyIndex], self)
		return nil
	end
	if self.astronomyIndex then return nil end
	self.astronomyIndex = astronomyIndex
	if self.space.astronomyBasins[astronomyIndex] == nil then self.space.astronomyBasins[astronomyIndex] = {} end
	tInsert(self.space.astronomyBasins[astronomyIndex], self)
	for i, neighbor in pairs(self.neighbors) do
		neighbor:FloodFillAstronomy(astronomyIndex)
	end
	return true
end

function Polygon:SetNeighbor(polygon2)
	self.isNeighbor[polygon2] = true
	polygon2.isNeighbor[self] = true
end

function Polygon:RelaxToCentroid()
	local space = self.space
	if #self.hexes ~= 0 then
		local totalX, totalY = 0, 0
		for i, hex in pairs(self.hexes) do
			local x, y = hex.x, hex.y
			if space.wrapX then
				local xdist = mAbs(x - self.minX)
				if xdist > space.halfWidth then x = x - space.w end
			end
			if space.wrapY then
				local ydist = mAbs(y - self.minY)
				if ydist > space.halfHeight then y = y - space.h end
			end
			totalX = totalX + x
			totalY = totalY + y
		end
		local centroidX = mCeil(totalX / #self.hexes)
		if centroidX < 0 then centroidX = space.w + centroidX end
		local centroidY = mCeil(totalY / #self.hexes)
		if centroidY < 0 then centroidY = space.h + centroidY end
		self.x, self.y = centroidX, centroidY
		if self.space.useMapLatitudes then self.latitude = Map.GetPlot(self.x, self.y):GetLatitude() end
	end
	self.area = 0
	self.minX, self.minY, self.maxX, self.maxY = space.w, space.h, 0, 0
	self.hexes = {}
end

function Polygon:CheckBottomTop(x, y)
	local space = self.space
	if y == 0 and self.y < space.halfHeight then
		self.bottomY = true
		tInsert(space.bottomYPolygons, self)
	end
	if x == 0 and self.x < space.halfWidth then
		self.bottomX = true
		tInsert(space.bottomXPolygons, self)
	end
	if y == space.h and self.y >= space.halfHeight then
		self.topY = true
		tInsert(space.topYPolygons, self)
	end
	if x == space.w and self.x >= space.halfWidth then
		self.topX = true
		tInsert(space.topXPolygons, self)
	end
end

function Polygon:NearOther(value, key)
	if key == nil then key = "continentIndex" end
	for ni, neighbor in pairs (self.neighbors) do
		if neighbor[key] ~= nil and neighbor[key] ~= value then
			return true
		end
	end
	return false
end

function Polygon:Subdivide()
	local hexBuffer = tDuplicate(self.hexes)
	for n = 1, self.space.subPolygonCount do
		if #hexBuffer == 0 then break end
		local hex = tRemoveRandom(hexBuffer)
		local subPolygon = Polygon(self.space, hex.x, hex.y, self)
		subPolygon.superPolygon = self
		subPolygon.adjacentSuperPolygons = {}
		tInsert(self.subPolygons, subPolygon)
	end
	for h, hex in pairs(self.hexes) do
		hex:Place()
	end
	-- compute neighbors
	for h, hex in pairs(self.hexes) do
		hex:ComputeAdjacentSuperPolygons()
	end
	-- pick off edge subpolygons at random, and populate subpolygon tables
	-- and create neighbor tables
	for i = #self.subPolygons, 1, -1 do
		local subPolygon = self.subPolygons[i]
		if #subPolygon.hexes > 0 then
			if #self.subPolygons > 1 and not subPolygon.deserter then
				local adjacent = {}
				for polygon, yes in pairs(subPolygon.adjacentSuperPolygons) do
					tInsert(adjacent, polygon)
				end
				if #adjacent > 0 and mRandom(1, 100) < self.space.subPolygonDesertionPercent then
					subPolygon.superPolygon = tGetRandom(adjacent)
					subPolygon.deserter = true
					--[[
					subPolygon.adjacentSuperPolygons[subPolygon.superPolygon] = nil
					subPolygon.adjacentSuperPolygons[self] = true
					]]--
					tInsert(subPolygon.superPolygon.subPolygons, subPolygon)
					tRemove(self.subPolygons, i)
				end
			end
			tInsert(self.space.subPolygons, subPolygon)
			if #subPolygon.hexes > self.space.biggestSubPolygon then
				self.space.biggestSubPolygon = #subPolygon.hexes
			elseif #subPolygon.hexes < self.space.smallestSubPolygon then
				self.space.smallestSubPolygon = #subPolygon.hexes
			end
		else
			tRemove(self.subPolygons, i)
		end
	end
	-- remove hexes that are no longer inside this pseudopolygon
	-- and move them to the correct polygon
	for i = #self.hexes, 1, -1 do
		local hex = self.hexes[i]
		if hex.subPolygon.superPolygon ~= self then
			hex.polygon = hex.subPolygon.superPolygon
			self.area = self.area - 1
			hex.polygon.area = hex.polygon.area + 1
			tInsert(hex.polygon.hexes, hex)
			tRemove(self.hexes, i)
		end
	end
end

function Polygon:PostProcess()
	self.neighbors = {}
	for neighbor, yes in pairs(self.isNeighbor) do
		tInsert(self.neighbors, neighbor)
	end
end

function Polygon:PickTinyIslands()
	for i, subPolygon in pairs(self.subPolygons) do
		local tooCloseForIsland = false
		if not tooCloseForIsland then
			for i, neighbor in pairs(subPolygon.neighbors) do
				if neighbor.superPolygon.continentIndex or neighbor.superPolygon.oceanIndex or neighbor.tinyIsland then
					tooCloseForIsland = true
					break
				end
			end
		end
		if not tooCloseForIsland and (Map.Rand(100, "tiny island chance") <= self.space.tinyIslandChance or (self.loneCoastal and not self.hasTinyIslands)) then
			subPolygon.tinyIsland = true
			self.hasTinyIslands = true
		end
	end
end

------------------------------------------------------------------------------

Region = class(function(a, space)
	a.space = space
	a.collection = {}
	a.polygons = {}
	a.area = 0
	a.hillCount = 0
	a.mountainCount = 0
	a.lakeCount = 0
	a.featureFillCounts = {}
	for featureType, feature in pairs(FeatureDictionary) do
		a.featureFillCounts[featureType] = 0
	end
end)

function Region:CreateCollection()
	-- get latitude (real or fake)
	self.latitude = self:GetLatitude()
	-- get temperature, rainfall, hillyness, mountainousness, lakeyness
	self.temperatureAvg, self.temperatureMin, self.temperatureMax = self.space:GetTemperature(self.latitude)
	self.rainfallAvg, self.rainfallMin, self.rainfallMax = self.space:GetRainfall(self.latitude)
	self.hillyness = self.space:GetHillyness()
	self.mountainous = mRandom(1, 100) < self.space.mountainousRegionPercent
	self.mountainousness = 0
	if self.mountainous then self.mountainousness = mRandom(self.space.mountainousnessMin, self.space.mountainousnessMax) end
	self.lakey = mRandom(1, 100) < self.space.lakeRegionPercent
	self.lakeyness = 0
	if self.lakey then self.lakeyness = mRandom(self.space.lakeynessMin, self.space.lakeynessMax) end
	EchoDebug(self.latitude, self.temperatureMin, self.temperatureMax, self.rainfallMin, self.rainfallMax, self.mountainousness, self.lakeyness, self.hillyness)
	-- create the collection
	self.size, self.subSize = self.space:GetCollectionSize()
	local subPolys = 0
	for i, polygon in pairs(self.polygons) do
		subPolys = subPolys + #polygon.subPolygons
	end
	self.size = mMin(self.size, subPolys) -- make sure there aren't more collections than subpolygons in the region
	self.totalSize = self.size * self.subSize
	local tempList = {}
	local tInc = (self.temperatureMax - self.temperatureMin) / (self.size - 1)
	for i = 0, self.size-1 do
		local temperature = self.temperatureMin + (tInc * i)
		tInsert(tempList, temperature)
	end
	local rainList = {}
	local rInc = (self.rainfallMax - self.rainfallMin) / (self.size - 1)
	for i = 0, self.size-1 do
		local rainfall = self.rainfallMin + (rInc * i)
		tInsert(rainList, rainfall)
	end
	for i = 1, self.size do
		local lake = mRandom(1, 100) < self.lakeyness
		local temperature = tRemoveRandom(tempList)
		local rainfall = tRemoveRandom(rainList)
		local subCollection = {}
		for si = 1, self.subSize do
			tInsert(subCollection, self:CreateElement(temperature, rainfall, lake))
		end
		tInsert(self.collection, subCollection)
	end
end

function Region:GetLatitude()
	local polygon = tGetRandom(self.polygons)
	return polygon.latitude
	--[[
	local latSum = 0
	for i, polygon in pairs(self.polygons) do
		latSum = latSum + polygon.latitude
	end
	return mFloor(latSum / #self.polygons)
	]]--
end

function Region:WithinBounds(thing, temperature, rainfall)
	temperature = mFloor(temperature)
	rainfall = mFloor(rainfall)
	if temperature < thing.temperature[1] then return false end
	if temperature > thing.temperature[2] then return false end
	if rainfall < thing.rainfall[1] then return false end
	if rainfall > thing.rainfall[2] then return false end
	return true
end

function Region:BoundsDistance(bounds, value)
	local min, max, mid = bounds[1], bounds[2], bounds[3]
	if value >= min and value <= max then
		mid = mid or (min + max) / 2
		return mAbs(value - mid)
	else
		if value > max then return 100 + (value - max) end
		if value < min then return 100 + (min - value) end
	end
end

function Region:TemperatureRainfallDistance(thing, temperature, rainfall)
	local tdist = self:BoundsDistance(thing.temperature, temperature)
	local rdist = self:BoundsDistance(thing.rainfall, rainfall)
	return mSqrt(tdist^2 + rdist^2)
	-- return tdist + rdist
end

function Region:CreateElement(temperature, rainfall, lake)
	temprature = temprature or mRandom(self.temperatureMin, self.temperatureMax)
	rainfall = rainfall or mRandom(self.rainfallMin, self.rainfallMax)
	local mountain = mRandom(1, 100) < self.mountainousness
	local hill = mRandom(1, 100) < self.hillyness
	if hill then
		temperature = mMax(temperature * 0.9, 0)
		rainfall = mMin(rainfall * 1.1, 100)
	end
	temperature = mFloor(temperature)
	rainfall = mFloor(rainfall)
	local bestDist = 300
	local bestTerrain
	for terrainType, terrain in pairs(TerrainDictionary) do
		if self:WithinBounds(terrain, temperature, rainfall) then
			local dist = self:TemperatureRainfallDistance(terrain, temperature, rainfall)
			if dist < bestDist then
				bestDist = dist
				bestTerrain = terrain
			end
		end
	end
	bestDist = 300
	local bestFeature
	for i, featureType in pairs(bestTerrain.features) do
		if featureType ~= featureNone and (featureType ~= featureFallout or self.space.falloutEnabled) then
			local feature = FeatureDictionary[featureType]
			if self:WithinBounds(feature, temperature, rainfall) then
				local dist = 300
				dist = self:TemperatureRainfallDistance(feature, temperature, rainfall)
				if dist < bestDist then
					bestDist = dist
					bestFeature = feature
				end
			end
		end
	end
	if bestFeature == nil or mRandom(1, 140) < bestDist or mRandom(1, 100) > bestFeature.percent then bestFeature = FeatureDictionary[bestTerrain.features[1]] end -- default to the first feature in the list
	local plotType = plotLand
	local terrainType = bestFeature.terrainType or bestTerrain.terrainType
	local featureType = bestFeature.featureType
	if mountain and self.mountainCount < mCeil(self.totalSize * (self.mountainousness / 100)) then
		plotType = plotMountain
		featureType = featureNone
		self.mountainCount = self.mountainCount + 1
	elseif lake and self.lakeCount < mCeil(self.totalSize * (self.lakeyness / 100)) then
		plotType = plotOcean
		terrainType = terrainCoast -- will become coast later
		featureType = featureNone
		self.lakeCount = self.lakeCount + 1
	elseif hill and bestFeature.hill and self.hillCount < mCeil(self.totalSize * (self.hillyness / 100)) then
		plotType = plotHills
		self.hillCount = self.hillCount + 1
	end
	return { plotType = plotType, terrainType = terrainType, featureType = featureType }
end

function Region:Fill()
	for i, polygon in pairs(self.polygons) do
		for spi, subPolygon in pairs(polygon.subPolygons) do
			local subCollection = tGetRandom(self.collection)
			for hi, hex in pairs(subPolygon.hexes) do
				local element = tGetRandom(subCollection)
				if hex.plotType ~= plotOcean then
					if element.plotType == plotOcean then
						hex.lake = true
						hex.subPolygon.lake = true
					end
					hex.plotType = element.plotType
					if element.plotType == plotMountain then tInsert(self.space.mountainHexes, hex) end
					hex.terrainType = element.terrainType
					if FeatureDictionary[element.featureType].limitRatio == -1 or self.featureFillCounts[element.featureType] < FeatureDictionary[element.featureType].limitRatio * self.area then
						hex.featureType = element.featureType
						self.featureFillCounts[element.featureType] = self.featureFillCounts[element.featureType] + 1
					else
						hex.featureType = featureNone
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------

Space = class(function(a)
	-- CONFIGURATION: --
	a.wrapX = true -- globe wraps horizontally?
	a.wrapY = false -- globe wraps vertically?
	a.polygonCount = 140 -- how many polygons (map scale)
	a.minkowskiOrder = 3 -- higher == more like manhatten distance, lower (> 1) more like euclidian distance, < 1 weird cross shapes
	a.relaxations = 1 -- how many lloyd relaxations (higher number is greater polygon uniformity)
	a.subPolygonCount = 12 -- how many subpolygons in each polygon
	a.subPolygonDesertionPercent = 10 -- out of 100, how many subpolygon are swapped over to the adjacent polygon
	a.oceanNumber = 2 -- how many large ocean basins
	a.majorContinentNumber = 1 -- how many large continents per astronomy basin
	a.islandRatio = 0.5 -- what part of the continent polygons are taken up by 1-3 polygon continents
	a.polarContinentChance = 3 -- out of ten chances
	a.useMapLatitudes = false -- should the climate have anything to do with latitude?
	a.collectionSizeMin = 2 -- of how many groups of kinds of tiles does a region consist, at minimum
	a.collectionSizeMax = 9 -- of how many groups of kinds of tiles does a region consist, at maximum
	a.subCollectionSizeMin = 1 -- of how many kinds of tiles does a group consist, at minimum (modified by map size)
	a.subCollectionSizeMax = 9 -- of how many kinds of tiles does a group consist, at maximum (modified by map size)
	a.regionSizeMin = 1 -- least number of polygons a region can have
	a.regionSizeMax = 3 -- most number of polygons a region can have (but most will be limited by their area, which must not exceed half the largest polygon's area)
	a.hillChance = 3 -- how many possible mountains out of ten become a hill when expanding and reducing
	a.mountainRangeMaxEdges = 8 -- how many polygon edges long can a mountain range be
	a.coastRangeRatio = 0.33
	a.mountainRatio = 0.04 -- how much of the land to be mountain tiles
	a.mountainRangeMult = 1.3 -- higher mult means more scattered mountains
	a.coastalPolygonChance = 2 -- out of ten, how often do water polygons become coastal?
	a.tinyIslandChance = 33 -- out of 100 possible subpolygons, how often do coastal shelves produce tiny islands
	a.coastDiceAmount = 2 -- how many dice does each polygon get for coastal expansion
	a.coastDiceMin = 2 -- the minimum sides for each polygon's dice
	a.coastDiceMax = 8 -- the maximum sides for each polygon's dice
	a.coastAreaRatio = 0.25 -- how much of the water on the map (not including coastal polygons) should be coast
	a.freezingTemperature = 18 -- this temperature and below creates ice. temperature is 0 to 100
	a.atollTemperature = 80 -- this temperature and above creates atolls
	a.atollPercent = 1 -- of 100 hexes, how often does atoll temperature produce atolls
	a.polarExponent = 1.2 -- exponent. lower exponent = smaller poles (somewhere between 0 and 2 is advisable)
	a.rainfallMidpoint = 50 -- 25 means rainfall varies from 0 to 50, 75 means 50 to 100, 50 means 0 to 100.
	a.rainfallExponent = 1 -- higher exponent = wetter climate. anything above 0 is okay
	a.temperatureMin = 0 -- lowest temperature possible (plus or minus intraregionTemperatureDeviation)
	a.temperatureMax = 100 -- highest temprature possible (plus or minus intraregionTemperatureDeviation)
	a.temperatureDice = 2 -- temperature probability distribution: 1 is flat, 2 is linearly weighted to the center like /\, 3 is a bell curve _/-\_, 4 is a skinnier bell curve
	a.intraregionTemperatureDeviation = 20 -- how much at maximum can a region's temperature vary within itself
	a.rainfallMin = 0 -- just like temperature above
	a.rainfallMax = 100 -- just like temperature above
	a.rainfallDice = 1 -- just like temperature above
	a.intraregionRainfallDeviation = 20 -- just like temperature above
	a.hillynessMax = 40 -- of 100 how many of a region's tile collection can be hills
	a.mountainousRegionPercent = 3 -- of 100 how many regions will have mountains
	a.mountainousnessMin = 33 -- in those mountainous regions, what's the minimum percentage of mountains in their collection
	a.mountainousnessMax = 66 -- in those mountainous regions, what's the maximum percentage of mountains in their collection
	a.lakeRegionPercent = 8 -- of 100 how many regions will have little lakes
	a.lakeynessMin = 10 -- in those lake regions, what's the minimum percentage of water in their collection
	a.lakeynessMax = 40 -- in those lake regions, what's the maximum percentage of water in their collection
	a.falloutEnabled = false -- place fallout on the map?
	----------------------------------
	-- DEFINITIONS: --
	a.oceans = {}
	a.continents = {}
	a.regions = {}
	a.polygons = {}
	a.subPolygons = {}
	a.edges = {}
	a.mountainRanges = {}
	a.bottomYPolygons = {}
	a.bottomXPolygons = {}
	a.topYPolygons = {}
	a.topXPolygons = {}
	a.hexes = {}
    a.mountainHexes = {}
    a.tinyIslandPolygons = {}
    a.deepHexes = {}
    a.culledPolygons = 0
end)

function Space:Compute()
    self.iW, self.iH = Map.GetGridSize()
    self.iA = self.iW * self.iH
    self.areaMod = mFloor(mSqrt(self.iA) / 30)
    self.coastalMod = self.areaMod
    self.subCollectionSizeMin = self.subCollectionSizeMin + self.areaMod
    self.subCollectionSizeMax = self.subCollectionSizeMax + self.areaMod
    self.nonOceanArea = self.iA
    self.w = self.iW - 1
    self.h = self.iH - 1
    self.halfWidth = self.w / 2
    self.halfHeight = self.h / 2
	self.polarExponentMultiplier = 90 ^ self.polarExponent
	if self.rainfallMidpoint > 50 then
		self.rainfallPlusMinus = 100 - self.rainfallMidpoint
	else
		self.rainfallPlusMinus = self.rainfallMidpoint
	end
	self.rainfallMax = self.rainfallMidpoint + self.rainfallPlusMinus
	self.rainfallExponentMultiplier = (self.rainfallMax / (self.rainfallMax ^ self.rainfallExponent))
    -- need to adjust island chance so that bigger maps have about the same number of islands, and of the same relative size
    self.minNonOceanPolygons = mCeil(self.polygonCount * 0.1)
    if not self.wrapX and not self.wrapY then self.minNonOceanPolygons = mCeil(self.polygonCount * 0.67) end
    self.nonOceanPolygons = self.polygonCount
	self.inverseMinkowskiOrder = 1 / self.minkowskiOrder
    EchoDebug(self.polygonCount .. " polygons", self.iA .. " hexes")
    EchoDebug("initializing polygons...")
    self:InitPolygons()
    if self.relaxations > 0 then
    	for i = 1, self.relaxations do
    		EchoDebug("filling polygons pre-relaxation...")
        	self:FillPolygons(true)
    		print("relaxing polygons... (" .. i .. "/" .. self.relaxations .. ")")
        	self:RelaxPolygons()
        end
    end
    EchoDebug("filling polygons post-relaxation...")
    self:FillPolygons()
    EchoDebug("culling polygons...")
    self:CullPolygons()
    EchoDebug("subdividing polygons...")
    self:SubdividePolygons()
    EchoDebug("computing polygon neighbors...")
    self:ComputePolygonNeighbors()
    EchoDebug("post-processing polygons...")
    self:PostProcessPolygons()
    EchoDebug("finding edge connections...")
    self:FindEdgeConnections()
    EchoDebug("picking oceans...")    
    self:PickOceans()
    EchoDebug("flooding astronomy basins...")
    self:FindAstronomyBasins()
    EchoDebug("picking continents...")
    self:PickContinents()
    EchoDebug("picking mountain ranges...")
    self:PickMountainRanges()
    EchoDebug("picking coasts...")
	self:PickCoasts()
	if not self.useMapLatitudes then
		EchoDebug("dispersing fake latitude...")
		self:DisperseFakeLatitude()
	end
	EchoDebug("computing seas...")
	self:ComputeSeas()
	EchoDebug("picking regions...")
	self:PickRegions()
	EchoDebug("filling regions...")
	self:FillRegions()
	EchoDebug("computing landforms...")
	self:ComputeLandforms()
	EchoDebug("computing ocean temperatures...")
	self:ComputeOceanTemperatures()
	EchoDebug("computing coasts...")
	self:ComputeCoasts()
end

function Space:ComputeLandforms()
	for pi, hex in pairs(self.hexes) do
		if hex.polygon.continentIndex ~= nil then
			-- near ocean trench?
			for neighbor, yes in pairs(hex.adjacentPolygons) do
				if neighbor.oceanIndex ~= nil then
					hex.nearOceanTrench = true
					if neighbor.nearOcean then EchoDebug("CONTINENT NEAR OCEAN TRENCH??") end
					break
				end
			end
			if hex.nearOceanTrench then
				EchoDebug("CONTINENT PLOT NEAR OCEAN TRENCH")
				hex.plotType = plotOcean
			else
				if hex.mountainRange then
					hex.plotType = plotMountain
					tInsert(self.mountainHexes, hex)
				end
			end
		end
	end
	self:AdjustMountains()
end

function Space:ComputeSeas()
	-- ocean plots and tiny islands:
	for pi, hex in pairs(self.hexes) do
		if hex.polygon.continentIndex == nil then
			if hex.polygon.coastal and hex.subPolygon.tinyIsland then
				hex.plotType = plotLand
			else
				hex.plotType = plotOcean
			end
		end
	end
end

function Space:ComputeCoasts()
	for i, subPolygon in pairs(self.subPolygons) do
		if (not subPolygon.superPolygon.continentIndex or subPolygon.lake) and not subPolygon.tinyIsland then
			if subPolygon.superPolygon.coastal then
				subPolygon.coast = true
				subPolygon.oceanTemperature = subPolygon.superPolygon.region.temperatureAvg
			else
				for ni, neighbor in pairs(subPolygon.neighbors) do
					if neighbor.superPolygon.continentIndex or neighbor.tinyIsland then
						subPolygon.coast = true
						subPolygon.oceanTemperature = neighbor.superPolygon.region.temperatureAvg
						break
					end
				end
			end
			subPolygon.oceanTemperature = subPolygon.oceanTemperature or self:GetTemperature(subPolygon.latitude)
			local ice = self:GimmeIce(subPolygon.oceanTemperature) -- subPolygon.oceanTemperature <= self.freezingTemperature
			if subPolygon.coast then
				local atoll = subPolygon.oceanTemperature >= self.atollTemperature
				for hi, hex in pairs(subPolygon.hexes) do
					if ice and self:GimmeIce(subPolygon.oceanTemperature) then -- and self:GimmeIce(subPolygon.oceanTemperature) then
						hex.featureType = featureIce
					elseif atoll and mRandom(1, 100) < self.atollPercent then
						hex.featureType = featureAtoll
					end
					hex.terrainType = terrainCoast
				end
			else
				for hi, hex in pairs(subPolygon.hexes) do
					if ice and self:GimmeIce(subPolygon.oceanTemperature) then hex.featureType = featureIce end
					hex.terrainType = terrainOcean
				end
			end
		end
	end
end

function Space:ComputeOceanTemperatures()
	for p, polygon in pairs(self.polygons) do
		if polygon.continentIndex == nil then
			if not self.useMapLatitudes and polygon.oceanIndex == nil then
				local latSum = 0
				local div = 0
				for n, neighbor in pairs(polygon.neighbors) do
					if neighbor.continentIndex then
						latSum = latSum + neighbor.latitude
						div = div + 1
					end
				end
				if div > 0 then polygon.latitude = latSum / div end
			end
			polygon.oceanTemperature = self:GetTemperature(polygon.latitude)
		end
	end
end

function Space:GimmeIce(temperature)
	local below = self.freezingTemperature - temperature
	if below < 0 then return false end
	return mRandom(1, 100) < 100 * (below / self.freezingTemperature)
end

function Space:SetPlots()
	for i, hex in pairs(self.hexes) do
		hex:SetPlot()
	end
end

function Space:SetTerrains()
	for i, hex in pairs(self.hexes) do
		hex:SetTerrain()
	end
end

function Space:SetFeatures()
	for i, hex in pairs(self.hexes) do
		hex:SetFeature()
	end
end


    ----------------------------------
    -- INTERNAL METAFUNCTIONS: --

function Space:InitPolygons()
	for i = 1, self.polygonCount do
		local polygon = Polygon(self)
		tInsert(self.polygons, polygon)
	end
end


function Space:FillPolygons(relax)
	for x = 0, self.w do
		for y = 0, self.h do
			local hex = Hex(self, x, y, self:GetIndex(x, y))
			hex:Place(relax)
		end
	end
end

function Space:RelaxPolygons()
	for i, polygon in pairs(self.polygons) do
		polygon:RelaxToCentroid()
	end
end

function Space:CullPolygons()
	for i = #self.polygons, 1, -1 do -- have to go backwards, otherwise table.remove screws up the iteration
		local polygon = self.polygons[i]
		if #polygon.hexes == 0 then
			tRemove(self.polygons, i)
			self.culledPolygons = self.culledPolygons + 1
		end
	end
	EchoDebug(self.culledPolygons .. " polygons culled")
end

function Space:SubdividePolygons()
	self.smallestSubPolygon = 1000
	self.biggestSubPolygon = 0
	for i, polygon in pairs(self.polygons) do
		polygon:Subdivide()
	end
	EchoDebug("smallest subpolygon: " .. self.smallestSubPolygon, "biggest subpolygon: " .. self.biggestSubPolygon)
end

function Space:ComputePolygonNeighbors()
	for i, hex in pairs(self.hexes) do
		hex:ComputeNeighbors()
	end
end

function Space:PostProcessPolygons()
	self.polygonMinArea = self.iA
	self.polygonMaxArea = 0
	for i, polygon in pairs(self.polygons) do
		polygon:PostProcess()
		if polygon.area < self.polygonMinArea and polygon.area > 0 then
			self.polygonMinArea = polygon.area
		end
		if polygon.area > self.polygonMaxArea then
			self.polygonMaxArea = polygon.area
		end
		for spi, subPolygon in pairs(polygon.subPolygons) do
			subPolygon:PostProcess()
		end
	end
	EchoDebug("smallest polygon: " .. self.polygonMinArea, "largest polygon: " .. self.polygonMaxArea)
end

function Space:FindEdgeConnections()
	for i, edge in pairs(self.edges) do
		local polygon1 = edge.polygons[1]
		local polygon2 = edge.polygons[2]
		local mutualNeighbors = {}
		for n, neighbor in pairs(polygon1.neighbors) do
			if neighbor.isNeighbor[polygon2] then
				mutualNeighbors[neighbor] = true
			end
		end
		for p, polygon in pairs(edge.polygons) do
			for pe, pedge in pairs(polygon.edges) do
				if (mutualNeighbors[pedge.polygons[1]] or mutualNeighbors[pedge.polygons[2]]) and pedge ~= edge then
					edge.connections[pedge] = true
				end
			end
		end
	end
end

function Space:PickOceans()
	if self.wrapX and self.wrapY then
		self:PickOceansDoughnut()
	elseif not self.wrapX and not self.wrapY then
		self:PickOceansRectangle()
	elseif self.wrapX and not self.wrapY then
		self:PickOceansCylinder()
	elseif self.wrapY and not self.wrapX then
		print("why have a vertically wrapped map?")
	end
	EchoDebug(#self.oceans .. " oceans", self.nonOceanPolygons .. " non-ocean polygons", self.nonOceanArea .. " non-ocean hexes")
end

function Space:PickOceansCylinder()
	local div = self.w / self.oceanNumber
	local x = mRandom(0, self.w)
	for oceanIndex = 1, self.oceanNumber do
		local hex = self.hexes[self:GetIndex(x, 0)]
		local polygon = hex.polygon
		local ocean = {}
		local iterations = 0
		local chosen = {}
		while self.nonOceanPolygons > self.minNonOceanPolygons do
			chosen[polygon] = true
			polygon.oceanIndex = oceanIndex
			tInsert(ocean, polygon)
			self.nonOceanArea = self.nonOceanArea - polygon.area
			self.nonOceanPolygons = self.nonOceanPolygons - 1
			if polygon.topY then
					EchoDebug("topY found, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
					break
			end
			local upNeighbors = {}
			local downNeighbors = {}
			for ni, neighbor in pairs(polygon.neighbors) do
				if not neighbor:NearOther(oceanIndex, "oceanIndex") then
					if not chosen[neighbor] then
						if neighbor.maxY > polygon.maxY then
							tInsert(upNeighbors, neighbor)
						else
							tInsert(downNeighbors, neighbor)
						end
					end
				end
			end
			if #upNeighbors == 0 then
				if #downNeighbors == 0 then
					if #polygon.neighbors == 0 then
						EchoDebug("no neighbors!, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
						break
					else
						upNeighbors = polygon.neighbors
					end
				else
					upNeighbors = downNeighbors
				end
			end
			local highestY = 0
			local highestNeigh
			for ni, neighbor in pairs(upNeighbors) do
				if neighbor.y > highestY then
					highestY = neighbor.y
					highestNeigh = neighbor
				end
			end
			polygon = highestNeigh or tGetRandom(upNeighbors)
			iterations = iterations + 1
		end
		tInsert(self.oceans, ocean)
		x = mCeil(x + div) % self.w
	end
end

function Space:PickOceansRectangle() 
	-- pick a corner and grow the ocean from there
	local corners = { [1] = {x = 0, y = 0}, [2] = {x = 0, y = self.h}, [3] = {x = self.w, y = 0}, [4] = {x = self.w, y = self.h} }
	for oceanIndex = 1, self.oceanNumber do
		local corner = tRemoveRandom(corners)
		local x, y = corner.x, corner.y
		local hex = self.hexes[self:GetIndex(x, y)]
		local polygon = hex.polygon
		local ocean = {}
		local iterations = 0
		while self.nonOceanPolygons > self.minNonOceanPolygons do
			local upNeighbors = {}
			for ni, neighbor in pairs(polygon.neighbors) do
				if neighbor.oceanIndex == nil then tInsert(upNeighbors, neighbor) end
			end
			if #upNeighbors == 0 then
				EchoDebug("no upNeighbors")
				break
			end
			if iterations == 0 then tInsert(upNeighbors, polygon) end
			for ni, neighbor in pairs(upNeighbors) do
				neighbor.oceanIndex = oceanIndex
				tInsert(ocean, neighbor)
				self.nonOceanArea = self.nonOceanArea - neighbor.area
				self.nonOceanPolygons = self.nonOceanPolygons - 1
			end
			polygon = tGetRandom(upNeighbors)
			iterations = iterations + 1
		end
	end
end

function Space:PickOceansDoughnut()
end

function Space:FindAstronomyBasins()
	for i, polygon in pairs(self.polygons) do
		if polygon.oceanIndex == nil and polygon:NearOther(nil, "oceanIndex") then
			polygon.nearOcean = true
		end
	end
	local astronomyIndex = 1
	self.astronomyBasins = {}
	for i, polygon in pairs(self.polygons) do
		if polygon:FloodFillAstronomy(astronomyIndex) then
			astronomyIndex = astronomyIndex + 1
			EchoDebug("astronomy basin #" .. astronomyIndex-1 .. " has " .. #self.astronomyBasins[astronomyIndex-1] .. " polygons")
		end
	end
	self.totalAstronomyBasins = astronomyIndex - 1
	EchoDebug(self.totalAstronomyBasins .. " astronomy basins")
end

function Space:PickContinents()
	self.filledArea = 0
	self.filledPolygons = 0
	for astronomyIndex, basin in pairs(self.astronomyBasins) do
		EchoDebug("picking for astronomy basin #" .. astronomyIndex .. ": " .. #basin .. " polygons...")
		self:PickContinentsInBasin(astronomyIndex)
	end
end

function Space:PickContinentsInBasin(astronomyIndex)
	local polygonBuffer = {}
	for i, polygon in pairs(self.astronomyBasins[astronomyIndex]) do
		tInsert(polygonBuffer, polygon)
	end
	local islandPolygons = mCeil(#polygonBuffer * self.islandRatio)
	local nonIslandPolygons = mMax(1, #polygonBuffer - islandPolygons)
	local filledPolygons = 0
	local continentIndex = 1
	while #polygonBuffer > 0 do
		-- determine theoretical continent size
		local size = mCeil(nonIslandPolygons / self.majorContinentNumber)
		if filledPolygons >= nonIslandPolygons then size = mRandom(1, 3) end
		-- pick a polygon to start the continent
		local polygon
		repeat
			polygon = tRemoveRandom(polygonBuffer)
			if polygon.continentIndex == nil and not polygon:NearOther(nil, "continentIndex") and (self.wrapY or (not polygon.topY and not polygon.bottomY)) and (self.wrapX or (not polygon.topX and not polygon.bottomX)) then
				break
			else
				polygon = nil
			end
		until #polygonBuffer == 0
		if polygon == nil then break end
		local backlog = {}
		local polarBacklog = {}
		polygon.continentIndex = continentIndex
		self.filledArea = self.filledArea + polygon.area
		filledPolygons = filledPolygons + 1
		local filledContinentArea = polygon.area
		local continent = { polygons = { polygon }, index = continentIndex }
		repeat
			local candidates = {}
			local polarCandidates = {}
			for ni, neighbor in pairs(polygon.neighbors) do
				if neighbor.continentIndex == nil and not neighbor:NearOther(continentIndex, "continentIndex") and neighbor.astronomyIndex < 10 then
					if self.wrapX and (neighbor.topY or neighbor.bottomY) then
						tInsert(polarCandidates, neighbor)
					else
						tInsert(candidates, neighbor)
					end
				end
			end
			local candidate
			if #candidates == 0 then
				if #polarCandidates > 0 then
					candidate = tRemoveRandom(polarCandidates) -- use a polar polygon
				else
					-- when there are no immediate candidates
					if #backlog > 0 then
						repeat
							candidate = tRemove(backlog, #backlog) -- pop off the most recent
							if candidate.continentIndex ~= nil then candidate = nil end
						until candidate ~= nil or #backlog == 0
					elseif #polarBacklog > 0 then
						repeat
							candidate = tRemove(polarBacklog, #polarBacklog) -- pop off the most recent polar
							if candidate.continentIndex ~= nil then candidate = nil end
						until candidate ~= nil or #polarBacklog == 0
					else
						break -- nothing left to do but stop
					end
				end
			else
				candidate = tRemoveRandom(candidates)
			end
			if candidate == nil then break end
			-- put the rest of the candidates in the backlog
			for nothing, polygon in pairs(candidates) do
				tInsert(backlog, polygon)
			end
			for nothing, polygon in pairs(polarCandidates) do
				tInsert(polarBacklog, polygon)
			end
			candidate.continentIndex = continentIndex
			self.filledArea = self.filledArea + candidate.area
			filledContinentArea = filledContinentArea + candidate.area
			filledPolygons = filledPolygons + 1
			tInsert(continent.polygons, candidate)
			polygon = candidate
		until #backlog == 0 or #continent.polygons >= size
		EchoDebug(size, #continent.polygons, filledContinentArea)
		tInsert(self.continents, continent)
		continentIndex = continentIndex + 1
	end
	self.filledPolygons = self.filledPolygons + filledPolygons
end

function Space:PickMountainRanges()
	local edgeBuffer = {}
	for i, edge in pairs(self.edges) do
		tInsert(edgeBuffer, edge)
	end
	local mountainRangeRatio = self.mountainRatio * self.mountainRangeMult
	local prescribedEdges = mountainRangeRatio * #self.edges
	local coastPrescription = mFloor(prescribedEdges * self.coastRangeRatio)
	local interiorPrescription = prescribedEdges - coastPrescription
	EchoDebug("prescribed mountain range edges: " .. prescribedEdges .. " of " .. #self.edges)
	local edgeCount = 0
	local coastCount = 0
	local interiorCount = 0
	while #edgeBuffer > 0 and edgeCount < prescribedEdges do
		local edge
		local coastRange
		repeat
			edge = tRemoveRandom(edgeBuffer)
			if (edge.polygons[1].continentIndex or edge.polygons[2].continentIndex) and not edge.mountains then
				if edge.polygons[1].continentIndex and edge.polygons[2].continentIndex and interiorCount < interiorPrescription then
					coastRange = false
					break
				elseif coastCount < coastPrescription then
					coastRange = true
					break
				end
			else
				edge = nil
			end
		until #edgeBuffer == 0
		if edge == nil then break end
		edge.mountains = true
		local range = { edge }
		edgeCount = edgeCount + 1
		if coastRange then coastCount = coastCount + 1 else interiorCount = interiorCount + 1 end
		repeat
			local nextPolygon = edge.polygons[mRandom(1, 2)]
			local nextEdges = {}
			for neighborPolygon, nextEdge in pairs(nextPolygon.edges) do
				local okay = false
				if (nextEdge.polygons[1].continentIndex or nextEdge.polygons[2].continentIndex) and not nextEdge.mountains then
					if coastRange and (not nextEdge.polygons[1].continentIndex or not nextEdge.polygons[2].continentIndex) then
						okay = true
					elseif not coastRange and nextEdge.polygons[1].continentIndex and nextEdge.polygons[2].continentIndex then
						okay = true
					end
				end
				if okay then
					for cedge, yes in pairs(nextEdge.connections) do
						if cedge.mountains and cedge ~= nextEdge then okay = false end
					end
				end
				if okay then
					tInsert(nextEdges, nextEdge)
				end
			end
			if #nextEdges == 0 then break end
			local nextEdge = tGetRandom(nextEdges)
			nextEdge.mountains = true
			tInsert(range, nextEdge)
			edgeCount = edgeCount + 1
			if coastRange then coastCount = coastCount + 1 else interiorCount = interiorCount + 1 end
			edge = nextEdge
		until #nextEdges == 0 or #range >= self.mountainRangeMaxEdges or coastCount > coastPrescription or interiorCount > interiorPrescription
		EchoDebug("new range", #range, tostring(coastRange))
		for i, e in pairs(range) do
			for hi, hex in pairs(e.hexes) do
				hex.mountainRange = true
			end
		end
		tInsert(self.mountainRanges, range)
	end
	EchoDebug(interiorCount, coastCount)
end

function Space:PickRegions()
	for ci, continent in pairs(self.continents) do
		local polygonBuffer = {}
		for polyi, polygon in pairs(continent.polygons) do
			tInsert(polygonBuffer, polygon)
		end
		while #polygonBuffer > 0 do
			local size = mRandom(self.regionSizeMin, self.regionSizeMax)
			local polygon
			repeat
				polygon = tRemoveRandom(polygonBuffer)
				if polygon.region == nil then
					break
				else
					polygon = nil
				end
			until #polygonBuffer == 0
			local region
			if polygon ~= nil then
				local backlog = {}
				region = Region(self)
				polygon.region = region
				tInsert(region.polygons, polygon)
				region.area = region.area + polygon.area
				repeat
					if #polygon.neighbors == 0 then break end
					local candidates = {}
					for ni, neighbor in pairs(polygon.neighbors) do
						if neighbor.continentIndex == continent.index then
							tInsert(candidates, neighbor)
						end
					end
					local candidate
					if #candidates == 0 then
						if #backlog == 0 then
							break
						else
							repeat
								candidate = tRemoveRandom(backlog)
								if candidate.region ~= nil then candidate = nil end
							 until candidate ~= nil or #backlog == 0
						end
					else
						candidate = tRemoveRandom(candidates)
					end
					if candidate == nil then break end
					candidate.region = region
					tInsert(region.polygons, candidate)
					region.area = region.area + candidate.area
					polygon = candidate
					for candi, c in pairs(candidates) do
						tInsert(backlog, c)
					end
				until #region.polygons == size or region.area > self.polygonMaxArea / 2 or #region.polygons == #continent.polygons
			end
			tInsert(self.regions, region)
		end
	end
	for p, polygon in pairs(self.tinyIslandPolygons) do
		polygon.region = Region(self)
		tInsert(polygon.region.polygons, polygon)
		polygon.region.area = polygon.area
		polygon.region.archipelago = true
		tInsert(self.regions, polygon.region)
	end
end

function Space:FillRegions()
	for i, region in pairs(self.regions) do
		region:CreateCollection()
		region:Fill()
	end
end

function Space:PickCoasts()
	self.waterArea = self.nonOceanArea - self.filledArea
	self.prescribedCoastArea = self.waterArea * self.coastAreaRatio
	EchoDebug(self.prescribedCoastArea .. " coastal tiles prescribed of " .. self.waterArea .. " total water tiles")
	self.coastArea = 0
	self.coastalPolygonArea = 0
	self.coastalPolygonCount = 0
	for i, polygon in pairs(self.polygons) do
		if polygon.continentIndex == nil and polygon.oceanIndex == nil then
			if Map.Rand(10, "coastal polygon dice") < self.coastalPolygonChance then
				polygon.coastal = true
				self.coastalPolygonCount = self.coastalPolygonCount + 1
				if not polygon:NearOther(nil, "continentIndex") then polygon.loneCoastal = true end
				polygon:PickTinyIslands()
				tInsert(self.tinyIslandPolygons, polygon)
			end
		end
	end
	EchoDebug(self.coastalPolygonCount .. " coastal polygons")
end

function Space:DisperseFakeLatitude()
	self.continentalFakeLatitudes = {}
	local increment = 90 / self.filledPolygons
    for i = 1, self.filledPolygons do
    	tInsert(self.continentalFakeLatitudes, increment * (i-1))
    end
	self.nonContinentalFakeLatitudes = {}
    increment = 90 / (#self.polygons - self.filledPolygons)
    for i = 1, (#self.polygons - self.filledPolygons) do
    	tInsert(self.nonContinentalFakeLatitudes, increment * (i-1))
    end
	for i, polygon in pairs(self.polygons) do
		polygon.latitude = self:GetFakeLatitude(polygon)
		for spi, subPolygon in pairs(polygon.subPolygons) do
			subPolygon.latitude = self:GetFakeSubLatitude(polygon.latitude)
		end
	end
end

function Space:ResizeMountains(prescribedArea)
	if #self.mountainHexes == prescribedArea then return end
	if #self.mountainHexes > prescribedArea then
		repeat
			local hex = tRemoveRandom(self.mountainHexes)
			if Map.Rand(10, "hill dice") < self.hillChance then
				hex.plotType = plotHills
				if hex.featureType and not FeatureDictionary[hex.featureType].hill then
					hex.featureType = featureNone
				end
			else
				hex.plotType = plotLand
			end
		until #self.mountainHexes <= prescribedArea
	elseif #self.mountainHexes < prescribedArea then
		local noNeighbors = 0
		repeat
			local hex = tGetRandom(self.mountainHexes)
			local neighbors = hex:Neighbors()
			local nhex
			repeat
				nhex = tRemoveRandom(neighbors)
			until nhex.plotType == plotLand or #neighbors == 0
			if nhex ~= nil and nhex.plotType == plotLand then
				if Map.Rand(10, "hill dice") < self.hillChance then
					nhex.plotType = plotHills
					if not FeatureDictionary[hex.featureType].hill then
						hex.featureType = featureNone
					end
				else
					nhex.plotType = plotMountain
					tInsert(self.mountainHexes, nhex)
				end
				noNeighbors = 0
			else
				noNeighbors = noNeighbors + 1
			end
		until #self.mountainHexes >= prescribedArea or noNeighbors > 20
	end
end

function Space:AdjustMountains()
	self.mountainArea = mCeil(self.mountainRatio * self.filledArea)
	EchoDebug(#self.mountainHexes, self.mountainArea)
	-- first expand them 1.1 times their size
	self:ResizeMountains(#self.mountainHexes * 1.1)
	-- then adjust to the right amount
	self:ResizeMountains(self.mountainArea)
	for i, hex in pairs(self.mountainHexes) do
		hex.featureType = featureNone
	end
end

----------------------------------
-- INTERNAL FUNCTIONS: --

function Space:GetFakeLatitude(polygon)
	if polygon then
		if polygon.continentIndex then
			return tRemoveRandom(self.continentalFakeLatitudes)
		else
			return tRemoveRandom(self.nonContinentalFakeLatitudes)
		end
	end
	return mRandom(0, 90)
end

function Space:GetFakeSubLatitude(latitudeStart)
	if latitudeStart then
		return mRandom(latitudeStart-5, latitudeStart+5)
	end
	return mRandom(0, 90)
end

function Space:GetTemperature(latitude)
	local rise = self.temperatureMax - self.temperatureMin
	local temp, temp2
	if latitude then
		local distFromPole = (90 - latitude) ^ self.polarExponent
		temp = (rise / self.polarExponentMultiplier) * distFromPole + self.temperatureMin
	else
		temp = diceRoll(self.temperatureDice, rise) + self.temperatureMin
	end
	local diff = mRandom(1, mFloor(self.intraregionTemperatureDeviation / 2))
	local temp2 = mMin(temp + diff, 100)
	local temp1 = mMax(temp - diff, 0)
	return mFloor(temp), mFloor(temp1), mFloor(temp2)
end

function Space:GetRainfall(latitude)
	local rain, rain2
	if latitude then
		if latitude > 75 then -- polar
			rain = (self.rainfallMidpoint/4) + ( (self.rainfallPlusMinus/4) * (mCos((mPi/15) * (latitude+15))) )
		elseif latitude > 37.5 then -- temperate
			rain = self.rainfallMidpoint + ((self.rainfallPlusMinus/2) * mCos(latitude * (mPi/25)))
		else -- tropics and desert
			rain = self.rainfallMidpoint + (self.rainfallPlusMinus * mCos(latitude * (mPi/25)))
		end
	else
		local rise = self.rainfallMax - self.rainfallMin
		rain = diceRoll(self.rainfallDice, rise) + self.rainfallMin
	end
	local diff = mRandom(1, mFloor(self.intraregionRainfallDeviation / 2))
	local rain1 = mMax(rain - diff, 0)
	local rain2 = mMin(rain + diff, 100)
	return mFloor(rain), mFloor(rain1), mFloor(rain2)
end

function Space:GetHillyness()
	return mRandom(0, self.hillynessMax)
end

function Space:GetCollectionSize()
	return mRandom(self.collectionSizeMin, self.collectionSizeMax), mRandom(self.subCollectionSizeMin, self.subCollectionSizeMax)
end

function Space:WrapDistance(x1, y1, x2, y2)
	local xdist = mAbs(x1 - x2)
	local ydist = mAbs(y1 - y2)
	if self.wrapX then
		if xdist > self.halfWidth then
			if x1 < x2 then
				xdist = x1 + (self.w - x2)
			else
				xdist = x2 + (self.w - x1)
			end
		end
	end
	if self.wrapY then
		if ydist > self.halfHeight then
			if y1 < y2 then
				ydist = y1 + (self.h - y2)
			else
				ydist = y2 + (self.h - y1)
			end
		end
	end
	return xdist, ydist
end

function Space:SquareDistance(x1, y1, x2, y2)
	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
	return (xdist * xdist) + (ydist * ydist)
end

function Space:EucDistance(x1, y1, x2, y2)
	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
	return mSqrt( (xdist * xdist) + (ydist * ydist) )
end

function Space:HexDistance(x1, y1, x2, y2)
	local xx1 = x1
	local zz1 = y1 - (x1 + x1%2) / 2
	local yy1 = -xx1-zz1
	local xx2 = x2
	local zz2 = y2 - (x2 + x2%2) / 2
	local yy2 = -xx2-zz2
	local xdist = mAbs(x1 - x2)
	-- x is the same orientation, so it can still wrap?
	if self.wrapX then
		if xdist > self.halfWidth then
			if x1 < x2 then
				xdist = x1 + (self.w - x2)
			else
				xdist = x2 + (self.w - x1)
			end
		end
	end
	return (xdist + mAbs(yy1 - yy2) + mAbs(zz1 - zz2)) / 2
end

function Space:Minkowski(x1, y1, x2, y2)
	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
	return (xdist^self.minkowskiOrder + ydist^self.minkowskiOrder)^self.inverseMinkowskiOrder
end

function Space:GetHexByXY(x, y)
	return self.hexes[self:GetIndex(x, y)]
end

function Space:GetXY(index)
	if index == nil then return nil end
	index = index - 1
	return index % self.iW, mFloor(index / self.iW)
end

function Space:GetIndex(x, y)
	if x == nil or y == nil then return nil end
	return (y * self.iW) + x + 1
end

------------------------------------------------------------------------------

function GetMapScriptInfo()
	local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
	return {
		Name = "Fantastical (dev)",
		Description = "Scribbles fantastical lands onto the world.",
		IconIndex = 5,
	}
end

--[[
function GetMapInitData(worldSize)

end
]]--

local mySpace

function GeneratePlotTypes()
    print("Generating Plot Types (Fantastical) ...")
	SetConstants()
    mySpace = Space()
    mySpace:Compute()
    --[[
    for l = 0, 90, 5 do
		EchoDebug(l, "temperature: " .. mySpace:GetTemperature(l), "rainfall: " .. mySpace:GetRainfall(l))
	end
	]]--
    print("Setting Plot Types (Fantastical) ...")
    mySpace:SetPlots()
end

function GenerateTerrain()
    print("Setting Terrain Types (Fantastical) ...")
	mySpace:SetTerrains()
end

function AddFeatures()
	print("Setting Feature Types (Fantastical) ...")
	mySpace:SetFeatures()
end

function AddLakes()
	print("Adding No Lakes (lakes have already been added) (Fantastical)")
end

-------------------------------------------------------------------------------

-- THE STUFF BELOW DOESN'T ACTUALLY DO ANYTHING IN WORLD BUILDER (AND IN GAME?)

function AssignStartingPlots:CanBeReef(x, y)
	-- Checks a candidate plot for eligibility to be the Great Barrier Reef.
	local iW, iH = Map.GetGridSize();
	local plotIndex = y * iW + x + 1;
	-- We don't care about the center plot for this wonder. It can be forced. It's the surrounding plots that matter.
	-- This is also the only natural wonder type with a footprint larger than seven tiles.
	-- So first we'll check the extra tiles, make sure they are there, are ocean water, and have no Ice.
	local iNumCoast = 0;
	local extra_direction_types = {
		DirectionTypes.DIRECTION_EAST,
		DirectionTypes.DIRECTION_SOUTHEAST,
		DirectionTypes.DIRECTION_SOUTHWEST};
	local SEPlot = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_SOUTHEAST)
	local southeastX = SEPlot:GetX();
	local southeastY = SEPlot:GetY();
	for loop, direction in ipairs(extra_direction_types) do -- The three plots extending another plot past the SE plot.
		local adjPlot = Map.PlotDirection(southeastX, southeastY, direction)
		if adjPlot == nil then
			return
		end
		if adjPlot:IsWater() == false or adjPlot:IsLake() == true then
			return
		end
		local featureType = adjPlot:GetFeatureType()
		if featureType == featureIce then
			return
		end
		local hex = Space.hexes[plotIndex+1]
		if hex.oceanIndex then
			return
		end
		local terrainType = adjPlot:GetTerrainType()
		if terrainType == terrainCoast then
			iNumCoast = iNumCoast + 1;
		end
	end
	-- Now check the rest of the adjacent plots.
	local direction_types = { -- Not checking to southeast.
		DirectionTypes.DIRECTION_NORTHEAST,
		DirectionTypes.DIRECTION_EAST,
		DirectionTypes.DIRECTION_SOUTHWEST,
		DirectionTypes.DIRECTION_WEST,
		DirectionTypes.DIRECTION_NORTHWEST
		};
	for loop, direction in ipairs(direction_types) do
		local adjPlot = Map.PlotDirection(x, y, direction)
		if adjPlot:IsWater() == false then
			return
		end
		local hex = Space.hexes[plotIndex+1]
		if hex.oceanIndex then
			return
		end
		local terrainType = adjPlot:GetTerrainType()
		if terrainType == terrainCoast then
			iNumCoast = iNumCoast + 1;
		end
	end
	-- If not enough coasts, reject this site.
	if iNumCoast < 6 then
		return
	end
	-- This site is in the water, with at least some of the water plots being coast, so it's good.
	table.insert(self.reef_list, plotIndex);
end

function AssignStartingPlots:CanBeKrakatoa(x, y)
	-- Checks a candidate plot for eligibility to be Krakatoa the volcano.
	local plot = Map.GetPlot(x, y)
	-- Check the center plot, which must be land surrounded on all sides by coast. (edited for fantastical)
	if plot:IsWater() then return end

	for loop, direction in ipairs(self.direction_types) do
		local adjPlot = Map.PlotDirection(x, y, direction)
		if not adjPlot:IsWater() or adjPlot:GetTerrainType() ~= terrainCoast or adjPlot:GetFeatureType() == featureIce then
			return
		end
	end
	
	-- Surrounding tiles are all ocean water, not lake, and free of Feature Ice, so it's good.
	local iW, iH = Map.GetGridSize();
	local plotIndex = y * iW + x + 1;
	table.insert(self.krakatoa_list, plotIndex);
end