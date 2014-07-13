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

Hex = class(function(a)
end)

function Hex:Init(space, index, relax)
	self.space = space
	self.index = index
	self.x = (index-1) % self.space.iW
	self.y = mFloor( (index-1) / self.space.iW )
	self.polygon, self.limiality = self:ClosestPolygon(relax)
	self.liminality = 0
	self.edginess = 0
	self.coastAstroIndex = 0
	self.edgeWith = {}
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
	if self.wrapX then
		if nx > self.w then nx = 0 elseif nx < 0 then nx = self.w end
	else
		if nx > self.w then nx = self.w elseif nx < 0 then nx = 0 end
	end
	if self.wrapY then
		if ny > self.space.h then ny = 0 elseif ny < 0 then ny = self.space.h end
	else
		if ny > self.space.h then ny = self.space.h elseif ny < 0 then ny = 0 end
	end
	return self.space:GetHexXY(nx, ny)
end

function Hex:Neighbors(directions)
	if directions == nil then directions = { 1, 2, 3, 4, 5, 6 } end
	local neighbors = {}
	for i, direction in pairs(directions) do
		tInsert(neighbors, self:Adjacent(direction))
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
		dists[i] = self:EucDistance(polygon.x, polygon.y, self.x, self.y)
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
	plot:SetPlotType(hex.plotType)
end

function Hex:SetTerrain()
	local plot = Map.GetPlotByIndex(self.index-1)
	if plot == nil then return end
	plot:SetTerrainType(hex.terrainType)
end

function Hex:SetFeature()
	local plot = Map.GetPlotByIndex(self.index-1)
	if plot == nil then return end
	plot:SetFeatureType(hex.featureType)
end

------------------------------------------------------------------------------

Polygon = class(function(a)
end)

function Polygon:Init(space, x, y)
	self.space = space
	self.x = x or Map.Rand(self.space.iW, "random x")
	self.y = y or Map.Rand(self.space.iH, "random y")
	self.hexes = {}
	self.isNeighbor = {}
	self.area = 0
	self.minX = self.space.w
	self.maxX = 0
	self.minY = self.space.h
	self.maxY = 0
end

function Polygon:FloodFillAstronomy(astronomyIndex)
	if self.oceanIndex then
		self.astronomyIndex = self.oceanIndex + 10
		return nil
	end
	if self.astronomyIndex then return nil end
	self.astronomyIndex = astronomyIndex
	for i, neighbor in pairs(polygon.neighbors) do
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
	end
	self.area = 0
	self.minX, self.minY, maxX, maxY = space.w, space.h, 0, 0
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

Space = class(function(a)
end)

function Space:Init()
	-- CONFIGURATION: --
	polygonCount = 140 -- how many polygons (map scale)
	minkowskiOrder = 3 -- higher == more like manhatten distance, lower (> 1) more like euclidian distance, < 1 weird cross shapes
	relaxations = 1 -- how many lloyd relaxations (higher number is greater polygon uniformity)
	liminalTolerance = 0.5 -- within this much, distances to other polygons are considered "equal"
	oceanNumber = 2 -- how many large ocean basins
	majorContinentNumber = 2 -- how many large continents, more or less
	islandRatio = 0.1 -- what part of the continent polygons are taken up by 1-3 polygon continents
	polarContinentChance = 3 -- out of ten chances
	hillThreshold = 5 -- how much edginess + liminality makes a hill
	hillChance = 5 -- how many possible mountains out of ten become a hill when expanding
	mountainThreshold = 7 -- how much edginess + liminality makes a mountain
	mountainRatio = 0.04 -- how much of the land to be mountain tiles
	coastalPolygonChance = 2 -- out of ten, how often do possible coastal polygons become coastal?
	tinyIslandChance = 5 -- out of 100 tiles, how often do coastal shelves produce tiny islands (1-7 hexes)
	coastExpansionDice = {3, 4}
	wrapX = true
	wrapY = false
	----------------------------------
	-- DEFINITIONS: --
	oceans = {}
	continents = {}
	regions = {}
	polygons = {}
	bottomYPolygons = {}
	bottomXPolygons = {}
	topYPolygons = {}
	topXPolygons = {}
	hexes = {}
    mountainPlots = {}
    tinyIslandPlots = {}
    hillPlots = {}
    deepTiles = {}
    maxLiminality = 0
    liminalTileCount = 0
    culledPolygons = 0
end

function Space:Compute()
    self.iW, self.iH = Map.GetGridSize()
    self.iA = self.iW * self.iH
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
    if self.relaxations > 0 then
    	for i = 1, self.relaxations do
        	self:FillPolygons(true)
    		print("relaxing polygons... (" .. i .. "/" .. self.relaxations .. ")")
        	self:RelaxPolygons()
        end
    end
    self:FillPolygons()
    self:CullPolygons()
    self:ComputePolygonNeighbors()
    self:PostProcessPolygons()
    self:PickOceans()
    self:FindAstronomyBasins()
    self:PickContinents()
	-- self:PickCoasts()
end

function Space:ComputePlots()
	for pi, hex in pairs(self.hexes) do
		if hex.polygon.continentIndex == nil then
			if hex.polygon.coastal then
				local nearOcean = false
				for npi, yes in pairs(hex.edgeWith) do
					local polygon = self.hexes[npi].polygon
					if not polygon.coastal then
						nearOcean = true
					end
				end
				if not nearOcean and Map.Rand(100, "tiny island chance") <= self.tinyIslandChance then
					hex.plotType = PlotTypes.PLOT_LAND
					tInsert(self.tinyIslandPlots, hex.index)
				else
					hex.plotType = PlotTypes.PLOT_OCEAN
				end
			else
				--[[
				if Map.Rand(1500, "tiny ocean island chance") <= self.tinyIslandChance then
					hex.plotType = PlotTypes.PLOT_LAND
					tInsert(self.tinyIslandPlots, hex.index)
				else
				]]--
					hex.plotType = PlotTypes.PLOT_OCEAN
				--end
			end
		else
			-- near other astrnomy basin?
			for npi, yes in pairs(hex.edgeWith) do
				local polygon = self.hexes[npi].polygon
				if polygon.astronomyIndex ~= hex.polygon.astronomyIndex then
					hex.nearOceanTrench = true
					break
				end
			end
			if hex.nearOceanTrench then
				hex.plotType = PlotTypes.PLOT_OCEAN
			else
				local edgeLim = hex.liminality + hex.edginess
				if edgeLim < self.hillThreshold then
					hex.plotType = PlotTypes.PLOT_LAND
				elseif edgeLim < self.mountainThreshold and Map.Rand(10, "hill dice primary") < self.hillChance then
					hex.plotType = PlotTypes.PLOT_HILLS
					tInsert(self.hillPlots, hex.index)
				else
					hex.plotType = PlotTypes.PLOT_MOUNTAIN
					tInsert(self.mountainPlots, hex.index)
				end
			end
		end
	end
	self:ExpandTinyIslands()
	self:AdjustMountains()
end

function Space:ComputeTerrain()
	for pi, hex in pairs(self.hexes) do
		if hex.plotType == PlotTypes.PLOT_OCEAN then
			local coast
			-- near land?
			for i, npi in pairs(self:HexNeighbors(hex.index)) do
				if self.plotTypes[npi] ~= PlotTypes.PLOT_OCEAN then
					local nhex = self.hexes[npi]
					if coast and coast ~= nhex.polygon.astronomyIndex then
						coast = 0
						EchoDebug("do not expand this coastal tile")
						break
					end
					coast = nhex.polygon.astronomyIndex
				end
			end
			if hex.nearOceanTrench then coast = 0 end
			if coast then
				hex.terrainType = GameInfoTypes["TERRAIN_COAST"]
				hex.coastAstroIndex = coast
			else
				if hex.polygon.coastal then
					hex.terrainType = GameInfoTypes["TERRAIN_COAST"]
					hex.coastAstroIndex = hex.polygon.astronomyIndex
				else
					hex.terrainType = GameInfoTypes["TERRAIN_OCEAN"]
					tInsert(self.deepTiles, hex.index)
				end
			end
		elseif hex.plotType == PlotTypes.PLOT_LAND then
			hex.terrainType = GameInfoTypes["TERRAIN_GRASS"]
		end
	end
	self:ExpandCoasts()
end

function Space:ComputeFeatures()
	-- to test neighbor problems
	--[[
	EchoDebug(self.halfWidth, self.halfHeight)
	local polygon = self.hexes[self:GetIndex(mCeil(self.halfWidth), mCeil(self.halfHeight))].polygon
	for hi, hex in pairs(polygon.hexes) do
		local plot = Map.GetPlotByIndex(hex.index-1)
		if plot ~= nil then
			plot:SetFeatureType(FeatureTypes.FEATURE_ICE)
		end
	end
	for i, neighbor in pairs(polygon.neighbors) do
		EchoDebug("neighbor " .. i, #neighbor.hexes)
		for hi, hex in pairs(neighbor.hexes) do
			local plot = Map.GetPlotByIndex(hex.index-1)
			if plot ~= nil then
				plot:SetFeatureType(FeatureTypes.FEATURE_JUNGLE)
			end
		end
	end
	]]--
	-- testing ocean rifts
	for i, hex in pairs(self.hexes) do
		--[[
		if hex.polygon.oceanIndex then
			local plot = Map.GetPlotByIndex(hex.index-1)
			if plot ~= nil then
				plot:SetFeatureType(FeatureTypes.FEATURE_ICE)
			end
		end
		]]--
		if hex.nearOceanTrench then
			local plot = Map.GetPlotByIndex(hex.index-1)
			if plot ~= nil then
				plot:SetFeatureType(FeatureTypes.FEATURE_ICE)
			end
		end
	end
	return self.featureTypes
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
		local polygon = Polygon()
		polygon:Init()
		tInsert(self.polygons, polygon)
	end
end


function Space:FillPolygons(relax)
	for x = 0, self.w do
		for y = 0, self.h do
			local polygon, liminality = self:ClosestPolygon(x, y, relax)
			if polygon ~= nil then
				local pi = self:GetIndex(x, y)
				local hex = { polygon = polygon, liminality = liminality, edginess = 0, coastAstroIndex = 0, edgeWith = {}, index = pi, x = x, y = y }
				self.hexes[pi] = hex
				tInsert(polygon.hexes, hex)
				polygon.area = polygon.area + 1
				if x < polygon.minX then polygon.minX = x end
				if y < polygon.minY then polygon.minY = y end
				if x > polygon.maxX then polygon.maxX = x end
				if y > polygon.maxY then polygon.maxY = y end
				if not relax then
					if liminality ~= 0 then
						self.liminalTileCount = self.liminalTileCount + 1
					end
					self:CheckBottomTop(polygon, x, y)
				end
			else
				EchoDebug("WARNING: NIL POLYGON")
			end
		end
	end
	if not relax then EchoDebug(self.maxLiminality .. " maximum liminality", self.liminalTileCount .. " total liminal tiles") end
end

function Space:ComputePolygonNeighbors()
	for i, hex in pairs(self.hexes) do
		local pi = hex.index
		local polygon = hex.polygon
		for ni, nindex in pairs(self:HexNeighbors(pi)) do -- 3 and 4 are are never there yet
			if nindex ~= pi then
				local nhex = self.hexes[nindex]
				if nhex ~= nil then
					if nhex.polygon ~= polygon then
						self:SetNeighborPolygons(polygon, nhex.polygon)
						if not hex.edgeWith[nindex] then
							hex.edginess = hex.edginess + 1
							hex.edgeWith[nindex] = true
						end
						if not nhex.edgeWith[pi] then
							nhex.edginess = nhex.edginess + 1
							nhex.edgeWith[pi] =true
						end
					end
				end
			end
		end
	end
end

function Space:RelaxPolygons()
	for i, polygon in pairs(self.polygons) do
		self:RelaxToCentroid(polygon)
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
				if not self:NearOther(neighbor, oceanIndex, "oceanIndex") then
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
				if not chosen[neighbor] and not self:NearOther(neighbor, oceanIndex, "oceanIndex") then
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
	local astronomyIndex = 1
	for i, polygon in pairs(self.polygons) do
		if polygon:FloodFillAstronomy(astronomyIndex) then
			astronomyIndex = astronomyIndex + 1
		end
	end
	EchoDebug(astronomyIndex-1 .. " astronomy basins")
end

function Space:PickContinents()
	local polygonBuffer = {}
	for i, polygon in pairs(self.polygons) do
		tInsert(polygonBuffer, polygon)
	end
	self.filledArea = 0
	local filledPolygons = 0
	local continentIndex = 1
	local islandPolygons = mCeil(self.nonOceanPolygons * self.islandRatio)
	local nonIslandPolygons = mMax(2, self.nonOceanPolygons - islandPolygons)
	local continentSize = mCeil(nonIslandPolygons / self.majorContinentNumber)
	EchoDebug(islandPolygons .. " island polygons", nonIslandPolygons .. " non-island polygons", continentSize .. " continent size in polygons")
	while #polygonBuffer > 1 do
		local polygon
		repeat
			if #polygonBuffer == 1 then break end
			polygon = tRemoveRandom(polygonBuffer)
		until polygon.continentIndex == nil and not self:NearOther(polygon, nil) and not self:NearOther(polygon, nil, "oceanIndex") and polygon.oceanIndex == nil and (self.wrapY or (not polygon.topY and not polygon.bottomY)) and (self.wrapX or (not polygon.topX and not polygon.bottomX))
		polygon.continentIndex = continentIndex
		self.filledArea = self.filledArea + polygon.area
		filledPolygons = filledPolygons + 1
		local size = continentSize
		if filledPolygons >= nonIslandPolygons then size = mRandom(1, 3) end
		local filledContinentArea = polygon.area
		local continent = { polygons = { polygon }, index = continentIndex }
		local n = 1
		local iterations = 0
		local lastRN
		while n < size and iterations < #polygonBuffer do
			local rn
			if lastRN ~= nil then
				rn = (lastRN + 1) % #polygon.neighbors
				if rn == 0 then rn = 1 end
			else
				rn = mRandom(1, #polygon.neighbors)
			end
			local neighbor = polygon.neighbors[rn]
			local polarOkay = neighbor == nil or self.polarContinentChance >= 10 or self.wrapY or not self.wrapX or (not neighbor.topY and not neighbor.bottomY) or Map.Rand(10, "polar continent chance") < self.polarContinentChance
			if neighbor ~= nil and not self:NearOther(neighbor, continentIndex) and neighbor.oceanIndex == nil and neighbor.astronomyIndex == polygon.astronomyIndex and polarOkay then
				neighbor.continentIndex = continentIndex
				self.filledArea = self.filledArea + neighbor.area
				filledContinentArea = filledContinentArea + neighbor.area
				filledPolygons = filledPolygons + 1
				n = n + 1
				tInsert(continent.polygons, neighbor)
				polygon = neighbor
				lastRN = nil
			else
				lastRN = rn
			end
			iterations = iterations + 1
		end
		EchoDebug(n, size, iterations, filledContinentArea)
		tInsert(self.continents, continent)
		continentIndex = continentIndex + 1
	end
	EchoDebug(continentIndex-1 .. " continents", filledPolygons .. " filled polygons", self.filledArea .. " filled hexes")
end

function Space:PickCoasts()
	self.coastalPolygonCount = 0
	for i, polygon in pairs(self.polygons) do
		if polygon.continentIndex == nil and not self:NearOther(polygon, polygon.astronomyIndex, "astronomyIndex") then
			if Map.Rand(10, "coastal polygon dice") < self.coastalPolygonChance then
				polygon.coastal = true
				self.coastalPolygonCount = self.coastalPolygonCount + 1
			end
		end
	end
	EchoDebug(self.coastalPolygonCount .. " coastal polygons")
end

function Space:ResizeMountains(perscribedArea)
	if #self.mountainPlots == perscribedArea then return end
	if #self.mountainPlots > perscribedArea then
		repeat
			local pi = tRemoveRandom(self.mountainPlots)
			self.plotTypes[pi] = PlotTypes.PLOT_LAND
		until #self.mountainPlots <= perscribedArea
	elseif #self.mountainPlots < perscribedArea then
		local noNeighbors = 0
		repeat
			local pi = self.mountainPlots[mRandom(1, #self.mountainPlots)]
			local neighbors = self:HexNeighbors(pi)
			local npi
			repeat
				npi = tRemoveRandom(neighbors)
			until self.plotTypes[npi] == PlotTypes.PLOT_LAND or #neighbors == 0
			if npi ~= nil and self.plotTypes[npi] == PlotTypes.PLOT_LAND then
				if Map.Rand(10, "hill dice") < self.hillChance then
					self.plotTypes[npi] = PlotTypes.PLOT_HILLS
					tInsert(self.hillPlots, npi)
				else
					self.plotTypes[npi] = PlotTypes.PLOT_MOUNTAIN
					tInsert(self.mountainPlots, npi)
				end
				noNeighbors = 0
			else
				noNeighbors = noNeighbors + 1
			end
		until #self.mountainPlots >= perscribedArea or noNeighbors > 20
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
	for i, pi in pairs(self.tinyIslandPlots) do
		local neighbors = self:HexNeighbors(pi)
		for i, npi in pairs(neighbors) do
			if self.plotTypes[npi] == PlotTypes.PLOT_OCEAN then
				local okay = true
				for i, nnpi in pairs(self:HexNeighbors(npi)) do
					if nnpi ~= pi and self.plotTypes[nnpi] ~= PlotTypes.PLOT_OCEAN then
						okay = false
						break
					end
				end
				if okay and Map.Rand(100, "tiny island expansion") < chance then
					tInsert(toExpand, npi)
				end
			end
		end
	end
	for i, pi in pairs(toExpand) do
		self.plotTypes[pi] = PlotTypes.PLOT_LAND
		tInsert(self.tinyIslandPlots, pi)
	end
	EchoDebug(#self.tinyIslandPlots .. " tiny islands")
end

function Space:ExpandCoasts()
	for d, dice in ipairs(self.coastExpansionDice) do
		local makeCoast = {}
		for i, pi in pairs(self.deepTiles) do
			if self.terrainTypes[pi] == GameInfoTypes["TERRAIN_OCEAN"] then
				local hex = self.hexes[pi]
				local nearcoast
				for n, npi in pairs(self:HexNeighbors(pi)) do
					local nhex = self.hexes[npi]
					if self.terrainTypes[npi] == GameInfoTypes["TERRAIN_COAST"] then
						local thiscoast = nhex.coastAstroIndex
						if thiscoast ~= nil then
							if thiscoast == 0 then
								nearcoast = nil
								break
							end
							if nearcoast == nil then
								nearcoast = thiscoast
							elseif thiscoast ~= nearcoast then
								nearcoast = nil
								break
							end
						else
							EchoDebug("nil coast astronomy")
						end
					elseif makeCoast[npi] then
						if nearcoast ~= nil and makeCoast[npi] ~= nearcoast then
							nearcoast = nil
							break
						end
					end
				end
				if nearcoast then -- and Map.Rand(dice, "expand coast?") == 0 then
					makeCoast[pi] = nearcoast
				end
			end
		end
		for pi, nearcoast in pairs(makeCoast) do
			self.terrainTypes[pi] = GameInfoTypes["TERRAIN_COAST"]
			self.hexes[pi].coastAstroIndex = nearcoast
		end
	end
end

----------------------------------
-- INTERNAL FUNCTIONS: --

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

function Space:GetXY(index)
	index = index - 1
	return index % self.iW, mFloor(index / self.iW)
end

function Space:GetIndex(x, y)
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

local space

function GeneratePlotTypes()
    print("Setting Plot Types (Fantastical) ...")
    space = Space:Init()
    space:Compute()
    space:ComputePlots()
    space:SetPlots()
    local args = { bExpandCoasts = false }
    -- GenerateCoasts(args)
end

function GenerateTerrain()
    print("Generating Terrain (Fantastical) ...")
    space:ComputeTerrain()
	space:SetTerrains()
end

function SetTerrainTypes(terrainTypes)
	print("Setting Terrain Types (Fantastical)");
	for i, plot in Plots() do
		plot:SetTerrainType(terrainTypes[i+1], false, false)
		-- MapGenerator's SetPlotTypes uses i+1, but MapGenerator's SetTerrainTypes uses just i. wtf.
	end
end

function AddFeatures()
	space:ComputeFeatures()
	space:SetFeatures()
	-- Space:ComputeFeatures()
	--[[
    print("Adding Features (using default implementation) ...")
    
    local featuregen = FeatureGenerator.Create()
    featuregen:AddFeatures()
    ]]--
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
						plot:SetPlotType(PlotTypes.PLOT_OCEAN);
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
		if featureType == FeatureTypes.FEATURE_ICE then
			return
		end
		local hex = Space.hexes[plotIndex+1]
		if hex.oceanIndex then
			return
		end
		local terrainType = adjPlot:GetTerrainType()
		if terrainType == TerrainTypes.TERRAIN_COAST then
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
		if terrainType == TerrainTypes.TERRAIN_COAST then
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