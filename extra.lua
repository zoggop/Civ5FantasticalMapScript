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