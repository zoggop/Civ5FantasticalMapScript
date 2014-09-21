require "common"
require "climate"

local terrainRegions = {
	{ name = "grassland", targetArea = 0.33, highT = true, highR = true,
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
	{ name = "desert", targetArea = 0.18, lowR = true,
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
	{ name = "tundra", targetArea = 0.16, lowT = true,
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
	{ name = "snow", targetArea = 0.08, fixed = true, lowT = true, lowR = true,
		points = {
			{t = 0, r = 0}
		},
		relations = {},
		color = {127, 127, 127}
	},
}

local featureRegions = {
	{ name = "none", targetArea = 0.5,
		targetTerrainAreas = {
			grassland = 0.5,
			plains = 0.5,
			desert = 0.9,
			tundra = 0.5,
			snow = 1.0,
		},
		points = {
			{t = 50, r = 50},
		},
		relations = {
			plains = {t = 1, r = 1},
			desert = {n = -1},
			tundra = {n = -1},
		},
		color = {0, 0, 0, 127}
	},
	{ name = "forest", targetArea = 0.25,
		targetTerrainAreas = {
			grassland = 0.25,
			plains = 0.5,
			tundra = 0.5,
		},
		points = {
			{t = 52, r = 90},
		},
		relations = {
			grassland = {t = -1, r = -1},
			desert = {r = 1},
			tundra = {t = 1} 
		},
		color = {127, 255, 0, 127}
	},
	{ name = "jungle", targetArea = 0.15,
		targetTerrainAreas = {
			grassland = 0.25,
		},
		points = {
			{t = 100, r = 100},
		},
		relations = {
			plains = {r = -1},
			tundra = {t = 1} 
		},
		color = {0, 255, 0, 127}
	},
	{ name = "marsh", targetArea = 0.08,
		points = {
			{t = 50, r = 100},
		},
		relations = {
			desert = {t = -1},
			plains = {t = -1} 
		},
		color = {0, 127, 255, 127}
	},
	{ name = "oasis", targetArea = 0.02,
		points = {
			{t = 100, r = 50}
		},
		relations = {},
		color = {255, 0, 0, 127}
	},
}

for i, region in pairs(terrainRegions) do
	region.targetLatitudeArea = region.targetArea * 90
	region.targetArea = region.targetArea * 10000
end

local myClimate

function love.load()
    love.window.setMode(600, 600, {resizable=false, vsync=false})
    myClimate = Climate(terrainRegions)
end

function love.mousereleased(x, y, button)
   if button == 'l' then
   		local output = ""
	   for i, point in pairs(myClimate.pointSet.points) do
	   		output = output .. point.region.name .. ": " .. point.t .. "," .. point.r .. "\n"
	   end
	   love.system.setClipboardText( output )
   elseif button == 'r' then
   		myClimate = Climate(terrainRegions)
   end
end

function love.draw()
	for t, rains in pairs(myClimate.pointSet.grid) do
		for r, point in pairs(rains) do
			if point.t == t and point.r == r then
				love.graphics.setColor( 0, 0, 0 )
				love.graphics.rectangle("fill", t*5, 500-r*5, 5, 5)
			elseif myClimate.latitudePoints[t .. " " .. r] then
				love.graphics.setColor( 127, 0, 0 )
				love.graphics.rectangle("fill", t*5, 500-r*5, 5, 5)
			else
				love.graphics.setColor( point.region.color )
				love.graphics.rectangle("fill", t*5, 500-r*5, 5, 5)
			end
		end
	end
	love.graphics.setColor( 255, 255, 255 )
	for i, point in pairs(myClimate.pointSet.points) do
		love.graphics.print(point.region.name .. "\n" .. (point.region.stableLatitudeArea or "nil") .. "/" .. mFloor(point.region.targetLatitudeArea) .. ", " .. (point.latitudeArea or "nil") .. "\n" .. (point.region.stableArea or "nil") .. "/" .. mFloor(point.region.targetArea) .. ", " .. (point.area or "nil") .. "\n" .. point.t .. "," .. point.r .. "\n" .. mFloor(point.tMove or 0) .. "," .. mFloor(point.rMove or 0), point.t*5, 500-point.r*5)
	end
	love.graphics.setColor(255, 0, 0)
	love.graphics.print(myClimate.nearestString, 10, 570)
end

function love.update(dt)
	myClimate:Optimize()
   love.window.setTitle( myClimate.iterations .. " " .. myClimate.generations .. " " .. mFloor(myClimate.pointSet.distance) )
end