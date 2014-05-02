-- Map Script: Fantastical
-- Author: zoggop
-- version 1

--------------------------------------------------------------
if include == nil then
	package.path = package.path..';C:\\Program Files (x86)\\Steam\\steamapps\\common\\Sid Meier\'s Civilization V\\Assets\\Gameplay\\Lua\\?.lua'
	include = require
end
include("math")
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


------------------------------------------------------------------------------

local Space =
{
	polygonCount = 200, -- how many polygons (map scale)
	oceanNumber = 2, -- how many large ocean basins
	majorContinentNumber = 2, -- how many large continents, more or less
	islandRatio = 0.1, -- what part of the continent polygons are taken up by 1-2 polygon continents
	wrapX = true,
	wrapY = false,
	oceans = {},
	continents = {},
	regions = {},
	polygons = {},
	hexes = {},
    plotTypes = {}, -- map generation result
    terrainTypes = {}, -- map generation result
    featureTypes = {}, -- map generation result
    polygonType = {},
    Create = function(self)
        self.iW, self.iH = Map.GetGridSize()
        self.iA = self.iW * self.iH
        self.nonOceanArea = self.iA
        self.w = self.iW - 1
        self.h = self.iH - 1
        self.halfWidth = self.w / 2
        self.halfHeight = self.h / 2
        self.polygonCount = math.min(mCeil(self.iA / 5), self.polygonCount)
        self.polygonCount = math.max(self.polygonCount, mCeil(self.iA / 60))
        self.nonOceanPolygons = self.polygonCount
        EchoDebug(self.polygonCount .. " polygons", self.iA .. " hexes")
        self:InitPolygons()
        self:FillPolygons()
        self:ListPolygonNeighbors()
        self:PickOceans()
        self:PickContinents()
        return self.plotTypes
    end,
    ComputePlots = function(self)
		for c, continent in pairs(self.continents) do
			for p, polygon in pairs(continent.polygons) do
				for h, hex in pairs(polygon.hexes) do
					self.plotTypes[hex.index] = PlotTypes.PLOT_LAND
				end
			end
		end
		for pi, hex in pairs(self.hexes) do
			if self.plotTypes[hex.index] == nil then
				self.plotTypes[hex.index] = PlotTypes.PLOT_OCEAN
			end
		end
		return self.plotTypes
	end,
    ComputeTerrain = function(self)
    	return self.terrainTypes
    end,
    ComputeFeatures = function(self)
    	return featureTypes
    end,
    DeepenOcean = function(self)
    	for oceanIndex, ocean in pairs(self.oceans) do
			for p, polygon in pairs(ocean) do
				for h, hex in pairs(polygon.hexes) do
					local plot = Map.GetPlotByIndex(hex.index - 1)
					plot:SetTerrainType(GameDefines.DEEP_WATER_TERRAIN, false, false)
				end
			end
		end
    end,
    InitPolygons = function(self)
    	for i = 1, self.polygonCount do
    		tInsert(self.polygons, self:NewPolygon())
    	end
    end,
    DistanceSquared = function(self, polygon, x, y)
    	local xdist = mAbs(polygon.x - x)
		local ydist = mAbs(polygon.y - y)
		if self.wrapX then
			if xdist > self.halfWidth then
				if polygon.x < x then
					xdist = polygon.x + (self.w - x)
				else
					xdist = x + (self.w - polygon.x)
				end
			end
		end
		if self.wrapY then
			if ydist > self.halfHeight then
				if polygon.y < y then
					ydist = polygon.y + (self.h - y)
				else
					ydist = y + (self.h - polygon.y)
				end
			end
		end
		return mSqrt ( (xdist * xdist) + (ydist * ydist) )
    end,
    ClosestPolygon = function(self, x, y)
    	local dists = {}
    	local closest_distance = 0
    	local closest_polygon
    	-- find the closest point to this point
    	for i = 1, #self.polygons do
    		local polygon = self.polygons[i]
    		dists[i] = self:DistanceSquared(polygon, x, y)
    		if i == 1 or dists[i] < closest_distance then
    			closest_distance = dists[i]
    			closest_polygon = polygon
    		end
    	end
    	-- sometimes a point is closer to more than one point
    	local liminality = 0
    	for i = 1, #self.polygons do
    		local polygon = self.polygons[i]
    		if dists[i] == closest_distance and polygon ~= closest_polygon then
    			liminality = liminality + 1
    		end
    	end
    	return closest_polygon, liminality
    end,
    NewPolygon = function(self, x, y, index)
		return {
			x = x or Map.Rand(self.iW, "random x"),
			y = y or Map.Rand(self.iH, "random y"),
			hexes = {},
			isNeighbor = {},
			area = 0,
			index = index or #self.polygons+1,
		}
	end,
	SetNeighborPolygons = function(self, polygon1, polygon2)
		polygon1.isNeighbor[polygon2] = true
		polygon2.isNeighbor[polygon1] = true
	end,
	FillPolygons = function(self)
		for x = 0, self.w do
			for y = 0, self.h do
				local polygon, liminality = self:ClosestPolygon(x, y)
				if polygon ~= nil then
					local pi = self:GetIndex(x, y)
					local hex = { polygon = polygon, liminality = liminality, index = pi, x = x, y = y }
					self.hexes[pi] = hex
					tInsert(polygon.hexes, hex)
					polygon.area = polygon.area + 1
					if y == 0 then polygon.bottomY = true end
					if x == 0 then polygon.bottomX = true end
					if y == self.h then polygon.topY = true end
					if x == self.w then polygon.topX = true end
					-- find neighbors from one hex to the next
					for i, nindex in pairs(self:HexNeighbors(pi)) do
						if nindex ~= pi then
							local nhex = self.hexes[nindex]
							if nhex ~= nil then
								if nhex.polygon ~= nil and nhex.polygon ~= hex.polygon then
									self:SetNeighborPolygons(polygon, nhex.polygon)
								end
							end
						end
					end
				else
					EchoDebug("nil polygon")
				end
			end
		end
	end,
	ListPolygonNeighbors = function(self)
		for i, polygon in pairs(self.polygons) do
			polygon.neighbors = {}
			for neighbor, yes in pairs(polygon.isNeighbor) do
				tInsert(polygon.neighbors, neighbor)
			end
		end
	end,
	PickOceans = function(self)
		local div = self.w / self.oceanNumber
		local x = mRandom(0, self.w)
		for oceanIndex = 1, self.oceanNumber do
			local hex = self.hexes[self:GetIndex(x, 0)]
			local polygon = hex.polygon
			if polygon == nil then EchoDebug(x .. ',0 has no polygon') end
			local ocean = {}
			while #polygon.neighbors ~= 0 do
				polygon.oceanIndex = oceanIndex
				tInsert(ocean, polygon)
				self.nonOceanArea = self.nonOceanArea - polygon.area
				self.nonOceanPolygons = self.nonOceanPolygons - 1
				if polygon.topY then break end
				local upNeighbors = {}
				for ni, neighbor in pairs(polygon.neighbors) do
					if (neighbor.y > polygon.y or neighbor.topY) and not self:NearOther(neighbor, oceanIndex, "oceanIndex") then
						tInsert(upNeighbors, neighbor)
					end
				end
				if #upNeighbors == 0 then break end
				for ni, neighbor in pairs(upNeighbors) do
					neighbor.oceanIndex = oceanIndex
					tInsert(ocean, neighbor)
					self.nonOceanArea = self.nonOceanArea - neighbor.area
					self.nonOceanPolygons = self.nonOceanPolygons - 1
				end
				polygon = upNeighbors[mRandom(1, #upNeighbors)]
			end
			tInsert(self.oceans, ocean)
			x = mCeil(x + div) % self.w
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
	PickContinents = function(self)
		local polygonBuffer = {}
		for i, polygon in pairs(self.polygons) do
			tInsert(polygonBuffer, polygon)
		end
		local filledArea = 0
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
				polygon = tRemove(polygonBuffer, mRandom(1, #polygonBuffer))
			until polygon.continentIndex == nil and not self:NearOther(polygon, nil) and not self:NearOther(polygon, nil, "oceanIndex") and polygon.oceanIndex == nil and (self.wrapY or (not polygon.topY and not polygon.bottomY)) and (self.wrapX or (not polygon.topX and not polygon.bottomX))
			polygon.continentIndex = continentIndex
			filledArea = filledArea + polygon.area
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
				if neighbor ~= nil and not self:NearOther(neighbor, continentIndex) and neighbor.oceanIndex == nil then
					neighbor.continentIndex = continentIndex
					filledArea = filledArea + neighbor.area
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
		EchoDebug(continentIndex-1 .. " continents", filledPolygons .. " filled polygons", filledArea .. " filled hexes")
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
    GenerateCoasts(args) -- will have to look into that as I want to avoid coasts spanning into oceans as they currently do too easily
    --Space:DeepenOcean()

end


function GenerateTerrain()
	--[[
    print("Generating Terrain (Using default for the moment) ...")
    
    local terraingen = TerrainGenerator.Create()
    local terrainTypes = terraingen:GenerateTerrain()
        
    SetTerrainTypes(terrainTypes)
    ]]--
end

function AddFeatures()
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