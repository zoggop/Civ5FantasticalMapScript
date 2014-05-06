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