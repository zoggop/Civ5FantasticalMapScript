local function CreatePolygon(x, y)
	local polygon = {
		x = x or 0,
		y = y or 0,
	}
	return polygon
end

local function DistanceSquared(polygon, x, y, w, h)
	local xdist = mAbs(polygon.x - x)
	local ydist = mAbs(polygon.y - y)
	if xdist > w / 2 then
		if polygon.x < x then
			xdist = polygon.x + (w - x)
		else
			xdist = x + (w - polygon.x)
		end
	end
	if ydist > h / 2 then
		if polygon.y < y then
			ydist = polygon.y + (h - y)
		else
			ydist = y + (h - polygon.y)
		end
	end
end