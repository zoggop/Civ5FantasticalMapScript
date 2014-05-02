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

local debugEnabled = false
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

local plotTypeMap = {}

------------------------------------------------------------------------------

local Space =
{
	scale = 20, -- how many tiles of map area per voronoi point
	maxContinentPolygons = 4, -- how many polygons can make up a continent at maximum
	landRatio = 0.3, -- how much of the map is land
	wrapX = true,
	wrapY = false,
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
        self.landArea = self.iA * self.landRatio
        self.w = self.iW - 1
        self.h = self.iH - 1
        self.halfWidth = self.w / 2
        self.halfHeight = self.h / 2
        self.polygonCount = mCeil(self.iA / self.scale)
        print(self.polygonCount)
        self:InitPolygons()
        self:FillPolygons()
        self:PickContinents()
        return self.plotTypes
    end,
    ComputePlots = function(self)
    	--[[
		for pi, hex in pairs(self.hexes) do
			local polygon = hex.polygon
			if self.polygonType[polygon] == nil then
				self.polygonType[polygon] = Map.Rand(3, "pick a plot type")
			end
			if hex.liminality == 0 then
				local pt = self.polygonType[polygon]
				self.plotTypes[hex.index] = plotTypeMap[pt]
			else
				self.plotTypes[hex.index] = PlotTypes.PLOT_MOUNTAIN
			end
		end
		]]--
		for c, continent in pairs(self.continents) do
			for p, polygon in pairs(continent) do
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
		return (xdist * xdist) + (ydist * ydist)
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
    			table.insert(closest_polygon.neighbors, polygon)
    			liminality = liminality + 1
    		end
    	end
    	return closest_polygon, liminality
    end,
    NewPolygon = function(self, x, y)
		return {
			x = x or Map.Rand(self.iW, "random x"),
			y = y or Map.Rand(self.iH, "random y"),
			hexes = {},
			neighbors = {},
			area = 0,
		}
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
				else
					print("nil polygon")
				end
			end
		end
	end,
	PickContinents = function(self)
		local polygonBuffer = {}
		for i, polygon in pairs(self.polygons) do
			tInsert(polygonBuffer, polygon)
		end
		local filledArea = 0
		while #polygonBuffer > 0 and filledArea < self.landArea do
			local i = mRandom(1, #polygonBuffer)
			local polygon = table.remove(polygonBuffer, i)
			if #polygon.neighbors ~= 0 and not polygon.picked then
				polygon.picked = true
				filledArea = filledArea + polygon.area
				local size = mRandom(1, self.maxContinentPolygons)
				local continent = { polygon }
				local neighbor = polygon
				for n = 1, size do
					if #neighbor.neighbors > 0 then
						local ni = mRandom(1, #neighbor.neighbors)
						neighbor = neighbor.neighbors[ni]
					end
					if not neighbor.picked then
						neighbor.picked = true
						filledArea = filledArea + neighbor.area
						tInsert(continent, neighbor)
					end
				end
				tInsert(self.continents, continent)
			end
		end
	end,
	SetPlotTypeXY = function(self, x, y, plotType)
		self.plotTypes[self:GetIndex(x, y)] = plotType
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

    plotTypeMap = {
    	[0] = PlotTypes.PLOT_OCEAN,
    	[1] = PlotTypes.PLOT_LAND,
    	[2] = PlotTypes.PLOT_HILLS,
    	[3] = PlotTypes.PLOT_MOUNTAIN,
	}

	Space:Create()
    local plotTypes = Space:ComputePlots()
    SetPlotTypes(plotTypes)
    local args = { bExpandCoasts = false }
    GenerateCoasts(args) -- will have to look into that as I want to avoid coasts spanning into oceans as they currently do too easily

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