require "common"
require "climate"

local terrainRegions = {
	{ name = "grassland", targetArea = 0.38, highT = true, highR = true,
		points = {
			{t = 100, r = 75},
			{t = 75, r = 100}
		},
		relations = {
			plains = {t = 1, r = 1},
			desert = {n = -1},
			tundra = {n = -1},
		},
		subRegionNames = {"none", "forest", "jungle", "marsh"},
		color = {0, 127, 0}
	},
	{ name = "plains", targetArea = 0.33, noLowT = true, noLowR = true,
		points = {
			{t = 75, r = 50},
			{t = 50, r = 75}
		},
		relations = {
			grassland = {t = -1, r = -1},
			desert = {r = 1},
			tundra = {t = 1} 
		},
		subRegionNames = {"none", "forest"},
		color = {127, 127, 0}
	},
	{ name = "desert", targetArea = 0.12, lowR = true,
		points = {
			{t = 25, r = 0},
			{t = 75, r = 0}
		},
		relations = {
			plains = {r = -1},
			tundra = {t = 1} 
		},
		subRegionNames = {"none", "oasis"},
		color = {127, 127, 63}
	},
	{ name = "tundra", targetArea = 0.09, lowT = true,
		points = {
			{t = 0, r = 25},
			{t = 0, r = 75}
		},
		relations = {
			desert = {t = -1},
			plains = {t = -1},
			snow = {r = 1},
		},
		subRegionNames = {"none", "forest"},
		color = {63, 63, 63}
	},
	{ name = "snow", targetArea = 0.02, fixed = true, lowT = true, lowR = true,
		points = {
			{t = 0, r = 0}
		},
		subRegionNames = {"none"},
		relations = {
			tundra = {r = -1},
		},
		color = {127, 127, 127}
	},
}

local featureRegions = {
	{ name = "none", targetArea = 0.70,
		points = {
			{t = 45, r = 55},
			-- {t = 55, r = 45},
		},
		relations = {},
		containedBy = { "grassland", "plains", "desert", "tundra", "snow" },
		color = {255, 255, 255, 0}
	},
	{ name = "forest", targetArea = 0.17, highR = true,
		points = {
			{t = 40, r = 60},
			-- {t = 25, r = 40},
		},
		relations = {},
		containedBy = { "grassland", "plains", "tundra" },
		color = {255, 255, 0, 127}
	},
	{ name = "jungle", targetArea = 0.1, highR = true, highT = true,
		points = {
			{t = 100, r = 100},
			-- {t = 90, r = 90},
		},
		containedBy = { "grassland" },
		relations = {},
		color = {0, 255, 0, 127}
	},
	{ name = "marsh", targetArea = 0.02, highR = true,
		points = {
			{t = 40, r = 75},
		},
		containedBy = { "grassland" },
		relations = {},
		color = {0, 0, 255, 127}
	},
	{ name = "oasis", targetArea = 0.01,
		points = {
			{t = 80, r = 50}
		},
		containedBy = { "desert" },
		relations = {},
		color = {255, 0, 0, 127}
	},
}

local myClimate

function love.load()
    love.window.setMode(displayMult * 100 + 200, displayMult * 100 + 100, {resizable=false, vsync=false})
    myClimate = Climate(terrainRegions, featureRegions)
end

function love.mousereleased(x, y, button)
   if button == 'l' then
   		local output = ""
	   for i, point in pairs(myClimate.pointSet.points) do
	   		output = output .. point.region.name .. ": " .. point.t .. "," .. point.r .. "\n"
	   end
	   for i, point in pairs(myClimate.subPointSet.points) do
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
				love.graphics.rectangle("fill", t*displayMult, displayMultHundred-r*displayMult, displayMult, displayMult)
			elseif myClimate.latitudePoints[t .. " " .. r] then
				love.graphics.setColor( 127, 0, 0 )
				love.graphics.rectangle("fill", t*displayMult, displayMultHundred-r*displayMult, displayMult, displayMult)
			else
				love.graphics.setColor( point.region.color )
				love.graphics.rectangle("fill", t*displayMult, displayMultHundred-r*displayMult, displayMult, displayMult)
			end
		end
	end
	for t, rains in pairs(myClimate.subPointSet.grid) do
		for r, point in pairs(rains) do
			if point.t == t and point.r == r then
				love.graphics.setColor( 255, 0, 255 )
				love.graphics.rectangle("fill", t*displayMult, displayMultHundred-r*displayMult, displayMult, displayMult)
			else
				love.graphics.setColor( point.region.color )
				love.graphics.rectangle("fill", t*displayMult, displayMultHundred-r*displayMult, displayMult, displayMult)
			end
		end
	end
	local y = 0
	for name, region in pairs(myClimate.regionsByName) do
		if region.containedBy then
			love.graphics.setColor( 255, 255, 127 )
		else
			love.graphics.setColor( 127, 255, 255 )
		end
		love.graphics.print(region.name .. "\n" .. (region.stableLatitudeArea or "nil") .. "/" .. mFloor(region.targetLatitudeArea) .. "\n" .. (region.stableArea or "nil") .. "/" .. mFloor(region.targetArea) .. "\n", displayMultHundred+70, y)
		y = y + 50
	end
	love.graphics.setColor( 255, 255, 255 )
	for i, point in pairs(myClimate.pointSet.points) do
		love.graphics.print( point.region.name .. "\n" .. (point.latitudeArea or "nil") .. "\n" .. (point.area or "nil") .. "\n" .. point.t .. "," .. point.r .. "\n" .. mFloor(point.tMove or 0) .. "," .. mFloor(point.rMove or 0), point.t*displayMult, displayMultHundred-point.r*displayMult)
	end
	for i, point in pairs(myClimate.subPointSet.points) do
		love.graphics.print( point.region.name .. "\n" .. (point.latitudeArea or "nil") .. "\n" .. (point.area or "nil") .. "\n" .. point.t .. "," .. point.r .. "\n" .. mFloor(point.tMove or 0) .. "," .. mFloor(point.rMove or 0), point.t*displayMult, displayMultHundred-point.r*displayMult)
	end
	love.graphics.setColor(255, 0, 0)
	love.graphics.print(myClimate.nearestString, 10, displayMultHundred + 70)
end

function love.update(dt)
	myClimate:Optimize()
   love.window.setTitle( myClimate.iterations .. " " .. myClimate.pointSet.generation .. " " .. mFloor(myClimate.pointSet.distance or 0) .. " (" .. myClimate.subPointSet.generation .. " " .. mFloor(myClimate.subPointSet.distance or 0) ..") " .. myClimate.mutationStrength )
end