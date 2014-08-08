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
local mTwicePi = math.pi * 2
local mAtan2 = math.atan2
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

local function AngleAtoB(x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1
	return mAtan2(-dy, dx)
end

local function AngleDist(angle1, angle2)
	return mAbs((angle1 + mPi -  angle2) % mTwicePi - mPi)
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

local OptionDictionary = {
	{ name = "World Wrap", sortpriority = 1, keys = { "wrapX", "wrapY" }, default = 1,
	values = {
			[1] = { name = "Globe (Wraps East-West)", values = {true, false} },
			[2] = { name = "Region (Does Not Wrap)", values = {false, false} },
			-- [3] = { name = "Donut (Horizontal and Vertical Wrapping)", values = {true, true} },
			-- sadly wrapY does not work
		}
	},
	{ name = "Oceans", sortpriority = 2, keys = { "oceanNumber", }, default = 2,
	values = {
			[1] = { name = "One", values = {1} },
			[2] = { name = "Two", values = {2} },
			[3] = { name = "Three", values = {3} },
			[4] = { name = "Four", values = {4} },
		}
	},
	{ name = "Continents/Ocean", sortpriority = 3, keys = { "majorContinentNumber", }, default = 1,
	values = {
			[1] = { name = "One", values = {1} },
			[2] = { name = "Two", values = {2} },
			[3] = { name = "Three", values = {3} },
			[4] = { name = "Four", values = {4} },
		}
	},
	{ name = "Islands", sortpriority = 4, keys = { "tinyIslandChance", "coastalPolygonChance", "islandRatio", }, default = 2,
	values = {
			[1] = { name = "Few", values = {10, 1, 0.25} },
			[2] = { name = "Some", values = {33, 2, 0.5} },
			[3] = { name = "Many", values = {80, 3, 0.75} },
		}
	},
	{ name = "World Age", sortpriority = 5, keys = { "mountainRatio", "hillynessMax" }, default = 4,
	values = {
			[1] = { name = "1 Billion Years", values = {0.25, 75} },
			[2] = { name = "2 Billion Years", values = {0.16, 60} },
			[3] = { name = "3 Billion Years", values = {0.08, 50} },
			[4] = { name = "4 Billion Years", values = {0.04, 40} },
			[5] = { name = "5 Billion Years", values = {0.02, 30} },
			[6] = { name = "6 Billion Years", values = {0.0, 20} },
		}
	},
	{ name = "Climate Realism", sortpriority = 6, keys = { "useMapLatitudes" }, default = 1,
	values = {
			[1] = { name = "Off", values = {false} },
			[2] = { name = "On", values = {true} },
		}
	},
	{ name = "Temperature", sortpriority = 7, keys = { "polarExponent", "temperatureMin", "temperatureMax" }, default = 3,
	values = {
			[1] = { name = "Ice Age", values = {3, 0, 50} },
			[2] = { name = "Cool", values = {1.4, 0, 85} },
			[3] = { name = "Temperate", values = {1.2, 0, 100} },
			[4] = { name = "Warm", values = {1.1, 5, 100} },
			[5] = { name = "Hot", values = {1.0, 20, 100} },
		}
	},
	{ name = "Rainfall", sortpriority = 8, keys = { "rainfallMidpoint" }, default = 3,
	values = {
			[1] = { name = "Wasteland", values = {13} },
			[2] = { name = "Arid", values = {35} },
			[3] = { name = "Normal", values = {50} },
			[4] = { name = "Wet", values = {60} },
			[5] = { name = "Waterlogged", values = {90} },
		}
	},
	{ name = "Fallout", sortpriority = 9, keys = { "falloutEnabled" }, default = 1,
	values = {
			[1] = { name = "Off", values = {false} },
			[2] = { name = "On", values = {true} },
		}
	},
}

local function GetCustomOptions()
	local custOpts = {}
	for i, option in pairs(OptionDictionary) do
		local opt = { Name = option.name, SortPriority = option.sortpriority, DefaultValue = option.default, Values = {} }
		for n, value in pairs(option.values) do
			opt.Values[n] = value.name
		end
		tInsert(custOpts, opt)
	end
	return custOpts
end

------------------------------------------------------------------------------

-- so that these constants can be shorter to access and consistent
local DirW, DirNW, DirNE, DirE, DirSE, DirSW = 1, 2, 3, 4, 5, 6
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
		[terrainGrass] = { temperature = {40, 100, 60}, rainfall = {20, 100, 50}, features = { featureNone, featureForest, featureJungle, featureMarsh, featureFallout } },
		[terrainPlains] = { temperature = {20, 60}, rainfall = {20, 100, 40}, features = { featureNone, featureForest, featureFallout } },
		[terrainDesert] = { temperature = {20, 100}, rainfall = {0, 20, 0}, features = { featureNone, featureOasis, featureFallout } },
		[terrainTundra] = { temperature = {0, 30, 5}, rainfall = {20, 100, 45}, features = { featureNone, featureForest, featureFallout } },
		[terrainSnow] = { temperature = {0, 20, 0}, rainfall = {0, 20}, features = { featureNone, featureFallout } },
	}

	-- percent is how likely it is to show up in a region's collection (if it's the closest rainfall and temperature)
	-- limitRatio is what fraction of a region's hexes may have this feature (-1 is no limit)

	FeatureDictionary = {
		[featureNone] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 100, limitRatio = -1, hill = true },
		[featureForest] = { temperature = {0, 85, 30}, rainfall = {50, 100, 90}, percent = 100, limitRatio = 0.85, hill = true },
		[featureJungle] = { temperature = {85, 100}, rainfall = {75, 100}, percent = 100, limitRatio = 0.85, hill = true, terrainType = terrainPlains },
		[featureMarsh] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 10, limitRatio = 0.33, hill = false },
		[featureOasis] = { temperature = {50, 100}, rainfall = {0, 100}, percent = 20, limitRatio = 0.01, hill = false },
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
	self.polygon = self:ClosestPolygon(relax)
	self.space.hexes[self.index] = self
	tInsert(self.polygon.hexes, self)
	if not relax then
		self.plot = Map.GetPlotByIndex(self.index-1)
		self.latitude = self.plot:GetLatitude()
		if not self.space.wrapX then
			self.latitude = self.space:RealmLatitude(self.y, self.latitude)
		end
	end
end

function Hex:SubPlace(relax, subPolygons)
	self.subPolygon = self:ClosestPolygon(relax, subPolygons)
	self:InsidePolygon(self.subPolygon)
end

function Hex:FinalPlace()
	self:InsidePolygon(self.polygon)
end

function Hex:InsidePolygon(polygon)
	tInsert(polygon.hexes, self)
	if self.x < polygon.minX then polygon.minX = self.x end
	if self.y < polygon.minY then polygon.minY = self.y end
	if self.x > polygon.maxX then polygon.maxX = self.x end
	if self.y > polygon.maxY then polygon.maxY = self.y end
	polygon:CheckBottomTop(self.x, self.y)
end

function Hex:Adjacent(direction)
	local x, y = self.x, self.y
	if direction == 0 or direction == nil then return hex end
	local nx = x
	local ny = y
	local odd = y % 2
	if direction == 1 then -- West
		nx = x - 1
	elseif direction == 2 then -- Northwest
		nx = x - 1 + odd
		ny = y + 1
	elseif direction == 3 then -- Northeast
		nx = x + odd
		ny = y + 1
	elseif direction == 4 then -- East
		nx = x + 1
	elseif direction == 5 then -- Southeast
		nx = x + odd
		ny = y - 1
	elseif direction == 6 then -- Southwest
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
		if nhex ~= nil then neighbors[direction] = nhex end
	end
	return neighbors
end

function Hex:ClosestPolygon(relax, polygons)
	local dists = {}
	local closest_distance = self.space.w
	local closest_polygon
	-- find the closest point to this point
	polygons = polygons or self.space.polygons
	for i = 1, #polygons do
		local polygon = polygons[i]
		if not polygon.deserter then
			dists[i] = self.space:SquaredDistance(polygon.x, polygon.y, self.x, self.y)
			if i == 1 or dists[i] < closest_distance then
				closest_distance = dists[i]
				closest_polygon = polygon
			end
		end
	end
	return closest_polygon
end

function Hex:ComputeSubPolygonNeighbors()
	for ni, nhex in pairs(self:Neighbors()) do -- 3 and 4 are are never there yet?
		if nhex.subPolygon ~= self.subPolygon then
			self.subPolygon:SetNeighbor(nhex.subPolygon)
			if self.subPolygon.edges[nhex.subPolygon] then
				local subEdge = self.subPolygon.edges[nhex.subPolygon]
				tInsert(subEdge.hexes, self)
				if self.x > subEdge.maxX then subEdge.maxX = self.x end
				if self.x < subEdge.minX then subEdge.minX = self.x end
				if self.y > subEdge.maxY then subEdge.maxY = self.y end
				if self.y < subEdge.minY then subEdge.minY = self.y end
			else
				local subEdge = { polygons = { self.subPolygon, nhex.subPolygon }, hexes = { self }, onEdge = {}, connections = {}, lowConnections = {}, highConnections = {}, hexOfRiver = {}, path = {}, minX = self.x, maxX = self.x, minY = self.y, maxY = self.y }
				self.subPolygon.edges[nhex.subPolygon] = subEdge
				nhex.subPolygon.edges[self.subPolygon] = subEdge
				tInsert(self.space.subEdges, subEdge)
			end
			self.subPolygon.edges[nhex.subPolygon].onEdge[self] = nhex
			if direction == DirE or direction == DirSE or direction == DirSW then
				if self.subPolygon.edges[nhex.subPolygon].hexOfRiver[self] == nil then self.subPolygon.edges[nhex.subPolygon].hexOfRiver[self] = {} end
				self.subPolygon.edges[nhex.subPolygon].hexOfRiver[self][direction-3] = true
			end
		end
	end
end

function Hex:ComputeNeighbors()
	for direction, nhex in pairs(self:Neighbors()) do -- 3 and 4 are are never there yet?
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
				local edge = self.polygon.edges[nhex.polygon]
				tInsert(edge.hexes, self)
				if self.x > edge.maxX then edge.maxX = self.x end
				if self.x < edge.minX then edge.minX = self.x end
				if self.y > edge.maxY then edge.maxY = self.y end
				if self.y < edge.minY then edge.minY = self.y end
			else
				local edge = { polygons = { self.polygon, nhex.polygon }, hexes = { self }, onEdge = {}, connections = {}, lowConnections = {}, highConnections = {}, hexOfRiver = {}, path = {}, minX = self.x, maxX = self.x, minY = self.y, maxY = self.y }
				self.polygon.edges[nhex.polygon] = edge
				nhex.polygon.edges[self.polygon] = edge
				tInsert(self.space.edges, edge)
			end
			self.polygon.edges[nhex.polygon].onEdge[self] = nhex
			if direction == DirE or direction == DirSE or direction == DirSW then
				if self.polygon.edges[nhex.polygon].hexOfRiver[self] == nil then self.polygon.edges[nhex.polygon].hexOfRiver[self] = {} end
				self.polygon.edges[nhex.polygon].hexOfRiver[self][direction-3] = true
			end
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
	--[[
	if self.ofRiver then
		self.plot:SetFeatureType(featureFallout)
		return
	end
	]]--
	if self.featureType == nil then return end
	if self.plot == nil then return end
	self.plot:SetFeatureType(self.featureType)
end

function Hex:SetRiver()
	if self.plot == nil then return end
	if not self.ofRiver then return end
	if self.ofRiver[DirW] then self.plot:SetWOfRiver(true, self.riverDirection) end
	if self.ofRiver[DirNW] then self.plot:SetNWOfRiver(true, self.riverDirection) end
	if self.ofRiver[DirNE] then self.plot:SetNEOfRiver(true, self.riverDirection) end
end

------------------------------------------------------------------------------

Polygon = class(function(a, space, x, y, superPolygon)
	a.space = space
	a.x = x or Map.Rand(space.iW, "random x")
	a.y = y or Map.Rand(space.iH, "random y")
	if space.useMapLatitudes then
		local plot = Map.GetPlot(x, y)
		a.latitude = plot:GetLatitude()
		if not space.wrapX then
			a.latitude = space:RealmLatitude(a.y, a.latitude)
		end
	end
	a.subPolygons = {}
	a.hexes = {}
	a.edges = {}
	a.vertices = {}
	a.isNeighbor = {}
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

function Polygon:FloodFillSuperPolygon(floodIndex, superPolygon)
	superPolygon = superPolygon or self.superPolygon
	if self.superPolygon ~= superPolygon or self.flooded then return false end
	if self.space.floods[floodIndex] == nil then self.space.floods[floodIndex] = {} end
	tInsert(self.space.floods[floodIndex], self)
	self.flooded = true
	for i, neighbor in pairs(self.neighbors) do
		neighbor:FloodFillSuperPolygon(floodIndex, superPolygon)
	end
	return true
end

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
		if self.space.useMapLatitudes then
			self.latitude = Map.GetPlot(self.x, self.y):GetLatitude()
			if not self.space.wrapX then
				self.latitude = self.space:RealmLatitude(self.y, self.latitude)
			end
		end
	end
	self.minX, self.minY, self.maxX, self.maxY = space.w, space.h, 0, 0
	self.hexes = {}
end

function Polygon:CheckBottomTop(x, y)
	local space = self.space
	if y == 0 and self.y < space.halfHeight then
		self.bottomY = true
		if not self.superPolygon then tInsert(space.bottomYPolygons, self) end
	end
	if x == 0 and self.x < space.halfWidth then
		self.bottomX = true
		if not self.superPolygon then tInsert(space.bottomXPolygons, self) end
	end
	if y == space.h and self.y >= space.halfHeight then
		self.topY = true
		if not self.superPolygon then tInsert(space.topYPolygons, self) end
	end
	if x == space.w and self.x >= space.halfWidth then
		self.topX = true
		if not self.superPolygon then tInsert(space.topXPolygons, self) end
	end
end

function Polygon:NearOther(value, key)
	if key == nil then key = "continent" end
	for ni, neighbor in pairs (self.neighbors) do
		if neighbor[key] ~= nil and neighbor[key] ~= value then
			return true
		end
	end
	return false
end

function Polygon:Subdivide()
	-- initialize subpolygons by picking locations randomly from the polygon's hexes
	local hexBuffer = tDuplicate(self.hexes)
	local n = 0
	local subPolygons = {}
	while #hexBuffer > 0 and n < self.space.subPolygonCount do
		local hex = tRemoveRandom(hexBuffer)
		if not hex.subPolygon then
			local subPolygon = Polygon(self.space, hex.x, hex.y, self)
			subPolygon.superPolygon = self
			tInsert(subPolygons, subPolygon)
			n = n + 1
		end
	end
	for r = 1, self.space.subPolygonRelaxations + 1 do
		-- fill the subpolygons with hexes
		for h, hex in pairs(self.hexes) do
			hex:SubPlace(false, subPolygons)
		end
		-- relax subpolygons
		if r <= self.space.subPolygonRelaxations then
			for i, subPolygon in pairs(subPolygons) do
				subPolygon:RelaxToCentroid()
			end
		end
	end
	-- populate space's subpolygon table (don't include those w/o hexes)
	for i, subPolygon in pairs(subPolygons) do
		if #subPolygon.hexes > 0 then
			tInsert(self.space.subPolygons, subPolygon)
			if #subPolygon.hexes > self.space.biggestSubPolygon then
				self.space.biggestSubPolygon = #subPolygon.hexes
			elseif #subPolygon.hexes < self.space.smallestSubPolygon then
				self.space.smallestSubPolygon = #subPolygon.hexes
			end
		end
	end
end

function Polygon:PopulateNeighbors()
	self.neighbors = {}
	for neighbor, yes in pairs(self.isNeighbor) do
		tInsert(self.neighbors, neighbor)
	end
end

function Polygon:PickTinyIslands()
	if (self.bottomX or self.topX) and self.oceanIndex and not self.space.wrapX then return end
	if (self.bottomY or self.topY) and self.oceanIndex and not self.space.wrapX then return end
	for i, subPolygon in pairs(self.subPolygons) do
		local tooCloseForIsland = false
		if not tooCloseForIsland then
			for i, neighbor in pairs(subPolygon.neighbors) do
				if neighbor.superPolygon.continent or self.oceanIndex ~= neighbor.superPolygon.oceanIndex or neighbor.tinyIsland then
					tooCloseForIsland = true
					break
				end
				for nn, neighneigh in pairs(neighbor.neighbors) do
					if self.oceanIndex ~= neighneigh.superPolygon.oceanIndex then
						tooCloseForIsland = true
						break
					end
				end
				if tooCloseForIsland then break end
			end
		end
		local chance = self.space.tinyIslandChance
		if self.oceanIndex then chance = chance * 1.5 end
		if not tooCloseForIsland and (Map.Rand(100, "tiny island chance") <= chance or ((self.loneCoastal or self.oceanIndex) and not self.hasTinyIslands)) then
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
	-- EchoDebug(self.latitude, self.temperatureMin, self.temperatureMax, self.rainfallMin, self.rainfallMax, self.mountainousness, self.lakeyness, self.hillyness)
	-- create the collection
	self.size, self.subSize = self.space:GetCollectionSize()
	local subPolys = 0
	for i, polygon in pairs(self.polygons) do
		subPolys = subPolys + #polygon.subPolygons
	end
	self.size = mMin(self.size, subPolys) -- make sure there aren't more collections than subpolygons in the region
	self.totalSize = self.size * self.subSize
	-- EchoDebug(self.size, self.subSize, self.totalSize, subPolys)
	-- create lists of possible temperature and rainfall
	local tempList = {}
	local rainList = {}
	local tInc = (self.temperatureMax - self.temperatureMin) / self.size
	local rInc = (self.rainfallMax - self.rainfallMin) / self.size
	local tSubInc = tInc / (self.subSize - 1)
	local rSubInc = rInc / (self.subSize - 1)
	for i = 1, self.size do
		local temperature = self.temperatureMin + (tInc * (i-1))
		local rainfall = self.rainfallMin + (rInc * (i-1))
		local temps = {}
		local rains = {}
		if self.subSize == 1 then
			temps = { temperature + (tInc / 2) }
			rains = { rainfall + (rInc / 2) }
		else
			for si = 1, self.subSize do
				local temp = temperature + (tSubInc * (si-1))
				local rain = rainfall + (rSubInc * (si-1))
				tInsert(temps, temp)
				tInsert(rains, rain)
			end
		end
		tInsert(tempList, temps)
		tInsert(rainList, rains)
	end
	-- pick randomly from lists of temperature and rainfall to create elements in the collection
	for i = 1, self.size do
		local lake = mRandom(1, 100) < self.lakeyness
		local temps = tRemoveRandom(tempList)
		local rains = tRemoveRandom(rainList)
		-- EchoDebug("lists", i, self.size, #tempList, #rainList, self.subSize, #temps, #rains)
		local subCollection = {}
		for si = 1, self.subSize do
			-- EchoDebug("sublists", si, #temps, #rains, self.subSize)
			local temperature = tRemoveRandom(temps)
			local rainfall = tRemoveRandom(rains)
			tInsert(subCollection, self:CreateElement(temperature, rainfall, lake))
		end
		tInsert(self.collection, subCollection)
	end
end

function Region:GetLatitude()
	local polygon = tGetRandom(self.polygons)
	return mFloor(polygon.latitude)
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
	a.subPolygonFlopPercent = 18 -- out of 100 subpolygons, how many flop to another polygon
	a.subPolygonRelaxations = 1 -- how many lloyd relaxations for subpolygons (higher number is greater polygon uniformity)
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
	a.majorRiverRatio = 1.0 -- ratio of total major rivers possible to actually create
	a.minorRiverRatio = 1.0 -- ratio of total minor rivers possible to actually create
	a.minorRiverLengthMin = 5
	a.minorRiverLengthMax = 20
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
	a.atollTemperature = 75 -- this temperature and above creates atolls
	a.atollPercent = 4 -- of 100 hexes, how often does atoll temperature produce atolls
	a.polarExponent = 1.2 -- exponent. lower exponent = smaller poles (somewhere between 0 and 2 is advisable)
	a.rainfallMidpoint = 50 -- 25 means rainfall varies from 0 to 50, 75 means 50 to 100, 50 means 0 to 100.
	a.temperatureMin = 0 -- lowest temperature possible (plus or minus intraregionTemperatureDeviation)
	a.temperatureMax = 100 -- highest temprature possible (plus or minus intraregionTemperatureDeviation)
	a.temperatureDice = 2 -- temperature probability distribution: 1 is flat, 2 is linearly weighted to the center like /\, 3 is a bell curve _/-\_, 4 is a skinnier bell curve
	a.intraregionTemperatureDeviation = 20 -- how much at maximum can a region's temperature vary within itself
	a.rainfallDice = 1 -- just like temperature above
	a.intraregionRainfallDeviation = 30 -- just like temperature above
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
	a.subEdges = {}
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

function Space:SetOptions()
	for optionNumber, option in ipairs(OptionDictionary) do
		local optionChoice = Map.GetCustomOption(optionNumber)
		for valueNumber, key in ipairs(option.keys) do
			EchoDebug(key, optionNumber, valueNumber, optionChoice, option.values[optionChoice].values[valueNumber])
			self[key] = option.values[optionChoice].values[valueNumber]
		end
	end
end

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
    if self.useMapLatitudes then
    	self.realmHemisphere = mRandom(1, 2)
    end
	self.polarExponentMultiplier = 90 ^ self.polarExponent
	if self.rainfallMidpoint > 50 then
		self.rainfallPlusMinus = 100 - self.rainfallMidpoint
	else
		self.rainfallPlusMinus = self.rainfallMidpoint
	end
	self.rainfallMax = self.rainfallMidpoint + self.rainfallPlusMinus
	self.rainfallMin = self.rainfallMidpoint - self.rainfallPlusMinus
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
    EchoDebug("culling empty polygons...")
    self:CullPolygons()
    EchoDebug("subdividing polygons...")
    self:SubdividePolygons()
    EchoDebug("determining subpolygon neighbors...")
    self:ComputeSubPolygonNeighbors()
    EchoDebug("flip-flopping subpolygons...")
    self:FlipFlopSubPolygons()
    EchoDebug("flood-filling fake polygons...")
    self:FloodFillFakePolygons()
    EchoDebug("populating polygon tables...")
    self:FinalFillPolygons()
    EchoDebug("culling real polygons...")
    self:CullPolygons()
    EchoDebug("computing polygon neighbors...")
    self:ComputePolygonNeighbors()
    EchoDebug("finding edge connections...")
    self:FindEdgeConnections()
    EchoDebug("computing edge paths...")
    self:ComputeEdgePaths()
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
	EchoDebug("finding potential rivers...")
	self:FindPotentialRivers()
	EchoDebug("picking major rivers...")
	self:PickMajorRivers()
	EchoDebug("picking minor rivers...")
	self:PickMinorRivers()
	EchoDebug("filling regions...")
	self:FillRegions()
	EchoDebug("computing landforms...")
	self:ComputeLandforms()
	EchoDebug("computing ocean temperatures...")
	self:ComputeOceanTemperatures()
	EchoDebug("computing coasts...")
	self:ComputeCoasts()
	EchoDebug("computing rivers...")
	self:ComputeRivers()
end

function Space:ComputeLandforms()
	for pi, hex in pairs(self.hexes) do
		if hex.polygon.continent ~= nil then
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
		if hex.polygon.continent == nil then
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
		if (not subPolygon.superPolygon.continent or subPolygon.lake) and not subPolygon.tinyIsland then
			if subPolygon.superPolygon.coastal then
				subPolygon.coast = true
				subPolygon.oceanTemperature = subPolygon.superPolygon.region.temperatureAvg
			else
				for ni, neighbor in pairs(subPolygon.neighbors) do
					if neighbor.superPolygon.continent or neighbor.tinyIsland then
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
					if (ice and self:GimmeIce(subPolygon.oceanTemperature)) or (self.useMapLatitudes and self.polarExponent >= 1.0 and (hex.y == self.h or hex.y == 0)) then
						hex.featureType = featureIce
					elseif atoll and mRandom(1, 100) < self.atollPercent then
						hex.featureType = featureAtoll
					end
					hex.terrainType = terrainCoast
				end
			else
				for hi, hex in pairs(subPolygon.hexes) do
					if (ice and self:GimmeIce(subPolygon.oceanTemperature)) or (self.useMapLatitudes and self.polarExponent >= 1.0 and (hex.y == self.h or hex.y == 0)) then hex.featureType = featureIce end
					hex.terrainType = terrainOcean
				end
			end
		end
	end
end

function Space:ComputeRivers()
	for i, river in pairs(self.majorRivers) do
		for e, edge in ipairs(river) do
			local low
			if river[e+1] ~= nil then
				low = edge.highConnections[river[e+1]]
			elseif river[e-1] ~= nil then
				low = edge.lowConnections[river[e-1]]
			else
				low = not edge.drainsHigh
			end
			local from, to, inc = 1, #edge.path, 1
			if low then from, to, inc = #edge.path, 1, -1 end
			for p = from, to, inc do
				local part = edge.path[p]
				for h, hex in pairs(part.hexes) do
					if edge.hexOfRiver[hex] then
						if hex.ofRiver == nil then hex.ofRiver = {} end
						for direction, yes in pairs(edge.hexOfRiver[hex]) do
							hex.ofRiver[direction] = true
						end
						hex.riverDirection = part.nextDirection
					end
				end
			end
		end
	end
	for mr, majorRiver in pairs(self.majorRivers) do
		for r, river in pairs(self.minorRivers[majorRiver]) do
			for e, edge in ipairs(river) do
				local low
				if river[e+1] ~= nil then
					low = edge.lowConnections[river[e+1]]
				elseif river[e-1] ~= nil then
					low = edge.highConnections[river[e-1]]
				else
					low = self.minorRiverForksLowHigh[river]
				end
				local from, to, inc = 1, #edge.path, 1
				if low then from, to, inc = #edge.path, 1, -1 end
				for p = from, to, inc do
					local part = edge.path[p]
					for h, hex in pairs(part.hexes) do
						if edge.hexOfRiver[hex] then
							if hex.ofRiver == nil then hex.ofRiver = {} end
							for direction, yes in pairs(edge.hexOfRiver[hex]) do
								hex.ofRiver[direction] = true
							end
							hex.riverDirection = part.nextDirection
						end
					end
				end
			end
		end
	end
end

function Space:ComputeOceanTemperatures()
	for p, polygon in pairs(self.polygons) do
		if polygon.continent == nil then
			if not self.useMapLatitudes and polygon.oceanIndex == nil then
				local latSum = 0
				local div = 0
				for n, neighbor in pairs(polygon.neighbors) do
					if neighbor.continent then
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

function Space:SetRivers()
	for i, hex in pairs(self.hexes)do
		hex:SetRiver()
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
	EchoDebug(self.culledPolygons .. " polygons culled", #self.polygons .. " remaining")
end

function Space:SubdividePolygons()
	self.smallestSubPolygon = 1000
	self.biggestSubPolygon = 0
	for i, polygon in pairs(self.polygons) do
		polygon:Subdivide()
		polygon.hexes = {}
	end
	EchoDebug("smallest subpolygon: " .. self.smallestSubPolygon, "biggest subpolygon: " .. self.biggestSubPolygon)
end

function Space:ComputeSubPolygonNeighbors()
	for i, hex in pairs(self.hexes) do
		hex:ComputeSubPolygonNeighbors()
	end
	for i, subPolygon in pairs(self.subPolygons) do
		subPolygon:PopulateNeighbors()
	end
end

function Space:FlipFlopSubPolygons()
	for i, subPolygon in pairs(self.subPolygons) do
		-- see if it's next to another superpolygon
		local adjacent = {}
		for n, neighbor in pairs(subPolygon.neighbors) do
			if neighbor.superPolygon ~= subPolygon.superPolygon then
				adjacent[neighbor.superPolygon] = true
			end
		end
		local choices = {}
		for superPolygon, yes in pairs(adjacent) do
			tInsert(choices, superPolygon)
		end
		if #choices > 0 and not subPolygon.flopped and mRandom(1, 100) < self.subPolygonFlopPercent then
			-- flop the subpolygon
			local superPolygon = tGetRandom(choices)
			for h, hex in pairs(subPolygon.hexes) do
				hex.polygon = superPolygon
			end
			subPolygon.superPolygon = superPolygon
			subPolygon.flopped = true
		end
	end
	-- fix stranded single subpolygons
	for i, subPolygon in pairs(self.subPolygons) do
		local hasFriendlyNeighbors = false
		local unfriendly = {}
		for n, neighbor in pairs(subPolygon.neighbors) do
			if neighbor.superPolygon == subPolygon.superPolygon then
				hasFriendlyNeighbors = true
				break
			else
				unfriendly[neighbor.superPolygon] = true
			end
		end
		if not hasFriendlyNeighbors then
			local uchoices = {}
			for superPolygon, yes in pairs(unfriendly) do
				tInsert(uchoices, superPolygon)
			end
			subPolygon.superPolygon = tGetRandom(uchoices)
			for h, hex in pairs(subPolygon.hexes) do
				hex.polygon = subPolygon.superPolygon
			end
			subPolygon.flopped = true
		end
	end
end

function Space:FloodFillFakePolygons()
	-- redo polygons based on flood filling subpolygons by superpolygon
	floodIndex = 1
	self.floods = {}
	for i, subPolygon in pairs(self.subPolygons) do
		if subPolygon:FloodFillSuperPolygon(floodIndex) then
			floodIndex = floodIndex + 1
		end
	end
	for fi, flood in pairs(self.floods) do
		local randCenter = tGetRandom(flood)
		local superPoly = Polygon(self, randCenter.x, randCenter.y)
		tInsert(self.polygons, superPoly)
		local xSum, ySum, n = 0, 0, 0
		for s, subPoly in pairs(flood) do
			subPoly.superPolygon = superPoly
			for h, hex in pairs(subPoly.hexes) do
				hex.polygon = superPoly
				xSum = xSum + hex.x
				ySum = ySum + hex.y
				n = n + 1
			end
		end
		superPoly.x = xSum / n
		superPoly.y = ySum / n
	end
end

function Space:FinalFillPolygons()
	for i, subPolygon in pairs(self.subPolygons) do
		tInsert(subPolygon.superPolygon.subPolygons, subPolygon)
		for i, hex in pairs(subPolygon.hexes) do
			hex:FinalPlace()
		end
	end
end

function Space:ComputePolygonNeighbors()
	for i, hex in pairs(self.hexes) do
		hex:ComputeNeighbors()
	end
	self.polygonMinArea = self.iA
	self.polygonMaxArea = 0
	for i, polygon in pairs(self.polygons) do
		polygon:PopulateNeighbors()
		if #polygon.hexes < self.polygonMinArea and #polygon.hexes > 0 then
			self.polygonMinArea = #polygon.hexes
		end
		if #polygon.hexes > self.polygonMaxArea then
			self.polygonMaxArea = #polygon.hexes
		end
	end
	EchoDebug("smallest polygon: " .. self.polygonMinArea, "largest polygon: " .. self.polygonMaxArea)
end

function Space:FindEdgeConnections()
	local allEdges = {}
	for i, edge in pairs(self.edges) do tInsert(allEdges, edge) end
	for i, edge in pairs(self.subEdges) do tInsert(allEdges, edge) end
	for i, edge in pairs(allEdges) do
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

function Space:ComputeEdgePaths()
	local allEdges = {}
	for i, edge in pairs(self.edges) do tInsert(allEdges, edge) end
	for i, edge in pairs(self.subEdges) do tInsert(allEdges, edge) end
	for i, edge in pairs(allEdges) do
		-- find an end of the edge
		local hex = tGetRandom(edge.hexes)
		repeat
			local pairHex = edge.onEdge[hex]
			hex.picked, pairHex.picked = true, true
			local newHex
			for d, nhex in pairs(hex:Neighbors()) do
				if edge.onEdge[nhex] and not nhex.picked then
					newHex = nhex
					break
				end
			end
			if not newHex then
				for d, nhex in pairs(pairHex:Neighbors()) do
					if edge.onEdge[nhex] and not nhex.picked then
						newHex = nhex
						break
					end
				end
			end
			hex = newHex or hex
		until not newHex
		-- determine which connections are connected to this end
		for cedge, yes in pairs(edge.connections) do
			local low = false
			for ch, chex in pairs(cedge.hexes) do
				if chex == hex or chex == edge.onEdge[hex] then
					low = true
					tInsert(edge.lowConnections, cedge)
					break
				end
			end
			if not low then tInsert(edge.highConnections, cedge) end
		end
		-- follow the edge's path from that end
		local p = 1
		repeat
			local pairHex = edge.onEdge[hex]
			hex.pickedAgain, pairHex.pickedAgain = true, true
			edge.path[p] = { hexes = {hex, pairHex} }
			local newHex
			local newDirection
			for d, nhex in pairs(hex:Neighbors()) do
				if edge.onEdge[nhex] and not nhex.pickedAgain then
					newHex = nhex
					edge.path[p].nextDirection = d
					break
				end
			end
			if not newHex then
				for d, nhex in pairs(pairHex:Neighbors()) do
					if edge.onEdge[nhex] and not nhex.pickedAgain then
						newHex = nhex
						edge.path[p].nextDirection = d
						break
					end
				end
			end
			p = p + 1
			hex = newHex or hex
		until not newHex
		-- reset hexes' temporary markers
		for h, hex in pairs(edge.hexes) do
			hex.picked, hex.pickedAgain = false, false
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
	local x = 0
	-- if self.oceanNumber == 1 then x = 0 else x = mRandom(0, self.w) end
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
			self.nonOceanArea = self.nonOceanArea - #polygon.hexes
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
	local sides = {
		{ {0,0}, {0,1} },
		{ {0,1}, {1,1} },
		{ {1,0}, {1,1} },
		{ {0,0}, {1,0} },
	}
	self.oceanSides = {}
	for oceanIndex = 1, self.oceanNumber do
		local side = tRemoveRandom(sides)
		EchoDebug("side: ", side[1][1], side[1][2], side[2][1], side[2][2])
		local x, y = side[1][1] * self.w, side[1][2] * self.h
		local xUp = side[2][1] - x == 1
		local yUp = side[2][2] - y == 1
		local xMinimize, yMinimize, xMaximize, yMaximize
		local bottomTopCriterion
		if xUp then
			if side[1][2] == 0 then
				bottomTopCriterion = "bottomYPolygons"
				self.oceanSides["bottomY"] = true
			elseif side[1][2] == 1 then
				bottomTopCriterion = "topYPolygons"
				self.oceanSides["topY"] = true
			end
		elseif yUp then
			if side[1][1] == 0 then
				bottomTopCriterion = "bottomXPolygons"
				self.oceanSides["bottomX"] = true
			elseif side[1][1] == 1 then
				bottomTopCriterion = "topXPolygons"
				self.oceanSides["topX"] = true
			end
		end
		local ocean = {}
		for i, polygon in pairs(self[bottomTopCriterion]) do
			if not polygon.oceanIndex then
				polygon.oceanIndex = oceanIndex
				tInsert(ocean, polygon)
				self.nonOceanArea = self.nonOceanArea - #polygon.hexes
				self.nonOceanPolygons = self.nonOceanPolygons - 1
			end
		end
		tInsert(self.oceans, ocean)
	end
end

function Space:PickOceansDoughnut()
	self.wrapX, self.wrapY = false, false
	local formulas = {
		[1] = { {1,2} },
		[2] = { {3}, {4} },
		[3] = { {-1}, {1,7,8}, {2,9,10} }, -- negative 1 denotes each subtable is a possibility of a list instead of a list of possibilities
		[4] = { {1}, {2}, {5}, {6} },
	}
	local hexAngles = {}
	local hex = self:GetHexByXY(mFloor(self.w / 2), mFloor(self.h / 2))
	for n, nhex in pairs(hex:Neighbors()) do
		local angle = AngleAtoB(hex.x, hex.y, nhex.x, nhex.y)
		EchoDebug(n, nhex.x-hex.x, nhex.y-hex.y, angle)
		hexAngles[n] = angle
	end
	local origins, terminals = self:InterpretFormula(formulas[self.oceanNumber])
	for oceanIndex = 1, #origins do
		local ocean = {}
		local origin, terminal = origins[oceanIndex], terminals[oceanIndex]
		local hex = self:GetHexByXY(origin.x, origin.y)
		local polygon = hex.polygon
		if not polygon.oceanIndex then
			polygon.oceanIndex = oceanIndex
			tInsert(ocean, polygon)
			self.nonOceanArea = self.nonOceanArea - #polygon.hexes
			self.nonOceanPolygons = self.nonOceanPolygons - 1
		end
		local iterations = 0
		EchoDebug(origin.x, origin.y, terminal.x, terminal.y)
		local mx = terminal.x - origin.x
		local my = terminal.y - origin.y
		local dx, dy
		if mx == 0 then
			dx = 0
			if my < 0 then dy = -1 else dy = 1 end
		elseif my == 0 then
			dy = 0
			if mx < 0 then dx = -1 else dx = 1 end
		else
			if mx < 0 then dx = -1 else dx = 1 end
			dy = my / mAbs(mx)
		end
		local x, y = origin.x, origin.y
		repeat
			-- find the next polygon if it's different
			x = x + dx
			y = y + dy
			local best = polygon
			local bestDist = self:EucDistance(x, y, polygon.x, polygon.y)
			for n, neighbor in pairs(polygon.neighbors) do
				local dist = self:EucDistance(x, y, neighbor.x, neighbor.y)
				if dist < bestDist then
					bestDist = dist
					best = neighbor
				end
			end
			polygon = best
			-- add the polygon here to the ocean
			if not polygon.oceanIndex then
				polygon.oceanIndex = oceanIndex
				tInsert(ocean, polygon)
				self.nonOceanArea = self.nonOceanArea - #polygon.hexes
				self.nonOceanPolygons = self.nonOceanPolygons - 1
			end
			iterations = iterations + 1
		until mFloor(x) == terminal.x and mFloor(y) == terminal.y
		tInsert(self.oceans, ocean)
	end
	self.wrapX, self.wrapY = true, true
end

local OceanLines = {
		[1] = { {0,0}, {0,1} }, -- straight sides
		[2] = { {0,0}, {1,0} },
		[3] = { {0,0}, {1,1} }, -- diagonals
		[4] = { {1,0}, {0,1} },
		[5] = { {0.5,0}, {0.5,1} }, -- middle cross
		[6] = { {0,0.5}, {1,0.5} },
		[7] = { {0.33,0}, {0.33,1} }, -- vertical thirds
		[8] = { {0.67,0}, {0.67,1} },
		[9] = { {0,0.33}, {1,0.33} }, -- horizontal thirds
		[10] = { {0,0.67}, {1,0.67} },
	}

function Space:InterpretFormula(formula)
	local origins = {}
	local terminals = {}
	if formula[1][1] == -1 then
		local list = formula[mRandom(2, #formula)]
		for l, lineCode in pairs(list) do
			local line = OceanLines[lineCode]
			tInsert(origins, self:InterpretPosition(line[1]))
			tInsert(terminals, self:InterpretPosition(line[2]))
		end
	else
		for i, part in pairs(formula) do
			local line = OceanLines[tGetRandom(part)]
			tInsert(origins, self:InterpretPosition(line[1]))
			tInsert(terminals, self:InterpretPosition(line[2]))
		end
	end
	return origins, terminals
end

function Space:InterpretPosition(position)
	return { x = mFloor(position[1] * self.w), y = mFloor(position[2] * self.h) }
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
	if self.oceanSides then
		self.nonOceanSides = {}
		if not self.oceanSides["bottomX"] then tInsert(self.nonOceanSides, "bottomX") end
		if not self.oceanSides["topX"] then tInsert(self.nonOceanSides, "topX") end
		if not self.oceanSides["bottomY"] then tInsert(self.nonOceanSides, "bottomY") end
		if not self.oceanSides["topY"] then tInsert(self.nonOceanSides, "topY") end
	end
	while #polygonBuffer > 0 do
		-- determine theoretical continent size
		local size = mCeil(nonIslandPolygons / self.majorContinentNumber)
		if filledPolygons >= nonIslandPolygons then size = mRandom(1, 3) end
		-- pick a polygon to start the continent
		local polygon
		repeat
			polygon = tRemoveRandom(polygonBuffer)
			if polygon.continent == nil and not polygon:NearOther(nil, "continent") then
				if (self.wrapY or (not polygon.topY and not polygon.bottomY)) and (self.wrapX or (not polygon.topX and not polygon.bottomX)) then
					break
				elseif (not self.wrapX and not self.wrapY) then
					local goodSide = false
					local sides = 0
					for nosi, side in pairs(self.nonOceanSides) do
						if polygon[side] then
							goodSide = true
							break
						end
						sides = sides + 1
					end
					if goodSide or sides == 0 then break else polygon = nil end
				else
					polygon = nil
				end
			else
				polygon = nil
			end
		until #polygonBuffer == 0
		if polygon == nil then break end
		local backlog = {}
		local polarBacklog = {}
		self.filledArea = self.filledArea + #polygon.hexes
		filledPolygons = filledPolygons + 1
		local filledContinentArea = #polygon.hexes
		local continent = { polygon }
		polygon.continent = continent
		repeat
			local candidates = {}
			local polarCandidates = {}
			for ni, neighbor in pairs(polygon.neighbors) do
				if neighbor.continent == nil and not neighbor:NearOther(continent, "continent") and neighbor.astronomyIndex < 10 then
					if self.wrapX and not self.wrapY and (neighbor.topY or neighbor.bottomY) then
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
							if candidate.continent ~= nil then candidate = nil end
						until candidate ~= nil or #backlog == 0
					elseif #polarBacklog > 0 then
						repeat
							candidate = tRemove(polarBacklog, #polarBacklog) -- pop off the most recent polar
							if candidate.continent ~= nil then candidate = nil end
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
			candidate.continent = continent
			self.filledArea = self.filledArea + #candidate.hexes
			filledContinentArea = filledContinentArea + #candidate.hexes
			filledPolygons = filledPolygons + 1
			tInsert(continent, candidate)
			polygon = candidate
		until #backlog == 0 or #continent >= size
		EchoDebug(size, #continent, filledContinentArea)
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
			if (edge.polygons[1].continent or edge.polygons[2].continent) and not edge.mountains then
				if edge.polygons[1].continent and edge.polygons[2].continent and interiorCount < interiorPrescription then
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
				if (nextEdge.polygons[1].continent or nextEdge.polygons[2].continent) and not nextEdge.mountains then
					if coastRange and (not nextEdge.polygons[1].continent or not nextEdge.polygons[2].continent) then
						okay = true
					elseif not coastRange and nextEdge.polygons[1].continent and nextEdge.polygons[2].continent then
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
		for polyi, polygon in pairs(continent) do
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
				region.area = region.area + #polygon.hexes
				repeat
					if #polygon.neighbors == 0 then break end
					local candidates = {}
					for ni, neighbor in pairs(polygon.neighbors) do
						if neighbor.continent == continent then
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
					region.area = region.area + #candidate.hexes
					polygon = candidate
					for candi, c in pairs(candidates) do
						tInsert(backlog, c)
					end
				until #region.polygons == size or region.area > self.polygonMaxArea / 2 or #region.polygons == #continent
			end
			tInsert(self.regions, region)
		end
	end
	for p, polygon in pairs(self.tinyIslandPolygons) do
		polygon.region = Region(self)
		tInsert(polygon.region.polygons, polygon)
		polygon.region.area = #polygon.hexes
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

function Space:FindPotentialRivers()
	self.regionEdges = {}
	self.regionEdgesDrain = {}
	self.edgesDrain = {}
	for i, edge in pairs(self.edges) do
		if edge.polygons[1].continent and edge.polygons[2].continent and not edge.polygons[1].region.lakey and not edge.polygons[2].region.lakey then
			edge.continental = true
			if edge.polygons[1].region ~= edge.polygons[2].region and edge.polygons[1].region and edge.polygons[2].region then
				edge.regionEdge = true
				tInsert(self.regionEdges, edge)
			end
			local waterPolys = {}
			for n, neighbor in pairs(edge.polygons[1].neighbors) do
				if not neighbor.continent then
					waterPolys[neighbor] = true
				end
			end
			for n, neighbor in pairs(edge.polygons[2].neighbors) do
				if waterPolys[neighbor] then
					edge.drainsToWater = true
					break
				end
			end
			if edge.drainsToWater then
				for c, cedge in pairs(edge.highConnections) do
					if waterPolys[cedge.polygons[1]] or waterPolys[cedge.polygons[2]] then
						edge.drainsHigh = true
						break
					end
				end
				for c, cedge in pairs(edge.lowConnections) do
					if waterPolys[cedge.polygons[1]] or waterPolys[cedge.polygons[2]] then
						edge.drainsLow = true
						break
					end
				end
				if edge.drainsLow and edge.drainsHigh then
					self.drainsToWater = nil
					self.continental = nil
				else
					if edge.regionEdge then tInsert(self.regionEdgesDrain, edge) end
					tInsert(self.edgesDrain, edge)
				end
			end
		end
	end
	-- do minor rivers
	self.subEdgesFork = {}
	for i, edge in pairs(self.subEdges) do
		if edge.polygons[1].superPolygon.continent and edge.polygons[2].superPolygon.continent and not edge.polygons[1].lake and not edge.polygons[2].lake then
			edge.continental = true
			local waterPolys = {}
			for n, neighbor in pairs(edge.polygons[1].neighbors) do
				if not neighbor.superPolygon.continent then
					waterPolys[neighbor] = true
				end
			end
			for n, neighbor in pairs(edge.polygons[2].neighbors) do
				if waterPolys[neighbor] then
					edge.drainsToWater = true
					break
				end
			end
			if not edge.drainsToWater then
				edge.highForks, edge.lowForks, edge.forks = {}, {}, {}
				for c, cedge in pairs(edge.highConnections) do
					if cedge.polygons[1].superPolygon ~= cedge.polygons[2].superPolygon then
						local superEdge = cedge.polygons[1].superPolygon.edges[cedge.polygons[2].superPolygon]
						edge.highForks[superEdge] = true
						edge.forks[superEdge] = true
						if self.subEdgesFork[superEdge] == nil then self.subEdgesFork[superEdge] = {} end
						self.subEdgesFork[superEdge][edge] = 2 -- 2 is high, 1 is low
					end
				end
				for c, cedge in pairs(edge.lowConnections) do
					if cedge.polygons[1].superPolygon ~= cedge.polygons[2].superPolygon then
						local superEdge = cedge.polygons[1].superPolygon.edges[cedge.polygons[2].superPolygon]
						edge.lowForks[superEdge] = true
						edge.forks[superEdge] = true
						if self.subEdgesFork[superEdge] == nil then self.subEdgesFork[superEdge] = {} end
						self.subEdgesFork[superEdge][edge] = 1 -- 2 is high, 1 is low
					end
				end
			end
		end
	end
end

function Space:PickMajorRivers()
	self.majorRiversMax = #self.edgesDrain * self.majorRiverRatio
	local edgeBuffer = tDuplicate(self.edgesDrain)
	self.majorRivers = {}
	while #edgeBuffer > 0 and #self.majorRivers < self.majorRiversMax do
		local river = {}
		local edge = tRemoveRandom(edgeBuffer)
		local n = 0
		repeat
			if n > 0 then
				local upstream = {}
				for cedge, yes in pairs(edge.connections) do
					if cedge.continental and not cedge.river and not cedge.drainsToWater then
						local badConnection = false
						for ccedge, yes in pairs(cedge.connections) do
							if (ccedge.river and ccedge.river ~= river) or not ccedge.continental then
								badConnection = true
								break
							end
						end
						if not badConnection then
							if cedge.mountains then
								upstream = { cedge }
								break
							end
							tInsert(upstream, cedge)
						end
					end
				end
				if #upstream == 0 then
					edge = nil
					break
				end
				edge = tGetRandom(upstream)
			end
			edge.majorRiver = true
			edge.river = river
			tInsert(river, edge)
			n = n + 1
		until not edge or edge.mountains
		if edge and edge.mountains and #river > 0 then
			EchoDebug(#river)
			tInsert(self.majorRivers, river)
		else
			for e, ed in pairs(river) do
				ed.majorRiver = nil
				ed.river = nil
			end
		end
	end
end

function Space:PickMinorRivers()
	self.minorRivers = {}
	self.minorRiverForksLowHigh = {}
	for mr, majorRiver in pairs(self.majorRivers) do
		local subEdgeBuffer = {}
		local isFork = {}
		for e, edge in pairs(majorRiver) do
			if self.subEdgesFork[edge] ~= nil then
				for subEdge, lowHigh in pairs(self.subEdgesFork[edge]) do
					tInsert(subEdgeBuffer, {subEdge = subEdge, lowHigh = lowHigh})
					isFork[subEdge] = true
				end
			end
		end
		minorRiversMax = #subEdgeBuffer * self.minorRiverRatio
		self.minorRivers[majorRiver] = {}
		while #subEdgeBuffer > 0 and #self.minorRivers[majorRiver] < minorRiversMax do
			local river = {}
			local riverLength = mRandom(self.minorRiverLengthMin, self.minorRiverLengthMax)
			local edgeContainer = tRemoveRandom(subEdgeBuffer)
			local edge, lowHigh = edgeContainer.subEdge, edgeContainer.lowHigh
			local n = 0
			repeat
				if n > 0 then
					local downstream = {}
					for cedge, yes in pairs(edge.connections) do
						if cedge.continental and not cedge.river and not isFork[cedge] and not cedge.drainsToWater then
							local badConnection = false
							for ccedge, yes in pairs(cedge.connections) do
								if ccedge.river and ccedge.river ~= river then
									badConnection = true
									break
								end
							end
							if not badConnection then tInsert(downstream, cedge) end
						end
					end
					if #downstream == 0 then
						edge = nil
						break
					end
					edge = tGetRandom(downstream)
				end
				edge.minorRiver = true
				edge.river = river
				tInsert(river, edge)
				n = n + 1
			until not edge or n > riverLength
			if #river > 0 then
				tInsert(self.minorRivers[majorRiver], river)
				self.minorRiverForksLowHigh[river] = lowHigh
			else
				for e, ed in pairs(river) do
					ed.minorRiver = nil
					ed.river = nil
				end
			end
		end
		EchoDebug(#self.minorRivers[majorRiver])
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
		if polygon.continent == nil then
			if polygon.oceanIndex == nil and Map.Rand(10, "coastal polygon dice") < self.coastalPolygonChance then
				polygon.coastal = true
				self.coastalPolygonCount = self.coastalPolygonCount + 1
				if not polygon:NearOther(nil, "continent") then polygon.loneCoastal = true end
				polygon:PickTinyIslands()
				tInsert(self.tinyIslandPolygons, polygon)
			elseif polygon.oceanIndex then
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
			local neighborBuffer = {} -- because neighbors has gaps in it
			for n, nhex in pairs(neighbors) do
				if nhex then
					tInsert(neighborBuffer, nhex)
				end
			end
			local nhex
			repeat
				nhex = tRemoveRandom(neighborBuffer)
			until nhex.plotType == plotLand or #neighborBuffer == 0
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
		if polygon.continent then
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

function Space:RealmLatitude(y, latitude)
	if self.realmHemisphere == 2 then y = self.h - y end
	return mFloor(y * (90 / self.h))
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
	local temp1 = mMax(temp - diff, 0)
	local temp2 = mMin(temp + diff, 100)
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

function Space:SquaredDistance(x1, y1, x2, y2)
	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
	return (xdist * xdist) + (ydist * ydist)
end
function Space:EucDistance(x1, y1, x2, y2)
	return mSqrt(self:SquaredDistance(x1, y1, x2, y2))
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
	local custOpts = GetCustomOptions()
	tInsert(custOpts, resources)
	return {
		Name = "Fantastical (dev)",
		Description = "Scribbles fantastical lands onto the world.",
		IconIndex = 5,
		CustomOptions = custOpts,
	}
end

function GetMapInitData(worldSize)
	-- i have to use Map.GetCustomOption because this is called before everything else
	if Map.GetCustomOption(1) == 2 then
		-- for Realm maps
		-- create a random map aspect ratio for the given map size
		local areas = {
			[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 40 * 25,
			[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 56 * 36,
			[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 66 * 42,
			[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 80 * 52,
			[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 104 * 64,
			[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 128 * 80,
		}
		local grid_area = areas[worldSize]
		local grid_width = mCeil( mSqrt(grid_area) * ((mRandom() * 0.67) + 0.67) )
		local grid_height = mCeil( grid_area / grid_width )
		local world = GameInfo.Worlds[worldSize]
		local wrap = Map.GetCustomOption(1) == 3
		if world ~= nil then
			return {
				Width = grid_width,
				Height = grid_height,
				WrapX = false,
			}
	    end
	end
end

local mySpace

function GeneratePlotTypes()
    print("Generating Plot Types (Fantastical) ...")
	SetConstants()
    mySpace = Space()
    mySpace:SetOptions()
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

function AddRivers()
	print("Adding Rivers (Fantastical) ...")
	mySpace:SetRivers()
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