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
include("FeatureGenerator")
include("TerrainGenerator")
include("AssignStartingPlots")

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

local function diceRoll(dice, invert, maximum)
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
local featureForest, featureJungle, featureIce, featureMarsh, featureOasis, featureAtoll, featureFallout
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
	featureAtoll = FeatureTypes.FEATURE_ATOLL
	featureFallout = FeatureTypes.FEATURE_FALLOUT

	FeatureDictionary = {
		[featureNone] = { featureType = featureNone, temperature = 50, rainfall = 25, percent = 50, hill = true },
		[featureForest] = { featureType = featureForest, temperature = 50, rainfall = 70, percent = 50, hill = true },
		[featureJungle] = { featureType = featureJungle, temperature = 100, rainfall = 100, percent = 50, hill = true },
		[featureMarsh] = { featureType = featureMarsh, temperature = 50, rainfall = 90, percent = 8, hill = false },
		[featureOasis] = { featureType = featureOasis, temperature = 50, rainfall = 75, percent = 8, hill = false },
		[featureFallout] = { featureType = featureFallout, temperature = 50, rainfall = 50, percent = 1, hill = true },
	}

	TerrainDictionary = {
		[terrainGrass] = { terrainType = terrainGrass, temperature = 50, rainfall = 60, features = { featureNone, featureForest, featureMarsh, featureFallout } },
		[terrainPlains] = { terrainType = terrainPlains, temperature = 60, rainfall = 40, features = { featureNone, featureForest, featureFallout } },
		[terrainDesert] = { terrainType = terrainDesert, temperature = 50, rainfall = 10, features = { featureNone, featureOasis, featureFallout } },
		[terrainTundra] = { terrainType = terrainTundra, temperature = 20, rainfall = 20, features = { featureNone, featureForest, featureFallout } },
		[terrainSnow] = { terrainType = terrainSnow, temperature = 0, rainfall = 50, features = { featureNone, featureFallout } },
		[99] = { terrainType = terrainPlains, temperature = 100, rainfall = 100, features = { featureJungle, featureFallout } },
	}
end

------------------------------------------------------------------------------

Hex = class(function(a, space, x, y, index)
	a.space = space
	a.index = index
	a.x, a.y = x, y
	a.liminality = 0
	a.edginess = 0
	a.edgeWith = {}
end)

function Hex:Place(relax)
	self.polygon, self.liminality = self:ClosestPolygon(relax)
	self.space.hexes[self.index] = self
	tInsert(self.polygon.hexes, self)
	self.polygon.area = self.polygon.area + 1
	if self.x < self.polygon.minX then self.polygon.minX = self.x end
	if self.y < self.polygon.minY then self.polygon.minY = self.y end
	if self.x > self.polygon.maxX then self.polygon.maxX = self.x end
	if self.y > self.polygon.maxY then self.polygon.maxY = self.y end
	if not relax then
		if self.liminality ~= 0 then
			self.space.liminalTileCount = self.space.liminalTileCount + 1
		end
		self.polygon:CheckBottomTop(self.x, self.y)
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
	for i = 1, #self.space.polygons do
		local polygon = self.space.polygons[i]
		dists[i] = self.space:EucDistance(polygon.x, polygon.y, self.x, self.y)
		if i == 1 or dists[i] < closest_distance then
			closest_distance = dists[i]
			closest_polygon = polygon
		end
	end
	local liminality = 0
	if not relax then
		-- sometimes a point is closer to more than one point
    	for i = 1, #self.space.polygons do
    		local polygon = self.space.polygons[i]
    		if dists[i] < closest_distance + self.space.liminalTolerance and polygon ~= closest_polygon then
    			liminality = liminality + 1
    		end
    	end
    	if liminality > self.space.maxLiminality then self.space.maxLiminality = liminality end
    end
	return closest_polygon, liminality
end

function Hex:SetPlot()
	local plot = Map.GetPlotByIndex(self.index-1)
	if plot == nil then return end
	plot:SetPlotType(self.plotType)
end

function Hex:SetTerrain()
	local plot = Map.GetPlotByIndex(self.index-1)
	if plot == nil then return end
	plot:SetTerrainType(self.terrainType, false, false)
end

function Hex:SetFeature()
	if self.featureType == nil then return end
	local plot = Map.GetPlotByIndex(self.index-1)
	if plot == nil then return end
	plot:SetFeatureType(self.featureType)
end

------------------------------------------------------------------------------

Polygon = class(function(a, space, x, y)
	a.space = space
	a.x = x or Map.Rand(space.iW, "random x")
	a.y = y or Map.Rand(space.iH, "random y")
	a.hexes = {}
	a.edges = {}
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

function Polygon:EdgeAddress(polygon2)
	return self.x .. " " .. self.y .. " " .. polygon2.x .. " " .. polygon2.y
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

------------------------------------------------------------------------------

Region = class(function(a, space, latitude)
	a.space = space
	tempA, tempB = space:GetTemperature(latitude), space:GetTemperature(latitude)
	if tempA > tempB then
		a.temperatureMin, a.temperatureMax = tempB, tempA
	else
		a.temperatureMin, a.temperatureMax = tempA, tempB
	end
	rainA, rainB = space:GetRainfall(latitude), space:GetRainfall(latitude)
	if rainA > rainB then
		a.rainfallMin, a.rainfallMax = rainB, rainA
	else
		a.rainfallMin, a.rainfallMax = rainA, rainB
	end
	a.hillyness = space:GetHillyness()
	EchoDebug(a.temperatureMin, a.temperatureMax, a.rainfallMin, a.rainfallMax, a.hillyness)
	a.collection = {}
	a.polygons = {}
end)

function Region:CreateCollection()
	for i = 1, self.space:GetCollectionSize() do
		tInsert(self.collection, self:CreateElement())
	end
end

function Region:CreateElement()
	local temperature = mRandom(self.temperatureMin, self.temperatureMax)
	local rainfall = mRandom(self.rainfallMin, self.rainfallMax)
	local hill = mRandom(1, 100) < self.hillyness
	local bestDist = 100
	local bestTerrain
	for i, terrain in pairs(TerrainDictionary) do
		local tdist = mAbs(terrain.temperature - temperature)
		local rdist = mAbs(terrain.rainfall - rainfall)
		local dist = tdist + rdist
		dist = dist - mRandom(1, 100)
		if dist < bestDist then
			bestDist = dist
			bestTerrain = terrain
		end
	end
	bestDist = 100
	local bestFeature
	for i, featureType in pairs(bestTerrain.features) do
		if featureType ~= featureFallout or self.space.falloutEnabled then
			local feature = FeatureDictionary[featureType]
			local tdist = mAbs(feature.temperature - temperature)
			local rdist = mAbs(feature.rainfall - rainfall)
			local dist = tdist + rdist
			if dist < bestDist then
				bestDist = dist
				bestFeature = feature
			end
		end
	end
	if bestFeature == nil or mRandom(1, 200) < bestDist then bestFeature = FeatureDictionary[bestTerrain.features[1]] end -- default to the first feature in the list
	local landOrHillsPlot = plotLand
	if hill and bestFeature.hill then landOrHillsPlot = plotHills end
	return { plotType = landOrHillsPlot, terrainType = bestTerrain.terrainType, featureType = bestFeature.featureType }
end

function Region:Fill()
	for i, polygon in pairs(self.polygons) do
		for hi, hex in pairs(polygon.hexes) do
			if hex.plotType ~= plotMountain and hex.plotType ~= plotOcean then
				local element
				local tried = {}
				local elementsTried = 0
				repeat
					local ei = mRandom(1, #self.collection)
					if tried[ei] == nil then
						elementsTried = elementsTried + 1
						tried[ei] = true
						element = self.collection[ei]
						if hex.plotType == plotHills and element.plotType ~= plotHills then element = nil end
					end
				until element ~= nil or elementsTried == #self.collection
				if element ~= nil then
					hex.plotType = element.plotType
					hex.terrainType = element.terrainType
					hex.featureType = element.featureType
				end
			end
		end
	end
end

------------------------------------------------------------------------------

Space = class(function(a)
	-- CONFIGURATION: --
	a.polygonCount = 140 -- how many polygons (map scale)
	a.minkowskiOrder = 3 -- higher == more like manhatten distance, lower (> 1) more like euclidian distance, < 1 weird cross shapes
	a.relaxations = 1 -- how many lloyd relaxations (higher number is greater polygon uniformity)
	a.liminalTolerance = 0.5 -- within this much, distances to other polygons are considered "equal"
	a.oceanNumber = 2 -- how many large ocean basins
	a.majorContinentNumber = 1 -- how many large continents per astronomy basin
	a.pangaea = false -- one big continent (except for a few large islands)
	a.islandRatio = 0.5 -- what part of the continent polygons are taken up by 1-3 polygon continents
	a.polarContinentChance = 3 -- out of ten chances
	a.hillChance = 4 -- how many possible mountains out of ten become a hill when expanding
	a.mountainRangeMaxEdges = 5 -- how many polygon edges long can a mountain range be
	a.mountainRatio = 0.04 -- how much of the land to be mountain tiles
	a.mountainRangeMult = 1.4 -- higher mult means more scattered mountains
	a.coastalPolygonChance = 2 -- out of ten, how often do possible coastal polygons become coastal?
	a.tinyIslandChance = 5 -- out of 100 tiles, how often do coastal shelves produce tiny islands (1-7 hexes)
	a.coastDiceAmount = 2
	a.coastDiceMin = 2
	a.coastDiceMax = 8
	a.coastAreaRatio = 0.25
	a.wrapX = true
	a.wrapY = false
	a.temperatureBase = 0
	a.temperatureRise = 100
	a.temperatureDice = 3
	a.rainfallBase = 0
	a.rainfallRise = 80
	a.rainfallDice = 3
	a.hillynessMin = 0
	a.hillynessMax = 20
	a.collectionSizeMin = 3
	a.collectionSizeMax = 12
	a.regionSizeMin = 1
	a.regionSizeMax = 3
	a.falloutEnabled = false
	----------------------------------
	-- DEFINITIONS: --
	a.oceans = {}
	a.continents = {}
	a.regions = {}
	a.polygons = {}
	a.edges = {}
	a.mountainRanges = {}
	a.bottomYPolygons = {}
	a.bottomXPolygons = {}
	a.topYPolygons = {}
	a.topXPolygons = {}
	a.hexes = {}
    a.mountainPlots = {}
    a.tinyIslandPlots = {}
    a.hillPlots = {}
    a.deepTiles = {}
    a.maxLiminality = 0
    a.liminalTileCount = 0
    a.culledPolygons = 0
end)

function Space:Compute()
    self.iW, self.iH = Map.GetGridSize()
    self.iA = self.iW * self.iH
    self.coastalMod = math.floor(math.sqrt(self.iA) / 30)
    self.nonOceanArea = self.iA
    self.w = self.iW - 1
    self.h = self.iH - 1
    self.halfWidth = self.w / 2
    self.halfHeight = self.h / 2
    -- need to adjust island chance so that bigger maps have about the same number of islands, and of the same relative size
    self.tinyIslandChance = mCeil(20000 / self.iA)
    self.minNonOceanPolygons = mCeil(self.polygonCount * 0.1)
    if not self.wrapX and not self.wrapY then self.minNonOceanPolygons = mCeil(self.polygonCount * 0.67) end
    self.nonOceanPolygons = self.polygonCount
	self.inverseMinkowskiOrder = 1 / self.minkowskiOrder
    EchoDebug(self.polygonCount .. " polygons", self.iA .. " hexes")
    self:InitPolygons()
    EchoDebug("polygons initialized")
    if self.relaxations > 0 then
    	for i = 1, self.relaxations do
    		EchoDebug("filling polygons pre-relaxation...")
        	self:FillPolygons(true)
    		print("relaxing polygons... (" .. i .. "/" .. self.relaxations .. ")")
        	self:RelaxPolygons()
        end
    end
    self:FillPolygons()
    EchoDebug("culling polygons...")
    self:CullPolygons()
    EchoDebug("computing polygon neighbors...")
    self:ComputePolygonNeighbors()
    EchoDebug("post-processing polygons...")
    self:PostProcessPolygons()
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
	EchoDebug("picking regions...")
	self:PickRegions()
end

function Space:ComputePlots()
	for pi, hex in pairs(self.hexes) do
		if hex.polygon.continentIndex == nil then
			if hex.polygon.coastal then
				local nearOcean = false
				for nhex, yes in pairs(hex.edgeWith) do
					if nhex.polygon.oceanIndex or nhex.polygon.continentIndex then
						hex.tooCloseForIsland = true
						break
					end
				end
				if not hex.tooCloseForIsland and (Map.Rand(100, "tiny island chance") <= self.tinyIslandChance or (hex.polygon.loneCoastal and not hex.polygon.hasTinyIslands)) then
					hex.plotType = plotLand
					tInsert(self.tinyIslandPlots, hex)
					hex.polygon.hasTinyIslands = true
				else
					hex.plotType = plotOcean
				end
			else
				hex.plotType = plotOcean
			end
		else
			-- near ocean trench?
			for nhex, yes in pairs(hex.edgeWith) do
				if nhex.polygon.oceanIndex ~= nil then
					hex.nearOceanTrench = true
					if hex.polygon.nearOcean then EchoDebug("CONTINENT NEAR OCEAN TRENCH??") end
					break
				end
			end
			if hex.nearOceanTrench then
				EchoDebug("continent plot near ocean trench")
				hex.plotType = plotOcean
			else
				if hex.mountainRange then
					hex.plotType = plotMountain
					tInsert(self.mountainPlots, hex)
				else
					hex.plotType = plotLand
				end
			end
		end
	end
	self:ExpandTinyIslands()
	self:AdjustMountains()
end

function Space:ComputeTerrain()
	for pi, hex in pairs(self.hexes) do
		if hex.plotType == plotOcean then
			-- near land?
			for i, nhex in pairs(hex:Neighbors()) do
				if nhex.plotType ~= plotOcean then
					hex.nearLand = true
				end
			end
			if hex.nearLand then
				hex.terrainType = terrainCoast
				self.coastArea = self.coastArea + 1
			else
				if hex.polygon.coastal then
					hex.terrainType = terrainCoast
					self.coastalPolygonArea = self.coastalPolygonArea + 1
				else
					hex.terrainType = terrainOcean
					tInsert(self.deepTiles, hex)
				end
			end
		elseif hex.plotType == plotLand then
			hex.terrainType = terrainGrass
		end
	end
	self:ExpandCoasts()
end

function Space:ComputeFeatures()
	-- testing ocean rifts
	for i, hex in pairs(self.hexes) do
		if hex.polygon.oceanIndex then
			if hex.terrainType == terrainOcean then
				-- hex.featureType = featureIce
			elseif hex.polygon.continentIndex then
				hex.featureType = featureIce
			else
				hex.featureType = featureJungle
				for i, nhex in pairs(hex:Neighbors()) do
					if nhex.plotType ~= plotOcean then
						EchoDebug("non ocean plot type: " .. nhex.plotType, nhex.tinyIsland)
					end
				end
				EchoDebug(hex.plotType, hex.nearLand)
			end
		end
		-- if hex.nearOceanTrench then hex.featureType = featureIce end
	end
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
	if not relax then EchoDebug(self.maxLiminality .. " maximum liminality", self.liminalTileCount .. " total liminal tiles") end
end

function Space:ComputePolygonNeighbors()
	for i, hex in pairs(self.hexes) do
		for ni, nhex in pairs(hex:Neighbors()) do -- 3 and 4 are are never there yet
			if nhex.polygon ~= hex.polygon then
				hex.polygon:SetNeighbor(nhex.polygon)
				if not hex.edgeWith[nhex] then
					hex.edginess = hex.edginess + 1
					hex.edgeWith[nhex] = true
				end
				if hex.polygon.edges[nhex.polygon] then
					tInsert(hex.polygon.edges[nhex.polygon].hexes, hex)
				else
					local edge = { polygons = { hex.polygon, nhex.polygon }, hexes = { hex } }
					hex.polygon.edges[nhex.polygon] = edge
					nhex.polygon.edges[hex.polygon] = edge
					tInsert(self.edges, edge)
				end
				--[[
				if not nhex.edgeWith[hex] then
					nhex.edginess = nhex.edginess + 1
					nhex.edgeWith[hex] = true
				end
				]]--
			end
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

function Space:PostProcessPolygons()
	self.polygonMinArea = self.iA
	self.polygonMaxArea = 0
	for i, polygon in pairs(self.polygons) do
		polygon.neighbors = {}
		for neighbor, yes in pairs(polygon.isNeighbor) do
			tInsert(polygon.neighbors, neighbor)
		end
		if polygon.area < self.polygonMinArea and polygon.area > 0 then
			self.polygonMinArea = polygon.area
		end
		if polygon.area > self.polygonMaxArea then
			self.polygonMaxArea = polygon.area
		end
	end
	EchoDebug("smallest polygon: " .. self.polygonMinArea, "largest polygon: " .. self.polygonMaxArea)
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
			--[[
			-- makes oceans really wide
			for i, neighbor in pairs(polygon.neighbors) do
				if not chosen[neighbor] and not neighbor:NearOther(oceanIndex, "oceanIndex") then
					chosen[neighbor] = true
					neighbor.oceanIndex = oceanIndex
					tInsert(ocean, neighbor)
					self.nonOceanArea = self.nonOceanArea - neighbor.area
					self.nonOceanPolygons = self.nonOceanPolygons - 1
				end
			end
			]]--
			polygon = highestNeigh or upNeighbors[mRandom(1, #upNeighbors)]
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
			polygon = upNeighbors[mRandom(1, #upNeighbors)]
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
end

function Space:PickMountainRanges()
	local edgeBuffer = {}
	for i, edge in pairs(self.edges) do
		tInsert(edgeBuffer, edge)
	end
	local mountainRangeRatio = self.mountainRatio * self.mountainRangeMult
	local prescribedEdges = mountainRangeRatio * #self.edges
	EchoDebug("prescribed mountain range edges: " .. prescribedEdges .. " of " .. #self.edges)
	local edgeCount = 0
	while #edgeBuffer > 0 and edgeCount < prescribedEdges do
		local edge
		repeat
			edge = tRemoveRandom(edgeBuffer)
			if (edge.polygons[1].continentIndex or edge.polygons[2].continentIndex) and not edge.mountains then
				break
			else
				edge = nil
			end
		until #edgeBuffer == 0
		if edge == nil then break end
		edge.mountains = true
		local range = { edge }
		edgeCount = edgeCount + 1
		repeat
			local nextPolygon = edge.polygons[mRandom(1, 2)]
			local nextEdges = {}
			for neighborPolygon, nextEdge in pairs(nextPolygon.edges) do
				if (nextEdge.polygons[1].continentIndex or nextEdge.polygons[2].continentIndex) and not nextEdge.mountains then
					tInsert(nextEdges, nextEdge)
				end
			end
			if #nextEdges == 0 then break end
			local nextEdge = nextEdges[mRandom(1, #nextEdges)]
			nextEdge.mountains = true
			tInsert(range, nextEdge)
			edgeCount = edgeCount + 1
			edge = nextEdge
		until #nextEdges == 0 or #range >= self.mountainRangeMaxEdges
		for i, e in pairs(range) do
			for hi, hex in pairs(e.hexes) do
				hex.mountainRange = true
			end
		end
		tInsert(self.mountainRanges, range)
	end
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
					polygon = candidate
					for candi, c in pairs(candidates) do
						tInsert(backlog, c)
					end
				until #region.polygons == size or #region.polygons == #continent.polygons
			end
			tInsert(self.regions, region)
		end
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
			end
		end
	end
	EchoDebug(self.coastalPolygonCount .. " coastal polygons")
end

function Space:ResizeMountains(prescribedArea)
	if #self.mountainPlots == prescribedArea then return end
	if #self.mountainPlots > prescribedArea then
		repeat
			local hex = tRemoveRandom(self.mountainPlots)
			hex.plotType = plotLand
		until #self.mountainPlots <= prescribedArea
	elseif #self.mountainPlots < prescribedArea then
		local noNeighbors = 0
		repeat
			local hex = self.mountainPlots[mRandom(1, #self.mountainPlots)]
			local neighbors = hex:Neighbors()
			local nhex
			repeat
				nhex = tRemoveRandom(neighbors)
			until nhex.plotType == plotLand or #neighbors == 0
			if nhex ~= nil and nhex.plotType == plotLand then
				if Map.Rand(10, "hill dice") < self.hillChance then
					nhex.plotType = plotHills
					tInsert(self.hillPlots, nhex)
				else
					nhex.plotType = plotMountain
					tInsert(self.mountainPlots, nhex)
				end
				noNeighbors = 0
			else
				noNeighbors = noNeighbors + 1
			end
		until #self.mountainPlots >= prescribedArea or noNeighbors > 20
	end
end

function Space:AdjustMountains()
	-- first expand them 1.5 times their size
	self:ResizeMountains(#self.mountainPlots * 1.5)
	-- then adjust to the right amount
	self.mountainArea = mCeil(self.mountainRatio * self.filledArea)
	self:ResizeMountains(self.mountainArea)
end

function Space:ExpandTinyIslands()
	local chance = mCeil(60 / self.tinyIslandChance)
	local toExpand = {}
	EchoDebug(#self.tinyIslandPlots .. " tiny islands")
	for i, hex in pairs(self.tinyIslandPlots) do
		for ni, nhex in pairs(hex:Neighbors()) do
			if nhex.plotType == plotOcean and not nhex.polygon.oceanIndex and not nhex.polygon.continentIndex then
				local okay = true
				for nni, nnhex in pairs(nhex:Neighbors()) do
					if nnhex ~= hex and (nnhex.polygon.oceanIndex or nnhex.polygon.continentIndex) then
						okay = false
						break
					end
				end
				if okay and Map.Rand(100, "tiny island expansion") < chance then
					tInsert(toExpand, nhex)
				end
			end
		end
	end
	for i, hex in pairs(toExpand) do
		hex.plotType = plotLand
		hex.tinyIsland = true
		tInsert(self.tinyIslandPlots, hex)
	end
	EchoDebug(#self.tinyIslandPlots .. " tiny islands")
end

function Space:ExpandCoasts()
	EchoDebug(self.coastArea .. " coastal hexes before expansion")
	local d = 1
	repeat 
		local makeCoast = {}
		local potential = 0
		for i, hex in pairs(self.deepTiles) do
			if hex.plotType == plotOcean and hex.terrainType == terrainOcean and hex.polygon.oceanIndex == nil then
				local nearcoast
				for n, nhex in pairs(hex:Neighbors()) do
					if nhex.terrainType == terrainCoast then
						nearcoast = true
						break
					end
				end
				if nearcoast then
					potential = potential + 1
					if Map.Rand(hex.polygon.coastExpansionDice[d], "expand coast?") == 0 then
						makeCoast[hex] = nearcoast
					end
				end
			end
		end
		for hex, nearcoast in pairs(makeCoast) do
			hex.terrainType = terrainCoast
			hex.expandedCoast = true
			self.coastArea = self.coastArea + 1
		end
		d = d + 1
		if d > self.coastDiceAmount then d = 1 end
	until self.coastArea >= self.prescribedCoastArea or potential == 0
	EchoDebug(self.coastArea .. " coastal hexes after expansion")
end

----------------------------------
-- INTERNAL FUNCTIONS: --

function Space:GetTemperature(latitude)
	local temp = diceRoll(self.temperatureDice, false, self.temperatureRise) + self.temperatureBase
	return mFloor(temp)
end

function Space:GetRainfall(latitude)
	local rain = diceRoll(self.rainfallDice, false, self.rainfallRise) + self.rainfallBase
	return mFloor(rain)
end

function Space:GetHillyness()
	return mRandom(self.hillynessMin, self.hillynessMax)
end

function Space:GetCollectionSize()
	return mRandom(self.collectionSizeMin, self.collectionSizeMax)
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
		Name = "Fantastical classes-dev",
		Description = "Draws voronoi.",
		IconIndex = 5,
	}
end

--[[
function GetMapInitData(worldSize)

end
]]--

local mySpace

function GeneratePlotTypes()
	SetConstants()
    print("Setting Plot Types (Fantastical) ...")
    mySpace = Space()
    mySpace:Compute()
    mySpace:ComputePlots()
    mySpace:ComputeTerrain()
	mySpace:ComputeFeatures()
	mySpace:FillRegions()
    mySpace:SetPlots()
    -- local args = { bExpandCoasts = false }
    -- GenerateCoasts(args)
end

function GenerateTerrain()
    print("Setting Terrain Types (Fantastical) ...")
	mySpace:SetTerrains()
end

function AddFeatures()
	print("Setting Feature Types (Fantastical) ...")
	mySpace:SetFeatures()
end

function SetTerrainTypes(terrainTypes)
	print("DON'T USE THIS Terrain Types (Fantastical)");
	for i, plot in Plots() do
		plot:SetTerrainType(self.hexes[i+1].terrainType, false, false)
		-- MapGenerator's SetPlotTypes uses i+1, but MapGenerator's SetTerrainTypes uses just i. wtf.
	end
end

function AddLakes()
	print("Adding Lakes (Fantastical)")
	--[[
	
	local numLakesAdded = 0;
	local lakePlotRand = GameDefines.LAKE_PLOT_RAND;
	lakePlotRand = lakePlotRand + (lakePlotRand * ismuthChance)
	for i, plot in Plots() do
		if not plot:IsWater() then
			if not plot:IsCoastalLand() then
				if not plot:IsRiver() then
					local r = Map.Rand(lakePlotRand, "Fantasy AddLakes");
					if r == 0 then
						plot:SetArea(-1);
						plot:SetPlotType(plotOcean);
						numLakesAdded = numLakesAdded + 1;
					end
				end
			end
		end
	end
	
	-- this is a minimalist update because lakes have been added
	if numLakesAdded > 0 then
		print(tostring(numLakesAdded).." lakes added")
		Map.CalculateAreas();
	end
	]]--
end

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
	if iNumCoast < 4 then
		return
	end
	-- This site is in the water, with at least some of the water plots being coast, so it's good.
	table.insert(self.reef_list, plotIndex);
end

function AssignStartingPlots:CanBeKrakatoa(x, y)
	-- Checks a candidate plot for eligibility to be Krakatoa the volcano.
	local plot = Map.GetPlot(x, y);
	-- Check the center plot, which must be land surrounded on all sides by ocean. (edited for fantastical)
	if plot:IsWater() then return end

	for loop, direction in ipairs(self.direction_types) do
		local adjPlot = Map.PlotDirection(x, y, direction)
		if adjPlot:IsWater() == false then
			return
		end
	end
	
	-- Surrounding tiles are all ocean water, not lake, and free of Feature Ice, so it's good.
	local iW, iH = Map.GetGridSize();
	local plotIndex = y * iW + x + 1;
	table.insert(self.krakatoa_list, plotIndex);
end