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
	polygons = {},
    plotTypes = {}, -- map generation result
    polygonType = {},
    Create = function(self)
        self.iW, self.iH = Map.GetGridSize()
        self.iA = self.iW * self.iH
        self.w = self.iW - 1
        self.h = self.iH - 1
        self.polygonCount = mCeil(self.iA / self.scale)
        print(self.polygonCount)
        self:InitPolygons()
        self:ComputePlots()
        return self.plotTypes
    end,
    InitPolygons = function(self)
    	for i = 1, self.polygonCount do
    		tInsert(self.polygons, self:NewPolygon())
    	end
    end,
    DistanceSquared = function(self, polygon, x, y)
    	local xdist = mAbs(polygon.x - x)
		local ydist = mAbs(polygon.y - y)
		if xdist > self.w / 2 then
			if polygon.x < x then
				xdist = polygon.x + (self.w - x)
			else
				xdist = x + (self.w - polygon.x)
			end
		end
		if ydist > self.h / 2 then
			if polygon.y < y then
				ydist = polygon.y + (self.h - y)
			else
				ydist = y + (self.h - polygon.y)
			end
		end
		return (xdist * xdist) + (ydist * ydist)
    end,
    ClosestPolygon = function(self, x, y)
    	local closest_distance = 0
    	local closest_polygon
    	-- find the closest point to this point
    	for i = 1, #self.polygons do
    		local polygon = self.polygons[i]
    		local dist = self:DistanceSquared(polygon, x, y)
    		if i == 1 or dist < closest_distance then
    			closest_distance = dist
    			closest_polygon = polygon
    		end
    	end
    	return closest_polygon
    end,
    NewPolygon = function(self, x, y)
		return {
			x = x or Map.Rand(self.iW, "random x"),
			y = y or Map.Rand(self.iH, "random y"),
		}
	end,
	ComputePlots = function(self)
		for x = 0, self.w do
			for y = 0, self.h do
				local polygon = self:ClosestPolygon(x, y)
				if polygon ~= nil then
					if self.polygonType[polygon] == nil then
						self.polygonType[polygon] = Map.Rand(4, "pick a plot type")
					end
					local pt = self.polygonType[polygon]
					self:SetPlotTypeXY(x, y, plotTypeMap[pt])
				else
					print("nil polygon")
				end
			end
		end
	end,
	DrawSegment = function(self, segment)
		local indices = self:GetIndicesInLine(segment.startPoint.x, segment.startPoint.y, segment.endPoint.x, segment.endPoint.y)
		for i, pi in pairs(indices) do
			self.plotTypes[pi] = PlotTypes.PLOT_LAND
		end
	end,
	SetPlotTypeXY = function(self, x, y, plotType)
		self.plotTypes[self:GetIndex(x, y)] = plotType
	end,
	GetIndex = function(self, x, y)
		return (y * self.iW) + x + 1
	end,
	GetIndicesInLine = function(self, x1, y1, x2, y2)
		local plots = {}
		local x1, y1 = mCeil(x1), mCeil(y1)
		local x2, y2 = mCeil(x2), mCeil(y2)
		if x1 > x2 then
			local x1store = x1+0
			x1 = x2+0
			x2 = x1store
		end
		if y1 > y2 then
			local y1store = y1+0
			y1 = y2+0
			y2 = y1store
		end
		local dx = x2 - x1
		local dy = y2 - y1
		if dx == 0 then
			if dy ~= 0 then
				for y = y1, y2 do
					tInsert(plots, self:GetIndex(x1, y))
				end
			end
		elseif dy == 0 then
			if dx ~= 0 then
				for x = x1, x2 do
					tInsert(plots, self:GetIndex(x, y1))
				end
			end
		else
			local m = dy / dx
	        local b = y1 - m*x1
			for x = x1, x2 do
				local y = mFloor( (m * x) + b + 0.5 )
				tInsert(plots, self:GetIndex(x, y))
			end
		end
		return plots
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

    local plotTypes = Space:Create()
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