--[[

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

function Space:ComputeFeatures()
	-- testing ocean rifts
	for i, hex in pairs(self.hexes) do
		if hex.polygon.oceanIndex then
			if hex.terrainType == terrainOcean then
				-- hex.featureType = featureIce
			elseif hex.polygon.continentIndex then
				hex.featureType = featureIce
			else
				hex.featureType = featureJungle
				for i, nhex in pairs(hex:Neighbors()) do
					if nhex.plotType ~= plotOcean then
						EchoDebug("non ocean plot type: " .. nhex.plotType, nhex.tinyIsland)
					end
				end
				EchoDebug(hex.plotType, hex.nearLand)
			end
		end
		-- if hex.nearOceanTrench then hex.featureType = featureIce end
	end
end

function SetTerrainTypes(terrainTypes)
	print("DON'T USE THIS Setting Terrain Types (Fantastical)");
	for i, plot in Plots() do
		plot:SetTerrainType(self.hexes[i+1].terrainType, false, false)
		-- MapGenerator's SetPlotTypes uses i+1, but MapGenerator's SetTerrainTypes uses just i. wtf.
	end
end

function Space:ExpandCoasts()
	EchoDebug(self.coastArea .. " coastal hexes before expansion")
	local d = 1
	repeat 
		local makeCoast = {}
		local potential = 0
		for i, hex in pairs(self.deepHexes) do
			if hex.plotType == plotOcean and hex.terrainType == terrainOcean and hex.polygon.oceanIndex == nil then
				local nearcoast
				for n, nhex in pairs(hex:Neighbors()) do
					if nhex.terrainType == terrainCoast then
						nearcoast = nhex
						break
					end
				end
				if nearcoast then
					potential = potential + 1
					if Map.Rand(hex.polygon.coastExpansionDice[d], "expand coast?") == 0 or nearcoast.featureType == featureIce then
						makeCoast[hex] = nearcoast
					end
				end
			end
		end
		for hex, nearcoast in pairs(makeCoast) do
			hex.terrainType = terrainCoast
			if nearcoast.coastalTemperature <= self.freezingTemperature then
				nearcoast.featureType = featureIce
			elseif nearcoast.coastalTemperature >= self.atollTemperature then
				nearcoast.featureType = featureAtoll
			end
			hex.expandedCoast = true
			hex.coastalTemperature = nearcoast.coastalTemperature
			self.coastArea = self.coastArea + 1
		end
		d = d + 1
		if d > self.coastDiceAmount then d = 1 end
	until self.coastArea >= self.prescribedCoastArea or potential == 0
	EchoDebug(self.coastArea .. " coastal hexes after expansion")
end

			local dx = terminal.x - hex.x
			local dy = terminal.y - hex.y
			if dx == 0 then
				if dy > 0 then d = mRandom(2, 3) else d = mRandom(5, 6) end
			elseif dx > 0 then
				if dy == 0 then
					d = 4
				elseif dy > 0 then
					d = mRandom(3, 4)
				elseif dy < 0 then
					d = mRandom(5, 4)
				end
			elseif dx < 0 then
				if dy == 0 then
					d = 1
				elseif dy > 0 then
					d = 2
				elseif dy < 0 then
					d = 6
				end
			end
			local neighbors = hex:Neighbors({d})
			hex = neighbors[1]
			local angle = AngleAtoB(hex.x, hex.y, terminal.x, terminal.y)
			local bestDist = 10
			local bestDir
			local neighbors = hex:Neighbors()
			for d = 1, 6 do
				if neighbors[d] then
					if hexAngles[d] == angle or neighbors[d] == terminalHex then
						bestDir = d
						break
					end
					local dist = AngleDist(angle, hexAngles[d])
					if dist < bestDist then
						bestDist = dist
						bestDir = d
					end
				end
			end
			hex = neighbors[bestDir]


function Space:PickOceansCylinder()
	local div = self.w / self.oceanNumber
	local x = 0
	-- if self.oceanNumber == 1 then x = 0 else x = mRandom(0, self.w) end
	for oceanIndex = 1, self.oceanNumber do
		local hex = self.hexes[self:GetIndex(x, 0)]
		local polygon = hex.polygon
		local edge
		for i, e in pairs(polygon.edges) do
			if e.polygons[1].bottomY and e.polygons[2].bottomY then
				edge = e
				break
			end
		end
		local ocean = {}
		local iterations = 0
		while iterations < 100 do
			edge.oceanIndex = oceanIndex
			for p = 1, 2 do
				if not edge.polygons[p].oceanIndex then
					edge.polygons[p].oceanIndex = oceanIndex
					tInsert(ocean, edge.polygons[p])
					self.nonOceanArea = self.nonOceanArea - edge.polygons[p].area
					self.nonOceanPolygons = self.nonOceanPolygons - 1
				end
			end
			if edge.polygons[1].topY and edge.polygons[2].topY then
				EchoDebug("topY found, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
				break
			end
			local up = {}
			local down = {}
			for cedge, yes in pairs(edge.connections) do
				if not cedge.oceanIndex then
					if cedge.maxY > edge.maxY then
						tInsert(up, cedge)
					else
						tInsert(down, cedge)
					end
				end
			end
			if #up == 0 then
				if #down == 0 then
					if #edge.connections == 0 then
						EchoDebug("no edge connections!, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
						break
					else
						up = edge.connections
					end
				else
					up = down
				end
			end
			local highestY = 0
			local highestEdge
			for c, cedge in pairs(up) do
				if cedge.maxY > highestY then
					highestY = cedge.maxY
					highestEdge = cedge
				end
			end
			edge = highestEdge or tGetRandom(up)
			iterations = iterations + 1
		end
		tInsert(self.oceans, ocean)
		x = mCeil(x + div) % self.w
	end
end

function Polygon:Subdivide()
	-- initialize subpolygons by picking locations randomly from the polygon's hexes
	local hexBuffer = tDuplicate(self.hexes)
	local n = 0
	while #hexBuffer > 0 and n < self.space.subPolygonCount do
		local hex = tRemoveRandom(hexBuffer)
		if not hex.subPolygon then
			local subPolygon = Polygon(self.space, hex.x, hex.y, self)
			subPolygon.superPolygon = self
			subPolygon.adjacentSuperPolygons = {}
			tInsert(self.subPolygons, subPolygon)
			n = n + 1
		end
	end
	-- see how many of these deserted from another polygon
	local deserterCount = 0
	for i, subPolygon in pairs(self.subPolygons) do
		if subPolygon.deserter then deserterCount = deserterCount + 1 end
	end
	local nonDeserterCount = #self.subPolygons - deserterCount
	-- fill the subpolygons with available hexes (hexes that did not come from deserter subpolygons)
	for h, hex in pairs(self.hexes) do
		if not hex.subPolygon then hex:SubPlace() end
	end
	-- compute superpolygon neighbors
	for h, hex in pairs(self.hexes) do
		if not hex.subPolygon.deserter then hex:ComputeAdjacentSuperPolygons() end
	end
	-- pick off edge subpolygons at random, and populate subpolygon tables
	-- and create neighbor tables
	local maxDeserters = #self.subPolygons * (self.space.subPolygonDesertionPercent / 100)
	local minNonDeserters = #self.subPolygons - maxDeserters
	EchoDebug("before", #self.subPolygons, deserterCount, nonDeserterCount)
	for i = #self.subPolygons, 1, -1 do
		local subPolygon = self.subPolygons[i]
		if #subPolygon.hexes > 0 then
			if not subPolygon.deserter then
				if deserterCount < maxDeserters and nonDeserterCount > minNonDeserters then
					local adjacent = {}
					for polygon, yes in pairs(subPolygon.adjacentSuperPolygons) do
						tInsert(adjacent, polygon)
					end
					if #adjacent > 0 and mRandom(1, 100) < self.space.subPolygonDesertionPercent then
						subPolygon.superPolygon = tGetRandom(adjacent)
						subPolygon.deserter = true
						tInsert(subPolygon.superPolygon.subPolygons, subPolygon)
						tRemove(self.subPolygons, i)
						nonDeserterCount = nonDeserterCount - 1
					end
				end
				subPolygon.adjacentSuperPolygons = {}
				tInsert(self.space.subPolygons, subPolygon)
				if #subPolygon.hexes > self.space.biggestSubPolygon then
					self.space.biggestSubPolygon = #subPolygon.hexes
				elseif #subPolygon.hexes < self.space.smallestSubPolygon then
					self.space.smallestSubPolygon = #subPolygon.hexes
				end
			end
		else
			tRemove(self.subPolygons, i)
		end
	end
	EchoDebug("after", #self.subPolygons, deserterCount, nonDeserterCount)
	-- remove hexes that are no longer inside this polygon
	-- and move them to the correct polygon
	for i = #self.hexes, 1, -1 do
		local hex = self.hexes[i]
		if hex.subPolygon.superPolygon ~= self then
			hex.polygon = hex.subPolygon.superPolygon
			tInsert(hex.polygon.hexes, hex)
			tRemove(self.hexes, i)
		end
	end
	-- find stranded subpolygons
	for i, hex in pairs(self.hexes) do
		for ni, nhex in pairs(hex:Neighbors()) do
			if hex.polygon == nhex.polygon then
				hex.subPolygon.hasPartisanNeighbors = true
			else
				if not hex.subPolygon.adjacentSuperPolygons[nhex.polygon] then
					hex.subPolygon.adjacentSuperPolygons[nhex.polygon] = true
				end
			end
		end
	end
	-- move stranded subpolygons to an adjacent polygon
	for i = #self.subPolygons, 1, -1 do
		local subPolygon = self.subPolygons[i]
		if not subPolygon.hasPartisanNeighbors then
			local adjacent = {}
			for polygon, yes in pairs(subPolygon.adjacentSuperPolygons) do
				tInsert(adjacent, polygon)
			end
			if #adjacent == 0 then EchoDebug("NONE ADJACENT") end
			local superPolygon = tGetRandom(adjacent)
			subPolygon.superPolygon = superPolygon
			subPolygon.deserter = true
			tInsert(superPolygon.subPolygons, subPolygon)
			tRemove(self.subPolygons, i)
			nonDeserterCount = nonDeserterCount - 1
		end
	end
	-- move moved hexes again
	for i = #self.hexes, 1, -1 do
		local hex = self.hexes[i]
		if hex.subPolygon.superPolygon ~= self then
			hex.polygon = hex.subPolygon.superPolygon
			tInsert(hex.polygon.hexes, hex)
			tRemove(self.hexes, i)
		end
	end
	if #self.subPolygons == 0 or #self.hexes == 0 then EchoDebug("NO SUBPOLYGONS OR HEXES") end
	EchoDebug("after removing stranded", #self.hexes, #self.subPolygons, deserterCount, nonDeserterCount)
end

]]--