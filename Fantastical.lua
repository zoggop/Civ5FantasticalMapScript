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
local mCeil = math.ceil
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local mAbs = math.abs
local mSqrt = math.sqrt
local tInsert = table.insert
local tRemove = table.remove

------------------------------------------------------------------------------

local function tRemoveRandom(fromTable)
	return tRemove(fromTable, mRandom(1, #fromTable))
end
local oneOverOrder = {}

------------------------------------------------------------------------------

local Space = {
	-- CONFIGURATION: --
	polygonCount = 140, -- how many polygons (map scale)
	minkowskiOrder = 3,
	relaxations = 1, -- how many lloyd relaxations (higher number is greater polygon uniformity)
	liminalTolerance = 0.5, -- within this much, distances to other polygons are considered "equal"
	oceanNumber = 2, -- how many large ocean basins
	majorContinentNumber = 2, -- how many large continents, more or less
	islandRatio = 0.1, -- what part of the continent polygons are taken up by 1-3 polygon continents
	polarContinentChance = 3, -- out of ten chances
	hillThreshold = 3, -- how much edginess + liminality makes a hill
	hillChance = 3, -- how many possible mountains out of ten become a hill when expanding
	mountainThreshold = 4, -- how much edginess + liminality makes a mountain
	mountainRatio = 0.04, -- how much of the land to be mountain tiles
	coastalPolygonChance = 0, -- out of ten, how often do possible coastal polygons become coastal?
	tinyIslandChance = 5, -- out of 100 tiles, how often do coastal shelves produce tiny islands (1-7 hexes)
	coastExpansionDice = {3, 4},
	wrapX = true,
	wrapY = false,
	----------------------------------
	-- DEFINITIONS: --
	oceans = {},
	continents = {},
	regions = {},
	polygons = {},
	bottomYPolygons = {},
	bottomXPolygons = {},
	topYPolygons = {},
	topXPolygons = {},
	hexes = {},
    plotTypes = {}, -- map generation result
    terrainTypes = {}, -- map generation result
    featureTypes = {}, -- map generation result
    polygonType = {},
    mountainPlots = {},
    tinyIslandPlots = {},
    hillPlots = {},
    deepTiles = {},
    maxLiminality = 0,
    liminalTileCount = 0,
    culledPolygons = 0,
    ----------------------------------
    -- EXTERNAL FUNCTIONS: --
    Create = function(self)
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
        self:FindPolygonNeighbors()
        self:PostProcessPolygons()
        self:PickOceans()
        self:FindAstronomyBasins()
        self:PickContinents()
    	self:PickCoasts()
    end,
    ComputePlots = function(self)
		for pi, hex in pairs(self.hexes) do
			if hex.polygon.continentIndex == nil then
				if hex.polygon.coastal then
					if Map.Rand(100, "tiny island chance") <= self.tinyIslandChance then
						self.plotTypes[hex.index] = PlotTypes.PLOT_LAND
						tInsert(self.tinyIslandPlots, hex.index)
					else
						self.plotTypes[hex.index] = PlotTypes.PLOT_OCEAN
					end
				else
					--[[
					if Map.Rand(1500, "tiny ocean island chance") <= self.tinyIslandChance then
						self.plotTypes[hex.index] = PlotTypes.PLOT_LAND
						tInsert(self.tinyIslandPlots, hex.index)
					else
					]]--
						self.plotTypes[hex.index] = PlotTypes.PLOT_OCEAN
					--end
				end
			else
				local edgeLim = hex.liminality + hex.edginess
				if edgeLim < self.hillThreshold then
					self.plotTypes[hex.index] = PlotTypes.PLOT_LAND
				elseif edgeLim < self.mountainThreshold and Map.Rand(10, "hill dice primary") < self.hillChance then
					self.plotTypes[hex.index] = PlotTypes.PLOT_HILLS
					tInsert(self.hillPlots, hex.index)
				else
					self.plotTypes[hex.index] = PlotTypes.PLOT_MOUNTAIN
					tInsert(self.mountainPlots, hex.index)
				end
			end
		end
		self:ExpandTinyIslands()
		self:AdjustMountains()
		return self.plotTypes
	end,
    ComputeTerrain = function(self)
    	for pi, hex in pairs(self.hexes) do
    		if self.plotTypes[hex.index] == PlotTypes.PLOT_OCEAN then
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
				if coast then
    				self.terrainTypes[hex.index] = GameInfoTypes["TERRAIN_COAST"]
    				hex.coastAstroIndex = coast
    			else
    				if hex.polygon.coastal then
    					self.terrainTypes[hex.index] = GameInfoTypes["TERRAIN_COAST"]
    					hex.coastAstroIndex = hex.polygon.astronomyIndex
    				else
    					self.terrainTypes[hex.index] = GameInfoTypes["TERRAIN_OCEAN"]
    					tInsert(self.deepTiles, hex.index)
    				end
    			end
    		elseif self.plotTypes[hex.index] == PlotTypes.PLOT_LAND then
    			self.terrainTypes[hex.index] = GameInfoTypes["TERRAIN_GRASS"]
    		end
    	end
    	self:ExpandCoasts()
    	return self.terrainTypes
    end,
    ComputeFeatures = function(self)
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
			if hex.polygon.oceanIndex then
				local plot = Map.GetPlotByIndex(hex.index-1)
				if plot ~= nil then
					plot:SetFeatureType(FeatureTypes.FEATURE_ICE)
				end
			end
		end
    	return self.featureTypes
    end,
    ----------------------------------
    -- INTERNAL METAFUNCTIONS: --
    InitPolygons = function(self)
    	for i = 1, self.polygonCount do
    		tInsert(self.polygons, self:NewPolygon())
    	end
    end,
    FillPolygons = function(self, relax)
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
						-- find neighbors from one hex to the next
						--[[
						local directions
						if pi % 2 == 0 then directions = {1, 2, 5, 6} else directions = {1, 6} end
						for i, nindex in pairs(self:HexNeighbors(pi), directions) do -- 3 and 4 are are never there yet
							if nindex ~= pi then
								local nhex = self.hexes[nindex]
								if nhex ~= nil then
									if nhex.polygon ~= polygon then
										-- EchoDebug(hex.x, hex.y, nhex.x, nhex.y)
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
						]]--
					end
				else
					EchoDebug("WARNING: NIL POLYGON")
				end
			end
		end
		if not relax then EchoDebug(self.maxLiminality .. " maximum liminality", self.liminalTileCount .. " total liminal tiles") end
	end,
	FindPolygonNeighbors = function(self)
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
	end,
	RelaxPolygons = function(self)
		for i, polygon in pairs(self.polygons) do
			self:RelaxToCentroid(polygon)
		end
	end,
	CullPolygons = function(self)
		self.culled = {}
		for i = #self.polygons, 1, -1 do -- have to go backwards, otherwise table.remove screws up the iteration
			local polygon = self.polygons[i]
			if #polygon.hexes == 0 then
				tRemove(self.polygons, i)
				self.culledPolygons = self.culledPolygons + 1
			end
		end
		EchoDebug(self.culledPolygons .. " polygons culled")
	end,
	PostProcessPolygons = function(self)
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
	end,
	PickOceans = function(self)
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
	end,
	PickOceansCylinder = function(self)
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
	end,
	PickOceansRectangle = function(self)
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
	end,
	PickOceansDoughnut = function(self)

	end,
	FindAstronomyBasins = function(self)
		local astronomyIndex = 1
		for i, polygon in pairs(self.polygons) do
			if self:FloodFillAstronomy(polygon, astronomyIndex) then
				astronomyIndex = astronomyIndex + 1
			end
		end
		EchoDebug(astronomyIndex-1 .. " astronomy basins")
	end,
	FloodFillAstronomy = function(self, polygon, astronomyIndex)
		if polygon.oceanIndex then
			polygon.astronomyIndex = polygon.oceanIndex + 10
			return nil
		end
		if polygon.astronomyIndex then return nil end
		polygon.astronomyIndex = astronomyIndex
		for i, neighbor in pairs(polygon.neighbors) do
			self:FloodFillAstronomy(neighbor, astronomyIndex)
		end
		return true
	end,
	PickContinents = function(self)
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
				if neighbor ~= nil and not self:NearOther(neighbor, continentIndex) and neighbor.oceanIndex == nil and polarOkay then
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
	end,
	PickCoasts = function(self)
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
	end,
	ResizeMountains = function(self, perscribedArea)
		if #self.mountainPlots == perscribedArea then return end
		if #self.mountainPlots > perscribedArea then
			repeat
				local pi = tRemoveRandom(self.mountainPlots)
				self.plotTypes[pi] = PlotTypes.PLOT_LAND
			until #self.mountainPlots <= perscribedArea
		elseif #self.mountainPlots < perscribedArea then
			repeat
				local pi = self.mountainPlots[mRandom(1, #self.mountainPlots)]
				local neighbors = self:HexNeighbors(pi)
				local npi
				repeat
					npi = tRemoveRandom(neighbors)
				until self.plotTypes[npi] == PlotTypes.PLOT_LAND or #neighbors == 0
				if npi ~= nil then
					if Map.Rand(10, "hill dice") < self.hillChance then
						self.plotTypes[npi] = PlotTypes.PLOT_HILLS
						tInsert(self.hillPlots, npi)
					else
						self.plotTypes[npi] = PlotTypes.PLOT_MOUNTAIN
						tInsert(self.mountainPlots, npi)
					end
				end
			until #self.mountainPlots >= perscribedArea
		end
	end,
	AdjustMountains = function(self)
		-- first expand them 1.5 times their size
		self:ResizeMountains(#self.mountainPlots * 1.5)
		-- then adjust to the right amount
		self.mountainArea = mCeil(self.mountainRatio * self.filledArea)
		self:ResizeMountains(self.mountainArea)
	end,
	ExpandTinyIslands = function(self)
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
	end,
	ExpandCoasts = function(self)
		for d, dice in ipairs(self.coastExpansionDice) do
			local makeCoast = {}
			for i, pi in pairs(self.deepTiles) do
				if self.terrainTypes[pi] == GameInfoTypes["TERRAIN_OCEAN"] then
					local hex = self.hexes[pi]
					local nearcoast
					for n, npi in pairs(self:HexNeighbors(pi)) do
						local nhex = self.hexes[npi]
						if self.terrainTypes[npi] == GameInfoTypes["TERRAIN_COAST"] then
							local thiscoast = makeCoast[npi] or nhex.coastAstroIndex
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
						end
					end
					if nearcoast and Map.Rand(dice, "expand coast?") == 0 then
						makeCoast[pi] = nearcoast
					end
				end
			end
			for pi, nearcoast in pairs(makeCoast) do
				self.terrainTypes[pi] = GameInfoTypes["TERRAIN_COAST"]
				self.hexes[pi].coastAstroIndex = nearcoast
			end
		end
	end,
	----------------------------------
	-- INTERNAL FUNCTIONS: --
	WrapDistance = function(self, x1, y1, x2, y2)
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
	end,
	SquareDistance = function(self, x1, y1, x2, y2)
		local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
		return (xdist * xdist) + (ydist * ydist)
	end,
    EucDistance = function(self, x1, y1, x2, y2)
    	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
		return mSqrt( (xdist * xdist) + (ydist * ydist) )
    end,
    HexDistance = function(self, x1, y1, x2, y2)
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
    end,
    Minkowski = function(self, x1, y1, x2, y2)
    	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
    	return (xdist^self.minkowskiOrder + ydist^self.minkowskiOrder)^self.inverseMinkowskiOrder
    end,
    ClosestPolygon = function(self, x, y, relax)
    	local dists = {}
    	local closest_distance = 0
    	local closest_polygon
    	-- find the closest point to this point
    	for i = 1, #self.polygons do
    		local polygon = self.polygons[i]
    		-- dists[i] = Map.PlotDistance(polygon.x, polygon.y, x, y)
    		dists[i] = self:EucDistance(polygon.x, polygon.y, x, y)
    		if i == 1 or dists[i] < closest_distance then
    			closest_distance = dists[i]
    			closest_polygon = polygon
    		end
    	end
    	local liminality = 0
    	if not relax then
    		-- sometimes a point is closer to more than one point
	    	for i = 1, #self.polygons do
	    		local polygon = self.polygons[i]
	    		if dists[i] < closest_distance + self.liminalTolerance and polygon ~= closest_polygon then
	    			liminality = liminality + 1
	    		end
	    	end
	    	if liminality > self.maxLiminality then self.maxLiminality = liminality end
	    end
    	return closest_polygon, liminality
    end,
    NewPolygon = function(self, x, y)
		return {
			x = x or Map.Rand(self.iW, "random x"),
			y = y or Map.Rand(self.iH, "random y"),
			hexes = {},
			isNeighbor = {},
			area = 0,
			minX = self.w, maxX = 0, minY = self.h, maxY = 0,
		}
	end,
	SetNeighborPolygons = function(self, polygon1, polygon2)
		polygon1.isNeighbor[polygon2] = true
		polygon2.isNeighbor[polygon1] = true
	end,
	RelaxToCentroid = function(self, polygon)
		if #polygon.hexes ~= 0 then
			local totalX, totalY = 0, 0
			for i, hex in pairs(polygon.hexes) do
				local x, y = hex.x, hex.y
				if self.wrapX then
					local xdist = mAbs(x - polygon.minX)
					if xdist > self.halfWidth then x = x - self.w end
				end
				if self.wrapY then
					local ydist = mAbs(y - polygon.minY)
					if ydist > self.halfHeight then y = y - self.h end
				end
				totalX = totalX + x
				totalY = totalY + y
			end
			local centroidX = mCeil(totalX / #polygon.hexes)
			if centroidX < 0 then centroidX = self.w + centroidX end
			local centroidY = mCeil(totalY / #polygon.hexes)
			if centroidY < 0 then centroidY = self.h + centroidY end
			-- EchoDebug(polygon.x .. ", " .. polygon.y .. "  to  " .. centroidX .. ", " .. centroidY, polygon.index, #polygon.hexes)
			polygon.x, polygon.y = centroidX, centroidY
		end
		polygon.area = 0
		polygon.minX, polygon.minY, maxX, maxY = self.w, self.h, 0, 0
		polygon.hexes = {}
	end,
	CheckBottomTop = function(self, polygon, x, y)
		if y == 0 and polygon.y < self.halfHeight then
			polygon.bottomY = true
			tInsert(self.bottomYPolygons, polygon)
		end
		if x == 0 and polygon.x < self.halfWidth then
			polygon.bottomX = true
			tInsert(self.bottomXPolygons, polygon)
		end
		if y == self.h and polygon.y >= self.halfHeight then
			polygon.topY = true
			tInsert(self.topYPolygons, polygon)
		end
		if x == self.w and polygon.x >= self.halfWidth then
			polygon.topX = true
			tInsert(self.topXPolygons, polygon)
		end
	end,
	NearOther = function(self, polygon, value, key)
		if key == nil then key = "continentIndex" end
		for ni, neighbor in pairs (polygon.neighbors) do
			if neighbor[key] ~= nil and neighbor[key] ~= value then
				return true
			end
		end
		return false
	end,
	HexNeighbors = function(self, index, directions)
		if directions == nil then directions = { 1, 2, 3, 4, 5, 6 } end
		local neighbors = {}
		local thisX, thisY = self:GetXY(index)
		for i, direction in pairs(directions) do
			local x, y = self:HexMove(thisX, thisY, direction)
			tInsert(neighbors, self:GetIndex(x, y))
		end
		return neighbors
	end,
	HexMove = function(self, x, y, direction)
		if direction == 0 or direction == nil then return x, y end
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
			if ny > self.h then ny = 0 elseif ny < 0 then ny = self.h end
		else
			if ny > self.h then ny = self.h elseif ny < 0 then ny = 0 end
		end
		return nx, ny
	end,
	SetPlotTypeXY = function(self, x, y, plotType)
		self.plotTypes[self:GetIndex(x, y)] = plotType
	end,
	GetXY = function(self, index)
		index = index - 1
		return index % self.iW, mFloor(index / self.iW)
	end,
	GetIndex = function(self, x, y)
		return (y * self.iW) + x + 1
	end,
}

------------------------------------------------------------------------------

function GetMapScriptInfo()
	local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
	return {
		Name = "Fantastical dev",
		Description = "Draws voronoi.",
		IconIndex = 5,
	}
end

--[[
function GetMapInitData(worldSize)

end
]]--

function GeneratePlotTypes()
    print("Setting Plot Types (Fantastical) ...")

	Space:Create()
    local plotTypes = Space:ComputePlots()
    SetPlotTypes(plotTypes)
    local args = { bExpandCoasts = false }
    -- GenerateCoasts(args)

end

function GenerateTerrain()
    print("Generating Terrain (Fantastical) ...")
	local terrainTypes = Space:ComputeTerrain()
	SetTerrainTypes(terrainTypes)
end

function SetTerrainTypes(terrainTypes)
	print("Setting Terrain Types (Fantastical)");
	for i, plot in Plots() do
		plot:SetTerrainType(terrainTypes[i+1], false, false)
		-- MapGenerator's SetPlotTypes uses i+1, but MapGenerator's SetTerrainTypes uses just i. wtf.
	end
end

function AddFeatures()
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