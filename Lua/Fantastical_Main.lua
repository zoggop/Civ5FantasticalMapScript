-- Fantastical_Main, lua helper for Fantastical Map Script
-- adds roads
-- Author: zoggop
-- version 7
--------------------------------------------------------------------
include("FLuaVector")
include("InstanceManager")
--------------------------------------------------------------------
g_Properties = {}
--------------------------------------------------------------------
local g_MapManager = InstanceManager:new("Map", "Anchor", Controls.MapContainer)
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
	if GameInfo.Ancient_Roads then
		local routeRoad = GameInfo.Routes.ROUTE_ROAD.ID
		for row in DB.Query("SELECT * FROM Ancient_Roads") do -- using the DB Query b/c gameinfo and the db sometimes differ inexplicably
			print("road at " .. row.x .. ", " .. row.y)
			local plot = Map.GetPlot(row.x, row.y)
			plot:SetRouteType(routeRoad)
		end
		print("Fantastical roads set.")
	else
		print("No Ancient_Roads in GameInfo")
	end
end
--------------------------------------------------------------------
Initialize()
