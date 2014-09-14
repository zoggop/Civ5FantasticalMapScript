-- Map Script: Fantastical
-- Author: zoggop
-- version 7

--------------------------------------------------------------
if include == nil then
	package.path = package.path..';C:\\Program Files (x86)\\Steam\\steamapps\\common\\Sid Meier\'s Civilization V\\Assets\\Gameplay\\Lua\\?.lua'
	include = require
end
include("math")
include("bit")
include("MapGenerator")
----------------------------------------------------------------------------------

local debugEnabled = true
local function EchoDebug(...)
	if debugEnabled then
		local printResult = ""
		for i,v in ipairs(arg) do
			printResult = printResult .. tostring(v) .. "\t"
		end
		print(printResult)
	end
end

------------------------------------------------------------------------------

local mCeil = math.ceil
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local mAbs = math.abs
local mSqrt = math.sqrt
local mSin = math.sin
local mCos = math.cos
local mPi = math.pi
local mTwicePi = math.pi * 2
local mAtan2 = math.atan2
local tInsert = table.insert
local tRemove = table.remove

------------------------------------------------------------------------------

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

------------------------------------------------------------------------------

local randomNumbers = 0

local function mRandom(lower, upper)
	local hundredth
	if lower and upper then
		if mFloor(lower) ~= lower or mFloor(upper) ~= upper then
			lower = mFloor(lower * 100)
			upper = mFloor(upper * 100)
			hundredth = true
		end
	end
	local divide
	if lower == nil then lower = 0 end
	if upper == nil then
		divide = true
		upper = 1000
	end
	local number = 1
	if upper == lower or lower > upper then
		number = lower
	else
		randomNumbers = randomNumbers + 1
		number = Map.Rand((upper + 1) - lower, "Fantastical Map Script " .. randomNumbers) + lower
	end
	if divide then number = number / upper end
	if hundredth then
		number = number / 100
	end
	return number
end

local function tRemoveRandom(fromTable)
	return tRemove(fromTable, mRandom(1, #fromTable))
end

local function tGetRandom(fromTable)
	return fromTable[mRandom(1, #fromTable)]
end

local function tDuplicate(sourceTable)
	local duplicate = {}
	for k, v in pairs(sourceTable) do
		tInsert(duplicate, v)
	end
	return duplicate
end

local function diceRoll(dice, maximum, invert)
	if invert == nil then invert = false end
	if maximum == nil then maximum = 1.0 end
	local n = 0
	for d = 1, dice do
		n = n + (mRandom() / dice)
	end
	if invert == true then
		if n >= 0.5 then n = n - 0.5 else n = n + 0.5 end
	end
	n = n * maximum
	return n
end

local function AngleAtoB(x1, y1, x2, y2)
	local dx = x2 - x1
	local dy = y2 - y1
	return mAtan2(-dy, dx)
end

local function AngleDist(angle1, angle2)
	return mAbs((angle1 + mPi -  angle2) % mTwicePi - mPi)
end

------------------------------------------------------------------------------
-- FOR CREATING CITY NAMES: MARKOV CHAINS
-- ADAPTED FROM drow <drow@bin.sh> http://donjon.bin.sh/code/name/
-- http://creativecommons.org/publicdomain/zero/1.0/

local name_set = {}
local name_types = {}
local chain_cache = {}

local function splitIntoWords(s)
  local words = {}
  for w in s:gmatch("%S+") do tInsert(words, w) end
  return words
end


local function scale_chain(chain)
  local table_len = {}
  for key in pairs(chain) do
    table_len[key] = 0
    for token in pairs(chain[key]) do
      local count = chain[key][token]
      local weighted = math.floor(math.pow(count,1.3))
      chain[key][token] = weighted
      table_len[key] = table_len[key] + weighted
    end
  end
  chain['table_len'] = table_len
  return chain
end

local function incr_chain(chain, key, token)
  if chain[key] then
    if chain[key][token] then
      chain[key][token] = chain[key][token] + 1
    else
      chain[key][token] = 1
    end
  else
    chain[key] = {}
    chain[key][token] = 1
  end
  return chain
end

-- construct markov chain from list of names
local function construct_chain(list)
  local chain = {}
  for i = 1, #list do
    local names = splitIntoWords(list[i])
    chain = incr_chain(chain,'parts',#names)
    for j = 1, #names do
      local name = names[j]
      chain = incr_chain(chain,'name_len',name:len())
      local c = name:sub(1, 1)
      chain = incr_chain(chain,'initial',c)
      local string = name:sub(2)
      local last_c = c
      while string:len() > 0 do
        local c = string:sub(1, 1)
        chain = incr_chain(chain,last_c,c)
        string = string:sub(2)
        last_c = c
      end
    end
  end
  return scale_chain(chain)
end

function select_link(chain, key)
  local len = chain['table_len'][key]
  if not len then return '-' end
  local idx = math.floor(mRandom() * len)
  local t = 0
  for token in pairs(chain[key]) do
    t = t + chain[key][token]
    if idx <= t then return token end
  end
  return '-'
end

-- construct name from markov chain
local function markov_name(chain)
  local parts = select_link(chain,'parts')
  local names = {}
  for i = 1, parts do
    local name_len = select_link(chain,'name_len')
    local c = select_link(chain,'initial')
    local name = c
    local last_c = c
    while name:len() < name_len do
      c = select_link(chain,last_c)
      name = name .. c
      last_c = c
    end
    table.insert(names, name)
  end
  local nameString = ""
  for i, name in ipairs(names) do nameString = nameString .. name .. " " end
  nameString = nameString:sub(1,-2)
  return nameString
end

-- get markov chain by type
local function markov_chain(type)
  local chain = chain_cache[type]
  if chain then
    return chain
  else
    local list = name_set[type]
    if list then
      local chain = construct_chain(list)
      if chain then
        chain_cache[type] = chain
        return chain
      end
    end
  end
  return false
end

-- generator function
local function generate_name(type)
  local chain = markov_chain(type)
  if chain then
    return markov_name(chain)
  end
  return ""
end

-- generate multiple
local function name_list(type, n_of)
  local list = {}
  for i = 1, n_of do
    table.insert(list, generate_name(type))
  end
  return list
end

------------------------------------------------------------------------------

-- Compatible with Lua 5.1 (not 5.0).
function class(base, init)
   local c = {}    -- a new class instance
   if not init and type(base) == 'function' then
      init = base
      base = nil
   elseif type(base) == 'table' then
    -- our new class is a shallow copy of the base class!
      for i,v in pairs(base) do
         c[i] = v
      end
      c._base = base
   end
   -- the class will be the metatable for all its objects,
   -- and they will look up their methods in it.
   c.__index = c

   -- expose a constructor which can be called by <classname>(<args>)
   local mt = {}
   mt.__call = function(class_tbl, ...)
   local obj = {}
   setmetatable(obj,c)
   if init then
      init(obj,...)
   else 
      -- make sure that any stuff from the base class is initialized!
      if base and base.init then
      base.init(obj, ...)
      end
   end
   return obj
   end
   c.init = init
   c.is_a = function(self, klass)
      local m = getmetatable(self)
      while m do 
         if m == klass then return true end
         m = m._base
      end
      return false
   end
   setmetatable(c, mt)
   return c
end

------------------------------------------------------------------------------

local LabelSyntaxes = {
	{ "Place", " of ", "Noun" },
	{ "Adjective", " ", "Place"},
	{ "Name", " ", "Place"},
	{ "Name", " ", "ProperPlace"},
	{ "PrePlace", " ", "Name"},
	{ "Adjective", " ", "Place", " of ", "Name"},
}

local LabelDictionary ={
	Place = {
		Land = { "Land" },
		Sea = { "Sea", "Shallows", "Reef" },
		Islet = { "Key", "Cay", "Ait", "Key", "Cay", "Ait" },
		Island = { "Island", "Isle" },
		Mountains = { "Heights", "Highlands", "Spires", "Crags" },
		Hills = { "Hills", "Plateau", "Fell" },
		Dunes = { "Dunes", "Sands", "Drift" },
		Plains = { "Plain", "Prarie", "Steppe" },
		Forest = { "Forest", "Wood", "Grove", "Thicket" },
		Jungle = { "Jungle", "Maze", "Tangle" },
		Swamp = { "Swamp", "Marsh", "Fen" },
		Range = "Mountains",
		Waste = { "Waste", "Desolation" },
		Grassland = { "Heath", "Vale" },
	},
	ProperPlace = {
		Ocean = "Ocean",
		River = "River",
	},
	PrePlace = {
		Lake = "Lake",
	},
	Noun = {
		Unknown = { "Despair" },
		Hot = { "Light", "The Sun", "The Anvil" },
		Cold = { "Frost", "Crystal" },
		Wet = { "The Clouds", "Fog", "Monsoons" },
		Dry = { "Dust", "Withering" },
		Big = { "The Ancients" },
		Small = { "The Needle" },
	},
	Adjective = {
		Unknown = { "Lost", "Enchanted", "Dismal" },
		Hot = { "Shining" },
		Cold = { "Snowy", "Icy", "Frigid" },
		Wet = { "Misty", "Murky", "Torrid" },
		Dry = { "Parched" },
		Big = { "Greater" },
		Small = { "Lesser" },
	}
}

local SpecialLabelTypes = {
	Ocean = "MapWaterBig",
	Lake = "MapWaterSmallMedium",
	Sea = "MapWaterMedium",
	River = "MapWaterSmall",
	Islet = "MapSmallMedium",
}

local LabelSyntaxesCentauri = {
	{ "FullPlace" },
	{ "Adjective", " ", "Place" },
}

local LabelDictionaryCentauri = {
	FullPlace = {
		Sea = { "Sea of Pholus", "Sea of Nessus", "Sea of Mnesimache", "Sea of Chiron", "Sea of Unity" },
		Bay = { "Landing Bay", "Eurytion Bay" },
		Rift = { "Great Marine Rift" },
		Freshwater = { "Freshwater Sea" },
		Cape = { "Cape Storm" },
		Isle = { "Isle of Deianira", "Isle of Dexamenus" },
		Jungle = { "Monsoon Jungle" },
	},
	Place = {
		Straights = { "Straights", "Straights", "Straights" },
		Ocean = { "Ocean" },
	},
	Adjective = {
		ColdCoast = { "Howling", "Zeus" },
		WarmCoast = { "Prometheus" },
		Northern = { "Great Northern" },
		Southern = { "Great Southern" },
	},
}

local SpecialLabelTypesCentauri = {
	Ocean = "MapWaterMedium",
	Freshwater = "MapWaterSmallMedium",
	Sea = "MapWaterSmallMedium",
	Bay = "MapWaterSmallMedium",
	Rift = "MapWaterBig",
	Straights = "MapWaterSmallMedium",
	Cape = "MapWaterSmallMedium"
}

local LabelDefinitions -- has to be set in SetConstants()

local LabelDefinitionsCentauri -- has to be set in Space:Compute()

local function EvaluateCondition(key, condition, thing)
	if type(condition) == "boolean" then
		if condition == false then return not thing[key] end
		return thing[key]
	end
	if thing[key] then
		if type(condition) == "table" then
			local met = false
			for subKey, subCondition in pairs(condition) do
				met = EvaluateCondition(subKey, subCondition, thing[key])
				if not met then
					return false
				end
			end
			return met
		elseif type(condition) == "number" then
			if condition > 0 then
				return thing[key] >= condition
			elseif condition < 0 then
				return thing[key] <= -condition
			elseif condition == 0 then
				return thing[key] == 0
			end
		else
			return false
		end
	end
	return false
end

local function GetLabel(thing)
	local metKinds = { Unknown = true }
	for kind, conditions in pairs(LabelDefinitions) do
		if EvaluateCondition(1, conditions, {thing}) then
			metKinds[kind] = true
		end
	end
	local goodSyntaxes = {}
	local preparedSyntaxes = {}
	for s, syntax in pairs(LabelSyntaxes) do
		local goodSyntax = true
		local preparedSyntax = {}
		for i , part in pairs(syntax) do
			if LabelDictionary[part] then
				local goodPart = false
				local partKinds = {}
				for kind, words in pairs(LabelDictionary[part]) do
					if metKinds[kind] and (type(words) == "string" or #words > 0) then
						goodPart = true
						tInsert(partKinds, kind)
					end
				end
				if goodPart then
					preparedSyntax[part] = partKinds
				else
					goodSyntax = false
					break
				end
			end
		end
		if goodSyntax then
			tInsert(goodSyntaxes, syntax)
			preparedSyntaxes[syntax] = preparedSyntax
		end
	end
	if #goodSyntaxes == 0 then return end
	local syntax = tGetRandom(goodSyntaxes)
	local labelType = "Map"
	local label = ""
	for i, part in ipairs(syntax) do
		if preparedSyntaxes[syntax][part] then
			local kind = tGetRandom(preparedSyntaxes[syntax][part])
			local word
			if type(LabelDictionary[part][kind]) == "string" then
				word = LabelDictionary[part][kind]
			else
				word = tRemoveRandom(LabelDictionary[part][kind])
			end
			label = label .. word
			labelType = SpecialLabelTypes[kind] or labelType
		else
			label = label .. part
		end
	end
	EchoDebug(label, "(" .. labelType .. ")")
	return label, labelType
end

------------------------------------------------------------------------------

local OptionDictionary = {
	{ name = "World Wrap", sortpriority = 1, keys = { "wrapX", "wrapY" }, default = 1,
	values = {
			[1] = { name = "Globe (Wraps East-West)", values = {true, false} },
			[2] = { name = "Realm (Does Not Wrap)", values = {false, false} },
			-- [3] = { name = "Donut (Horizontal and Vertical Wrapping)", values = {true, true} },
			-- sadly wrapY does not work
		}
	},
	{ name = "Oceans", sortpriority = 2, keys = { "oceanNumber", }, default = 2,
	values = {
			[1] = { name = "One", values = {1} },
			[2] = { name = "Two", values = {2} },
			[3] = { name = "Three", values = {3} },
			[4] = { name = "Four", values = {4} },
			[5] = { name = "Random", values = "keys" },
		}
	},
	{ name = "Continents/Ocean", sortpriority = 3, keys = { "majorContinentNumber", }, default = 1,
	values = {
			[1] = { name = "One", values = {1} },
			[2] = { name = "Two", values = {2} },
			[3] = { name = "Three", values = {3} },
			[4] = { name = "Four", values = {4} },
			[5] = { name = "Random", values = "keys" },
		}
	},
	{ name = "Islands", sortpriority = 4, keys = { "tinyIslandChance", "coastalPolygonChance", "islandRatio", }, default = 2,
	values = {
			[1] = { name = "Few", values = {10, 1, 0.25} },
			[2] = { name = "Some", values = {33, 2, 0.5} },
			[3] = { name = "Many", values = {80, 3, 0.75} },
			[4] = { name = "Random", values = "keys" },
		}
	},
	{ name = "World Age", sortpriority = 5, keys = { "mountainRatio", "hillynessMax" }, default = 4,
	values = {
			[1] = { name = "1 Billion Years", values = {0.25, 75} },
			[2] = { name = "2 Billion Years", values = {0.16, 60} },
			[3] = { name = "3 Billion Years", values = {0.08, 50} },
			[4] = { name = "4 Billion Years", values = {0.04, 40} },
			[5] = { name = "5 Billion Years", values = {0.02, 30} },
			[6] = { name = "6 Billion Years", values = {0.0, 20} },
			[7] = { name = "Random", values = "keys" },
		}
	},
	{ name = "Climate Realism", sortpriority = 6, keys = { "useMapLatitudes" }, default = 1,
	values = {
			[1] = { name = "Off", values = {false} },
			[2] = { name = "On", values = {true} },
		}
	},
	{ name = "Temperature", sortpriority = 7, keys = { "polarExponent", "temperatureMin", "temperatureMax" }, default = 3,
	values = {
			[1] = { name = "Ice Age", values = {2.0, 0, 45} },
			[2] = { name = "Cool", values = {1.4, 0, 85} },
			[3] = { name = "Temperate", values = {1.2, 0, 100} },
			[4] = { name = "Hot", values = {1.1, 5, 100} },
			[5] = { name = "Jurassic", values = {0.9, 20, 100} },
			[6] = { name = "Random", values = "keys" },
		}
	},
	{ name = "Rainfall", sortpriority = 8, keys = { "rainfallMidpoint" }, default = 3,
	values = {
			[1] = { name = "Wasteland", values = {13} },
			[2] = { name = "Arid", values = {35} },
			[3] = { name = "Normal", values = {50} },
			[4] = { name = "Wet", values = {60} },
			[5] = { name = "Waterlogged", values = {90} },
			[6] = { name = "Random", values = "values" },
		}
	},
	{ name = "Fallout", sortpriority = 9, keys = { "falloutEnabled", "contaminatedWater", "contaminatedSoil" }, default = 1,
	values = {
			[1] = { name = "None", values = {false, false, false} },
			[2] = { name = "A Bit", values = {true, false, false} },
			[3] = { name = "Contaminated Soil", values = {true, false, true} },
			[4] = { name = "Contaminated Water", values = {true, true, false} },
			[5] = { name = "Contaminated Everything", values = {true, true, true} },
		}
	},
	{ name = "Ancient Roads", sortpriority = 10, keys = { "roadCount" }, default = 2,
	values = {
			[1] = { name = "None", values = {0} },
			[2] = { name = "Some", values = {5} },
			[3] = { name = "Many", values = {10} },
		}
	},
}

local function GetCustomOptions()
	local custOpts = {}
	for i, option in ipairs(OptionDictionary) do
		local opt = { Name = option.name, SortPriority = option.sortpriority, DefaultValue = option.default, Values = {} }
		for n, value in pairs(option.values) do
			opt.Values[n] = value.name
		end
		tInsert(custOpts, opt)
	end
	return custOpts
end

local function DatabaseQuery(sqlStatement)
	for whatever in DB.Query(sqlStatement) do
		local stuff = whatever
	end
	return rows
end

local function CreateOrOverwriteTable(tableName, dataSql)
	-- for whatever in DB.Query("SHOW TABLES LIKE '".. tableName .."';") do
	if GameInfo[tableName] then
		EchoDebug("table " .. tableName .. " exists, dropping")
		DatabaseQuery("DROP TABLE " .. tableName)
		-- break
	end
	EchoDebug("creating table " .. tableName)
	DatabaseQuery("CREATE TABLE " .. tableName .. " ( " .. dataSql .. " );")
end

local function DatabaseInsert(tableName, values)
	local valueString = ""
	local nameString = ""
	for name, value in pairs(values) do
		nameString = nameString .. name .. ", "
		if type(value) == "string" then
			valueString = valueString .. "'" .. value .. "', "
		else
			valueString = valueString .. value .. ", "
		end
	end
	nameString = string.sub(nameString, 1, -3)
	valueString = string.sub(valueString, 1, -3)
	DatabaseQuery("INSERT INTO " .. tableName .. " (" .. nameString ..") VALUES (" .. valueString .. ");")
end

local LabelIndex = 0

local function InsertLabel(X, Y, Type, Label, hexes)
	LabelIndex = LabelIndex + 1
	DatabaseInsert("Fantastical_Map_Labels", {X = X, Y = Y, Type = Type, Label = Label, ID = LabelIndex})
	local LabelTable = "Fantastical_Map_Label_ID_" .. LabelIndex
	CreateOrOverwriteTable(LabelTable, "X integer DEFAULT 0, Y integer DEFAULT 0")
	for i, hex in pairs(hexes) do
		DatabaseInsert(LabelTable, {X = hex.x, Y = hex.y})
	end
end

local function LabelThing(thing, x, y, hexes)
	if not thing then return end
	x = x or thing.x
	if not x then return end
	y = y or thing.y
	local label, labelType = GetLabel(thing)
	if label then
		InsertLabel(x, y, labelType, label, hexes or thing.hexes)
		return true
	else
		return false
	end
end

------------------------------------------------------------------------------

-- so that these constants can be shorter to access and consistent
local DirW, DirNW, DirNE, DirE, DirSE, DirSW = 1, 2, 3, 4, 5, 6
local FlowDirN, FlowDirNE, FlowDirSE, FlowDirS, FlowDirSW, FlowDirNW
local DirConvert = {}

local function DirFant2Native(direction)
	return DirConvert[direction] or DirectionTypes.NO_DIRECTION
end

local function OppositeDirection(direction)
	direction = direction + 3
	if direction > 6 then direction = direction - 6 end
	return direction
end

local function OfRiverDirection(direction)
	if direction == DirE or direction == DirSE or direction == DirSW then
		return true
	end
	return false
end

-- direction1 crosses the river to another hex
-- direction2 goes to a mutual neighbor
local function GetFlowDirection(direction1, direction2)
	if direction1 == DirW or direction1 == DirE then
		if direction2 == DirSE or direction2 == DirSW then
			return FlowDirS
		else
			return FlowDirN
		end
	elseif direction1 == DirNW or direction1 == DirSE then
		if direction2 == DirSW or direction2 == DirW then
			return FlowDirSW
		else
			return FlowDirNE
		end
	elseif direction1 == DirNE or direction1 == DirSW then
		if direction2 == DirNW or direction2 == DirW then
			return FlowDirNW
		else
			return FlowDirSE
		end
	end
	return -1
end

local DirNames = {
	[DirW] = "West",
	[DirNW] = "Northwest",
	[DirNE] = "Northeast",
	[DirE] = "East",
	[DirSE] = "Southeast",
	[DirSW] = "Southwest",
}
local FlowDirNames = {}

local function DirName(direction)
	return DirNames[direction]
end

local function FlowDirName(flowDirection)
	return FlowDirNames[flowDirection]
end

local plotOcean, plotLand, plotHills, plotMountain
local terrainOcean, terrainCoast, terrainGrass, terrainPlains, terrainDesert, terrainTundra, terrainSnow
local featureForest, featureJungle, featureIce, featureMarsh, featureOasis, featureFallout, featureAtoll
local TerrainDictionary, FeatureDictionary
local TerrainDictionaryCentauri, FeatureDictionaryCentauri
local artOcean, artAmerica, artAsia, artAfrica, artEurope
local resourceSilver, resourceSpices

local function SetConstants()
	artOcean, artAmerica, artAsia, artAfrica, artEurope = 0, 1, 2, 3, 4

	resourceSilver, resourceSpices = 16, 22

	FlowDirN, FlowDirNE, FlowDirSE, FlowDirS, FlowDirSW, FlowDirNW = FlowDirectionTypes.FLOWDIRECTION_NORTH, FlowDirectionTypes.FLOWDIRECTION_NORTHEAST, FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST, FlowDirectionTypes.FLOWDIRECTION_SOUTH, FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST, FlowDirectionTypes.FLOWDIRECTION_NORTHWEST
	FlowDirNames = {
		[FlowDirN] = "North",
		[FlowDirNE] = "Northeast",
		[FlowDirSE] = "Southeast",
		[FlowDirS] = "South",
		[FlowDirSW] = "Southwest",
		[FlowDirNW] = "Northwest",
	}

	DirConvert = { [DirW] = DirectionTypes.DIRECTION_WEST, [DirNW] = DirectionTypes.DIRECTION_NORTHWEST, [DirNE] = DirectionTypes.DIRECTION_NORTHEAST, [DirE] = DirectionTypes.DIRECTION_EAST, [DirSE] = DirectionTypes.DIRECTION_SOUTHEAST, [DirSW] = DirectionTypes.DIRECTION_SOUTHWEST }

	routeRoad = GameInfo.Routes.ROUTE_ROAD.ID

	plotOcean = PlotTypes.PLOT_OCEAN
	plotLand = PlotTypes.PLOT_LAND
	plotHills = PlotTypes.PLOT_HILLS
	plotMountain = PlotTypes.PLOT_MOUNTAIN

	terrainOcean = TerrainTypes.TERRAIN_OCEAN
	terrainCoast = TerrainTypes.TERRAIN_COAST
	terrainGrass = TerrainTypes.TERRAIN_GRASS
	terrainPlains = TerrainTypes.TERRAIN_PLAINS
	terrainDesert = TerrainTypes.TERRAIN_DESERT
	terrainTundra = TerrainTypes.TERRAIN_TUNDRA
	terrainSnow = TerrainTypes.TERRAIN_SNOW

	featureNone = FeatureTypes.NO_FEATURE
	featureForest = FeatureTypes.FEATURE_FOREST
	featureJungle = FeatureTypes.FEATURE_JUNGLE
	featureIce = FeatureTypes.FEATURE_ICE
	featureMarsh = FeatureTypes.FEATURE_MARSH
	featureOasis = FeatureTypes.FEATURE_OASIS
	featureFloodPlains = FeatureTypes.FEATURE_FLOOD_PLAINS
	featureFallout = FeatureTypes.FEATURE_FALLOUT

	for thisFeature in GameInfo.Features() do
		if thisFeature.Type == "FEATURE_ATOLL" then
			featureAtoll = thisFeature.ID
		end
	end

	-- in temperature and rainfall, first number is minimum, seecond is maximum, third is midpoint (optional: it defaults to the average of min and max)

	TerrainDictionary = {
		[terrainGrass] = { temperature = {40, 100, 60}, rainfall = {20, 100, 50}, features = { featureNone, featureForest, featureJungle, featureMarsh, featureFallout } },
		[terrainPlains] = { temperature = {20, 60}, rainfall = {20, 100, 40}, features = { featureNone, featureForest, featureFallout } },
		[terrainDesert] = { temperature = {20, 100}, rainfall = {0, 20, 0}, features = { featureNone, featureOasis, featureFallout } },
		[terrainTundra] = { temperature = {0, 30, 5}, rainfall = {20, 100, 45}, features = { featureNone, featureForest, featureFallout } },
		[terrainSnow] = { temperature = {0, 20, 0}, rainfall = {0, 20}, features = { featureNone, featureFallout } },
	}

	-- percent is how likely it is to show up in a region's collection (if it's the closest rainfall and temperature)
	-- limitRatio is what fraction of a region's hexes may have this feature (-1 is no limit)

	FeatureDictionary = {
		[featureNone] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 100, limitRatio = -1, hill = true },
		[featureForest] = { temperature = {0, 85, 30}, rainfall = {50, 100, 90}, percent = 100, limitRatio = 0.85, hill = true },
		[featureJungle] = { temperature = {85, 100}, rainfall = {75, 100}, percent = 100, limitRatio = 0.85, hill = true, terrainType = terrainPlains },
		[featureMarsh] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 10, limitRatio = 0.33, hill = false },
		[featureOasis] = { temperature = {50, 100}, rainfall = {0, 100}, percent = 20, limitRatio = 0.01, hill = false },
		[featureFallout] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 18, limitRatio = 0.75, hill = true },
	}

	-- doing it this way just so the declarations above are shorter
	for terrainType, terrain in pairs(TerrainDictionary) do
		if terrain.terrainType == nil then terrain.terrainType = terrainType end
	end
	for featureType, feature in pairs(FeatureDictionary) do
		if feature.featureType == nil then feature.featureType = featureType end
	end

	-- for Alpha Centauri Maps:

	TerrainDictionaryCentauri = {
		[terrainGrass] = { temperature = {0, 100, 50}, rainfall = {0, 100, 50}, features = { featureNone, featureJungle, featureMarsh } },
		[terrainPlains] = { temperature = {0, 100, 50}, rainfall = {0, 90, 35}, features = { featureNone, } },
		[terrainDesert] = { temperature = {0, 100}, rainfall = {0, 6, 0}, features = { featureNone, } },
	}

	FeatureDictionaryCentauri = {
		[featureNone] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 100, limitRatio = -1, hill = true },
		[featureJungle] = { temperature = {90, 100}, rainfall = {90, 100}, percent = 100, limitRatio = 0.95, hill = false },
		[featureMarsh] = { temperature = {10, 90}, rainfall = {10, 90}, percent = 80, limitRatio = 0.95, hill = true },
	}

	-- doing it this way just so the declarations above are shorter
	for terrainType, terrain in pairs(TerrainDictionaryCentauri) do
		if terrain.terrainType == nil then terrain.terrainType = terrainType end
	end
	for featureType, feature in pairs(FeatureDictionaryCentauri) do
		if feature.featureType == nil then feature.featureType = featureType end
	end

	LabelDefinitions = {
		Sea = { plotRatios = {[plotOcean] = 0.8}, terrainRatios = {[terrainCoast] = 0.4} },
		Land = { plotRatios = {[plotLand] = 1.0} },
		Islet = { tinyIsland = true },
		Island = { continentSize = -3, },
		Mountains = { plotRatios = {[plotMountain] = 0.2}, },
		Hills = { plotRatios = {[plotHills] = 0.33} },
		Dunes = { plotRatios = {[plotHills] = 0.33}, terrainRatios = {[terrainDesert] = 0.85} },
		Plains = { plotRatios = {[plotLand] = 0.85}, terrainRatios = {[terrainPlains] = 0.5}, featureRatios = {[featureNone] = 0.85} },
		Forest = { featureRatios = {[featureForest] = 0.4} },
		Jungle = { featureRatios = {[featureJungle] = 0.45} },
		Swamp = { featureRatios = {[featureMarsh] = 0.15} },
		Waste = { terrainRatios = {[terrainSnow] = 0.75}, featureRatios = {[featureNone] = 0.8} },
		Grassland = { terrainRatios = {[terrainGrass] = 0.75}, featureRatios = {[featureNone] = 0.75} },

		Range = { rangeLength = 1 },
		Ocean = { oceanSize = 1 },
		Lake = { lake = true },
		River = { riverLength = 1 },

		Hot = { temperatureAvg = 80 },
		Cold = { temperatureAvg = -20 },
		Wet = { rainfallAvg = 80 },
		Dry = { rainfallAvg = -20 },
		Big = { subPolygonCount = 30 },
		Small = { subPolygonCount = -8 }
	}
end

local function GetCityNames(numberOfCivs)
	numberOfCivs = numberOfCivs or 1
	local civTypeGot = {}
	local civTypes = {}
	for value in GameInfo.Civilization_CityNames() do
		for k, v in pairs(value) do
			if k == "CivilizationType" then
				if not civTypeGot[v] then tInsert(civTypes, v) end
				civTypeGot[v] = true
			end
		end
	end
	local cityNames = {}
	local civs = {}
	local n = 0
	repeat
		local cNames = {}
		local civType = tRemoveRandom(civTypes)
		for value in GameInfo.Civilization_CityNames("CivilizationType='" .. civType .. "'") do
			for k, v in pairs(value) do
				-- TXT_KEY_CITY_NAME_ARRETIUM
				local begOfCrap, endOfCrap = string.find(v, "CITY_NAME_")
				if endOfCrap then
					local name = string.sub(v, endOfCrap+1)
					name = string.gsub(name, "_", " ")
					name = string.lower(name)
					name = name:gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
					-- if k == "CityName" then EchoDebug(name) end
					tInsert(cNames, name)
				end
			end
		end
		if #cNames > 5 then
			EchoDebug(civType)
			cityNames[civType] = cNames
			tInsert(civs, civType)
			n = n + 1
		end
	until n == numberOfCivs
	return cityNames, civs
end

------------------------------------------------------------------------------

Hex = class(function(a, space, x, y, index)
	a.space = space
	a.index = index
	a.x, a.y = x, y
	a.adjacentPolygons = {}
	a.edgeLow = {}
	a.edgeHigh = {}
	a.edgeEnd = {}
	a.subEdgeLow = {}
	a.subEdgeHigh = {}
	a.subEdgeEnd = {}
	a.subEdgeParts = {}
	a.edges = {}
	a.subEdges = {}
	a.onRiver = {}
end)

function Hex:Place(relax)
	self.subPolygon = self:ClosestSubPolygon()
	self.space.hexes[self.index] = self
	tInsert(self.subPolygon.hexes, self)
	if not relax then
		self.plot = Map.GetPlotByIndex(self.index-1)
		if self.space.wrapX then
			self.latitude = self.space:GetPlotLatitude(self.plot)
		else
			self.latitude = self.space:RealmLatitude(self.y)
		end
		self:InsidePolygon(self.subPolygon)
	end
end

function Hex:InsidePolygon(polygon)
	if self.x < polygon.minX then polygon.minX = self.x end
	if self.y < polygon.minY then polygon.minY = self.y end
	if self.x > polygon.maxX then polygon.maxX = self.x end
	if self.y > polygon.maxY then polygon.maxY = self.y end
	polygon:CheckBottomTop(self)
end

function Hex:Adjacent(direction)
	local x, y = self.x, self.y
	if direction == 0 or direction == nil then return hex end
	local nx = x
	local ny = y
	local odd = y % 2
	if direction == 1 then -- West
		nx = x - 1
	elseif direction == 2 then -- Northwest
		nx = x - 1 + odd
		ny = y + 1
	elseif direction == 3 then -- Northeast
		nx = x + odd
		ny = y + 1
	elseif direction == 4 then -- East
		nx = x + 1
	elseif direction == 5 then -- Southeast
		nx = x + odd
		ny = y - 1
	elseif direction == 6 then -- Southwest
		nx = x - 1 + odd
		ny = y - 1
	end
	if self.space.wrapX then
		if nx > self.space.w then nx = 0 elseif nx < 0 then nx = self.space.w end
	else
		if nx > self.space.w then nx = self.space.w elseif nx < 0 then nx = 0 end
	end
	if self.space.wrapY then
		if ny > self.space.h then ny = 0 elseif ny < 0 then ny = self.space.h end
	else
		if ny > self.space.h then ny = self.space.h elseif ny < 0 then ny = 0 end
	end
	local nhex = self.space:GetHexByXY(nx, ny)
	local adjPlot = Map.PlotDirection(x, y, DirFant2Native(direction))
	if adjPlot ~= nil then
		local px, py = adjPlot:GetX(), adjPlot:GetY()
		if ((nhex.x ~= px or nhex.y ~= py) and nhex.x ~= 0 and nhex.x ~= self.space.w) or (nhex.y ~= py and (nhex.x == 0 or nhex.x == self.space.w)) then
			EchoDebug("mismatched direction " .. direction .. "/" .. DirFant2Native(direction) .. ":", nhex.x .. ", " .. nhex.y, "vs", px .. ", " .. py)
		end
	end
	if nhex ~= self then return nhex end
end

function Hex:Neighbors(directions)
	if directions == nil then directions = { 1, 2, 3, 4, 5, 6 } end
	local neighbors = {}
	for i, direction in pairs(directions) do
		neighbors[direction] = self:Adjacent(direction)
	end
	return neighbors
end

function Hex:GetDirectionTo(hex)
	for d, nhex in pairs(self:Neighbors()) do
		if nhex == hex then return d end
	end
end

function Hex:ClosestSubPolygon()
	return self.space:ClosestThing(self, self.space.subPolygons)
end

function Hex:FindSubPolygonNeighbors()
	for direction, nhex in pairs(self:Neighbors()) do -- 3 and 4 are are never there yet?
		if nhex.subPolygon ~= self.subPolygon then
			self.subPolygon:SetNeighbor(nhex.subPolygon)
			local subEdge = self.subPolygon.edges[nhex.subPolygon] or SubEdge(self.subPolygon, nhex.subPolygon)
			subEdge:AddHexPair(self, nhex, direction)
		end
	end
end

function Hex:Near(hexKey, hexValue, subPolygonKey, subPolygonValue, polygonKey, polygonValue)
	for d, nhex in pairs(self:Neighbors()) do
		if hexKey ~= nil and nhex[hexKey] == hexValue then return true end
		if subPolygonKey ~= nil and nhex.subPolygon[subPolygonKey] == subPolygonValue then return true end
		if polygonKey ~= nil and nhex.polygon[polygonKey] == polygonValue then return true end
	end
	return false
end

function Hex:NearOcean()
	return self:Near(nil, nil, nil, nil, "continent", nil)
end

function Hex:IsNeighbor(hex)
	for d, nhex in pairs(self:Neighbors()) do
		if nhex == hex then return d end
	end
	return false
end

function Hex:SetPlot()
	if self.plotType == nil then EchoDebug("nil plotType at " .. self.x .. ", " .. self.y) end
	if self.plot == nil then return end
	self.plot:SetPlotType(self.plotType)
end

function Hex:SetTerrain()
	if self.plot == nil then return end
	self.plot:SetTerrainType(self.terrainType, false, false)
end

function Hex:SetFeature()
	if self.featureType == nil then return end
	if self.plot == nil then return end
	if self.plotType == plotMountain then
		if self.space.falloutEnabled and mRandom(0, 100) < mMin(25, FeatureDictionary[featureFallout].percent) then
			self.featureType = featureFallout
		end
	elseif self.isRiver then
		if self.space.falloutEnabled and self.space.contaminatedWater and mRandom(0, 100) < FeatureDictionary[featureFallout].percent then
			self.featureType = featureFallout
		elseif self.terrainType == terrainDesert and self.plotType == plotLand then
			self.featureType = featureFloodPlains
		end
	elseif self.plot:IsCoastalLand() then
		if self.space.falloutEnabled and self.space.contaminatedWater and mRandom(0, 100) < (100 - FeatureDictionary[featureFallout].percent) then
			self.featureType = featureFallout
		end
	end
	self.plot:SetFeatureType(self.featureType)
end

function Hex:SetRiver()
	if self.plot == nil then return end
	if not self.ofRiver then return end
	if self.ofRiver[DirW] then self.plot:SetWOfRiver(true, self.ofRiver[DirW] or FlowDirectionTypes.NO_DIRECTION) end
	if self.ofRiver[DirNW] then self.plot:SetNWOfRiver(true, self.ofRiver[DirNW] or FlowDirectionTypes.NO_DIRECTION) end
	if self.ofRiver[DirNE] then self.plot:SetNEOfRiver(true, self.ofRiver[DirNE] or FlowDirectionTypes.NO_DIRECTION) end
	-- for d, fd in pairs(self.ofRiver) do
		-- EchoDebug(DirName(d), FlowDirName(fd))
	-- end
end

function Hex:SetRoad()
	if self.plot == nil then return end
	if not self.road then return end
	-- self.plot:SetFeatureType(featureFallout)
	-- self.plot:SetRouteType(routeRoad)
	local sqlStatement = "INSERT INTO Ancient_Roads (x, y) VALUES (" .. self.x .. ", " .. self.y .. ");"
	for whatever in DB.Query(sqlStatement) do
		EchoDebug(tostring(whatever))
	end
end

function Hex:SetContinentArtType()
	if self.plot == nil then return end
	if self.polygon.region then
		self.plot:SetContinentArtType(self.polygon.region.artType)
	else
		if self.plotType == plotOcean then
			self.plot:SetContinentArtType(artOcean)
		else
			self.plot:SetContinentArtType(tGetRandom(self.space.artContinents))
		end
	end
end

function Hex:EdgeCount()
	if self.edgeCount then return self.edgeCount end
	self.edgeCount = 0
	for e, edge in pairs(self.edges) do
		self.edgeCount = self.edgeCount + 1
	end
	return self.edgeCount
end

function Hex:Locate()
	return self.x .. ", " .. self.y
end

------------------------------------------------------------------------------

Polygon = class(function(a, space, x, y)
	a.space = space
	a.x = x or Map.Rand(space.iW, "random x")
	a.y = y or Map.Rand(space.iH, "random y")
	a.centerPlot = Map.GetPlot(a.x, a.y)
	if space.useMapLatitudes then
		a.latitude = space:GetPlotLatitude(a.centerPlot)
		if not space.wrapX then
			a.latitude = space:RealmLatitude(a.y)
		end
	end
	a.subPolygons = {}
	a.hexes = {}
	a.edges = {}
	a.subEdges = {}
	a.isNeighbor = {}
	a.neighbors = {}
	a.minX = space.w
	a.maxX = 0
	a.minY = space.h
	a.maxY = 0
end)

function Polygon:FloodFillSuperPolygon(floodIndex, superPolygon)
	superPolygon = superPolygon or self.superPolygon
	if self.superPolygon ~= superPolygon or self.flooded then return false end
	if self.space.floods[floodIndex] == nil then self.space.floods[floodIndex] = {} end
	tInsert(self.space.floods[floodIndex], self)
	self.flooded = true
	for i, neighbor in pairs(self.neighbors) do
		neighbor:FloodFillSuperPolygon(floodIndex, superPolygon)
	end
	return true
end

function Polygon:FloodFillAstronomy(astronomyIndex)
	if self.oceanIndex or self.nearOcean then
		self.astronomyIndex = (self.oceanIndex or self.nearOcean) + 100
		return nil
	end
	if self.astronomyIndex then return nil end
	self.astronomyIndex = astronomyIndex
	if self.space.astronomyBasins[astronomyIndex] == nil then self.space.astronomyBasins[astronomyIndex] = {} end
	tInsert(self.space.astronomyBasins[astronomyIndex], self)
	for i, neighbor in pairs(self.neighbors) do
		neighbor:FloodFillAstronomy(astronomyIndex)
	end
	return true
end

function Polygon:SetNeighbor(polygon)
	if not self.isNeighbor[polygon] then
		tInsert(self.neighbors, polygon)
	end
	if not polygon.isNeighbor[self] then
		tInsert(polygon.neighbors, self)
	end
	self.isNeighbor[polygon] = true
	polygon.isNeighbor[self] = true
end

function Polygon:RelaxToCentroid()
	local hexes
	if #self.subPolygons ~= 0 then
		hexes = {}
		for spi, subPolygon in pairs(self.subPolygons) do
			for hi, hex in pairs(subPolygon.hexes) do
				tInsert(hexes, hex)
			end
		end
	elseif #self.hexes ~= 0 then
		hexes = self.hexes
	end
	if hexes then
		local totalX, totalY, total = 0, 0, 0
		for hi, hex in pairs(hexes) do
			local x, y = hex.x, hex.y
			if self.space.wrapX then
				local xdist = mAbs(x - self.minX)
				if xdist > self.space.halfWidth then x = x - self.space.w end
			end
			if self.space.wrapY then
				local ydist = mAbs(y - self.minY)
				if ydist > self.space.halfHeight then y = y - self.space.h end
			end
			totalX = totalX + x
			totalY = totalY + y
			total = total + 1
		end
		local centroidX = mCeil(totalX / total)
		if centroidX < 0 then centroidX = self.space.w + centroidX end
		local centroidY = mCeil(totalY / total)
		if centroidY < 0 then centroidY = self.space.h + centroidY end
		self.x, self.y = centroidX, centroidY
		if self.space.useMapLatitudes then
			self.latitude = self.space:GetHexByXY(self.x, self.y).latitude
			if not self.space.wrapX then
				self.latitude = self.space:RealmLatitude(self.y)
			end
		end
	end
	self.minX, self.minY, self.maxX, self.maxY = self.space.w, self.space.h, 0, 0
	self.hexes, self.subPolygons = {}, {}
end

function Polygon:CheckBottomTop(hex)
	local x, y = hex.x, hex.y
	local space = self.space
	if y == 0 and self.y < space.halfHeight then
		self.bottomY = true
		if not self.superPolygon then tInsert(space.bottomYPolygons, self) end
	end
	if x == 0 and self.x < space.halfWidth then
		self.bottomX = true
		if not self.superPolygon then tInsert(space.bottomXPolygons, self) end
	end
	if y == space.h and self.y >= space.halfHeight then
		self.topY = true
		if not self.superPolygon then tInsert(space.topYPolygons, self) end
	end
	if x == space.w and self.x >= space.halfWidth then
		self.topX = true
		if not self.superPolygon then tInsert(space.topXPolygons, self) end
	end
	if self.space.useMapLatitudes and self.space.polarExponent >= 1.0 and hex.latitude == 90 then
		self.polar = true
	end
end

function Polygon:NearOther(value, key)
	if key == nil then key = "continent" end
	for ni, neighbor in pairs (self.neighbors) do
		if neighbor[key] ~= nil and neighbor[key] ~= value then
			return true
		end
	end
	return false
end

function Polygon:FindPolygonNeighbors()
	for n, neighbor in pairs(self.neighbors) do
		if neighbor.superPolygon ~= self.superPolygon then
			self.superPolygon:SetNeighbor(neighbor.superPolygon)
			local superEdge = self.superPolygon.edges[neighbor.superPolygon] or Edge(self.superPolygon, neighbor.superPolygon)
			superEdge:AddSubEdge(self.subEdges[neighbor])
		end
	end
end

function Polygon:Place()
	self.superPolygon = self:ClosestPolygon()
	tInsert(self.superPolygon.subPolygons, self)
end

function Polygon:ClosestPolygon()
	return self.space:ClosestThing(self, self.space.polygons)
end

function Polygon:FillHexes()
	for spi, subPolygon in pairs(self.subPolygons) do
		for hi, hex in pairs(subPolygon.hexes) do
			hex:InsidePolygon(self)
			tInsert(self.hexes, hex)
			hex.polygon = self
		end
	end
end

function Polygon:PickTinyIslands()
	if (self.bottomX or self.topX) and self.oceanIndex and not self.space.wrapX then return end
	if (self.bottomY or self.topY) and self.oceanIndex and not self.space.wrapX then return end
	for i, subPolygon in pairs(self.subPolygons) do
		local tooCloseForIsland = false
		if not tooCloseForIsland then
			for i, neighbor in pairs(subPolygon.neighbors) do
				if neighbor.superPolygon.continent or self.oceanIndex ~= neighbor.superPolygon.oceanIndex or neighbor.tinyIsland then
					tooCloseForIsland = true
					break
				end
				for nn, neighneigh in pairs(neighbor.neighbors) do
					if self.oceanIndex ~= neighneigh.superPolygon.oceanIndex then
						tooCloseForIsland = true
						break
					end
				end
				if tooCloseForIsland then break end
			end
		end
		local chance = self.space.tinyIslandChance
		if self.oceanIndex then chance = chance * 1.5 end
		if not tooCloseForIsland and (Map.Rand(100, "tiny island chance") <= chance or ((self.loneCoastal or self.oceanIndex) and not self.hasTinyIslands)) then
			subPolygon.tinyIsland = true
			tInsert(self.space.tinyIslandSubPolygons, subPolygon)
			self.hasTinyIslands = true
		end
	end
end

function Polygon:EmptyCoastHex()
	local hexPossibilities = {}
	local destHex
	for isph, sphex in pairs(self.hexes) do
		if sphex.plotType == plotOcean and sphex.featureType ~= featureIce and sphex.featureType ~= featureAtoll and sphex.terrainType == terrainCoast then
			for d, nhex in pairs(sphex:Neighbors()) do
				if nhex.plotType ~= plotOcean then
					destHex = sphex
					break
				end
			end
			if destHex then break end
			tInsert(hexPossibilities, sphex)
		end
	end
	if not destHex and #hexPossibilities > 0 then
		destHex = tGetRandom(hexPossibilities)
	end
	return destHex
end

------------------------------------------------------------------------------

SubEdge = class(function(a, polygon1, polygon2)
	a.space = polygon1.space
	a.polygons = { polygon1, polygon2 }
	a.hexes = {}
	a.pairings = {}
	a.path = {}
	a.hexOfRiver = {}
	a.connections = {}
	a.lowConnections = {}
	a.highConnections = {}
	polygon1.subEdges[polygon2] = a
	polygon2.subEdges[polygon1] = a
	tInsert(a.space.subEdges, a)
end)

function SubEdge:AddHexPair(hex, pairHex, direction)
	direction = direction or hex:GetDirectionTo(pairHex)
	if self.pairings[hex] == nil then
		tInsert(self.hexes, hex)
		self.pairings[hex] = {}
	end
	if self.pairings[pairHex] == nil then
		tInsert(self.hexes, pairHex)
		self.pairings[pairHex] = {}
	end
	self.pairings[hex][pairHex] = direction
	self.pairings[pairHex][hex] = OppositeDirection(direction)
	if direction == DirE or direction == DirSE or direction == DirSW then
		if self.hexOfRiver[hex] == nil then self.hexOfRiver[hex] = {} end
		self.hexOfRiver[hex][OppositeDirection(direction)] = true
	else
		if self.hexOfRiver[pairHex] == nil then self.hexOfRiver[pairHex] = {} end
		self.hexOfRiver[pairHex][direction] = true
	end
	hex.subEdges[self], pairHex.subEdges[self] = true, true
end

function SubEdge:Assemble()
	-- get a random starting point
	local hex = tGetRandom(self.hexes)
	-- find an end
	repeat
		hex.picked = true
		local newHex
		for d, nhex in pairs(hex:Neighbors()) do
			if self.pairings[nhex] and not nhex.picked then
				newHex = nhex
				break
			end
		end
		hex = newHex or hex
	until not newHex
	-- this end will be called low
	self.lowHex = hex
	hex.subEdgeLow[self], hex.subEdgeEnd[self] = true, true
	-- follow the edge's path from that end
	local pairHex
	local direction
	local leastNeighs = 6
	for phex, pdir in pairs(self.pairings[hex]) do
		local neighs = 0
		for d, nhex in pairs(phex:Neighbors()) do
			if self.pairings[nhex] and nhex ~= hex then
				neighs = neighs + 1
			end
		end
		if neighs < leastNeighs then
			leastNeighs = neighs
			pairHex = phex
			direction = pdir
		end
	end
	local iteration = 1
	local lastHex
	repeat
		local newHex, newDirection, newDirectionPair
		local behindHex, behindDirection, behindDirectionPair
		local neighs = {}
		for d, nhex in pairs(hex:Neighbors()) do
			if nhex ~= pairHex then
				neighs[nhex] = d
			end
		end
		local mutual = {}
		local mut = 0
		for d, nhex in pairs(pairHex:Neighbors()) do
			if neighs[nhex] then
				mutual[nhex] = d
				mut = mut + 1
			end
		end
		for mhex, pdir in pairs(mutual) do
			if mhex.edges[self] and mhex ~= lastHex then
				newHex = mhex
				newDirection = neighs[mhex]
				newDirectionPair = pdir
			else
				behindHex = mhex
				behindDirection = neighs[mhex]
				behindDirectionPair = pdir
			end
		end
		local forwardHex, forwardDirection, forwardDirectionPair = newHex, newDirection, newDirectionPair
		if not forwardHex then
			for mhex, pdir in pairs(mutual) do
				if mhex ~= behindHex then
					forwardHex = mhex
					forwardDirection = neighs[mhex]
					forwardDirectionPair = pdir
				end
			end
		end
		-- if not forwardHex then EchoDebug("no forward hex", mut, hex.x .. ", " .. hex.y, pairHex.x .. ", " .. pairHex.y) end
		local behindFlowDirection = GetFlowDirection(direction, behindDirection)
		local forwardFlowDirection = GetFlowDirection(direction, newDirection)
		local part = {hex = hex, pairHex = pairHex, direction = direction, behindHex = behindHex, behindDirection = behindDirection, behindDirectionPair = behindDirectionPair, behindFlowDirection = behindFlowDirection, forwardHex = forwardHex, forwardDirection = forwardDirection, forwardDirectionPair = forwardDirectionPair, forwardFlowDirection = forwardFlowDirection}
		if hex.subEdgeParts[self] == nil then hex.subEdgeParts[self] = {} end
		if pairHex.subEdgeParts[self] == nil then pairHex.subEdgeParts[self] = {} end
		tInsert(hex.subEdgeParts[self], part)
		tInsert(pairHex.subEdgeParts[self], part)
		tInsert(self.path, part)
		if not newHex then break end
		if self.pairings[hex] and self.pairings[hex][newHex] then
			lastHex = pairHex
			pairHex = newHex
			direction = newDirection
		elseif self.pairings[pairHex] and self.pairings[pairHex][newHex] then
			lastHex = hex
			hex = pairHex
			pairHex = newHex
			direction = newDirectionPair
		else
			EchoDebug("MUTUAL NEIGHBOR IS NEITHER'S PAIRING")
			break
		end
		iteration = iteration + 1
	until not newHex
	-- this end will be called high
	self.highHex = hex
	hex.edgeHigh[self], hex.edgeEnd[self] = true, true
	-- reset temporary hex markers
	for h, hex in pairs(self.hexes) do
		hex.picked = nil
	end
end

function SubEdge:FindConnections()
	local neighs = {}
	for i, neighbor in pairs(self.polygons[1].neighbors) do
		neighs[neighbor] = true
	end
	local mut = 0
	local mutual = {}
	for i, neighbor in pairs(self.polygons[2].neighbors) do
		if neighs[neighbor] then
			mutual[neighbor] = true
			mut = mut + 1
		end
	end
	-- if mut ~= 2 and not (self.polygons[1].topY or self.polygons[1].bottomY or self.polygons[2].topY or self.polygons[2].bottomY) then EchoDebug(mut .. " mutual neighbors ", tostring(self.polygons[1].topY or self.polygons[1].bottomY or self.polygons[2].topY or self.polygons[2].bottomY)) end
	local actual, fake = 0, 0
	local lowHex = self.path[1].behindHex
	local highHex = self.path[#self.path].forwardHex
	for neighbor, yes in pairs(mutual) do
		for p, polygon in pairs(self.polygons) do
			local subEdge = neighbor.subEdges[polygon] or polygon.subEdges[neighbor]
			fake = fake + 1
			if lowHex and lowHex.subPolygon == neighbor then
				self.lowConnections[subEdge] = true
			else -- if highHex and highHex.subPolygon == neighbor then
				self.highConnections[subEdge] = true
			end
			if self.highConnections[subEdge] or self.lowConnections[subEdge] then
				self.connections[subEdge] = true
				subEdge.connections[self] = true
				actual = actual + 1
			end
		end
	end
	-- if fake ~= 4 and not (self.polygons[1].topY or self.polygons[1].bottomY or self.polygons[2].topY or self.polygons[2].bottomY) then EchoDebug(fake .. " fake connections", actual .. " actual connections", tostring(self.polygons[1].topY or self.polygons[1].bottomY or self.polygons[2].topY or self.polygons[2].bottomY)) end
	--[[
	for lowHigh = 1, 2 do
		local hex, phex, mhex
		if lowHigh == 1 then
			local part = self.path[1]
			hex = part.hex
			phex = part.pairHex
			mhex = part.behindHex
		else
			local part = self.path[#self.path]
			hex = part.hex
			phex = part.pairHex
			mhex = part.forwardHex
		end
		-- if not mhex then EchoDebug("no mhex", lowHigh) end
		if mhex then
			for cedge, yes in pairs(mhex.subEdges) do
				if cedge ~= self and (cedge.pairings[mhex][phex] or cedge.pairings[mhex][hex]) then
					self.connections[cedge] = { hex = hex, pairHex = phex, direction = hex:GetDirectionTo(phex), connectionDirection = hex:GetDirectionTo(mhex), connectionHex = mhex }
					if lowHigh == 1 then
						self.lowConnections[cedge] = self.connections[cedge]
					else
						self.highConnections[cedge] = self.connections[cedge]
					end
					cedge.connections[self] = true
					if mhex == cedge.path[1].hex or mhex == cedge.path[1].pairHex then
						cedge.lowConnections[self] = true
					else
						cedge.highConnections[self] = true
					end
				end
			end
		end
	end
	]]--
end

------------------------------------------------------------------------------

Edge = class(function(a, polygon1, polygon2)
	a.space = polygon1.space
	a.polygons = { polygon1, polygon2 }
	a.subEdges = {}
	a.orderedSubEdges = {}
	a.connections = {}
	a.lowConnections = {}
	a.highConnections = {}
	polygon1.edges[polygon2] = a
	polygon2.edges[polygon1] = a
	tInsert(a.space.edges, a)
end)

function Edge:AddSubEdge(subEdge)
	if subEdge.superEdge ~= self then
		subEdge.superEdge = self
		tInsert(self.subEdges, subEdge)
	end
end

function Edge:DetermineOrder()
	local picked, pickedAgain = {}, {}
	local subEdge = self.subEdges[1]
	-- find a beginning
	local it = 0
	repeat
		local newEdge
		if subEdge == nil then EchoDebug(it, #self.subEdges) end
		picked[subEdge] = true
		local routes = 0
		for cedge, yes in pairs(subEdge.connections) do
			if cedge.superEdge == self and not picked[cedge] then
				newEdge = cedge
				routes = routes + 1
			end
		end
		-- if self.space.edges[1] == self then EchoDebug(routes .. " routes", subEdge.polygons[1].superPolygon, subEdge.polygons[2].superPolygon) end
		subEdge = newEdge or subEdge
		it = it + 1
	until not newEdge
	-- EchoDebug(it .. " iterations", #self.subEdges .. " subedges" )
	self.lowSubEdge = subEdge
	-- find an end
	repeat
		local newEdge
		pickedAgain[subEdge] = true
		tInsert(self.orderedSubEdges, subEdge)
		local routes = 0
		for cedge, yes in pairs(subEdge.connections) do
			if cedge.superEdge == self and not pickedAgain[cedge] then
				newEdge = cedge
				if subEdge.lowConnections[cedge] then subEdge.superEdgeLow = true end
				routes = routes + 1
			end
		end
		-- if self.space.edges[1] == self then EchoDebug(routes .. " routes", subEdge.polygons[1].superPolygon, subEdge.polygons[2].superPolygon) end
		subEdge = newEdge or subEdge
	until not newEdge
	self.highSubEdge = subEdge
	if #self.orderedSubEdges < #self.subEdges then EchoDebug(#self.orderedSubEdges, #self.subEdges) end
end

function Edge:FindConnections()
	-- determine which way end subedges are oriented
	for cedge, yes in pairs(self.lowSubEdge.lowConnections) do
		if cedge.superEdge == self then
			self.lowSubEdge.superEdgeLow = true
			break
		end
	end
	for cedge, yes in pairs(self.highSubEdge.lowConnections) do
		if cedge.superEdge == self then
			self.highSubEdge.superEdgeLow = true
			break
		end
	end
	-- find low end connections
	local connections
	if self.lowSubEdge.superEdgeLow then
		connections = self.lowSubEdge.highConnections
	else
		connections = self.lowSubEdge.lowConnections
	end
	for cedge, yes in pairs(connections) do
		if cedge.superEdge and cedge.superEdge ~= self then
			self.lowConnections[cedge.superEdge] = true
			self.connections[cedge.superEdge] = true
		end
	end
	-- find high end connections
	if self.highSubEdge.superEdgeLow then
		connections = self.highSubEdge.highConnections
	else
		connections = self.highSubEdge.lowConnections
	end
	for cedge, yes in pairs(connections) do
		if cedge.superEdge and cedge.superEdge ~= self then
			self.highConnections[cedge.superEdge] = true
			self.connections[cedge.superEdge] = true
		end
	end
end


------------------------------------------------------------------------------

Region = class(function(a, space)
	a.space = space
	a.collection = {}
	a.polygons = {}
	a.area = 0
	a.hillCount = 0
	a.mountainCount = 0
	a.featureFillCounts = {}
	for featureType, feature in pairs(FeatureDictionary) do
		a.featureFillCounts[featureType] = 0
	end
	if space.centauri then
		a.artType = tGetRandom(space.artContinents)
	end
end)

function Region:CreateCollection()
	-- get latitude (real or fake)
	self.latitude = self:GetLatitude()
	-- get temperature, rainfall, hillyness, mountainousness, lakeyness
	self.temperatureAvg, self.temperatureMin, self.temperatureMax = self.space:GetTemperature(self.latitude)
	self.rainfallAvg, self.rainfallMin, self.rainfallMax = self.space:GetRainfall(self.latitude)
	self.hillyness = self.space:GetHillyness()
	self.mountainous = mRandom(1, 100) < self.space.mountainousRegionPercent
	self.mountainousness = 0
	if self.mountainous then self.mountainousness = mRandom(self.space.mountainousnessMin, self.space.mountainousnessMax) end
	self.lakey = mRandom(1, 100) < self.space.lakeRegionPercent or #self.space.lakeSubPolygons < self.space.minLakes
	self.lakeyness = 0
	if self.lakey then self.lakeyness = mRandom(self.space.lakeynessMin, self.space.lakeynessMax) end
	-- EchoDebug(self.latitude, self.temperatureMin, self.temperatureMax, self.rainfallMin, self.rainfallMax, self.mountainousness, self.lakeyness, self.hillyness)
	-- create the collection
	self.size, self.subSize = self.space:GetCollectionSize()
	local subPolys = 0
	for i, polygon in pairs(self.polygons) do
		subPolys = subPolys + #polygon.subPolygons
	end
	self.size = mMin(self.size, subPolys) -- make sure there aren't more collections than subpolygons in the region
	self.totalSize = self.size * self.subSize
	-- EchoDebug(self.size, self.subSize, self.totalSize, subPolys)
	-- create lists of possible temperature and rainfall
	local tempList = {}
	local rainList = {}
	local tInc = (self.temperatureMax - self.temperatureMin) / self.size
	local rInc = (self.rainfallMax - self.rainfallMin) / self.size
	local tSubInc = tInc / (self.subSize - 1)
	local rSubInc = rInc / (self.subSize - 1)
	for i = 1, self.size do
		local temperature = self.temperatureMin + (tInc * (i-1))
		local rainfall = self.rainfallMin + (rInc * (i-1))
		local temps = {}
		local rains = {}
		if self.subSize == 1 then
			temps = { temperature + (tInc / 2) }
			rains = { rainfall + (rInc / 2) }
		else
			for si = 1, self.subSize do
				local temp = temperature + (tSubInc * (si-1))
				local rain = rainfall + (rSubInc * (si-1))
				tInsert(temps, temp)
				tInsert(rains, rain)
			end
		end
		tInsert(tempList, temps)
		tInsert(rainList, rains)
	end
	-- pick randomly from lists of temperature and rainfall to create elements in the collection
	if self.polar then
		self.size = self.size + 1
		self.polarTemps = {}
		self.polarRains = tDuplicate(tGetRandom(rainList))
		local temp, tmin, tmax = self.space:GetTemperature(90)
		for si = 1, self.subSize do
			local temp = tmin + (tSubInc * (si-1))
			tInsert(self.polarTemps, temp)
		end
	end
	for i = 1, self.size do
		local lake = mRandom(1, 100) < self.lakeyness
		if i == 1 then lake = nil end
		local temps, rains
		if self.polar and i == self.size then
			temps = self.polarTemps
			rains = self.polarRains
			lake = nil
		else
			temps = tRemoveRandom(tempList)
			rains = tRemoveRandom(rainList)
		end
		-- EchoDebug("lists", i, self.size, #tempList, #rainList, self.subSize, #temps, #rains)
		local subCollection = { elements = {}, lake = lake }
		local tempTotal, rainTotal = 0, 0
		for si = 1, self.subSize do
			-- EchoDebug("sublists", si, #temps, #rains, self.subSize)
			local temperature = tRemoveRandom(temps)
			local rainfall = tRemoveRandom(rains)
			tempTotal = tempTotal + temperature
			rainTotal = rainTotal + rainfall
			tInsert(subCollection.elements, self:CreateElement(temperature, rainfall, lake))
		end
		subCollection.temperature = mFloor(tempTotal / self.subSize)
		subCollection.rainfall = mFloor(rainTotal / self.subSize)
		if self.polar and i == self.size then subCollection.polar = true end
		tInsert(self.collection, subCollection)
	end
end

function Region:GetLatitude()
	if self.space.useMapLatitudes then
		for i, polygon in pairs(self.polygons) do
			if polygon.polar then
				self.polar = true
				return mFloor((polygon.latitude + 90) / 2)
			end
		end
	end
	local polygon = tGetRandom(self.polygons)
	return mFloor(polygon.latitude)
	--[[
	local latSum = 0
	for i, polygon in pairs(self.polygons) do
		latSum = latSum + polygon.latitude
	end
	return mFloor(latSum / #self.polygons)
	]]--
end

function Region:WithinBounds(thing, temperature, rainfall)
	temperature = mFloor(temperature)
	rainfall = mFloor(rainfall)
	if temperature < thing.temperature[1] then return false end
	if temperature > thing.temperature[2] then return false end
	if rainfall < thing.rainfall[1] then return false end
	if rainfall > thing.rainfall[2] then return false end
	return true
end

function Region:BoundsDistance(bounds, value)
	local min, max, mid = bounds[1], bounds[2], bounds[3]
	if value >= min and value <= max then
		mid = mid or (min + max) / 2
		return mAbs(value - mid)
	else
		if value > max then return 100 + (value - max) end
		if value < min then return 100 + (min - value) end
	end
end

function Region:TemperatureRainfallDistance(thing, temperature, rainfall)
	local tdist = self:BoundsDistance(thing.temperature, temperature)
	local rdist = self:BoundsDistance(thing.rainfall, rainfall)
	return mSqrt(tdist^2 + rdist^2)
	-- return tdist + rdist
end

function Region:CreateElement(temperature, rainfall, lake)
	temperature = temperature or mRandom(self.temperatureMin, self.temperatureMax)
	rainfall = rainfall or mRandom(self.rainfallMin, self.rainfallMax)
	local mountain = mRandom(1, 100) < self.mountainousness
	local hill = mRandom(1, 100) < self.hillyness
	if lake then
		mountain = false
		hill = false
	end
	if hill then
		temperature = mMax(temperature * 0.9, 0)
		rainfall = mMin(rainfall * 1.1, 100)
	end
	temperature = mFloor(temperature)
	rainfall = mFloor(rainfall)
	local bestDist = 300
	local bestTerrain
	for terrainType, terrain in pairs(TerrainDictionary) do
		if self:WithinBounds(terrain, temperature, rainfall) then
			local dist = self:TemperatureRainfallDistance(terrain, temperature, rainfall)
			if dist < bestDist then
				bestDist = dist
				bestTerrain = terrain
			end
		end
	end
	bestDist = 300
	local bestFeature
	for i, featureType in pairs(bestTerrain.features) do
		if featureType ~= featureNone and (featureType ~= featureFallout or self.space.falloutEnabled) then
			local feature = FeatureDictionary[featureType]
			if self:WithinBounds(feature, temperature, rainfall) then
				local dist = 300
				dist = self:TemperatureRainfallDistance(feature, temperature, rainfall)
				if dist < bestDist then
					bestDist = dist
					bestFeature = feature
				end
			end
		end
	end
	if bestFeature == nil or mRandom(1, 140) < bestDist or mRandom(1, 100) > bestFeature.percent then bestFeature = FeatureDictionary[bestTerrain.features[1]] end -- default to the first feature in the list
	local plotType = plotLand
	local terrainType = bestFeature.terrainType or bestTerrain.terrainType
	local featureType = bestFeature.featureType
	if mountain and self.mountainCount < mCeil(self.totalSize * (self.mountainousness / 100)) then
		plotType = plotMountain
		featureType = featureNone
		self.mountainCount = self.mountainCount + 1
	elseif lake then
		plotType = plotOcean
		terrainType = terrainCoast -- will become coast later
		featureType = featureNone
	elseif hill and bestFeature.hill and self.hillCount < mCeil(self.totalSize * (self.hillyness / 100)) then
		plotType = plotHills
		self.hillCount = self.hillCount + 1
	end
	return { plotType = plotType, terrainType = terrainType, featureType = featureType, temperature = temperature, rainfall = rainfall }
end

function Region:Fill()
	local filledHexes = {}
	for i, polygon in pairs(self.polygons) do
		for spi, subPolygon in pairs(polygon.subPolygons) do
			local subCollection = tGetRandom(self.collection)
			if self.polar and subPolygon.polar then
				subCollection = self.collection[#self.collection]
			end
			if subCollection.lake then
				for ni, neighbor in pairs(subPolygon.neighbors) do
					if not neighbor.superPolygon.continent or neighbor.lake then
						-- can't have a lake that's actually a part of the ocean
						local subCollectionBuffer = tDuplicate(self.collection)
						repeat
							subCollection = tRemoveRandom(subCollectionBuffer)
						until not subCollection.lake
						break
					end
				end
			end
			if subCollection.lake then
				self.hasLakes = true
				tInsert(self.space.lakeSubPolygons, subPolygon)
				EchoDebug("LAKE", #subPolygon.hexes .. " hexes ", subPolygon, polygon)
			end
			subPolygon.temperature = subCollection.temperature
			subPolygon.rainfall = subCollection.rainfall
			subPolygon.lake = subCollection.lake
			for hi, hex in pairs(subPolygon.hexes) do
				local element = tGetRandom(subCollection.elements)
				if hex.plotType ~= plotOcean then
					if filledHexes[hex] then EchoDebug("DUPE REGION FILL HEX at " .. hex:Locate()) end
					if element.plotType == plotOcean then
						hex.lake = true
						-- EchoDebug("lake hex at ", hex:Locate())
					end
					hex.plotType = element.plotType
					if element.plotType == plotMountain then tInsert(self.space.mountainHexes, hex) end
					hex.terrainType = element.terrainType
					if FeatureDictionary[element.featureType].limitRatio == -1 or self.featureFillCounts[element.featureType] < FeatureDictionary[element.featureType].limitRatio * self.area then
						hex.featureType = element.featureType
						self.featureFillCounts[element.featureType] = self.featureFillCounts[element.featureType] + 1
					else
						hex.featureType = featureNone
					end
					hex.temperature = element.temperature
					hex.rainfall = element.rainfall
					filledHexes[hex] = true
				end
			end
		end
	end
end

function Region:Label()
	if self.polygons[1].continent then
		self.continentSize = #self.polygons[1].continent
	end
	self.astronomyIndex = self.polygons[1].astronomyIndex
	if self.astronomyIndex >= 100 then
		self.astronomyIndex = mRandom(1, self.space.totalAstronomyBasins)
	end
	self.plotCounts = {}
	for i = -1, PlotTypes.NUM_PLOT_TYPES - 1 do
		self.plotCounts[i] = 0
	end
	self.terrainCounts = {}
	for i = -1, TerrainTypes.NUM_TERRAIN_TYPES - 1 do
		self.terrainCounts[i] = 0
	end
	self.featureCounts = {}
	for i = -1, 21 do
		self.featureCounts[i] = 0
	end
	self.subPolygonCount = 0
	local count = 0
	local avgX = 0
	local avgY = 0
	for ip, polygon in pairs(self.polygons) do
		for ih, hex in pairs(polygon.hexes) do
			if hex.plotType then
				self.plotCounts[hex.plotType] = self.plotCounts[hex.plotType] + 1
			end
			if hex.terrainType then
				self.terrainCounts[hex.terrainType] = self.terrainCounts[hex.terrainType] + 1
			end
			if hex.featureType then
				self.featureCounts[hex.featureType] = self.featureCounts[hex.featureType] + 1
			end
			count = count + 1
			avgX = avgX + hex.x
			avgY = avgY + hex.y
		end
		self.subPolygonCount = self.subPolygonCount + #polygon.subPolygons
	end
	avgX = mCeil(avgX / count)
	avgY = mCeil(avgY / count)
	self.plotRatios = {}
	self.terrainRatios = {}
	self.featureRatios = {}
	for plotType, tcount in pairs(self.plotCounts) do
		self.plotRatios[plotType] = tcount / count
		-- EchoDebug("plot", plotType, self.plotRatios[plotType])
	end
	for terrainType, tcount in pairs(self.terrainCounts) do
		self.terrainRatios[terrainType] = tcount / count
		-- EchoDebug("terrain", terrainType, self.terrainRatios[terrainType])
	end
	for featureType, tcount in pairs(self.featureCounts) do
		self.featureRatios[featureType] = tcount / count
		-- EchoDebug("feature", featureType, self.featureRatios[featureType])
	end
	local hexes = {}
	for i, polygon in pairs(self.polygons) do
		for h, hex in pairs(polygon.hexes) do
			tInsert(hexes, hex)
		end
	end
	local label = LabelThing(self, avgX, avgY, hexes)
	if label then return true end
end

------------------------------------------------------------------------------

Space = class(function(a)
	-- CONFIGURATION: --
	a.wrapX = true -- globe wraps horizontally?
	a.wrapY = false -- globe wraps vertically?
	a.polygonCount = 140 -- how many polygons (map scale)
	a.relaxations = 1 -- how many lloyd relaxations (higher number is greater polygon uniformity)
	a.subPolygonCount = 1700 -- how many subpolygons
	a.subPolygonFlopPercent = 18 -- out of 100 subpolygons, how many flop to another polygon
	a.subPolygonRelaxations = 0 -- how many lloyd relaxations for subpolygons (higher number is greater polygon uniformity, also slower)
	a.oceanNumber = 2 -- how many large ocean basins
	a.majorContinentNumber = 1 -- how many large continents per astronomy basin
	a.islandRatio = 0.5 -- what part of the continent polygons are taken up by 1-3 polygon continents
	a.polarMaxLandRatio = 0.15 -- how much of the land in each astronomy basin can be at the poles
	a.useMapLatitudes = false -- should the climate have anything to do with latitude?
	a.collectionSizeMin = 2 -- of how many groups of kinds of tiles does a region consist, at minimum
	a.collectionSizeMax = 9 -- of how many groups of kinds of tiles does a region consist, at maximum
	a.subCollectionSizeMin = 1 -- of how many kinds of tiles does a group consist, at minimum (modified by map size)
	a.subCollectionSizeMax = 9 -- of how many kinds of tiles does a group consist, at maximum (modified by map size)
	a.regionSizeMin = 1 -- least number of polygons a region can have
	a.regionSizeMax = 3 -- most number of polygons a region can have (but most will be limited by their area, which must not exceed half the largest polygon's area)
	a.riverLandRatio = 0.19 -- how much of the map to have tiles next to rivres. modified by rainfall
	a.riverRainMultiplier = 0.25 -- modifies rainfall effect on river inking. 0 is no rivers (except between lakes, which are not based on rain)
	a.riverSpawnRainfall = 85 -- how much rainfall spawns a river seed even without mountains/hills
	a.hillChance = 3 -- how many possible mountains out of ten become a hill when expanding and reducing
	a.mountainRangeMaxEdges = 8 -- how many polygon edges long can a mountain range be
	a.coastRangeRatio = 0.33
	a.mountainRatio = 0.04 -- how much of the land to be mountain tiles
	a.mountainRangeMult = 1.3 -- higher mult means more (globally) scattered mountains
	a.mountainCoreTenacity = 9 -- 0 to 10, higher is more range-like mountains, less widely scattered
	a.coastalPolygonChance = 2 -- out of ten, how often do water polygons become coastal?
	a.tinyIslandChance = 33 -- out of 100 possible subpolygons, how often do coastal shelves produce tiny islands
	a.coastDiceAmount = 2 -- how many dice does each polygon get for coastal expansion
	a.coastDiceMin = 2 -- the minimum sides for each polygon's dice
	a.coastDiceMax = 8 -- the maximum sides for each polygon's dice
	a.coastAreaRatio = 0.25 -- how much of the water on the map (not including coastal polygons) should be coast
	a.freezingTemperature = 19 -- this temperature and below creates ice. temperature is 0 to 100
	a.atollTemperature = 75 -- this temperature and above creates atolls
	a.atollPercent = 4 -- of 100 hexes, how often does atoll temperature produce atolls
	a.polarExponent = 1.2 -- exponent. lower exponent = smaller poles (somewhere between 0 and 2 is advisable)
	a.rainfallMidpoint = 50 -- 25 means rainfall varies from 0 to 50, 75 means 50 to 100, 50 means 0 to 100.
	a.temperatureMin = 0 -- lowest temperature possible (plus or minus intraregionTemperatureDeviation)
	a.temperatureMax = 100 -- highest temperature possible (plus or minus intraregionTemperatureDeviation)
	a.temperatureDice = 2 -- temperature probability distribution: 1 is flat, 2 is linearly weighted to the center like /\, 3 is a bell curve _/-\_, 4 is a skinnier bell curve
	a.intraregionTemperatureDeviation = 20 -- how much at maximum can a region's temperature vary within itself
	a.rainfallDice = 1 -- just like temperature above
	a.intraregionRainfallDeviation = 30 -- just like temperature above
	a.hillynessMax = 40 -- of 100 how many of a region's tile collection can be hills
	a.mountainousRegionPercent = 3 -- of 100 how many regions will have mountains
	a.mountainousnessMin = 33 -- in those mountainous regions, what's the minimum percentage of mountains in their collection
	a.mountainousnessMax = 66 -- in those mountainous regions, what's the maximum percentage of mountains in their collection
	a.minLakes = 3 -- below this number of lakes will cause a region to become lakey
	a.lakeRegionPercent = 11 -- of 100 how many regions will have little lakes
	a.lakeynessMin = 5 -- in those lake regions, what's the minimum percentage of water in their collection
	a.lakeynessMax = 60 -- in those lake regions, what's the maximum percentage of water in their collection
	a.roadCount = 5 -- how many polygon-to-polygon 'ancient' roads
	a.falloutEnabled = false -- place fallout on the map?
	a.contaminatedWater = false -- place fallout in rainy areas and along rivers?
	a.contaminatedSoil = false -- place fallout in dry areas and in mountains?
	a.mapLabelsEnabled = true -- add place names to the map?
	a.regionLabelsMax = 10 -- maximum number of labelled regions
	a.rangeLabelsMax = 5 -- maximum number of labelled mountain ranges (descending length)
	a.riverLabelsMax = 5 -- maximum number of labelled rivers (descending length)
	a.tinyIslandLabelsMax = 5 -- maximum number of labelled tiny islands
	----------------------------------
	-- DEFINITIONS: --
	a.oceans = {}
	a.continents = {}
	a.regions = {}
	a.polygons = {}
	a.subPolygons = {}
	a.discontEdges = {}
	a.edges = {}
	a.subEdges = {}
	a.mountainRanges = {}
	a.bottomYPolygons = {}
	a.bottomXPolygons = {}
	a.topYPolygons = {}
	a.topXPolygons = {}
	a.hexes = {}
    a.mountainHexes = {}
    a.mountainCoreHexes = {}
    a.tinyIslandPolygons = {}
    a.tinyIslandSubPolygons = {}
    a.deepHexes = {}
    a.lakeSubPolygons = {}
    a.rivers = {}
end)

function Space:SetOptions(optDict)
	for optionNumber, option in ipairs(optDict) do
		local optionChoice = Map.GetCustomOption(optionNumber)
		if option.values[optionChoice].values == "keys" then
			optionChoice = mRandom(1, #option.values-1)
		elseif option.values[optionChoice].values == "values" then
			local lowValues = option.values[1].values
			local highValues = option.values[#option.values-1].values
			local randValues = {}
			for valueNumber, key in pairs(option.keys) do
				local low, high = lowValues[valueNumber], highValues[valueNumber]
				local change = high - low
				randValues[valueNumber] = low + (change * mRandom(1))
				if mFloor(low) == low and mFloor(high) == high then
					randValues[valueNumber] = mFloor(randValues[valueNumber])
				end
			end
			option.values[optionChoice].values = randValues
		end
 		for valueNumber, key in ipairs(option.keys) do
			EchoDebug(key, option.name, valueNumber, optionChoice, option.values[optionChoice].values[valueNumber])
			self[key] = option.values[optionChoice].values[valueNumber]
		end
	end
end

function Space:Compute()
    self.iW, self.iH = Map.GetGridSize()
    self.iA = self.iW * self.iH
    self.areaMod = mFloor(mSqrt(self.iA) / 30)
    self.coastalMod = self.areaMod
    self.subCollectionSizeMin = self.subCollectionSizeMin + self.areaMod
    self.subCollectionSizeMax = self.subCollectionSizeMax + self.areaMod
    self.nonOceanArea = self.iA
    self.w = self.iW - 1
    self.h = self.iH - 1
    self.halfWidth = self.w / 2
    self.halfHeight = self.h / 2
    self.northLatitudeMult = 90 / Map.GetPlot(0, self.h):GetLatitude()
    local activatedMods = Modding.GetActivatedMods()
	for i,v in ipairs(activatedMods) do
		local title = Modding.GetModProperty(v.ID, v.Version, "Name")
		if title == "Fantastical Place Names" then
			EchoDebug("Fantastical Place Names enabled, labels will be generated")
			self.mapLabelsEnabled = true
		elseif title == "Alpha Centauri Maps" then
			EchoDebug("Alpha Centauri Maps enabled, will create random Map of Planet")
			self.centauri = true
			self.artContinents = { artAsia, artAfrica }
			TerrainDictionary, FeatureDictionary = TerrainDictionaryCentauri, FeatureDictionaryCentauri
			self.silverCount = mFloor(self.iA / 128)
			self.spicesCount = mFloor(self.iA / 160)
			self.polarMaxLandRatio = 0.0
			-- all centauri definitions are for subPolygons
			LabelDefinitionsCentauri = {
				Sea = { tinyIsland = false, superPolygon = {region = {coastal=true}} },
				Straights = { tinyIsland = false, coastContinentsTotal = 2, superPolygon = {waterTotal = -2} },
				Bay = { coast = true, coastTotal = 3, coastContinentsTotal = -1, superPolygon = {coastTotal = 3, coastContinentsTotal = -1, waterTotal = -1} },
				Ocean = { coast = false, superPolygon = {coast = false, continent = false, oceanIndex = false} },
				Cape = { coast = true, coastContinentsTotal = -1, superPolygon = {coastTotal = -1, coastContinentsTotal = 1, oceanIndex = false, } },
				Rift = { superPolygon = {oceanIndex = 1, polar = false, region={coastal=false}} },
				Freshwater = { superPolygon = {coastContinentsTotal = -1, coastTotal = 4, waterTotal = 0} },
				Isle = { continentSize = -3 },
				Jungle = { superPolygon = {continent = true, region = {temperatureAvg=95,rainfallAvg=95}} },
				ColdCoast = { coast = true, latitude = 75 },
				WarmCoast = { coast = true, latitude = -25 },
				Northern = { coast = false, polar = false, y = self.h * 0.7 },
				Southern = { coast = false, polar = false, y = self.h * -0.3 },
			}
			self.badNaturalWonders = {}
			self.centauriNaturalWonders = {}
			local badWonderTypes = { FEATURE_LAKE_VICTORIA = true, FEATURE_KILIMANJARO = true, FEATURE_SOLOMONS_MINES = true, FEATURE_FUJI = true }
			for f in GameInfo.Features() do
				if badWonderTypes[f.Type] then
					EchoDebug(f.ID, f.Type)
					self.badNaturalWonders[f.ID] = f.Type
				elseif f.ID > 6 and f.Type ~= "FEATURE_ATOLL" then
					self.centauriNaturalWonders[f.ID] = f.Description
				end

			end
		end
	end
    self.freshFreezingTemperature = self.freezingTemperature * 1.12
    if self.useMapLatitudes then
    	self.realmHemisphere = mRandom(1, 2)
    end
	self.polarExponentMultiplier = 90 ^ self.polarExponent
	if self.rainfallMidpoint > 50 then
		self.rainfallPlusMinus = 100 - self.rainfallMidpoint
	else
		self.rainfallPlusMinus = self.rainfallMidpoint
	end
	self.rainfallMax = self.rainfallMidpoint + self.rainfallPlusMinus
	self.rainfallMin = self.rainfallMidpoint - self.rainfallPlusMinus
    -- need to adjust island chance so that bigger maps have about the same number of islands, and of the same relative size
    self.minNonOceanPolygons = mCeil(self.polygonCount * 0.1)
    if not self.wrapX and not self.wrapY then self.minNonOceanPolygons = mCeil(self.polygonCount * 0.67) end
    self.nonOceanPolygons = self.polygonCount
    -- set fallout options
	-- [featureFallout] = { temperature = {0, 100}, rainfall = {0, 100}, percent = 15, limitRatio = 0.75, hill = true },
    if self.contaminatedWater and self.contaminatedSoil then
    	FeatureDictionary[featureFallout].percent = 70
    	FeatureDictionary[featureFallout].rainfall = {0, 100}
    elseif self.contaminatedWater then
    	FeatureDictionary[featureFallout].percent = 70
    	FeatureDictionary[featureFallout].rainfall = {65, 100}
    elseif self.contaminatedSoil then
    	FeatureDictionary[featureFallout].percent = 70
    	FeatureDictionary[featureFallout].limitRatio = 0.85
    	FeatureDictionary[featureFallout].rainfall = {0, 25}
    end
    EchoDebug(self.polygonCount .. " polygons", self.iA .. " hexes")
    EchoDebug("initializing polygons...")
    self:InitPolygons()
    if self.subPolygonRelaxations > 0 then
    	for r = 1, self.subPolygonRelaxations do
    		EchoDebug("filling subpolygons pre-relaxation...")
        	self:FillSubPolygons(true)
    		print("relaxing subpolygons... (" .. r .. "/" .. self.subPolygonRelaxations .. ")")
        	self:RelaxPolygons(self.subPolygons)
        end
    end
    EchoDebug("filling subpolygons post-relaxation...")
    self:FillSubPolygons()
    EchoDebug("culling empty subpolygons...")
    self:CullPolygons(self.subPolygons)
    self:GetSubPolygonSizes()
	EchoDebug("smallest subpolygon: " .. self.subPolygonMinArea, "largest subpolygon: " .. self.subPolygonMaxArea)
    if self.relaxations > 0 then
    	for r = 1, self.relaxations do
    		EchoDebug("filling polygons pre-relaxation...")
        	self:FillPolygons()
    		print("relaxing polygons... (" .. r .. "/" .. self.relaxations .. ")")
        	self:RelaxPolygons(self.polygons)
        end
    end
    EchoDebug("filling polygons post-relaxation...")
    self:FillPolygons()
    EchoDebug("populating polygon hex tables...")
    self:FillPolygonHexes()
    -- EchoDebug("flip-flopping subpolygons...")
    -- self:FlipFlopSubPolygons()
    EchoDebug("culling empty polygons...")
    self:CullPolygons(self.polygons)
    self:GetPolygonSizes()
	EchoDebug("smallest polygon: " .. self.polygonMinArea, "largest polygon: " .. self.polygonMaxArea)
    EchoDebug("determining subpolygon neighbors...")
    self:FindSubPolygonNeighbors()
    EchoDebug("finding polygon neighbors...")
    self:FindPolygonNeighbors()
    EchoDebug("assembling subedges...")
    self:AssembleSubEdges()
    EchoDebug("finding subedge connections...")
    self:FindSubEdgeConnections()
    EchoDebug("assembling edges...")
    self:AssembleEdges()
    EchoDebug("picking oceans...")
    self:PickOceans()
    EchoDebug("flooding astronomy basins...")
    self:FindAstronomyBasins()
    EchoDebug("picking continents...")
    self:PickContinents()
    EchoDebug("picking coasts...")
	self:PickCoasts()
	if not self.useMapLatitudes then
		EchoDebug("dispersing fake latitude...")
		self:DisperseFakeLatitude()
	end
	EchoDebug("computing seas...")
	self:ComputeSeas()
	EchoDebug("picking regions...")
	self:PickRegions()
	EchoDebug("filling regions...")
	self:FillRegions()
	EchoDebug("picking mountain ranges...")
    self:PickMountainRanges()
	EchoDebug("computing landforms...")
	self:ComputeLandforms()
	EchoDebug("computing ocean temperatures...")
	self:ComputeOceanTemperatures()
	EchoDebug("computing coasts...")
	self:ComputeCoasts()
	EchoDebug("finding river seeds...")
	self:FindRiverSeeds()
	EchoDebug("drawing lake rivers...")
	self:DrawLakeRivers()
	EchoDebug("drawing rivers...")
	self:DrawRivers()
	if self.roadCount > 0 then
		EchoDebug("drawing roads...")
		self:DrawRoads()
	end
	if self.mapLabelsEnabled then
		EchoDebug("labelling map...")
		self:LabelMap()
		-- for some reason the db and gameinfo are different, i have no idea why
		--[[
		for row in GameInfo.Fantastical_Map_Labels() do
			EchoDebug(row.Label, row.Type, row.x .. ", " .. row.y)
		end
		EchoDebug("query:")
		local results = DB.Query("SELECT * FROM Fantastical_Map_Labels")
		for row in results do
			EchoDebug(row.Label, row.Type, row.x .. ", " .. row.y)
		end
		]]--
	end
end

function Space:ComputeLandforms()
	for pi, hex in pairs(self.hexes) do
		if hex.polygon.continent ~= nil then
			-- near ocean trench?
			for neighbor, yes in pairs(hex.adjacentPolygons) do
				if neighbor.oceanIndex ~= nil then
					hex.nearOceanTrench = true
					if neighbor.nearOcean then EchoDebug("CONTINENT NEAR OCEAN TRENCH??") end
					break
				end
			end
			if hex.nearOceanTrench then
				EchoDebug("CONTINENT PLOT NEAR OCEAN TRENCH")
				hex.plotType = plotOcean
			else
				if hex.mountainRange then
					hex.plotType = plotMountain
					tInsert(self.mountainHexes, hex)
				end
			end
		end
	end
	self:AdjustMountains()
end

function Space:ComputeSeas()
	-- ocean plots and tiny islands:
	for pi, hex in pairs(self.hexes) do
		if hex.polygon.continent == nil then
			if hex.subPolygon.tinyIsland then
				hex.plotType = plotLand
			else
				hex.plotType = plotOcean
			end
		end
	end
end

function Space:ComputeCoasts()
	for i, subPolygon in pairs(self.subPolygons) do
		if (not subPolygon.superPolygon.continent or subPolygon.lake) and not subPolygon.tinyIsland then
			if subPolygon.superPolygon.coastal then
				subPolygon.coast = true
				subPolygon.oceanTemperature = subPolygon.temperature
			else
				local coastTempTotal = 0
				local coastTotal = 0
				for ni, neighbor in pairs(subPolygon.neighbors) do
					if neighbor.superPolygon.continent or neighbor.tinyIsland then
						subPolygon.coast = true
						if subPolygon.polar then break end
						coastTempTotal = coastTempTotal + neighbor.temperature
						coastTotal = coastTotal + 1
					end
				end
				if coastTotal > 0 then
					-- coastTotal = coastTotal + 1
					-- coastTempTotal = coastTempTotal + self:GetOceanTemperature(subPolygon.latitude)
					subPolygon.oceanTemperature = mCeil(coastTempTotal / coastTotal)
				end
			end
			if subPolygon.polar then
				subPolygon.oceanTemperature = -5 -- self:GetOceanTemperature(90)
			elseif subPolygon.superPolygon.coast and not subPolygon.coast then
				subPolygon.oceanTemperature = mFloor((subPolygon.superPolygon.oceanTemperature + self:GetOceanTemperature(subPolygon.latitude)) / 2)
			end
			subPolygon.oceanTemperature = subPolygon.oceanTemperature or subPolygon.temperature or self:GetOceanTemperature(subPolygon.latitude)
			local ice
			if subPolygon.lake then
				ice = subPolygon.oceanTemperature <= self.freshFreezingTemperature
			else
				ice = subPolygon.oceanTemperature <= self.freezingTemperature
			end
			if subPolygon.coast then
				local atoll = subPolygon.oceanTemperature >= self.atollTemperature
				for hi, hex in pairs(subPolygon.hexes) do
					local bad = false
					if self.centauri and hex.y ~= 0 and hex.y ~= self.h then
						for d, nhex in pairs(hex:Neighbors()) do
							if nhex.polygon.continent then
								bad = true
								break
							end
						end
					end
					if not bad and ice and self:GimmeIce(subPolygon.oceanTemperature) then
						hex.featureType = featureIce
					elseif atoll and mRandom(1, 100) < self.atollPercent then
						hex.featureType = featureAtoll
					end
					hex.terrainType = terrainCoast
				end
			else
				for hi, hex in pairs(subPolygon.hexes) do
					if ice and self:GimmeIce(subPolygon.oceanTemperature) then
						hex.featureType = featureIce
					end
					hex.terrainType = terrainOcean
				end
			end
		end
	end
	-- fill in gaps in the ice
	for i, subPolygon in pairs(self.subPolygons) do
		if (not subPolygon.superPolygon.continent or subPolygon.lake) and not subPolygon.tinyIsland then
			for hi, hex in pairs(subPolygon.hexes) do
				if hex.featureType ~= featureIce then
					local surrounded = true
					for d, nhex in pairs(hex:Neighbors()) do
						if nhex.featureType ~= featureIce then
							surrounded = false
							break
						end
					end
					if not surrounded then
						local picked = {}
						local notPicked = {}
						local chex = hex
						for n = 1, 24 do
							picked[chex] = true
							local newHex
							for d, nhex in pairs(chex:Neighbors()) do
								if nhex.plotType ~= plotOcean then
									newHex = true
									break
								elseif nhex.featureType ~= featureIce and not picked[nhex] then
									if newHex then
										tInsert(notPicked, nhex)
									else
										newHex = nhex
									end
								end
							end
							if newHex == true then
								break -- found land
							elseif not newHex then
								if #notPicked > 0 then
									continue = true
									repeat
										newHex = tRemove(notPicked)
									until not picked[newHex] or #notPicked == 0
									if picked[newHex] then newHex = nil end
								end
								if not newHex then
									for chex, yes in pairs(picked) do
										chex.featureType = featureIce
									end
									break
								end
							end
							chex = newHex
						end
					end
					if surrounded then hex.featureType = featureIce end
				end
			end
		end
	end
end

function Space:ComputeOceanTemperatures()
	self.avgOceanLat = 0
	local totalLats = 0
	for p, polygon in pairs(self.polygons) do
		if polygon.continent == nil then
			totalLats = totalLats + 1
			self.avgOceanLat = self.avgOceanLat + polygon.latitude
		end
	end
	self.avgOceanLat = mFloor(self.avgOceanLat / totalLats)
	self.avgOceanTemp = self:GetTemperature(self.avgOceanLat)
	EchoDebug(self.avgOceanLat .. " is average ocean latitude with temperature of " .. self.avgOceanTemp, " temperature at equator: " .. self:GetTemperature(0))
	self.avgOceanTemp = (self.avgOceanTemp * 0.5) + (self:GetTemperature(0) * 0.5)
	-- self.avgOceanTemp = mMax(self.avgOceanTemp, self.freezingTemperature + 5)
	EchoDebug(" adjusted avg ocean temp: " .. self.avgOceanTemp)
	for p, polygon in pairs(self.polygons) do
		if polygon.continent == nil then
			local coastTempTotal = 0
			local coastTotal = 0
			local coastalContinents = {}
			polygon.coastContinentsTotal = 0
			polygon.waterTotal = 0
			for ni, neighbor in pairs(polygon.neighbors) do
				if neighbor.continent then
					polygon.coast = true
					coastTempTotal = coastTempTotal + neighbor.region.temperatureAvg
					coastTotal = coastTotal + 1
					if not coastalContinents[neighbor.continent] then
						coastalContinents[neighbor.continent] = true
						polygon.coastContinentsTotal = polygon.coastContinentsTotal + 1
					end
				else
					polygon.waterTotal = polygon.waterTotal + 1
				end
			end
			if coastTotal > 0 then
				polygon.oceanTemperature = mCeil(coastTempTotal / coastTotal)
			end
			polygon.coastTotal = coastTotal
			polygon.oceanTemperature = polygon.oceanTemperature or self:GetOceanTemperature(polygon.latitude)
		end
	end 
end

function Space:GetOceanTemperature(latitude)
	local temperature = (self:GetTemperature(latitude) * 0.5) + (self.avgOceanTemp * 0.5)
	return temperature
end

function Space:GimmeIce(temperature)
	local below = self.freezingTemperature - temperature
	if below < 0 then return false end
	return mRandom(1, 100) < 100 * (below / self.freezingTemperature)
end

function Space:MoveSilverAndSpices()
	local totalSpices = 0
	local totalSilver = 0
	for i, hex in pairs(self.hexes) do
		local resource = hex.plot:GetResourceType()
		if resource == resourceSilver or resource == resourceSpices then
			-- EchoDebug(resource, " found")
			-- this plot has silver and spices, i.e. minerals and kelp
			-- look for a nearby water plot
			local destHex
			-- look in hex neighbors
			for d, nhex in pairs(hex:Neighbors()) do
				if nhex.plotType == plotOcean and nhex.featureType ~= featureIce and nhex.featureType ~= featureAtoll and nhex.terrainType == terrainCoast then
					destHex = nhex
					break
				end
			end
			if not destHex then
				-- look in subpolygon neighbors
				for isp, subPolygon in pairs(hex.subPolygon.neighbors) do
					if (not subPolygon.superPolygon.continent and not subPolygon.tinyIsland) or subPolygon.lake then
						destHex = subPolygon:EmptyCoastHex()
						if destHex then break end
					end
				end
			end
			if not destHex then
				-- look in polygon neighbors
				for ip, polygon in pairs(hex.polygon.neighbors) do
					if not polygon.continent or polygon.hasLakes then
						for isp, subPolygon in pairs(polygon.subPolygons) do
							if (not polygon.continent and not subPolygon.tinyIsland) or (polygon.hasLakes and subPolygon.lake) then
								destHex = subPolygon:EmptyCoastHex()
						if destHex then break end
							end
						end
						break
					end
				end
			end
			-- move resource
			hex.plot:SetResourceType(-1)
			if destHex then
				-- EchoDebug("found spot for " .. resource)
				destHex.plot:SetResourceType(resource)
				if resource == resourceSilver then
					totalSilver = totalSilver + 1
				elseif resource == resourceSpices then
					totalSpices = totalSpices + 1
				end
			else
				-- EchoDebug("no spot found for " .. resource)
			end
		end
	end
	-- add more if not enough
	EchoDebug("silver: " .. totalSilver .. "/" .. self.silverCount, " spices: " .. totalSpices .. "/" .. self.spicesCount)
	if totalSilver < self.silverCount or totalSpices < self.spicesCount then
		local subPolygonBuffer = {}
		for i, polygon in pairs(self.polygons) do
			if not polygon.continent or polygon.hasLakes then
				for isp, subPolygon in pairs(polygon.subPolygons) do
					if (not polygon.continent and not subPolygon.tinyIsland) or (polygon.hasLakes and subPolygon.lake) then
						tInsert(subPolygonBuffer, subPolygon)
					end
				end
			end
		end
		repeat
			local subPolygon = tRemoveRandom(subPolygonBuffer)
			local destHex = subPolygon:EmptyCoastHex()
			if destHex then
				local silverSpices = mRandom(1, 2)
				local resource
				if (silverSpices == 1 and totalSilver < self.silverCount) or totalSpices >= self.spicesCount then
					resource = resourceSilver
					totalSilver = totalSilver + 1
				else
					resource = resourceSpices
					totalSpices = totalSpices + 1
				end
				destHex.plot:SetResourceType(resource)
			end
		until (totalSilver >= self.silverCount and totalSpices >= self.spicesCount) or #subPolygonBuffer == 0
	end
	EchoDebug("silver: " .. totalSilver .. "/" .. self.silverCount, " spices: " .. totalSpices .. "/" .. self.spicesCount)
end

function Space:RemoveBadNaturalWonders()
	local labelledTypes = {}
	for i, hex in pairs(self.hexes) do
		local featureType = hex.plot:GetFeatureType()
		if self.badNaturalWonders[featureType] then
			hex.plot:SetFeatureType(featureNone)
			EchoDebug("removed natural wonder feature ", self.badNaturalWonders[featureType])
		elseif self.centauriNaturalWonders[featureType] and not labelledTypes[featureType] then -- it's a centauri wonder
			if self.mapLabelsEnabled then
				EchoDebug("adding label", self.centauriNaturalWonders[featureType])
				DatabaseInsert("Fantastical_Map_Labels", {x = hex.x, y = hex.y, Type = "Map", Label = self.centauriNaturalWonders[featureType]})
				labelledTypes[featureType] = true
			end
		end
	end
end

function Space:SetPlots()
	for i, hex in pairs(self.hexes) do
		hex:SetPlot()
	end
end

function Space:SetTerrains()
	for i, hex in pairs(self.hexes) do
		hex:SetTerrain()
	end
end

function Space:SetFeatures()
	for i, hex in pairs(self.hexes) do
		hex:SetFeature()
	end
end

function Space:SetRivers()
	for i, hex in pairs(self.hexes)do
		hex:SetRiver()
	end
end

function Space:SetRoads()
	CreateOrOverwriteTable("Ancient_Roads", "x integer DEFAULT 0, y integer DEFAULT 0")
	for i, hex in pairs(self.hexes) do
		hex:SetRoad()
	end
end

function Space:SetContinentArtTypes()
	for i, hex in pairs(self.hexes) do
		hex:SetContinentArtType()
	end
end

    ----------------------------------
    -- INTERNAL METAFUNCTIONS: --

function Space:InitPolygons()
	for i = 1, self.subPolygonCount do
		local subPolygon = Polygon(self)
		tInsert(self.subPolygons, subPolygon)
	end
	for i = 1, self.polygonCount do
		local polygon = Polygon(self)
		tInsert(self.polygons, polygon)
	end
end


function Space:FillSubPolygons(relax)
	for x = 0, self.w do
		for y = 0, self.h do
			local hex = Hex(self, x, y, self:GetIndex(x, y))
			hex:Place(relax)
		end
		local percent = mFloor((x / self.w) * 100)
		if percent % 10 == 0 and percent > 0 then EchoDebug(percent .. "%") end
	end
end

function Space:FillPolygons()
	for i, subPolygon in pairs(self.subPolygons) do
		subPolygon:Place()
	end
end

function Space:RelaxPolygons(polygons)
	for i, polygon in pairs(polygons) do
		polygon:RelaxToCentroid()
	end
end

function Space:FillPolygonHexes()
	for i, polygon in pairs(self.polygons) do
		polygon:FillHexes()
	end
end

function Space:CullPolygons(polygons)
	culled = 0
	for i = #polygons, 1, -1 do -- have to go backwards, otherwise table.remove screws up the iteration
		local polygon = polygons[i]
		if #polygon.hexes == 0 then
			tRemove(polygons, i)
			culled = culled + 1
		end
	end
	EchoDebug(culled .. " polygons culled", #polygons .. " remaining")
end

function Space:FindSubPolygonNeighbors()
	for i, hex in pairs(self.hexes) do
		hex:FindSubPolygonNeighbors()
	end
end

function Space:FlipFlopSubPolygons()
	for i, subPolygon in pairs(self.subPolygons) do
		-- see if it's next to another superpolygon
		local adjacent = {}
		for n, neighbor in pairs(subPolygon.neighbors) do
			if neighbor.superPolygon ~= subPolygon.superPolygon then
				adjacent[neighbor.superPolygon] = true
			end
		end
		local choices = {}
		for superPolygon, yes in pairs(adjacent) do
			tInsert(choices, superPolygon)
		end
		if #choices > 0 and not subPolygon.flopped and mRandom(1, 100) < self.subPolygonFlopPercent then
			-- flop the subpolygon
			local superPolygon = tGetRandom(choices)
			for h, hex in pairs(subPolygon.hexes) do
				hex.polygon = superPolygon
			end
			subPolygon.superPolygon = superPolygon
			subPolygon.flopped = true
		end
	end
	-- fix stranded single subpolygons
	for i, subPolygon in pairs(self.subPolygons) do
		local hasFriendlyNeighbors = false
		local unfriendly = {}
		for n, neighbor in pairs(subPolygon.neighbors) do
			if neighbor.superPolygon == subPolygon.superPolygon then
				hasFriendlyNeighbors = true
				break
			else
				unfriendly[neighbor.superPolygon] = true
			end
		end
		if not hasFriendlyNeighbors then
			local uchoices = {}
			for superPolygon, yes in pairs(unfriendly) do
				tInsert(uchoices, superPolygon)
			end
			subPolygon.superPolygon = tGetRandom(uchoices)
			for h, hex in pairs(subPolygon.hexes) do
				hex.polygon = subPolygon.superPolygon
			end
			subPolygon.flopped = true
		end
	end
end

function Space:GetSubPolygonSizes()
	self.subPolygonMinArea = self.iA
	self.subPolygonMaxArea = 0
	for i, polygon in pairs(self.subPolygons) do
		if #polygon.hexes < self.subPolygonMinArea and #polygon.hexes > 0 then
			self.subPolygonMinArea = #polygon.hexes
		end
		if #polygon.hexes > self.subPolygonMaxArea then
			self.subPolygonMaxArea = #polygon.hexes
		end
	end
end

function Space:GetPolygonSizes()
	self.polygonMinArea = self.iA
	self.polygonMaxArea = 0
	for i, polygon in pairs(self.polygons) do
		if #polygon.hexes < self.polygonMinArea and #polygon.hexes > 0 then
			self.polygonMinArea = #polygon.hexes
		end
		if #polygon.hexes > self.polygonMaxArea then
			self.polygonMaxArea = #polygon.hexes
		end
	end
end

function Space:FindPolygonNeighbors()
	for spi, subPolygon in pairs(self.subPolygons) do
		subPolygon:FindPolygonNeighbors()
	end
end

function Space:AssembleSubEdges()
	for i, subEdge in pairs(self.subEdges) do
		subEdge:Assemble()
	end
end

function Space:FindSubEdgeConnections()
	for i, subEdge in pairs(self.subEdges) do
		subEdge:FindConnections()
	end
end

function Space:AssembleEdges()
	for i, edge in pairs(self.edges) do
		edge:DetermineOrder()
	end
	for i, edge in pairs(self.edges) do
		edge:FindConnections()
	end
end

function Space:PickOceans()
	if self.wrapX and self.wrapY then
		self:PickOceansDoughnut()
	elseif not self.wrapX and not self.wrapY then
		self:PickOceansRectangle()
	elseif self.wrapX and not self.wrapY then
		self:PickOceansCylinder()
	elseif self.wrapY and not self.wrapX then
		print("why have a vertically wrapped map?")
	end
	EchoDebug(#self.oceans .. " oceans", self.nonOceanPolygons .. " non-ocean polygons", self.nonOceanArea .. " non-ocean hexes")
end

function Space:PickOceansCylinder()
	local div = self.w / self.oceanNumber
	local x = 0
	-- if self.oceanNumber == 1 then x = 0 else x = mRandom(0, self.w) end
	for oceanIndex = 1, self.oceanNumber do
		local hex = self.hexes[self:GetIndex(x, 0)]
		local polygon = hex.polygon
		local ocean = {}
		local iterations = 0
		local chosen = {}
		while self.nonOceanPolygons > self.minNonOceanPolygons do
			chosen[polygon] = true
			polygon.oceanIndex = oceanIndex
			tInsert(ocean, polygon)
			self.nonOceanArea = self.nonOceanArea - #polygon.hexes
			self.nonOceanPolygons = self.nonOceanPolygons - 1
			if polygon.topY then
					EchoDebug("topY found, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
					break
			end
			local upNeighbors = {}
			local downNeighbors = {}
			for ni, neighbor in pairs(polygon.neighbors) do
				if not neighbor:NearOther(oceanIndex, "oceanIndex") then
					if not chosen[neighbor] then
						if neighbor.maxY > polygon.maxY then
							tInsert(upNeighbors, neighbor)
						else
							tInsert(downNeighbors, neighbor)
						end
					end
				end
			end
			if #upNeighbors == 0 then
				if #downNeighbors == 0 then
					if #polygon.neighbors == 0 then
						EchoDebug("no neighbors!, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
						break
					else
						upNeighbors = polygon.neighbors
					end
				else
					upNeighbors = downNeighbors
				end
			end
			local highestY = 0
			local highestNeigh
			for ni, neighbor in pairs(upNeighbors) do
				if neighbor.y > highestY then
					highestY = neighbor.y
					highestNeigh = neighbor
				end
			end
			polygon = highestNeigh or tGetRandom(upNeighbors)
			iterations = iterations + 1
		end
		tInsert(self.oceans, ocean)
		x = mCeil(x + div) % self.w
	end
end

function Space:PickOceansRectangle()
	local sides = {
		{ {0,0}, {0,1} },
		{ {0,1}, {1,1} },
		{ {1,0}, {1,1} },
		{ {0,0}, {1,0} },
	}
	self.oceanSides = {}
	for oceanIndex = 1, self.oceanNumber do
		local side = tRemoveRandom(sides)
		EchoDebug("side: ", side[1][1], side[1][2], side[2][1], side[2][2])
		local x, y = side[1][1] * self.w, side[1][2] * self.h
		local xUp = side[2][1] - x == 1
		local yUp = side[2][2] - y == 1
		local xMinimize, yMinimize, xMaximize, yMaximize
		local bottomTopCriterion
		if xUp then
			if side[1][2] == 0 then
				bottomTopCriterion = "bottomYPolygons"
				self.oceanSides["bottomY"] = true
			elseif side[1][2] == 1 then
				bottomTopCriterion = "topYPolygons"
				self.oceanSides["topY"] = true
			end
		elseif yUp then
			if side[1][1] == 0 then
				bottomTopCriterion = "bottomXPolygons"
				self.oceanSides["bottomX"] = true
			elseif side[1][1] == 1 then
				bottomTopCriterion = "topXPolygons"
				self.oceanSides["topX"] = true
			end
		end
		local ocean = {}
		for i, polygon in pairs(self[bottomTopCriterion]) do
			if not polygon.oceanIndex then
				polygon.oceanIndex = oceanIndex
				tInsert(ocean, polygon)
				self.nonOceanArea = self.nonOceanArea - #polygon.hexes
				self.nonOceanPolygons = self.nonOceanPolygons - 1
			end
		end
		tInsert(self.oceans, ocean)
	end
end

function Space:PickOceansDoughnut()
	self.wrapX, self.wrapY = false, false
	local formulas = {
		[1] = { {1,2} },
		[2] = { {3}, {4} },
		[3] = { {-1}, {1,7,8}, {2,9,10} }, -- negative 1 denotes each subtable is a possibility of a list instead of a list of possibilities
		[4] = { {1}, {2}, {5}, {6} },
	}
	local hexAngles = {}
	local hex = self:GetHexByXY(mFloor(self.w / 2), mFloor(self.h / 2))
	for n, nhex in pairs(hex:Neighbors()) do
		local angle = AngleAtoB(hex.x, hex.y, nhex.x, nhex.y)
		EchoDebug(n, nhex.x-hex.x, nhex.y-hex.y, angle)
		hexAngles[n] = angle
	end
	local origins, terminals = self:InterpretFormula(formulas[self.oceanNumber])
	for oceanIndex = 1, #origins do
		local ocean = {}
		local origin, terminal = origins[oceanIndex], terminals[oceanIndex]
		local hex = self:GetHexByXY(origin.x, origin.y)
		local polygon = hex.polygon
		if not polygon.oceanIndex then
			polygon.oceanIndex = oceanIndex
			tInsert(ocean, polygon)
			self.nonOceanArea = self.nonOceanArea - #polygon.hexes
			self.nonOceanPolygons = self.nonOceanPolygons - 1
		end
		local iterations = 0
		EchoDebug(origin.x, origin.y, terminal.x, terminal.y)
		local mx = terminal.x - origin.x
		local my = terminal.y - origin.y
		local dx, dy
		if mx == 0 then
			dx = 0
			if my < 0 then dy = -1 else dy = 1 end
		elseif my == 0 then
			dy = 0
			if mx < 0 then dx = -1 else dx = 1 end
		else
			if mx < 0 then dx = -1 else dx = 1 end
			dy = my / mAbs(mx)
		end
		local x, y = origin.x, origin.y
		repeat
			-- find the next polygon if it's different
			x = x + dx
			y = y + dy
			local best = polygon
			local bestDist = self:EucDistance(x, y, polygon.x, polygon.y)
			for n, neighbor in pairs(polygon.neighbors) do
				local dist = self:EucDistance(x, y, neighbor.x, neighbor.y)
				if dist < bestDist then
					bestDist = dist
					best = neighbor
				end
			end
			polygon = best
			-- add the polygon here to the ocean
			if not polygon.oceanIndex then
				polygon.oceanIndex = oceanIndex
				tInsert(ocean, polygon)
				self.nonOceanArea = self.nonOceanArea - #polygon.hexes
				self.nonOceanPolygons = self.nonOceanPolygons - 1
			end
			iterations = iterations + 1
		until mFloor(x) == terminal.x and mFloor(y) == terminal.y
		tInsert(self.oceans, ocean)
	end
	self.wrapX, self.wrapY = true, true
end

local OceanLines = {
		[1] = { {0,0}, {0,1} }, -- straight sides
		[2] = { {0,0}, {1,0} },
		[3] = { {0,0}, {1,1} }, -- diagonals
		[4] = { {1,0}, {0,1} },
		[5] = { {0.5,0}, {0.5,1} }, -- middle cross
		[6] = { {0,0.5}, {1,0.5} },
		[7] = { {0.33,0}, {0.33,1} }, -- vertical thirds
		[8] = { {0.67,0}, {0.67,1} },
		[9] = { {0,0.33}, {1,0.33} }, -- horizontal thirds
		[10] = { {0,0.67}, {1,0.67} },
	}

function Space:InterpretFormula(formula)
	local origins = {}
	local terminals = {}
	if formula[1][1] == -1 then
		local list = formula[mRandom(2, #formula)]
		for l, lineCode in pairs(list) do
			local line = OceanLines[lineCode]
			tInsert(origins, self:InterpretPosition(line[1]))
			tInsert(terminals, self:InterpretPosition(line[2]))
		end
	else
		for i, part in pairs(formula) do
			local line = OceanLines[tGetRandom(part)]
			tInsert(origins, self:InterpretPosition(line[1]))
			tInsert(terminals, self:InterpretPosition(line[2]))
		end
	end
	return origins, terminals
end

function Space:InterpretPosition(position)
	return { x = mFloor(position[1] * self.w), y = mFloor(position[2] * self.h) }
end

function Space:FindAstronomyBasins()
	for i, polygon in pairs(self.polygons) do
		if polygon.oceanIndex == nil then
			for ni, neighbor in pairs(polygon.neighbors) do
				if neighbor.oceanIndex then
					polygon.nearOcean = neighbor.oceanIndex
					break
				end
			end
		end
	end
	local astronomyIndex = 1
	self.astronomyBasins = {}
	for i, polygon in pairs(self.polygons) do
		if polygon:FloodFillAstronomy(astronomyIndex) then
			astronomyIndex = astronomyIndex + 1
			EchoDebug("astronomy basin #" .. astronomyIndex-1 .. " has " .. #self.astronomyBasins[astronomyIndex-1] .. " polygons")
		end
	end
	for i, polygon in pairs(self.polygons) do
		for si, subPolygon in pairs(polygon.subPolygons) do
			subPolygon.astronomyIndex = polygon.astronomyIndex
		end
	end
	self.totalAstronomyBasins = astronomyIndex - 1
	EchoDebug(self.totalAstronomyBasins .. " astronomy basins")
end

function Space:PickContinents()
	self.filledArea = 0
	self.filledPolygons = 0
	for astronomyIndex, basin in pairs(self.astronomyBasins) do
		EchoDebug("picking for astronomy basin #" .. astronomyIndex .. ": " .. #basin .. " polygons...")
		self:PickContinentsInBasin(astronomyIndex)
	end
end

function Space:PickContinentsInBasin(astronomyIndex)
	local polygonBuffer = {}
	for i, polygon in pairs(self.astronomyBasins[astronomyIndex]) do
		tInsert(polygonBuffer, polygon)
	end
	local maxPolarPolygons = #polygonBuffer * self.polarMaxLandRatio
	EchoDebug(maxPolarPolygons .. " maximum polar polygons of " .. #polygonBuffer .. " in astronomy basin")
	local polarPolygonCount = 0
	local islandPolygons = mCeil(#polygonBuffer * self.islandRatio)
	local nonIslandPolygons = mMax(1, #polygonBuffer - islandPolygons)
	local filledPolygons = 0
	local continentIndex = 1
	if self.oceanSides then
		self.nonOceanSides = {}
		if not self.oceanSides["bottomX"] then tInsert(self.nonOceanSides, "bottomX") end
		if not self.oceanSides["topX"] then tInsert(self.nonOceanSides, "topX") end
		if not self.oceanSides["bottomY"] then tInsert(self.nonOceanSides, "bottomY") end
		if not self.oceanSides["topY"] then tInsert(self.nonOceanSides, "topY") end
	end
	while #polygonBuffer > 0 do
		-- determine theoretical continent size
		local size = mCeil(nonIslandPolygons / self.majorContinentNumber)
		if filledPolygons >= nonIslandPolygons then size = mRandom(1, 3) end
		-- pick a polygon to start the continent
		local polygon
		repeat
			polygon = tRemoveRandom(polygonBuffer)
			if polygon.continent == nil and not polygon:NearOther(nil, "continent") then
				local nearPole = polygon:NearOther(nil, "topY") or polygon:NearOther(nil, "bottomY")
				if (self.wrapY or (not polygon.topY and not polygon.bottomY)) and (self.wrapX or (not polygon.topX and not polygon.bottomX)) and (not nearPole or not self.noContinentsNearPoles) then
					break
				elseif (not self.wrapX and not self.wrapY) then
					local goodSide = false
					local sides = 0
					for nosi, side in pairs(self.nonOceanSides) do
						if polygon[side] then
							goodSide = true
							break
						end
						sides = sides + 1
					end
					if goodSide or sides == 0 then break else polygon = nil end
				else
					polygon = nil
				end
			else
				polygon = nil
			end
		until #polygonBuffer == 0
		if polygon == nil then break end
		local backlog = {}
		local polarBacklog = {}
		self.filledArea = self.filledArea + #polygon.hexes
		filledPolygons = filledPolygons + 1
		local filledContinentArea = #polygon.hexes
		local continent = { polygon }
		polygon.continent = continent
		repeat
			local candidates = {}
			local polarCandidates = {}
			for ni, neighbor in pairs(polygon.neighbors) do
				if neighbor.continent == nil and not neighbor:NearOther(continent, "continent") and neighbor.astronomyIndex < 100 then
					local nearPole = neighbor:NearOther(nil, "topY") or neighbor:NearOther(nil, "bottomY")
					if self.wrapX and not self.wrapY and (neighbor.topY or neighbor.bottomY or (self.noContinentsNearPoles and nearPole)) then
						tInsert(polarCandidates, neighbor)
					else
						tInsert(candidates, neighbor)
					end
				end
			end
			local candidate
			if #candidates == 0 then
				if #polarCandidates > 0 and polarPolygonCount < maxPolarPolygons then
					candidate = tRemoveRandom(polarCandidates) -- use a polar polygon
					polarPolygonCount = polarPolygonCount + 1
				else
					-- when there are no immediate candidates
					if #backlog > 0 then
						repeat
							candidate = tRemove(backlog, #backlog) -- pop off the most recent
							if candidate.continent ~= nil then candidate = nil end
						until candidate ~= nil or #backlog == 0
					elseif #polarBacklog > 0 then
						repeat
							candidate = tRemove(polarBacklog, #polarBacklog) -- pop off the most recent polar
							if candidate.continent ~= nil then candidate = nil end
						until candidate ~= nil or #polarBacklog == 0
					else
						break -- nothing left to do but stop
					end
				end
			else
				candidate = tRemoveRandom(candidates)
			end
			if candidate == nil then break end
			-- put the rest of the candidates in the backlog
			for nothing, polygon in pairs(candidates) do
				tInsert(backlog, polygon)
			end
			for nothing, polygon in pairs(polarCandidates) do
				tInsert(polarBacklog, polygon)
			end
			candidate.continent = continent
			self.filledArea = self.filledArea + #candidate.hexes
			filledContinentArea = filledContinentArea + #candidate.hexes
			filledPolygons = filledPolygons + 1
			tInsert(continent, candidate)
			polygon = candidate
		until #backlog == 0 or #continent >= size
		EchoDebug(size, #continent, filledContinentArea)
		tInsert(self.continents, continent)
		continentIndex = continentIndex + 1
	end
	self.filledPolygons = self.filledPolygons + filledPolygons
end

function Space:PickMountainRanges()
	local edgeBuffer = {}
	for i, edge in pairs(self.edges) do
		tInsert(edgeBuffer, edge)
	end
	local mountainRangeRatio = self.mountainRatio * self.mountainRangeMult
	local prescribedEdges = mountainRangeRatio * #self.edges
	local coastPrescription = mFloor(prescribedEdges * self.coastRangeRatio)
	local interiorPrescription = prescribedEdges - coastPrescription
	EchoDebug("prescribed mountain range edges: " .. prescribedEdges .. " of " .. #self.edges)
	local edgeCount = 0
	local coastCount = 0
	local interiorCount = 0
	while #edgeBuffer > 0 and edgeCount < prescribedEdges do
		local edge
		local coastRange
		repeat
			edge = tRemoveRandom(edgeBuffer)
			if (edge.polygons[1].continent or edge.polygons[2].continent) and not edge.mountains then
				if edge.polygons[1].continent and edge.polygons[2].continent  and edge.polygons[1].region ~= edge.polygons[2].region and interiorCount < interiorPrescription then
					coastRange = false
					break
				elseif coastCount < coastPrescription then
					coastRange = true
					break
				end
			else
				edge = nil
			end
		until #edgeBuffer == 0
		if edge == nil then break end
		edge.mountains = true
		local range = { edge }
		edgeCount = edgeCount + 1
		if coastRange then coastCount = coastCount + 1 else interiorCount = interiorCount + 1 end
		repeat
			local nextEdges = {}
			for nextEdge, yes in pairs(edge.connections) do
				local okay = false
				if (nextEdge.polygons[1].continent or nextEdge.polygons[2].continent) and not nextEdge.mountains then
					if coastRange and (not nextEdge.polygons[1].continent or not nextEdge.polygons[2].continent) then
						okay = true
					elseif not coastRange and nextEdge.polygons[1].continent and nextEdge.polygons[2].continent and nextEdge.polygons[1].region ~= nextEdge.polygons[2].region then
						okay = true
					end
				end
				if okay then
					for cedge, yes in pairs(nextEdge.connections) do
						if cedge.mountains and cedge ~= nextEdge then okay = false end
					end
				end
				if okay then
					tInsert(nextEdges, nextEdge)
				end
			end
			if #nextEdges == 0 then break end
			local nextEdge = tGetRandom(nextEdges)
			nextEdge.mountains = true
			tInsert(range, nextEdge)
			edgeCount = edgeCount + 1
			if coastRange then coastCount = coastCount + 1 else interiorCount = interiorCount + 1 end
			edge = nextEdge
		until #nextEdges == 0 or #range >= self.mountainRangeMaxEdges or coastCount > coastPrescription or interiorCount > interiorPrescription
		-- EchoDebug("new range", #range, tostring(coastRange))
		for ire, redge in pairs(range) do
			for ise, subEdge in pairs(redge.subEdges) do
				for ih, hex in pairs(subEdge.hexes) do
					if hex.plotType ~= plotOcean then
						hex.mountainRangeCore = true
						hex.mountainRange = true
						tInsert(self.mountainCoreHexes, hex)
					end
				end
				for isp, subPolygon in pairs(subEdge.polygons) do
					if not subPolygon.lake then
						subPolygon.mountainRange = true
						for hi, hex in pairs(subPolygon.hexes) do
							if hex.plotType ~= plotOcean then hex.mountainRange = true end
						end
					end
				end
			end
		end
		tInsert(self.mountainRanges, range)
	end
	EchoDebug(interiorCount .. " interior ranges ", coastCount .. " coastal ranges")
end

function Space:PickRegions()
	for ci, continent in pairs(self.continents) do
		local polygonBuffer = {}
		for polyi, polygon in pairs(continent) do
			tInsert(polygonBuffer, polygon)
		end
		while #polygonBuffer > 0 do
			local size = mRandom(self.regionSizeMin, self.regionSizeMax)
			local polygon
			repeat
				polygon = tRemoveRandom(polygonBuffer)
				if polygon.region == nil then
					break
				else
					polygon = nil
				end
			until #polygonBuffer == 0
			local region
			if polygon ~= nil then
				local backlog = {}
				region = Region(self)
				polygon.region = region
				tInsert(region.polygons, polygon)
				region.area = region.area + #polygon.hexes
				repeat
					if #polygon.neighbors == 0 then break end
					local candidates = {}
					for ni, neighbor in pairs(polygon.neighbors) do
						if neighbor.continent == continent and neighbor.region == nil then
							tInsert(candidates, neighbor)
						end
					end
					local candidate
					if #candidates == 0 then
						if #backlog == 0 then
							break
						else
							repeat
								candidate = tRemoveRandom(backlog)
								if candidate.region ~= nil then candidate = nil end
							 until candidate ~= nil or #backlog == 0
						end
					else
						candidate = tRemoveRandom(candidates)
					end
					if candidate == nil then break end
					if candidate.region then EchoDebug("DUPLICATE REGION POLYGON") end
					candidate.region = region
					tInsert(region.polygons, candidate)
					region.area = region.area + #candidate.hexes
					polygon = candidate
					for candi, c in pairs(candidates) do
						tInsert(backlog, c)
					end
				until #region.polygons == size or region.area > self.polygonMaxArea / 2 or #region.polygons == #continent
			end
			tInsert(self.regions, region)
		end
	end
	for p, polygon in pairs(self.tinyIslandPolygons) do
		polygon.region = Region(self)
		tInsert(polygon.region.polygons, polygon)
		polygon.region.area = #polygon.hexes
		polygon.region.archipelago = true
		tInsert(self.regions, polygon.region)
	end
end

function Space:FillRegions()
	for i, region in pairs(self.regions) do
		region:CreateCollection()
		region:Fill()
	end
end


function Space:LabelMap()
	CreateOrOverwriteTable("Fantastical_Map_Labels", "X integer DEFAULT 0, Y integer DEFAULT 0, Type text DEFAULT null, Label text DEFAULT null, ID integer DEFAULT 0")
	if self.centauri then
		EchoDebug("giving centauri labels to subpolygons...")
		LabelSyntaxes, LabelDictionary, LabelDefinitions, SpecialLabelTypes = LabelSyntaxesCentauri, LabelDictionaryCentauri, LabelDefinitionsCentauri, SpecialLabelTypesCentauri
		local polygonBuffer = tDuplicate(self.polygons)
		repeat
			local polygon = tRemoveRandom(polygonBuffer)
			local subPolygonBuffer = tDuplicate(polygon.subPolygons)
			repeat
				local subPolygon = tRemoveRandom(subPolygonBuffer)
				if not subPolygon.superPolygon.continent and not subPolygon.tinyIsland then
					subPolygon.coastContinentsTotal = 0
					subPolygon.coastTotal = 0
					local coastalContinents = {}
					for ni, neighbor in pairs(subPolygon.neighbors) do
						if neighbor.superPolygon.continent then
							if not coastalContinents[neighbor.superPolygon.continent] then
								subPolygon.coastContinentsTotal = subPolygon.coastContinentsTotal + 1
								coastalContinents[neighbor.superPolygon.continent] = true
							end
							subPolygon.coastTotal = subPolygon.coastTotal + 1
						end
					end
				end
				if subPolygon.superPolygon.continent then
					subPolygon.continentSize = #subPolygon.superPolygon.continent
				end
				if LabelThing(subPolygon) then break end
			until #subPolygonBuffer == 0
		until #polygonBuffer == 0
		return
	end
	EchoDebug("generating names...")
	name_set, name_types = GetCityNames(self.totalAstronomyBasins)
	LabelDictionary.Name = {}
	for i, name_type in ipairs(name_types) do
		LabelDictionary.Name[name_type] = name_list(name_type, 100)
		LabelDefinitions[name_type] = { astronomyIndex = i }
	end
	EchoDebug("labelling oceans...")
	local astronomyIndexBuffer = {}
	for i = 1, self.totalAstronomyBasins do
		tInsert(astronomyIndexBuffer, i)
	end
	for i, ocean in pairs(self.oceans) do
		local index = mCeil(#ocean/2)
		local away = 1
		local sub = false
		local polygon = ocean[index]
		while polygon.hasTinyIslands do
			if sub then
				index = index - away
				away = away + 1
			else
				index = index + away
				away = away + 1
			end
			sub = not sub
			if index > #ocean or index < 1 then break end
			polygon = ocean[index]
			if not polygon.hasTinyIslands then break end
		end
		local astronomyIndex
		if #astronomyIndexBuffer == 0 then
			astronomyIndex = 1
		else
			astronomyIndex = tRemoveRandom(astronomyIndexBuffer)
		end
		local thing = { oceanSize = #ocean, x = polygon.x, y = polygon.y, astronomyIndex = astronomyIndex, hexes = {} }
		for p, polygon in pairs(ocean) do
			for h, hex in pairs(polygon.hexes) do
				tInsert(thing.hexes, hex)
			end
		end
		LabelThing(thing)
	end
	EchoDebug("labelling lakes...")
	for i, subPolygon in pairs(self.lakeSubPolygons) do
		LabelThing(subPolygon)
	end
	EchoDebug("labelling rivers...")
	local riversByLength = {}
	for i, river in pairs(self.rivers) do
		riversByLength[-river.riverLength] = river
	end
	local n = 0
	for negLength, river in pairsByKeys(riversByLength) do
		local hex = river.path[mCeil(#river.path/2)].hex
		river.hexes = {}
		for i, flow in pairs(river.path) do
			tInsert(river.hexes, flow.hex)
			tInsert(river.hexes, flow.pairHex)
		end
		river.x, river.y = hex.x, hex.y
		river.astronomyIndex = hex.polygon.astronomyIndex
		if LabelThing(river) then n = n + 1 end
		if n == self.riverLabelsMax then break end
	end
	EchoDebug("labelling regions...")
	local regionsLabelled = 0
	local regionBuffer = tDuplicate(self.regions)
	repeat
		local region = tRemoveRandom(regionBuffer)
		if region:Label() then regionsLabelled = regionsLabelled + 1 end
	until #regionBuffer == 0 or regionsLabelled >= self.regionLabelsMax
	EchoDebug("labelling tiny islands...")
	local tinyIslandBuffer = tDuplicate(self.tinyIslandSubPolygons)
	local tinyIslandsLabelled = 0
	repeat
		local subPolygon = tRemoveRandom(tinyIslandBuffer)
		if LabelThing(subPolygon) then tinyIslandsLabelled = tinyIslandsLabelled + 1 end
	until #tinyIslandBuffer == 0 or tinyIslandsLabelled >= self.tinyIslandLabelsMax
	EchoDebug("labelling mountain ranges...")
	local rangesByLength = {}
	for i, range in pairs(self.mountainRanges) do
		rangesByLength[-#range] = range
	end
	local rangesLabelled = 0
	for negLength, range in pairsByKeys(rangesByLength) do
		local temperatureAvg = 0
		local rainfallAvg = 0
		local tempCount = 0
		local rainCount = 0
		local x, y
		local hexes = {}
		for ie, edge in pairs(range) do
			for ip, polygon in pairs(edge.polygons) do
				if polygon.oceanTemperature then
					temperatureAvg = temperatureAvg + polygon.oceanTemperature
					tempCount = tempCount + 1
				end
			end
			for ise, subEdge in pairs(edge.subEdges) do
				for isp, subPolygon in pairs(subEdge.polygons) do
					if subPolygon.temperature then
						temperatureAvg = temperatureAvg + subPolygon.temperature
						tempCount = tempCount + 1
					end
					if subPolygon.rainfall then
						rainfallAvg = rainfallAvg + subPolygon.rainfall
						rainCount = rainCount + 1
					end
					for ih, hex in pairs(subPolygon.hexes) do
						if hex.plotType == plotMountain then
							tInsert(hexes, hex)
							if not x then x, y = hex.x, hex.y end
						end
					end
				end
			end
		end
		if x then
			temperatureAvg = temperatureAvg / tempCount
			rainfallAvg = rainfallAvg / rainCount
			-- EchoDebug("valid mountain range: ", #range, temperatureAvg, temperatureAvg)
			local thing = { rangeLength = #range, x = x, y = y, rainfallAvg = rainfallAvg, temperatureAvg = temperatureAvg, astronomyIndex = range[1].polygons[1].astronomyIndex, hexes = hexes }
			if LabelThing(thing) then rangesLabelled = rangesLabelled + 1 end
		end
		if rangesLabelled == self.rangeLabelsMax then break end
	end
end

function Space:FindRiverSeeds()
	self.lakeRiverSeeds = {}
	self.majorRiverSeeds = {}
	self.minorRiverSeeds = {}
	self.tinyRiverSeeds = {}
	local lakeCount = 0
	local rainSeedCount = 0
	for ih, hex in pairs(self.hexes) do
		if (hex.polygon.continent and not hex.subPolygon.lake) or hex.subPolygon.tinyIsland then
			local neighs, polygonNeighs, subPolygonNeighs, hexNeighs, oceanNeighs, lakeNeighs, mountainNeighs, dryNeighs = {}, {}, {}, {}, {}, {}, {}, {}
			for d, nhex in pairs(hex:Neighbors()) do
				if nhex.subPolygon.lake then
					lakeNeighs[nhex] = d
				elseif nhex.plotType == plotOcean then
					oceanNeighs[nhex] = d
				else
					dryNeighs[nhex] = d
					if nhex.polygon ~= hex.polygon then
						polygonNeighs[nhex] = d
					end
					if nhex.subPolygon ~= hex.subPolygon and nhex.polygon == hex.polygon then
						subPolygonNeighs[nhex] = d
					end
					if nhex.subPolygon == hex.subPolygon and nhex.polygon == hex.polygon then
						hexNeighs[nhex] = d
					end
					if nhex.plotType == plotMountain then
						mountainNeighs[nhex] = d
					end
				end
				neighs[nhex] = d
			end
			for nhex, d in pairs(dryNeighs) do
				for dd, nnhex in pairs(nhex:Neighbors()) do
					if lakeNeighs[nnhex] then
						if self.lakeRiverSeeds[nnhex.subPolygon] == nil then
							lakeCount = lakeCount + 1
							self.lakeRiverSeeds[nnhex.subPolygon] = {}
						end
						seed = { hex = hex, pairHex = nhex, direction = d, lastHex = nnhex, lastDirection = neighs[nnhex], lake = nnhex.subPolygon, dontConnect = true, avoidConnection = true, toWater = true, growsDownstream = true }
						tInsert(self.lakeRiverSeeds[nnhex.subPolygon], seed)
					end
				end
			end
			for nhex, d in pairs(polygonNeighs) do
				local rainfall = mMin(hex.polygon.region.rainfallAvg, nhex.polygon.region.rainfallAvg) -- mFloor((hex.polygon.region.rainfallAvg + nhex.polygon.region.rainfallAvg) / 2)
				local seed, connectsToOcean, connectsToLake
				for dd, nnhex in pairs(nhex:Neighbors()) do
					if neighs[nnhex] then
						local inTheHills = self:HillsOrMountains(hex, nhex, nnhex) >= 2
						if mountainNeighs[nnhex] or inTheHills then
							seed = { hex = hex, pairHex = nhex, direction = d, lastHex = nnhex, lastDirection = neighs[nnhex], rainfall = rainfall, major = true, dontConnect = true, avoidConnection = true, toWater = true, spawnSeeds = true, growsDownstream = true }
						end
						if oceanNeighs[nnhex] then
							connectsToOcean = true
						end
						if lakeNeighs[nnhex] then
							connectsToLake = true
						end
					end
				end
				if seed and not connectsToOcean and not connectsToLake then
					tInsert(self.majorRiverSeeds, seed)
				end
			end
			for nhex, d in pairs(subPolygonNeighs) do
				local oceanSeed, hillSeed, rainSeed, connectsToOcean, connectsToLake
				for dd, nnhex in pairs(nhex:Neighbors()) do
					local rainfall = mMin(hex.subPolygon.rainfall, nhex.subPolygon.rainfall, nnhex.subPolygon.rainfall or 100)
					if oceanNeighs[nnhex] then
						if not oceanSeed then
							oceanSeed = { hex = hex, pairHex = nhex, direction = d, lastHex = nnhex, lastDirection = oceanNeighs[nnhex], rainfall = rainfall, minor = true, dontConnect = true, avoidConnection = true, avoidWater = true, toHills = true, spawnSeeds = true }
						else
							oceanSeed = nil
						end
						connectsToOcean = true
					end
					if neighs[nnhex] then
						local inTheHills = self:HillsOrMountains(hex, nhex, nnhex) >= 2
						if mountainNeighs[nnhex] or inTheHills then
							hillSeed = { hex = hex, pairHex = nhex, direction = d, lastHex = nnhex, lastDirection = neighs[nnhex], rainfall = rainfall, minor = true, dontConnect = true, avoidConnection = true, toWater = true, spawnSeeds = true, growsDownstream = true }
						end
						if rainfall > self.riverSpawnRainfall then
							rainSeed = { hex = hex, pairHex = nhex, direction = d, lastHex = nnhex, lastDirection = neighs[nnhex], rainfall = rainfall, minor = true, dontConnect = true, avoidConnection = true, toWater = true, spawnSeeds = true, growsDownstream = true }
						end
					end
					if lakeNeighs[nnhex] then
						connectsToLake = true
					end
				end
				if oceanSeed then
					tInsert(self.minorRiverSeeds, oceanSeed)
				elseif hillSeed and not connectsToOcean and not connectsToLake then
					tInsert(self.minorRiverSeeds, hillSeed)
				elseif rainSeed and not connectsToOcean and not connectsToLake then
					tInsert(self.minorRiverSeeds, rainSeed)
					rainSeedCount = rainSeedCount + 1
				end
			end
			for nhex, d in pairs(hexNeighs) do
				local oceanSeed, hillSeed, rainSeed, connectsToOcean, connectsToLake
				for dd, nnhex in pairs(nhex:Neighbors()) do
					local rainfall = mMin(hex.rainfall, nhex.rainfall, nnhex.rainfall or 100)
					if oceanNeighs[nnhex] then
						if not oceanSeed then
							oceanSeed = { hex = hex, pairHex = nhex, direction = d, lastHex = nnhex, lastDirection = oceanNeighs[nnhex], rainfall = rainfall, tiny = true, dontConnect = true, avoidConnection = true, avoidWater = true, toHills = true, doneAnywhere = true }
						else
							oceanSeed = nil
						end
						connectsToOcean = true
					end
					if neighs[nnhex] then
						local inTheHills = self:HillsOrMountains(hex, nhex, nnhex) >= 2
						if mountainNeighs[nnhex] or inTheHills then
							hillSeed = { hex = hex, pairHex = nhex, direction = d, lastHex = nnhex, lastDirection = neighs[nnhex], rainfall = rainfall, tiny = true, dontConnect = true, avoidConnection = true, toWater = true, growsDownstream = true }
						end
						if rainfall > self.riverSpawnRainfall then
							rainSeed = { hex = hex, pairHex = nhex, direction = d, lastHex = nnhex, lastDirection = neighs[nnhex], rainfall = rainfall, tiny = true, dontConnect = true, avoidConnection = true, toWater = true, growsDownstream = true }
						end
					end
					if lakeNeighs[nnhex] then
						connectsToLake = true
					end
				end
				if oceanSeed then
					tInsert(self.tinyRiverSeeds, oceanSeed)
				elseif hillSeed and not connectsToOcean and not connectsToLake then
					tInsert(self.tinyRiverSeeds, hillSeed)
				elseif rainSeed and not connectsToOcean and not connectsToLake then
					tInsert(self.tinyRiverSeeds, rainSeed)
					rainSeedCount = rainSeedCount + 1
				end
			end
		end
	end
	EchoDebug(rainSeedCount .. " rain seeds") 
	EchoDebug(lakeCount .. " lakes ", #self.majorRiverSeeds .. " major ", #self.minorRiverSeeds .. " minor ", #self.tinyRiverSeeds .. " tiny")
end

function Space:HillsOrMountains(...)
	local hills = 0
	for i, hex in pairs({...}) do
		if hex.plotType == plotMountain or hex.plotType == plotHills then
			hills = hills + 1
		end
	end
	return hills
end

function Space:DrawRiver(seed)
	local hex = seed.hex
	local pairHex = seed.pairHex
	local direction = seed.direction or hex:GetDirectionTo(pairHex)
	local lastHex = seed.lastHex
	local lastDirection = seed.lastDirection or hex:GetDirectionTo(lastHex)
	if hex.plotType == plotOcean or pairHex.plotType == plotOcean then
		EchoDebug("river will seed next to water")
	end
	if hex.onRiver[pairHex] or pairHex.onRiver[hex] then
		-- EchoDebug("SEED ALREADY ON RIVER")
		return
	end
	if seed.dontConnect then
		if hex.onRiver[lastHex] or pairHex.onRiver[lastHex] or lastHex.onRiver[hex] or lastHex.onRiver[pairHex] then
			-- EchoDebug("SEED ALREADY CONNECTS TO RIVER")
			return
		end
	end
	local river = {}
	local onRiver = {}
	local seedSpawns = {}
	local done
	local it = 0
	repeat
		-- find next mutual neighbor
		local neighs = {}
		for d, nhex in pairs(hex:Neighbors()) do
			if nhex ~= pairHex then
				neighs[nhex] = d
			end
		end
		local newHex, newDirection, newDirectionPair
		for d, nhex in pairs(pairHex:Neighbors()) do
			if neighs[nhex] and nhex ~= lastHex then
				newHex = nhex
				newDirection = neighs[nhex]
				newDirectionPair = d
			end
		end
		-- check if the river needs to stop before it gets connected to the next mutual neighbor
		if newHex then
			local stop
			if seed.avoidConnection then
				if hex.onRiver[newHex] or pairHex.onRiver[newHex] or (onRiver[hex] and onRiver[hex][newHex]) or (onRiver[pairHex] and onRiver[pairHex][newHex]) then
					-- EchoDebug("WOULD CONNECT TO ANOTHER RIVER OR ITSELF")
					stop = true
				end
			end
			if seed.avoidWater then
				if newHex.plotType == plotOcean then
					-- EchoDebug("WOULD CONNECT TO WATER")
					stop = true
				end
			end
			if seed.lake then
				if newHex.subPolygon.lake and (newHex.subPolygon == seed.lake or self.lakeConnections[newHex.subPolygon]) then
					-- EchoDebug("WOULD CONNECT TO AN ALREADY CONNECTED LAKE OR ITS SOURCE LAKE")
					stop = true
				end
			end
			if stop then
				if it > 0 then
					seedSpawns[it-1] = {}
				end
				break
			end
		end
		if not newHex then break end
		-- connect the river
		local flowDirection = GetFlowDirection(direction, lastDirection)
		if seed.growsDownstream then flowDirection = GetFlowDirection(direction, newDirection) end
		if OfRiverDirection(direction) then
			tInsert(river, { hex = hex, pairHex = pairHex, direction = OppositeDirection(direction), flowDirection = flowDirection })
		else
			tInsert(river, { hex = pairHex, pairHex = hex, direction = direction, flowDirection = flowDirection })
		end
		if onRiver[hex] == nil then onRiver[hex] = {} end
		if onRiver[pairHex] == nil then onRiver[pairHex] = {} end
		onRiver[hex][pairHex] = flowDirection
		onRiver[pairHex][hex] = flowDirection
		-- check if river will finish here
		if seed.toWater then
			if newHex.plotType == plotOcean or seed.connectsToOcean then
				-- EchoDebug("iteration " .. it .. ": ", "FOUND WATER at " .. newHex.x .. ", " .. newHex.y, " from " .. seed.lastHex.x .. ", " .. seed.lastHex.y, seed.hex.x .. ", " .. seed.hex.y, " / ", seed.pairHex.x .. ", " .. seed.pairHex.y)
				done = newHex
				break
			end
		end
		if seed.toHills then
			if self:HillsOrMountains(newHex, hex, pairHex) >= 2 then
				-- EchoDebug("FOUND HILLS/MOUNTAINS")
				done = newHex
				break
			end
		end
		-- check for potential river forking points
		seedSpawns[it] = {}
		if seed.spawnSeeds then -- use this once it works
			local minor, tiny, toWater, toHills, avoidConnection, avoidWater, growsDownstream, dontConnect, doneAnywhere
			local spawnNew, spawnNewPair, spawnLast, spawnLastPair
			if seed.major then
				minor, toHills, avoidConnection, avoidWater = true, true, true, true
				if hex.polygon == newHex.polygon and hex.subPolygon ~= newHex.subPolygon then
					spawnNew = true
				end
				if pairHex.polygon == newHex.polygon and pairHex.subPolygon ~= newHex.subPolygon then
					spawnNewPair = true
				end
				if it > 0 then
					if hex.polygon == lastHex.polygon and hex.subPolygon ~= lastHex.subPolygon then
						spawnLast = true
					end
					if pairHex.polygon == lastHex.polygon and pairHex.subPolygon ~= lastHex.subPolygon then
						spawnLastPair = true
					end
				end
			elseif seed.minor then
				tiny, toHills, avoidConnection, avoidWater, doneAnywhere, alwaysDraw = true, true, true, true, true
				if hex.subPolygon == newHex.subPolygon then
					spawnNew = true
				end
				if pairHex.subPolygon == newHex.subPolygon then
					spawnNewPair = true
				end
				if it > 0 then
					if hex.subPolygon == lastHex.subPolygon then
						spawnLast = true
					end
					if pairHex.subPolygon == lastHex.subPolygon then
						spawnLastPair = true
					end
				end
			end
			if spawnNew then
				tInsert(seedSpawns[it], {hex = hex, pairHex = newHex, direction = newDirection, lastHex = pairHex, lastDirection = direction, rainfall = seed.rainfall, minor = minor, tiny = tiny, toWater = toWater, toHills = toHills, avoidConnection = avoidConnection, avoidWater = avoidWater, growsDownstream = growsDownstream, dontConnect = dontConnect, doneAnywhere = doneAnywhere, fork = true})
			end
			if spawnNewPair then
				tInsert(seedSpawns[it], {hex = pairHex, pairHex = newHex, direction = newDirectionPair, lastHex = hex, lastDirection = OppositeDirection(direction), rainfall = seed.rainfall, minor = minor, tiny = tiny, toWater = toWater, toHills = toHills, avoidConnection = avoidConnection, avoidWater = avoidWater, growsDownstream = growsDownstream, dontConnect = dontConnect, doneAnywhere = doneAnywhere, fork = true})
			end
			if spawnLast then
				tInsert(seedSpawns[it], {hex = hex, pairHex = lastHex, direction = lastDirection, lastHex = pairHex, lastDirection = direction, rainfall = seed.rainfall, minor = minor, tiny = tiny, toWater = toWater, toHills = toHills, avoidConnection = avoidConnection, avoidWater = avoidWater, growsDownstream = growsDownstream, dontConnect = dontConnect, doneAnywhere = doneAnywhere, fork = true})
			end
			if spawnLastPair then
				tInsert(seedSpawns[it], {hex = pairHex, pairHex = lastHex, direction = lastDirectionPair, lastHex = hex, lastDirection = OppositeDirection(direction), rainfall = seed.rainfall, minor = minor, tiny = tiny, toWater = toWater, toHills = toHills, avoidConnection = avoidConnection, avoidWater = avoidWater, growsDownstream = growsDownstream, dontConnect = dontConnect, doneAnywhere = doneAnywhere, fork = true})
			end
		end
		-- decide which direction for the river to flow into next
		local useHex, usePair
		if seed.major then
			if hex.polygon ~= newHex.polygon then
				useHex = true
			end
			if pairHex.polygon ~= newHex.polygon then
				usePair = true
			end
		elseif seed.minor then
			if hex.subPolygon ~= newHex.subPolygon then
				useHex = true
			end
			if pairHex.subPolygon ~= newHex.subPolygon then
				usePair = true
			end
		elseif seed.tiny then
			useHex = true
			usePair = true
		end
		if useHex and hex.onRiver[newHex] or onRiver[hex][newHex] then
			useHex = false
		end
		if usePair and pairHex.onRiver[newHex] or onRiver[pairHex][newHex] then
			usePair = false
		end
		if useHex and usePair then
			if Map.Rand(2, "tiny river which direction") == 1 then
				usePair = false
			else
				useHex = false
			end
		end
		if useHex then
			lastHex = pairHex
			lastDirection = direction
			pairHex = newHex
			direction = newDirection
		elseif usePair then
			lastHex = hex
			lastDirection = OppositeDirection(direction)
			hex = pairHex
			pairHex = newHex
			direction = newDirectionPair
		else
			-- EchoDebug("NO WAY FORWARD")
			break
		end
		it = it + 1
	until not newHex or it > 1000
	local endRainfall
	if not seed.growsDownstream and river and #river > 0 then
		endRainfall = mMin(river[#river].hex.rainfall, river[#river].pairHex.rainfall) -- mCeil((river[#river].hex.subPolygon.rainfall + river[#river].pairHex.subPolygon.rainfall) / 2)
	end
	-- EchoDebug(it)
	return river, done, seedSpawns, endRainfall
end

function Space:InkRiver(river, seed, seedSpawns, done)
	for f, flow in pairs(river) do
		if flow.hex.ofRiver == nil then flow.hex.ofRiver = {} end
		flow.hex.ofRiver[flow.direction] = flow.flowDirection
		flow.hex.onRiver[flow.pairHex] = true
		flow.pairHex.onRiver[flow.hex] = true
		if not flow.hex.isRiver then self.riverArea = self.riverArea + 1 end
		if not flow.pairHex.isRiver then self.riverArea = self.riverArea + 1 end
		flow.hex.isRiver = true
		flow.pairHex.isRiver = true
		-- EchoDebug(flow.hex:Locate() .. ": " .. tostring(flow.hex.plotType) .. " " .. tostring(flow.hex.subPolygon.lake) .. " " .. tostring(flow.hex.mountainRange), " / ", flow.pairHex:Locate() .. ": " .. tostring(flow.pairHex.plotType) .. " " .. tostring(flow.pairHex.subPolygon.lake).. " " .. tostring(flow.pairHex.mountainRange))
	end
	for nit, newseeds in pairs(seedSpawns) do
		for nsi, newseed in pairs(newseeds) do
			if newseed.minor then
				tInsert(self.minorForkSeeds, newseed)
			elseif newseed.tiny then
				tInsert(self.tinyForkSeeds, newseed)
			end
		end
	end
	if seed.lake then
		self.lakeConnections[seed.lake] = done.subPolygon
		EchoDebug("connecting lake ", tostring(seed.lake), " to ", tostring(done.subPolygon), tostring(done.subPolygon.lake), done.x .. ", " .. done.y)
	end
	tInsert(self.rivers, { path = river, seed = seed, done = done, riverLength = #river })
end

function Space:FindLakeFlow(seeds)
	if self.lakeConnections[seeds[1].lake] then return end
	local toOcean
	for si, seed in pairs(seeds) do
		local river, done, seedSpawns = self:DrawRiver(seed)
		if done then
			if done.subPolygon.lake then
				-- EchoDebug("found lake-to-lake river")
				self:InkRiver(river, seed, seedSpawns, done)
				self:FindLakeFlow(self.lakeRiverSeeds[done.subPolygon])
				return
			else
				toOcean = {river = river, seed = seed, seedSpawns = seedSpawns, done = done}
			end
		end
	end
	if toOcean then
		-- EchoDebug("found lake-to-ocean river")
		self:InkRiver(toOcean.river, toOcean.seed, toOcean.seedSpawns, toOcean.done)
	end
end

function Space:DrawLakeRivers()
	self.riverArea = 0
	self.lakeConnections = {}
	local lakeSeedBuffer = tDuplicate(self.lakeRiverSeeds)
	while #lakeSeedBuffer > 0 do
		local seeds = tRemoveRandom(lakeSeedBuffer)
		self:FindLakeFlow(seeds)
	end
end

function Space:DrawRivers()
	self.minorForkSeeds, self.tinyForkSeeds = {}, {}
	local laterRiverSeeds = {}
	local seedBoxes = { "majorRiverSeeds", "minorRiverSeeds", "tinyRiverSeeds", "minorForkSeeds", "tinyForkSeeds" }
	self.riverLandRatio = self.riverLandRatio * (self.rainfallMidpoint / 50)
	local prescribedRiverArea = self.riverLandRatio * self.filledArea
	local drawn = 0
	local lastRecycleDrawn = 0
	while self.riverArea < prescribedRiverArea do
		local anyAreaAtAll
		for i, box in pairs(seedBoxes) do
			local seeds = self[box]
			if #seeds > 0 then
				anyAreaAtAll = true
				local inked
				local seed = tRemoveRandom(seeds)
				-- local list = ""
				-- for key, value in pairs(seed) do list = list .. key .. ": " .. tostring(value) .. ", " end
				-- EchoDebug("drawing river seed #" .. si, list)
				local river, done, seedSpawns, endRainfall = self:DrawRiver(seed)
				local rainfall = endRainfall or seed.rainfall
				if (seed.doneAnywhere and river and #river > 0) or done then
					local drawIt = seed.alwaysDraw or (Map.Rand(100, "river chance") < rainfall * self.riverRainMultiplier)
					-- EchoDebug(endRainfall or seed.rainfall, " rainfall ", (endRainfall or seed.rainfall) * 0.67, tostring(drawIt))
					if drawIt then
						self:InkRiver(river, seed, seedSpawns, done)
						drawn = drawn + 1
						lastRecycleDrawn = lastRecycleDrawn + 1
						inked = true
						if self.riverArea >= prescribedRiverArea then break end
					end
				end
				if not inked then
					tInsert(laterRiverSeeds, seed)
				end
			end
		end
		if not anyAreaAtAll and self.riverArea < prescribedRiverArea then
			if #laterRiverSeeds > 0 then
				if lastRecycleDrawn == 0 then
					EchoDebug("none drawn from last recycle")
					break
				end
				EchoDebug("(recycling " .. #laterRiverSeeds .. " unused river seeds...)")
				for si, seed in pairs(laterRiverSeeds) do
					if seed.major then
						tInsert(self.majorRiverSeeds, seed)
					elseif seed.minor then
						if seed.fork then
							tInsert(self.minorForkSeeds, seed)
						else
							tInsert(self.minorRiverSeeds, seed)
						end
					elseif seed.tiny then
						if seed.fork then
							tInsert(self.tinyForkSeeds, seed)
						else
							tInsert(self.tinyRiverSeeds, seed)
						end
					end
				end
				lastRecycleDrawn = 0
			else
				EchoDebug("no seeds available at all")			
				break
			end
		end
	end
	local rlpercent = mFloor( (self.riverArea / self.filledArea) * 100 )
	local rpercent = mFloor( (self.riverArea / self.iA) * 100 )
	EchoDebug(drawn .. " drawn ", " river area: " .. self.riverArea, "(" .. rlpercent .. "% of land, " .. rpercent .. "% of map)")
end

function Space:DrawRoad(origHex, destHex)
	local hex = origHex
	local it = 0
	local picked = {}
	repeat
		if hex.plotType == plotLand or hex.plotType == plotHills then
			hex.road = true
		end
		hex.invisibleRoad = true
		picked[hex] = true
		if hex == destHex then break end
		local xdist, ydist = self:WrapDistanceSigned(hex.x, hex.y, destHex.x, destHex.y)
		local directions
		if xdist > 1 then
			directions = { DirNE, DirE, DirSE }
		elseif xdist < 1 then
			directions = { DirNW, DirW, DirSW }
		elseif ydist > 0 then
			directions = { DirNE, DirNW }
		elseif ydist < 0 then
			directions = { DirSE, DirSW }
		end
		local leastCost = 10
		local leastHex
		for direction, nhex in pairs(hex:Neighbors(directions)) do
			if not picked[nhex] then
				if nhex == destHex then
					cost = -1
				elseif nhex.plotType == plotMountain then
					cost = 3
				elseif nhex.plotType == plotOcean then
					cost = 2
				elseif nhex.plotType == plotHills then
					cost = 1
				else
					cost = 0
				end
				if cost < leastCost then
					leastCost = cost
					leastHex = nhex
				end
			end
		end
		hex = leastHex or hex
		it = it + 1
	until not leastHex or it > 1000
	EchoDebug(it)
end

function Space:DrawRoads()
	if self.roadCount == 0 then return end
	local drawnRoads = 0
	repeat
		local polygon
		repeat
			polygon = tGetRandom(self.polygons)
		until polygon.continent
		for n, neighbor in pairs(polygon.neighbors) do
			if neighbor.continent and (not polygon.roads or not polygon.roads[neighbor]) then
				toPolygon = neighbor
				break
			end
		end
		if toPolygon then
			self:DrawRoad(self:GetHexByXY(polygon.x, polygon.y), self:GetHexByXY(toPolygon.x, toPolygon.y))
			if polygon.roads == nil then polygon.roads = {} end
			if toPolygon.roads == nil then toPolygon.roads = {} end
			polygon.roads[toPolygon] = true
			toPolygon.roads[polygon] = true
			EchoDebug("road from ", polygon, " to " , toPolygon)
			drawnRoads = drawnRoads + 1
		end
	until drawnRoads >= self.roadCount
end

function Space:PickCoasts()
	self.waterArea = self.nonOceanArea - self.filledArea
	self.prescribedCoastArea = self.waterArea * self.coastAreaRatio
	EchoDebug(self.prescribedCoastArea .. " coastal tiles prescribed of " .. self.waterArea .. " total water tiles")
	self.coastArea = 0
	self.coastalPolygonArea = 0
	self.coastalPolygonCount = 0
	self.polarMaxLandPercent = self.polarMaxLandRatio * 100
	for i, polygon in pairs(self.polygons) do
		if polygon.continent == nil then
			if polygon.oceanIndex == nil and Map.Rand(10, "coastal polygon dice") < self.coastalPolygonChance then
				polygon.coastal = true
				self.coastalPolygonCount = self.coastalPolygonCount + 1
				if not polygon:NearOther(nil, "continent") then polygon.loneCoastal = true end
				if not polygon.polar or mRandom(0, 100) < self.polarMaxLandPercent then
					polygon:PickTinyIslands()
					tInsert(self.tinyIslandPolygons, polygon)
				end
			elseif polygon.oceanIndex then
				if not polygon.polar or mRandom(0, 100) < self.polarMaxLandPercent then
					polygon:PickTinyIslands()
					tInsert(self.tinyIslandPolygons, polygon)
				end
			end
		end
	end
	EchoDebug(self.coastalPolygonCount .. " coastal polygons")
end

function Space:DisperseFakeLatitude()
	self.continentalFakeLatitudes = {}
	local increment = 90 / self.filledPolygons
    for i = 1, self.filledPolygons do
    	tInsert(self.continentalFakeLatitudes, increment * (i-1))
    end
	self.nonContinentalFakeLatitudes = {}
    increment = 90 / (#self.polygons - self.filledPolygons)
    for i = 1, (#self.polygons - self.filledPolygons) do
    	tInsert(self.nonContinentalFakeLatitudes, increment * (i-1))
    end
	for i, polygon in pairs(self.polygons) do
		polygon.latitude = self:GetFakeLatitude(polygon)
		for spi, subPolygon in pairs(polygon.subPolygons) do
			subPolygon.latitude = self:GetFakeSubLatitude(polygon.latitude)
		end
	end
end

function Space:ResizeMountains(prescribedArea)
	if #self.mountainHexes == prescribedArea then return end
	if #self.mountainHexes > prescribedArea then
		repeat
			local hex = tRemoveRandom(self.mountainHexes)
			if hex.mountainRangeCore and #self.mountainHexes > #self.mountainCoreHexes and Map.Rand(11, "core mountain remove") < self.mountainCoreTenacity then
				tInsert(self.mountainHexes, hex)
			else
				if Map.Rand(10, "hill dice") < self.hillChance then
					hex.plotType = plotHills
					if hex.featureType and not FeatureDictionary[hex.featureType].hill then
						hex.featureType = featureNone
					end
				else
					hex.plotType = plotLand
				end
			end
		until #self.mountainHexes <= prescribedArea
	elseif #self.mountainHexes < prescribedArea then
		local noNeighbors = 0
		repeat
			local hex = tGetRandom(self.mountainHexes)
			local neighbors = hex:Neighbors()
			local neighborBuffer = {} -- because neighbors has gaps in it
			for n, nhex in pairs(neighbors) do
				if nhex then
					tInsert(neighborBuffer, nhex)
				end
			end
			local nhex
			repeat
				nhex = tRemoveRandom(neighborBuffer)
			until nhex.plotType == plotLand or #neighborBuffer == 0
			if nhex ~= nil and nhex.plotType == plotLand then
				if Map.Rand(10, "hill dice") < self.hillChance then
					nhex.plotType = plotHills
					if not FeatureDictionary[hex.featureType].hill then
						hex.featureType = featureNone
					end
				else
					nhex.plotType = plotMountain
					tInsert(self.mountainHexes, nhex)
				end
				noNeighbors = 0
			else
				noNeighbors = noNeighbors + 1
			end
		until #self.mountainHexes >= prescribedArea or noNeighbors > 20
	end
end

function Space:AdjustMountains()
	self.mountainArea = mCeil(self.mountainRatio * self.filledArea)
	EchoDebug(#self.mountainHexes, self.mountainArea)
	-- first expand them 1.1 times their size
	-- self:ResizeMountains(#self.mountainHexes * 1.1)
	-- then adjust to the right amount
	self:ResizeMountains(self.mountainArea)
	for i, hex in pairs(self.mountainHexes) do
		hex.featureType = featureNone
	end
end

----------------------------------
-- INTERNAL FUNCTIONS: --

function Space:GetPlotLatitude(plot)
	if plot:GetY() > self.halfHeight then
		return mCeil(plot:GetLatitude() * self.northLatitudeMult)
	else
		return plot:GetLatitude()
	end
end

function Space:GetFakeLatitude(polygon)
	if polygon then
		if polygon.continent then
			return tRemoveRandom(self.continentalFakeLatitudes)
		else
			return tRemoveRandom(self.nonContinentalFakeLatitudes)
		end
	end
	return mRandom(0, 90)
end

function Space:GetFakeSubLatitude(latitudeStart)
	if latitudeStart then
		return mRandom(latitudeStart-5, latitudeStart+5)
	end
	return mRandom(0, 90)
end

function Space:RealmLatitude(y)
	if self.realmHemisphere == 2 then y = self.h - y end
	return mCeil(y * (90 / self.h))
end

function Space:GetTemperature(latitude)
	local rise = self.temperatureMax - self.temperatureMin
	local temp, temp2
	if latitude then
		local distFromPole = (90 - latitude) ^ self.polarExponent
		temp = (rise / self.polarExponentMultiplier) * distFromPole + self.temperatureMin
	else
		temp = diceRoll(self.temperatureDice, rise) + self.temperatureMin
	end
	local diff = mRandom(1, mFloor(self.intraregionTemperatureDeviation / 2))
	local temp1 = mMax(temp - diff, 0)
	local temp2 = mMin(temp + diff, 100)
	return mFloor(temp), mFloor(temp1), mFloor(temp2)
end

function Space:GetRainfall(latitude)
	local rain, rain2
	if latitude then
		if latitude > 75 then -- polar
			rain = (self.rainfallMidpoint/4) + ( (self.rainfallPlusMinus/4) * (mCos((mPi/15) * (latitude+15))) )
		elseif latitude > 37.5 then -- temperate
			rain = self.rainfallMidpoint + ((self.rainfallPlusMinus/2) * mCos(latitude * (mPi/25)))
		else -- tropics and desert
			rain = self.rainfallMidpoint + (self.rainfallPlusMinus * mCos(latitude * (mPi/25)))
		end
	else
		local rise = self.rainfallMax - self.rainfallMin
		rain = diceRoll(self.rainfallDice, rise) + self.rainfallMin
	end
	local diff = mRandom(1, mFloor(self.intraregionRainfallDeviation / 2))
	local rain1 = mMax(rain - diff, 0)
	local rain2 = mMin(rain + diff, 100)
	return mFloor(rain), mFloor(rain1), mFloor(rain2)
end

function Space:GetHillyness()
	return mRandom(0, self.hillynessMax)
end

function Space:GetCollectionSize()
	return mRandom(self.collectionSizeMin, self.collectionSizeMax), mRandom(self.subCollectionSizeMin, self.subCollectionSizeMax)
end

function Space:ClosestThing(this, things)
	local dists = {}
	local closestDist = self.w
	local closestThing
	-- find the closest point to this point
	for i, thing in pairs(things) do
		local predistx, predisty = self:WrapDistance(thing.x, thing.y, this.x, this.y)
		if predistx < closestDist or predisty < closestDist then
			dists[i] = self:SquaredDistance(thing.x, thing.y, this.x, this.y, predistx, predisty)
			if i == 1 or dists[i] < closestDist then
				closestDist = dists[i]
				closestThing = thing
			end
		end
	end
	return closestThing
end

function Space:WrapDistanceSigned(x1, y1, x2, y2)
	local xdist = x2 - x1
	local ydist = y2 - y1
	if self.wrapX then
		if xdist > self.halfWidth then
			xdist = xdist - self.w
		elseif xdist < -self.halfWidth then
			xdist = xdist + self.w
		end
	end
	if self.wrapY then
		if ydist > self.halfHeight then
			ydist = ydist - self.h
		elseif ydist < -self.halfHeight then
			ydist = ydist + self.h
		end
	end
	return xdist, ydist
end

function Space:WrapDistance(x1, y1, x2, y2)
	local xdist = mAbs(x1 - x2)
	local ydist = mAbs(y1 - y2)
	if self.wrapX then
		if xdist > self.halfWidth then
			if x1 < x2 then
				xdist = x1 + (self.w - x2)
			else
				xdist = x2 + (self.w - x1)
			end
		end
	end
	if self.wrapY then
		if ydist > self.halfHeight then
			if y1 < y2 then
				ydist = y1 + (self.h - y2)
			else
				ydist = y2 + (self.h - y1)
			end
		end
	end
	return xdist, ydist
end

function Space:SquaredDistance(x1, y1, x2, y2)
	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
	return (xdist * xdist) + (ydist * ydist)
end
function Space:EucDistance(x1, y1, x2, y2)
	return mSqrt(self:SquaredDistance(x1, y1, x2, y2))
end

function Space:HexDistance(x1, y1, x2, y2)
	local xx1 = x1
	local zz1 = y1 - (x1 + x1%2) / 2
	local yy1 = -xx1-zz1
	local xx2 = x2
	local zz2 = y2 - (x2 + x2%2) / 2
	local yy2 = -xx2-zz2
	local xdist = mAbs(x1 - x2)
	-- x is the same orientation, so it can still wrap?
	if self.wrapX then
		if xdist > self.halfWidth then
			if x1 < x2 then
				xdist = x1 + (self.w - x2)
			else
				xdist = x2 + (self.w - x1)
			end
		end
	end
	return (xdist + mAbs(yy1 - yy2) + mAbs(zz1 - zz2)) / 2
end

function Space:GetHexByXY(x, y)
	return self.hexes[self:GetIndex(x, y)]
end

function Space:GetXY(index)
	if index == nil then return nil end
	index = index - 1
	return index % self.iW, mFloor(index / self.iW)
end

function Space:GetIndex(x, y)
	if x == nil or y == nil then return nil end
	return (y * self.iW) + x + 1
end

------------------------------------------------------------------------------

function GetMapScriptInfo()
	local world_age, temperature, rainfall, sea_level, resources = GetCoreMapOptions()
	local custOpts = GetCustomOptions()
	tInsert(custOpts, resources)
	return {
		Name = "Fantastical (dev)",
		Description = "Fantastical lands! Convoluted rivers! Epic mountain ranges!",
		IsAdvancedMap = 0,
		SupportsMultiplayer = true,
		SortIndex = 1,
		IconAtlas = "WORLDTYPE_FANTASTICAL_ATLAS",
		IconIndex = 0,
		CustomOptions = custOpts,
	}
end

function GetMapInitData(worldSize)
	-- i have to use Map.GetCustomOption because this is called before everything else
	if Map.GetCustomOption(1) == 2 then
		-- for Realm maps
		-- create a random map aspect ratio for the given map size
		local areas = {
			[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 40 * 25,
			[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 56 * 36,
			[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 66 * 42,
			[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 80 * 52,
			[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 104 * 64,
			[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 128 * 80,
		}
		local grid_area = areas[worldSize]
		local grid_width = mCeil( mSqrt(grid_area) * ((mRandom() * 0.67) + 0.67) )
		local grid_height = mCeil( grid_area / grid_width )
		local world = GameInfo.Worlds[worldSize]
		local wrap = Map.GetCustomOption(1) == 3
		if world ~= nil then
			return {
				Width = grid_width,
				Height = grid_height,
				WrapX = false,
			}
	    end
	end
end

local mySpace

function GeneratePlotTypes()
	FantasticalLands = "HELLO THERE"
    print("Generating Plot Types (Fantastical) ...")
	SetConstants()
    mySpace = Space()
    mySpace:SetOptions(OptionDictionary)
    mySpace:Compute()
    --[[
    for l = 0, 90, 5 do
		EchoDebug(l, "temperature: " .. mySpace:GetTemperature(l), "rainfall: " .. mySpace:GetRainfall(l))
	end
	]]--
    print("Setting Plot Types (Fantastical) ...")
    mySpace:SetPlots()
end

function GenerateTerrain()
    print("Setting Terrain Types (Fantastical) ...")
	mySpace:SetTerrains()
end

function AddFeatures()
	print("Setting Feature Types (Fantastical) ...")
	mySpace:SetFeatures()
	print("Setting roads instead (Fantastical) ...")
	mySpace:SetRoads()
end

function AddRivers()
	print("Adding Rivers (Fantastical) ...")
	mySpace:SetRivers()
end

function AddLakes()
	print("Adding No Lakes (lakes have already been added) (Fantastical)")
end

function DetermineContinents()
	print("Determining continents for art purposes (Fantastical.lua)");
	if mySpace.centauri then
		EchoDebug("map is alpha centauri, using only Africa and Asia...")
		mySpace:SetContinentArtTypes()
		EchoDebug("map is alpha centauri, moving minerals and kelp to the sea...")
		mySpace:MoveSilverAndSpices()
		EchoDebug("map is alpha centauri, removing non-centauri natural wonders...")
		mySpace:RemoveBadNaturalWonders()
	else
		EchoDebug("using default continent stamper...")
		Map.DefaultContinentStamper()
	end
end

-------------------------------------------------------------------------------

-- THE STUFF BELOW NEVER GETS CALLED, FOR REASONS I DON'T UNDERSTAND

function AssignStartingPlots:CanBeReef(x, y)
	-- Checks a candidate plot for eligibility to be the Great Barrier Reef.
	local iW, iH = Map.GetGridSize();
	local plotIndex = y * iW + x + 1;
	-- We don't care about the center plot for this wonder. It can be forced. It's the surrounding plots that matter.
	-- This is also the only natural wonder type with a footprint larger than seven tiles.
	-- So first we'll check the extra tiles, make sure they are there, are ocean water, and have no Ice.
	local iNumCoast = 0;
	local extra_direction_types = {
		DirectionTypes.DIRECTION_EAST,
		DirectionTypes.DIRECTION_SOUTHEAST,
		DirectionTypes.DIRECTION_SOUTHWEST};
	local SEPlot = Map.PlotDirection(x, y, DirectionTypes.DIRECTION_SOUTHEAST)
	local southeastX = SEPlot:GetX();
	local southeastY = SEPlot:GetY();
	for loop, direction in ipairs(extra_direction_types) do -- The three plots extending another plot past the SE plot.
		local adjPlot = Map.PlotDirection(southeastX, southeastY, direction)
		if adjPlot == nil then
			return
		end
		if adjPlot:IsWater() == false or adjPlot:IsLake() == true then
			return
		end
		local featureType = adjPlot:GetFeatureType()
		if featureType == featureIce then
			return
		end
		local hex = Space.hexes[plotIndex+1]
		if hex.oceanIndex then
			return
		end
		local terrainType = adjPlot:GetTerrainType()
		if terrainType == terrainCoast then
			iNumCoast = iNumCoast + 1;
		end
	end
	-- Now check the rest of the adjacent plots.
	local direction_types = { -- Not checking to southeast.
		DirectionTypes.DIRECTION_NORTHEAST,
		DirectionTypes.DIRECTION_EAST,
		DirectionTypes.DIRECTION_SOUTHWEST,
		DirectionTypes.DIRECTION_WEST,
		DirectionTypes.DIRECTION_NORTHWEST
		};
	for loop, direction in ipairs(direction_types) do
		local adjPlot = Map.PlotDirection(x, y, direction)
		if adjPlot:IsWater() == false then
			return
		end
		local hex = Space.hexes[plotIndex+1]
		if hex.oceanIndex then
			return
		end
		local terrainType = adjPlot:GetTerrainType()
		if terrainType == terrainCoast then
			iNumCoast = iNumCoast + 1;
		end
	end
	-- If not enough coasts, reject this site.
	if iNumCoast < 6 then
		return
	end
	-- This site is in the water, with at least some of the water plots being coast, so it's good.
	table.insert(self.reef_list, plotIndex);
end

function AssignStartingPlots:CanBeKrakatoa(x, y)
	-- Checks a candidate plot for eligibility to be Krakatoa the volcano.
	local plot = Map.GetPlot(x, y)
	-- Check the center plot, which must be land surrounded on all sides by coast. (edited for fantastical)
	if plot:IsWater() then return end

	for loop, direction in ipairs(self.direction_types) do
		local adjPlot = Map.PlotDirection(x, y, direction)
		if not adjPlot:IsWater() or adjPlot:GetTerrainType() ~= terrainCoast or adjPlot:GetFeatureType() == featureIce then
			return
		end
	end
	
	-- Surrounding tiles are all ocean water, not lake, and free of Feature Ice, so it's good.
	local iW, iH = Map.GetGridSize();
	local plotIndex = y * iW + x + 1;
	table.insert(self.krakatoa_list, plotIndex);
end