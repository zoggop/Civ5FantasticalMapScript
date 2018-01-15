require "common"
require "climate"

-- local TerrainDictionary = {
-- 	[terrainGrass] = { points = {}, features = { featureNone, featureForest, featureJungle, featureMarsh, featureFallout } },
-- 	[terrainPlains] = { points = {}, features = { featureNone, featureForest, featureFallout } },
-- 	[terrainDesert] = { points = {}, features = { featureNone, featureOasis, featureFallout }, specialFeature = featureOasis },
-- 	[terrainTundra] = { points = {}, features = { featureNone, featureForest, featureFallout } },
-- 	[terrainSnow] = { points = {}, features = { featureNone, featureFallout } },
-- }

-- local FeatureDictionary = {
-- 	[featureNone] = { points = {}, percent = 100, limitRatio = -1, hill = true },
-- 	[featureForest] = { points = {}, percent = 100, limitRatio = 0.85, hill = true },
-- 	[featureJungle] = { points = {}, percent = 100, limitRatio = 0.85, hill = true, terrainType = terrainPlains },
-- 	[featureMarsh] = { points = {}, percent = 100, limitRatio = 0.33, hill = false },
-- 	[featureOasis] = { points = {}, percent = 2.4, limitRatio = 0.01, hill = false },
-- 	[featureFallout] = { points = {}, disabled = true, percent = 0, limitRatio = 0.75, hill = true },
-- }

local terrainRegions = {
	{ name = "grassland", dictName = "terrainGrass", targetArea = 0.36, highT = true, highR = true, noLowR = true, noLowT = true,
		points = {
			-- {t = 100, r = 75},
			{t = 75, r = 100}
		},
		relations = {
			-- plains = {t = 1, r = 1},
			desert = {t = -1, r = 1},
			tundra = {n = -1},
		},
		subRegionNames = {"none", "forest", "jungle", "marsh"},
		remainderString = "features = { featureNone, featureForest, featureJungle, featureMarsh, featureFallout }",
		color = {0, 127, 0}
	},
	{ name = "plains", dictName = "terrainPlains", targetArea = 0.26, noLowT = true, noLowR = true,
		points = {
			-- {t = 75, r = 50},
			{t = 50, r = 75}
		},
		relations = {
			-- grassland = {t = -1, r = -1},
			desert = {r = 1},
			tundra = {t = 1} 
		},
		subRegionNames = {"none", "forest"},
		remainderString = "features = { featureNone, featureForest, featureFallout }",
		color = {127, 127, 0}
	},
	{ name = "desert", dictName = "terrainDesert", targetArea = 0.195, lowR = true, noHighR = true,
		points = {
			-- {t = 25, r = 0},
			{t = 80, r = 0}
		},
		relations = {
			plains = {r = -1},
			tundra = {t = 1},
			grassland = {t = 1, r = -1},
		},
		subRegionNames = {"none", "oasis"},
		remainderString = "features = { featureNone, featureOasis, featureFallout }, specialFeature = featureOasis",
		color = {127, 127, 63}
	},
	{ name = "tundra", dictName = "terrainTundra", targetArea = 0.13, contiguous = true, noHighT = true,
		points = {
			{t = 3, r = 25},
			-- {t = 1, r = 75}
		},
		relations = {
			desert = {t = -1},
			plains = {t = -1},
			snow = {t = 1},
			grassland = {n = -1},
		},
		subRegionNames = {"none", "forest"},
		remainderString = "features = { featureNone, featureForest, featureFallout }",
		color = {63, 63, 63}
	},
	{ name = "snow", dictName = "terrainSnow", targetArea = 0.065, lowT = true, contiguous = true, noHighT = true,
		points = {
			{t = 0, r = 25},
			-- {t = 0, r = 70},
		},
		subRegionNames = {"none"},
		remainderString = "features = { featureNone, featureFallout }",
		relations = {
			tundra = {t = -1},
			plains = {n = -1},
		},
		color = {127, 127, 127}
	},
}

-- 

local featureRegions = {
	{ name = "none", dictName = "featureNone", targetArea = 0.73,
		points = {
			{t = 60, r = 40},
			-- {t = 55, r = 45},
		},
		relations = {},
		containedBy = { "grassland", "plains", "desert", "tundra", "snow" },
		dontEqualizeSuperAreas = true,
		remainderString = "percent = 100, limitRatio = -1, hill = true",
		color = {255, 255, 255, 0}
	},
	{ name = "forest", dictName = "featureForest", targetArea = 0.17, highR = true, noLowR = true,
		points = {
			{t = 45, r = 60},
			-- {t = 25, r = 40},
		},
		relations = {},
		containedBy = { "grassland", "plains", "tundra" },
		remainderString = "percent = 100, limitRatio = 0.85, hill = true",
		color = {255, 255, 0, 127}
	},
	{ name = "jungle", dictName = "featureJungle", targetArea = 0.1, highR = true, highT = true, noLowR = true, noLowT = true,
		points = {
			{t = 100, r = 100},
			-- {t = 90, r = 90},
		},
		containedBy = { "grassland" },
		remainderString = "percent = 100, limitRatio = 0.85, hill = true, terrainType = terrainPlains",
		relations = {},
		color = {0, 255, 0, 127}
	},
	--[[
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
	]]--
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
local paused

function love.load()
    love.window.setMode(displayMult * 100 + 200, displayMult * 100 + 100, {resizable=false, vsync=false})
    myClimate = Climate(terrainRegions, nullFeatureRegions)
end

function love.keyreleased(key)
	print(key)
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
	elseif key == "o" then
		-- [terrainGrass] = { points = {{t=47,r=76}, {t=73,r=58}}, features = { featureNone, featureForest, featureJungle, featureMarsh, featureFallout } },
		local block = "TerrainDictionary = {\n"
		for r, region in pairs(myClimate.regions) do
			local pointList = ""
			for i, point in pairs(myClimate.pointSet.points) do
				if point.region == region then
					pointList = pointList .. "{t=" .. point.t .. ",r=" .. point.r .. "}," 
				end
			end
			block = block .. '\t[' .. region.dictName .. '] = { points = {' .. pointList .. '}, ' .. region.remainderString .. " },\n"
		end
		block = block .. "}\n\n"
		block = block .. "FeatureDictionary = {\n"
		for r, region in pairs(myClimate.subRegions) do
			local pointList = ""
			for i, point in pairs(myClimate.subPointSet.points) do
				if point.region == region then
					pointList = pointList .. "{t=" .. point.t .. ",r=" .. point.r .. "}," 
				end
			end
			block = block .. '\t[' .. region.dictName .. '] = { points = {' .. pointList .. '}, ' .. region.remainderString .. " },\n"
		end
		block = block .. [[
	[featureMarsh] = { points = {}, percent = 100, limitRatio = 0.33, hill = false },
	[featureOasis] = { points = {}, percent = 2.4, limitRatio = 0.01, hill = false },
	[featureFallout] = { points = {{t=50,r=0}}, disabled = true, percent = 0, limitRatio = 0.75, hill = true },]]
		block = block .. "\n}"
		love.system.setClipboardText( block )
	elseif key == "space" then
		paused = not paused
	elseif key == "f" then
		myClimate = Climate(nil, featureRegions, myClimate)
	elseif key == "up" then
		myClimate:SetPolarExponent(myClimate.polarExponent+0.1)
	elseif key == "down" then
		myClimate:SetPolarExponent(myClimate.polarExponent-0.1)
	elseif key == "right" then
		myClimate.temperatureMin = myClimate.temperatureMin + 5
		myClimate:ResetLatitudes()
	elseif key == "left" then
		myClimate.temperatureMin = myClimate.temperatureMin - 5
		myClimate:ResetLatitudes()
	elseif key == "pagedown" then
		myClimate.temperatureMax = myClimate.temperatureMax + 5
		myClimate:ResetLatitudes()
	elseif key == "pageup" then
		myClimate.temperatureMax = myClimate.temperatureMax - 5
		myClimate:ResetLatitudes()
	elseif key == "." then
		myClimate:SetRainfallMidpoint(myClimate.rainfallMidpoint + 1)
	elseif key == "," then
		myClimate:SetRainfallMidpoint(myClimate.rainfallMidpoint - 1)
	elseif key == "l" or key == "v" then
		-- load points from file
		local lines
		if key == "l" then
			if love.filesystem.exists( "points.txt" ) then
				print('points.txt exists')
				lines = {}
				for line in love.filesystem.lines("points.txt") do
					tInsert(lines, line)
				end
			end
		elseif key == "v" then
			local clipText = love.system.getClipboardText()
			lines = clipText:split("\n")
		end
		if lines then
			myClimate.pointSet = PointSet(myClimate)
			myClimate.subPointSet = PointSet(myClimate, nil, true)
			for i, line in pairs(lines) do
				local words = splitIntoWords(line)
				if #words > 1 then
					local regionName = words[1]
					local tr = {}
					for i, n in pairs(words[2]:split(",")) do tInsert(tr, n) end
					if #tr > 1 then
						local t, r = tonumber(tr[1]), tonumber(tr[2])
						print(regionName, t, r, type(regionName), type(t), type(r))
						local region = myClimate.subRegionsByName[regionName] or myClimate.superRegionsByName[regionName]
						local pointSet
						if region then
							print('got region')
							if myClimate.subRegionsByName[regionName] then
								pointSet = myClimate.subPointSet
								print("sub")
							elseif myClimate.superRegionsByName[regionName] then
								pointSet = myClimate.pointSet
								print("super")
							end
							local point = Point(region, t, r)
							pointSet:AddPoint(point)
						end
					end
				end
			end
			print('points loaded')
			print(#myClimate.pointSet.points, #myClimate.subPointSet.points)
		end
	end
end

local buttonPointSets = { 'pointSet', 'subPointSet' }
local mousePress = {}
local mousePoint = {}
local mousePointOriginalPosition = {}

function love.mousepressed(x, y, button)
	print("mouse pressed", x, y, button)
	if buttonPointSets[button] then
		print("mouse has command")
		local t, r = DisplayToGrid(x, y)
		local pointSet = myClimate[buttonPointSets[button]]
		local point = pointSet:NearestPoint(t, r)
		if not point then
			print("no point under mouse")
			return
		end
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
		elseif love.keyboard.isDown('lalt') then
			-- fix or unfix the point
			point.fixed = not point.fixed
		else
			print("dragging point")
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
			love.graphics.setColor( point.region.color )
			love.graphics.rectangle("fill", t*displayMult, displayMultHundred-r*displayMult, displayMult, displayMult)
		end
	end
	for t, rains in pairs(myClimate.subPointSet.grid) do
		for r, point in pairs(rains) do
			love.graphics.setColor( point.region.color )
			love.graphics.rectangle("fill", t*displayMult, displayMultHundred-r*displayMult, displayMult, displayMult)
		end
	end
	love.graphics.setColor( 127, 0, 0 )
	for latitude, values in pairs(myClimate.pseudoLatitudes) do
		love.graphics.rectangle("fill", values.temperature*displayMult, displayMultHundred-values.rainfall*displayMult, displayMult, displayMult)
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
		love.graphics.setColor( 255, 255, 255 )
		love.graphics.rectangle("fill", point.t*displayMult, displayMultHundred-point.r*displayMult, displayMult, displayMult)
		if point.fixed then
			love.graphics.setColor( 255, 0, 255 )
		else
			love.graphics.setColor( 255, 255, 255 )
		end
		love.graphics.print( point.region.name .. "\n" .. (point.latitudeArea or "nil") .. "\n" .. (point.area or "nil") .. "\n" .. point.t .. "," .. point.r .. "\n" .. mFloor(point.tMove or 0) .. "," .. mFloor(point.rMove or 0), point.t*displayMult, displayMultHundred-point.r*displayMult)
	end
	for i, point in pairs(myClimate.subPointSet.points) do
		love.graphics.setColor( 0, 0, 0 )
		love.graphics.rectangle("fill", point.t*displayMult, displayMultHundred-point.r*displayMult, displayMult, displayMult)
		if point.fixed then
			love.graphics.setColor( 255, 0, 255 )
		else
			love.graphics.setColor( 255, 255, 255 )
		end
		love.graphics.print( point.region.name .. "\n" .. (point.latitudeArea or "nil") .. "\n" .. (point.area or "nil") .. "\n" .. point.t .. "," .. point.r .. "\n" .. mFloor(point.tMove or 0) .. "," .. mFloor(point.rMove or 0), point.t*displayMult, displayMultHundred-point.r*displayMult)
	end
	love.graphics.setColor(255, 0, 0)
	love.graphics.print(mFloor(myClimate.pointSet.distance or "nil") .. " " .. mFloor(myClimate.subPointSet.distance or "nil"), 10, displayMultHundred + 70)
	love.graphics.setColor(255, 0, 255)
	love.graphics.print("polar exponent: " .. myClimate.polarExponent .. "   minimum temperature: " .. myClimate.temperatureMin .. "   maximum temperature: " .. myClimate.temperatureMax .. "   rainfall midpoint: " .. myClimate.rainfallMidpoint, 10, displayMultHundred + 50)
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
	if paused then
		myClimate:Fill()
	else
		myClimate:Optimize()
	end
   love.window.setTitle( myClimate.iterations .. " " .. myClimate.pointSet.generation .. " " .. mFloor(myClimate.pointSet.distance or 0) .. " (" .. myClimate.subPointSet.generation .. " " .. mFloor(myClimate.subPointSet.distance or 0) ..") " .. myClimate.mutationStrength )
end