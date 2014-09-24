require "common"
require "climate"

--[[
grassland: 49,66
desert: 23,1
plains: 21,61
snow: 0,64
tundra: 9,62
grassland: 88,54
tundra: 14,22
desert: 59,8
snow: 1,24
plains: 61,21
]]--

local terrainRegions = {
	{ name = "grassland", targetArea = 0.40, highT = true, highR = true,
		points = {
			{t = 100, r = 75},
			{t = 75, r = 100}
		},
		relations = {
			-- plains = {t = 1, r = 1},
			desert = {n = -1},
			tundra = {n = -1},
		},
		subRegionNames = {"none", "forest", "jungle", "marsh"},
		color = {0, 127, 0}
	},
	{ name = "plains", targetArea = 0.30, noLowT = true, noLowR = true,
		points = {
			{t = 75, r = 50},
			{t = 50, r = 75}
		},
		relations = {
			-- grassland = {t = -1, r = -1},
			desert = {r = 1},
			tundra = {t = 1} 
		},
		subRegionNames = {"none", "forest"},
		color = {127, 127, 0}
	},
	{ name = "desert", targetArea = 0.13, lowR = true,
		points = {
			{t = 25, r = 0},
			{t = 75, r = 0}
		},
		relations = {
			plains = {r = -1},
			tundra = {t = 1},
			grassland = {n = -1},
		},
		subRegionNames = {"none", "oasis"},
		color = {127, 127, 63}
	},
	{ name = "tundra", targetArea = 0.1, noLowR = true, contiguous = true,
		points = {
			{t = 3, r = 25},
			{t = 1, r = 75}
		},
		relations = {
			desert = {t = -1},
			plains = {t = -1},
			snow = {t = 1},
			grassland = {n = -1},
		},
		subRegionNames = {"none", "forest"},
		color = {63, 63, 63}
	},
	{ name = "snow", targetArea = 0.07, lowT = true, maxR = 75, contiguous = true,
		points = {
			{t = 0, r = 25},
			{t = 0, r = 70},
		},
		subRegionNames = {"none"},
		relations = {
			tundra = {t = -1},
			plains = {n = -1},
		},
		color = {127, 127, 127}
	},
}

local featureRegions = {
	{ name = "none", targetArea = 0.70,
		points = {
			{t = 60, r = 40},
			-- {t = 55, r = 45},
		},
		relations = {},
		containedBy = { "grassland", "plains", "desert", "tundra", "snow" },
		color = {255, 255, 255, 0}
	},
	{ name = "forest", targetArea = 0.17, highR = true,
		points = {
			{t = 45, r = 60},
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
			{t = 90, r = 0}
		},
		containedBy = { "desert" },
		relations = {},
		color = {255, 0, 0, 127}
	},
}

nullFeatureRegions = {
	{ name = "none", targetArea = 1.0,
		points = {
			{t = 50, r = 50},
		},
		relations = {},
		containedBy = { "grassland", "plains", "desert", "tundra", "snow" },
		color = {255, 255, 255, 0}
	},
}

local myClimate

function love.load()
    love.window.setMode(displayMult * 100 + 200, displayMult * 100 + 100, {resizable=false, vsync=false})
    myClimate = Climate(terrainRegions, nullFeatureRegions)
end

function love.keyreleased(key)
	if key == "c" or key == "s" then
		local output = ""
		for i, point in pairs(myClimate.pointSet.points) do
			output = output .. point.region.name .. " " .. point.t .. "," .. point.r .. "\n"
		end
		for i, point in pairs(myClimate.subPointSet.points) do
			output = output .. point.region.name .. " " .. point.t .. "," .. point.r .. "\n"
		end
		if key == "c" then
			-- save points to clipboard
			love.system.setClipboardText( output )
		elseif key == "s" then
			-- save points to file
			local success = love.filesystem.write( "points.txt", output )
			if success then print('points.txt written') end
		end
	elseif key == "f" then
		myClimate = Climate(nil, featureRegions, myClimate)
	elseif key == "l" or key == "v" then
		-- load points from file
		local lines
		if key == "l" then
			if love.filesystem.exists( "points.txt" ) then
				print('points.txt exists')
				lines = love.filesystem.lines("points.txt")
			end
		elseif key == "v" then
			local clipText = love.system.getClipboardText()
			local clipLines = clipText:split("\n")
			if #clipLines > 0 then
				lines = pairs(clipLines)
			end
		end
		if lines then
			myClimate.pointSet = PointSet(myClimate)
			myClimate.subPointSet = PointSet(myClimate, nil, true)
			for line in love.filesystem.lines("points.txt") do
				local words = splitIntoWords(line)
				local regionName = words[1]
				local tr = {}
				for i, n in pairs(words[2]:split(",")) do tInsert(tr, n) end
				local t, r = tr[1], tr[2]
				print(regionName, t, r)
				local region = myClimate.subRegionsByName[regionName] or myClimate.superRegionsByName[regionName]
				if region then
					if region.isSub then
						pointSet = myClimate.subPointSet
					else
						pointSet = myClimate.pointSet
					end
					local point = Point(region, t, r)
					pointSet:AddPoint(point)
				end
			end
			print('points loaded from file')
		end
	end
end

local buttonPointSets = { l = 'pointSet', r = 'subPointSet' }
local mousePress = {}
local mousePoint = {}
local mousePointOriginalPosition = {}

function love.mousepressed(x, y, button)
	if buttonPointSets[button] then
		local t, r = DisplayToGrid(x, y)
		local pointSet = myClimate[buttonPointSets[button]]
		local point = pointSet:NearestPoint(t, r)
		if love.keyboard.isDown( 'lctrl' ) then
			if love.keyboard.isDown( 'lshift' ) then
				-- delete a point
				for i = #point.pointSet.points, 1, -1 do
					if point.pointSet.points[i] == point then
						tRemove(point.pointSet.points, i)
						break
					end
				end
			else
				-- insert a point
				local insertPoint = Point(point.region, t, r)
				pointSet:AddPoint(insertPoint)
			end
			pointSet:Fill()
			if pointSet.isSub then
				regions = myClimate.subRegions
			else
				regions = myClimate.regions
			end
			myClimate:GiveRegionsExcessAreas(regions)
			pointSet:GiveDistance()
		else
			mousePoint[button] = point
			mousePointOriginalPosition[button] = { t = point.t, r = point.r }
			point.fixed = true
		end
	end
	mousePress[button] = {x = x, y = y}
end

function love.mousereleased(x, y, button)
	if mousePoint[button] then
		mousePoint[button].fixed = false
	end
	mousePoint[button] = nil
	mousePress[button] = nil
	mousePointOriginalPosition[button] = nil
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
				love.graphics.setColor( 255, 255, 255 )
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
	for i, point in pairs(myClimate.pointSet.points) do
		if point.fixed then
			love.graphics.setColor( 255, 0, 255 )
		else
			love.graphics.setColor( 255, 255, 255 )
		end
		love.graphics.print( point.region.name .. "\n" .. (point.latitudeArea or "nil") .. "\n" .. (point.area or "nil") .. "\n" .. point.t .. "," .. point.r .. "\n" .. mFloor(point.tMove or 0) .. "," .. mFloor(point.rMove or 0), point.t*displayMult, displayMultHundred-point.r*displayMult)
	end
	for i, point in pairs(myClimate.subPointSet.points) do
		if point.fixed then
			love.graphics.setColor( 255, 0, 255 )
		else
			love.graphics.setColor( 255, 255, 255 )
		end
		love.graphics.print( point.region.name .. "\n" .. (point.latitudeArea or "nil") .. "\n" .. (point.area or "nil") .. "\n" .. point.t .. "," .. point.r .. "\n" .. mFloor(point.tMove or 0) .. "," .. mFloor(point.rMove or 0), point.t*displayMult, displayMultHundred-point.r*displayMult)
	end
	love.graphics.setColor(255, 0, 0)
	love.graphics.print(myClimate.nearestString, 10, displayMultHundred + 70)
end

function love.update(dt)
	for button, point in pairs(mousePoint) do
		local curT, curR = DisplayToGrid(love.mouse.getX(), love.mouse.getY())
		local pressT, pressR = DisplayToGrid(mousePress[button].x, mousePress[button].y)
		local dt = curT - pressT
		local dr = curR - pressR
		point.t = mMax(0, mMin(100, mousePointOriginalPosition[button].t + dt))
		point.r = mMax(0, mMin(100, mousePointOriginalPosition[button].r + dr))
	end
	myClimate:Optimize()
   love.window.setTitle( myClimate.iterations .. " " .. myClimate.pointSet.generation .. " " .. mFloor(myClimate.pointSet.distance or 0) .. " (" .. myClimate.subPointSet.generation .. " " .. mFloor(myClimate.subPointSet.distance or 0) ..") " .. myClimate.mutationStrength )
end