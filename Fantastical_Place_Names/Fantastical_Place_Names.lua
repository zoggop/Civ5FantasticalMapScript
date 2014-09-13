-- Fantastical Place Names, helper mod for Fantastical Map Script
-- handles map labels
-- Author: zoggop
-- version 7
--------------------------------------------------------------------
include("FLuaVector")
include("InstanceManager")
include("Serializer.lua")
--------------------------------------------------------------------
g_Properties = {}
--------------------------------------------------------------------
local g_SaveData	= Modding.OpenSaveData();
local g_MapManager = InstanceManager:new("Map", "Anchor", Controls.MapContainer)
local g_WorldOffset = {x=0, y=0, z=0}
--------------------------------------------------------------------
function F_ActivePlayerTurnStart()
	local labelledHexes = GetPersistentTable("Fantastical_Labelled_Hexes")
	local teamID = Game.GetActiveTeam()
	for i, ID in pairs(GetPersistentTable("Fantastical_Label_IDs")) do
		local label = GetPersistentTable("Fantastical_Map_Label_ID_" .. ID)
		local allRevealed = true
		for h, hex in pairs(label.Hexes) do
			local plot = Map.GetPlot(hex.X, hex.Y)
			if not plot:IsRevealed(teamID) then
				allRevealed = false
				break
			end
		end
		if allRevealed then
			local labelled = (labelledHexes[label.X] and labelledHexes[label.X][label.Y]) or (labelledHexes[label.X-1] and labelledHexes[label.X+1][label.Y]) or (labelledHexes[label.X+1] and labelledHexes[label.X+1][label.Y])
			if not labelled then
				print(label.Label, label.Type, label.X .. ", " .. label.Y)
				local instance = g_MapManager:GetInstance()
				instance[label.Type]:LocalizeAndSetText(label.Label)
				local labelPlot = Map.GetPlot(label.X, label.Y)
				PlaceInWorld(instance.Anchor, GetWorldPos(labelPlot))
				if labelledHexes[label.X] == nil then labelledHexes[label.X] = {} end
				if labelledHexes[label.X-1] == nil then labelledHexes[label.X-1] = {} end
				if labelledHexes[label.X+1] == nil then labelledHexes[label.X+1] = {} end
				labelledHexes[label.X][label.Y] = label.ID
				labelledHexes[label.X-1][label.Y] = label.ID
				labelledHexes[label.X+1][label.Y] = label.ID
			end
		end
	end
	SetPersistentTable("Fantastical_Labelled_Hexes", labelled_Hexes)
end
Events.ActivePlayerTurnStart.Add( F_ActivePlayerTurnStart )
--------------------------------------------------------------------
function GetWorldPos(pPlot)
	return HexToWorld(ToHexFromGrid({x=pPlot:GetX(), y=pPlot:GetY()}))
end
--------------------------------------------------------------------
function PlaceInWorld(control, world)
	control:SetWorldPosition(VecAdd(world, g_WorldOffset))
end
--------------------------------------------------------------------
function SetInitialized()
	SetPersistentProperty("Fantastical_Place_Names_Init", true);
end
--------------------------------------------------------------------
function IsInitialized()
	return GetPersistentProperty("Fantastical_Place_Names_Init");
end
--------------------------------------------------------------------
function GetPersistentProperty(name)
	if (g_Properties[name] == nil) then
		g_Properties[name] = g_SaveData.GetValue(name);
	end
	return g_Properties[name];
end
--------------------------------------------------------------------
function SetPersistentProperty(name, value)
	g_SaveData.SetValue(name, value);
	g_Properties[name] = value;
end
--------------------------------------------------------------------
function GetPersistentTable(name)
	if (g_Properties[name] == nil) then
		local code = g_SaveData.GetValue(name);
		g_Properties[name] = loadstring(code)();
	end
	return g_Properties[name];
end
--------------------------------------------------------------------
function SetPersistentTable(name, t)
    g_SaveData.SetValue(name, serialize(t))
	g_Properties[name] = t;
end
--------------------------------------------------------------------
function Initialize()
	if not IsInitialized() then
		print("Initializing Fantastical Place Names...")
		SetPersistentTable("Fantastical_Labelled_Hexes", {})
		-- local labelledPlots = {}
		if GameInfo.Fantastical_Map_Labels then
			local IDs = {}
			for row in DB.Query("SELECT * FROM Fantastical_Map_Labels") do -- using the DB Query b/c gameinfo and the db sometimes differ inexplicably
				row.Hexes = {}
				for hex in DB.Query("SELECT * FROM Fantastical_Map_Label_ID_" .. row.ID .. ";") do
					tInsert(row.Hexes, hex)
				end
				SetPersistentTable("Fantastical_Map_Label_ID_" .. row.ID, row)
				tInsert(IDs, row.ID)
				--[[
				local plot = Map.GetPlot(row.X, row.Y)
				local westPlot = Map.PlotDirection(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_WEST);
				local eastPlot = Map.PlotDirection(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_EAST);
				if not labelledPlots[plot] and not labelledPlots[westPlot] and not labelledPlots[eastPlot] then
					print(row.Label, row.Type, row.x .. ", " .. row.y)
					local instance = g_MapManager:GetInstance()
					instance[row.Type]:LocalizeAndSetText(row.Label)
					PlaceInWorld(instance.Anchor, GetWorldPos(plot))
					labelledPlots[plot] = row
					labelledPlots[westPlot] = row
					labelledPlots[eastPlot] = row
				end
				]]--
			end
			SetPersistentTable("Fantastical_Label_IDs", IDs)
			print("Fantastical labels loaded.")
		else
			print("no Fantastical_Map_Labels in GameInfo")
		end
		SetInitialized();
	else
		print("Fantastical Place Names already initialized in savedata")
	end
end
--------------------------------------------------------------------
Initialize()

--[[
local function OnHexFogEvent(hexPos, fogState, bWholeMap)
	if not bWholeMap then
		local x, y = ToGridFromHex( hexPos.x, hexPos.y );
		local index = mapWidth * y + x;
		fog[index] = fogState;
	end
end
Events.HexFOWStateChanged.Add(OnHexFogEvent)
]]--