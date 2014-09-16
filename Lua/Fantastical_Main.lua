-- Fantastical_Main, lua helper for Fantastical Map Script
-- adds roads
-- Author: zoggop
-- version 7
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
