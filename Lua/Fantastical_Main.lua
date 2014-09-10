-- Fantastical_Main
-- Author: zoggop
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
	local labelledPlots = {}
	if GameInfo.Fantastical_Map_Labels then
		for row in DB.Query("SELECT * FROM Fantastical_Map_Labels") do -- using the DB Query b/c gameinfo and the db sometimes differ inexplicably
			local plot = Map.GetPlot(row.x, row.y)
			local westPlot = Map.PlotDirection(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_WEST);
			local eastPlot = Map.PlotDirection(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_EAST);
			if not labelledPlots[plot] and not labelledPlots[westPlot] and not labelledPlots[eastPlot] then
				print(row.Label, row.Type, row.x .. ", " .. row.y)
				local instance = g_MapManager:GetInstance()
				instance[row.Type]:SetText(row.Label)
				PlaceInWorld(instance.Anchor, GetWorldPos(plot))
				labelledPlots[plot] = row
				labelledPlots[westPlot] = row
				labelledPlots[eastPlot] = row
			end
		end
		print("Fantastical labels loaded.")
	else
		print("no Fantastical_Map_Labels in GameInfo")
	end
	if GameInfo.Ancient_Roads thne
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
