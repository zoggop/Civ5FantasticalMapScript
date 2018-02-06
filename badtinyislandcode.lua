function Polygon:PickTinyIslands()
	if (self.bottomX or self.topX) and self.oceanIndex and not self.space.wrapX then return end
	if (self.bottomY or self.topY) and self.oceanIndex and not self.space.wrapX then return end
	local newAstroIndex = 99
	local connectedAstros = {}
	local subPolyBuffer = tDuplicate(self.subPolygons)
	while #subPolyBuffer > 0 do
		local subPolygon = tRemoveRandom(subPolyBuffer)
		local subPolyAstroIndex
		if subPolygon.astronomyIndex and (subPolygon.astronomyIndex < 100 or connectedAstros[subPolygon.astronomyIndex]) then
			subPolyAstroIndex = subPolygon.astronomyIndex
		end
		local nearbyAstronomyIndex
		local tooCloseForIsland = self.space.wrapX and (subPolygon.bottomY or subPolygon.topY) and mRandom(0, 100) > self.space.polarMaxLandPercent
		if not tooCloseForIsland then
			for i, neighbor in pairs(subPolygon.neighbors) do
				-- local neighAstroIndex
				-- if neighbor.astronomyIndex and (neighbor.astronomyIndex < 100 or connectedAstros[neighbor.astronomyIndex]) then
				-- 	neighAstroIndex = neighbor.astronomyIndex
				-- 	nearbyAstronomyIndex = nearbyAstronomyIndex or neighbor.astronomyIndex
				-- end
				-- if neighbor.superPolygon.continent or neighbor.tinyIsland or (subPolyAstroIndex and neighAstroIndex and subPolyAstroIndex ~= neighAstroIndex) or (subPolygon.astronomyIndex and not subPolyAstroIndex and nearbyAstronomyIndex and neighAstroIndex and neighAstroIndex ~= nearbyAstronomyIndex) then
				-- 	tooCloseForIsland = true
				-- 	break
				-- end
				if neighbor.superPolygon.oceanIndex ~= self.oceanIndex or neighbor.tinyIsland or neighbor.superPolygon.continent then
					tooCloseForIsland = true
					break
				end
				for nn, neighneigh in pairs(neighbor.neighbors) do
					-- local nnAstroIndex
					-- if neighneigh.astronomyIndex and (neighneigh.astronomyIndex < 100 or connectedAstros[neighneigh.astronomyIndex]) then
					-- 	nnAstroIndex = neighneigh.astronomyIndex
					-- 	nearbyAstronomyIndex = nearbyAstronomyIndex or neighneigh.astronomyIndex
					-- end
					-- if (subPolyAstroIndex and nnAstroIndex and subPolyAstroIndex ~= nnAstroIndex) or (subPolygon.astronomyIndex and not subPolyAstroIndex and nearbyAstronomyIndex and nnAstroIndex and nnAstroIndex ~= nearbyAstronomyIndex) then
					-- 	tooCloseForIsland = true
					-- 	break
					-- end
					if neighneigh.superPolygon.oceanIndex ~= self.oceanIndex then
						tooCloseForIsland = true
						break
					end
				end
				if tooCloseForIsland then break end
			end
		end
		local chance = self.space.tinyIslandChance
		if self.oceanIndex or self.loneCoastal then chance = chance * 2 end
		-- or ((self.loneCoastal or self.oceanIndex) and not self.hasTinyIslands)) )
		if not tooCloseForIsland and Map.Rand(100, "tiny island chance") < chance then
			-- EchoDebug("tiny island", "chance: " .. chance, "lone coastal: " .. tostring(self.loneCoastal), "is ocean: " .. tostring(self.oceanIndex), "has tiny islands: " .. tostring(self.hasTinyIslands))
			subPolygon.tinyIsland = true
			-- local expandAstroIndex = subPolyAstroIndex or nearbyAstronomyIndex or connectedAstros[subPolygon.astronomyIndex] or newAstroIndex
			-- if expandAstroIndex == newAstroIndex then
			-- 	connectedAstros[subPolygon.astronomyIndex] = newAstroIndex
			-- 	connectedAstros[newAstroIndex] = subPolygon.astronomyIndex
			-- 	newAstroIndex = newAstroIndex - 1
			-- end
			-- subPolygon.astronomyIndex = expandAstroIndex
			for i, neighbor in pairs(subPolygon.neighbors) do
				-- EchoDebug(neighbor.astronomyIndex, expandAstroIndex)
				neighbor.astronomyIndex = subPolygon.astronomyIndex -- expandAstroIndex
			end
			tInsert(self.space.tinyIslandSubPolygons, subPolygon)
			self.hasTinyIslands = true
		end
	end
end