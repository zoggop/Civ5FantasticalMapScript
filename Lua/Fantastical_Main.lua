-- Fantastical_Main
-- Author: zoggop
--------------------------------------------------------------------
include("FLuaVector")
include("InstanceManager")
--------------------------------------------------------------------
g_Properties = {}
--------------------------------------------------------------------
local g_MapManager	= InstanceManager:new("Map", "Anchor", Controls.MapContainer)
local g_WorldOffset = {x=0, y=0, z=0}
--------------------------------------------------------------------
function GetWorldPos(pPlot)
	return HexToWorld(ToHexFromGrid({x=pPlot:GetX(), y=pPlot:GetY()}))
end
--------------------------------------------------------------------
function PlaceInWorld(control, world)
	control:SetWorldPosition(VecAdd(world, g_WorldOffset))
end
--------------------------------------------------------------------
function Initialize()
	print("Initializing Fantastical_Main...")
	for row in GameInfo.Fantastical_Map_Labels() do
		local plot = Map.GetPlot(row.x, row.y)
		local instance = g_MapManager:GetInstance()
		instance.Map:LocalizeAndSetText(row.Label)
		PlaceInWorld(instance.Anchor, GetWorldPos(plot))
	end
	print("Fantastical labels loaded.")
	local routeRoad = GameInfo.Routes.ROUTE_ROAD.ID
	for row in GameInfo.Ancient_Roads() do
		print("road at " .. row.x .. ", " .. row.y)
		local plot = Map.GetPlot(row.x, row.y)
		plot:SetRouteType(routeRoad)
	end
	print("Fantastical roads set")
end
--------------------------------------------------------------------
Initialize()
