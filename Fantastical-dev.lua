-- Map Script: Fantastical
-- Author: eronoobos
-- version 27

--------------------------------------------------------------
if include == nil then
	package.path = package.path..';C:\\Program Files (x86)\\Steam\\steamapps\\common\\Sid Meier\'s Civilization V\\Assets\\Gameplay\\Lua\\?.lua'
	include = require
end
include("math")
include("bit")
include("MapGenerator")
include("FLuaVector.lua")
----------------------------------------------------------------------------------

local debugEnabled = true
local clockEnabled = false
local function EchoDebug(...)
	if debugEnabled then
		local printResult = ""
		if clockEnabled then
			local clock = math.floor(os.clock() / 0.1) * 0.1
			printResult = printResult .. "(" .. clock .. "): \t"
		end
		for i,v in ipairs(arg) do
			local vString
			if type(v) == "number" and math.floor(v) ~= v then
				vString = string.format("%.4f", v)
			elseif type(v) == "table" and v[1] then
				vString = ""
				for ii, vv in ipairs(v) do
					if type(vv) == "number" and math.floor(vv) ~= vv then
						vvStr = string.format("%.2f", vv)
					else
						vvStr = tostring(vv)
					end
					vString = vString .. vvStr
					if ii < #v then vString = vString .. ", " end
				end
			else
				vString = tostring(v)
			end
			printResult = printResult .. vString .. "\t"
		end
		print(printResult)
	end
end

local function StartDebugTimer()
	return os.clock()
end

local function StopDebugTimer(timer)
	local time = os.clock() - timer
	local multiplier
	local unit
	local format
	if time < 1 then
		multiplier = 1000
		unit = "ms"
		format  ="%.0f"
	else
		multiplier = 1
		unit = "s"
		if time < 10 then
			format = "%.3f"
		elseif time < 100 then
			format = "%.2f"
		elseif time < 1000 then
			format = "%.1f"
		else
			format = "%.0f"
		end
	end
	return string.format(format, multiplier * time) .. " " .. unit
end

------------------------------------------------------------------------------

local mCeil = math.ceil
local mFloor = math.floor
local mMin = math.min
local mMax = math.max
local mAbs = math.abs
local mSqrt = math.sqrt
local mLog = math.log
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

-- uses civ's Map.Rand function to generate random numbers so that multiplayer works
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

local function int(x)
	return x + 0.5 - (x + 0.5) % 1
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

-- converts civ 5's two dimensional hex coords to cube coords
local function OddRToCube(x, y)
	local xx = x - (y - y%2) / 2
	local zz = y
	local yy = -(xx+zz)
	return xx, yy, zz
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
		Bay = { "Bay", "Cove", "Gulf" },
		Straights = { "Straights", "Sound", "Channel" },
		Cape = { "Cape", "Cape", "Cape" },
		Islet = "Key",
		Island = { "Island", "Isle" },
		Mountains = { "Heights", "Highlands", "Spires", "Crags" },
		Hills = { "Hills", "Plateau", "Fell" },
		Dunes = { "Dunes", "Sands", "Drift" },
		Plains = { "Plain", "Prarie", "Steppe" },
		Forest = { "Forest", "Wood", "Grove", "Thicket" },
		Jungle = { "Jungle", "Maze", "Tangle" },
		Swamp = { "Swamp", "Marsh", "Fen", "Pit" },
		Range = "Mountains",
		Waste = { "Waste", "Desolation" },
		Grassland = { "Heath", "Vale" },
	},
	ProperPlace = {
		Ocean = "Ocean",
		InlandSea = "Sea",
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
	InlandSea = "MapWaterMedium",
	Bay = "MapWaterMedium",
	Cape = "MapWaterMedium",
	Straights = "MapWaterMedium",
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
	{ name = "Landmass Type", keys = { "wrapX", "oceanNumber", "majorContinentNumber", "tinyIslandChance", "coastalPolygonChance", "islandRatio", "inlandSeaContinentRatio", "inlandSeasMax", "lakeMinRatio", "astronomyBlobNumber", "astronomyBlobMinPolygons", "astronomyBlobMaxPolygons", "astronomyBlobsMustConnectToOcean" }, default = 9,
	values = {
			[1] = { name = "Land All Around", values = {
				oceanNumber = -1,
				inlandSeasMax = 0,
				lakeMinRatio = 0,
			}},
			[2] = { name = "Lakes", values = {
				oceanNumber = -1,
				tinyIslandChance = 30,
				inlandSeaContinentRatio = 0.015,
				inlandSeasMax = 2,
				lakeMinRatio = 0.02,
			}},
			[3] = { name = "Inland Seas", values = {
				oceanNumber = -1,
				tinyIslandChance = 8,
				inlandSeaContinentRatio = 0.04,
				inlandSeasMax = 3,
				lakeMinRatio = 0.015,
			}},
			[4] = { name = "Inland Sea", values = {
				oceanNumber = -1,
				tinyIslandChance = 3,
				inlandSeaContinentRatio = 0.4,
				inlandSeasMax = 1,
			}},
			[5] = { name = "Low Seas", values = {
				oceanNumber = 0,
				majorContinentNumber = 3,
				islandRatio = 0.15,
				inlandSeasMax = 0,
				astronomyBlobNumber = 1,
				astronomyBlobMinPolygons = 1,
				astronomyBlobMaxPolygons = 1,
			}},
			[6] = { name = "Archipelago", values = {
				oceanNumber = 0,
				majorContinentNumber = 7,
				tinyIslandChance = 30,
				coastalPolygonChance = 2,
				islandRatio = 0.32,
				astronomyBlobNumber = 2,
				astronomyBlobMinPolygons = 1,
				astronomyBlobMaxPolygons = 5,
			}},
			[7] = { name = "Pangaea", values = {
				oceanNumber = 						1,
				majorContinentNumber = 				1,
				tinyIslandChance = 					20,
				islandRatio = 						0.1,
				inlandSeaContinentRatio = 			0.02,
				inlandSeasMax = 					1,
				astronomyBlobNumber = 				1,
				astronomyBlobMinPolygons = 			3,
				astronomyBlobMaxPolygons = 			7,
				astronomyBlobsMustConnectToOcean = 	true,
			}},
			[8] = { name = "Centauri-like", values = {
				oceanNumber = 1,
				majorContinentNumber = 3,
				islandRatio = 0.2,
				inlandSeaContinentRatio = 0.03,
				inlandSeasMax = 1,
			}},
			[9] = { name = "Two Continents", values = {
				-- all defaults
			}},
			[10] = { name = "Earthish", values = {
				majorContinentNumber = 2,
				islandRatio = 0.3,
			}},
			[11] = { name = "Earthseaish", values = {
				oceanNumber = 3,
				majorContinentNumber = 5,
				tinyIslandChance = 25,
				coastalPolygonChance = 2,
				islandRatio = 0.75,
			}},
			[12] = { name = "Lonely Oceans", values = {
				oceanNumber = 0,
				majorContinentNumber = 12,
				tinyIslandChance = 100,
				coastalPolygonChance = 1,
				islandRatio = 0.8,
				astronomyBlobNumber = 5,
			}},
			[13] = { name = "Random Globe", values = "keys", randomKeys = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12} },
			[14] = { name = "Dry Land", values = {
				wrapX = false,
				oceanNumber = -1,
				inlandSeasMax = 0,
				lakeMinRatio = 0,
			}},
			[15] = { name = "Landlocked Lakes", values = {
				wrapX = false,
				oceanNumber = -1,
				tinyIslandChance = 30,
				inlandSeaContinentRatio = 0.015,
				inlandSeasMax = 2,
				lakeMinRatio = 0.02,
			}},
			[16] = { name = "Landlocked Seas", values = {
				wrapX = false,
				oceanNumber = -1,
				tinyIslandChance = 8,
				inlandSeaContinentRatio = 0.04,
				inlandSeasMax = 3,
				lakeMinRatio = 0.015,
			}},
			[17] = { name = "Landlocked Sea", values = {
				wrapX = false,
				oceanNumber = -1,
				tinyIslandChance = 3,
				inlandSeaContinentRatio = 0.4,
				inlandSeasMax = 1,
			}},
			[18] = { name = "Estuary", values = {
				wrapX = false,
				oceanNumber = 0,
				majorContinentNumber = 3,
				islandRatio = 0.15,
				inlandSeasMax = 0,
			}},
			[19] = { name = "Coast", values = {
				wrapX = false,
				oceanNumber = 2,
				tinyIslandChance = 20,
				coastalPolygonChance = 2,
				islandRatio = 0.2,
				inlandSeasMax = 0,
			}},
			[20] = { name = "Peninsula", values = {
				wrapX = false,
				oceanNumber = 3,
				tinyIslandChance = 25,
				coastalPolygonChance = 2,
				inlandSeasMax = 0,
			}},
			[21] = { name = "Continent", values = {
				wrapX = false,
				oceanNumber = 4,
				tinyIslandChance = 30,
				coastalPolygonChance = 3,
				islandRatio = 0.2,
				astronomyBlobNumber = 1,
				astronomyBlobMinPolygons = 3,
				astronomyBlobMaxPolygons = 7,
				astronomyBlobsMustConnectToOcean = true,
			}},
			[22] = { name = "Island Chain", values = {
				wrapX = false,
				oceanNumber = 4,
				majorContinentNumber = 7,
				tinyIslandChance = 30,
				coastalPolygonChance = 2,
				islandRatio = 0.8,
				astronomyBlobNumber = 2,
			}},
			[23] = { name = "Random Realm", values = "keys", randomKeys = {14, 15, 16, 17, 18, 19, 20, 21, 22} },
		}
	},
	-- { name = "Inland Water Bodies", keys = { "inlandSeasMax", "inlandSeaContinentRatio", "lakeMinRatio" }, default = 2,
	-- values = {
	-- 		[1] = { name = "None", values = {0, 0, 0} },
	-- 		[2] = { name = "Some Lakes", values = {1, 0.015, 0.0065} },
	-- 		[3] = { name = "Many Lakes", values = {1, 0.025, 0.02} },
	-- 		[4] = { name = "Seas", values = {3, 0.04, 0.01} },
	-- 		[5] = { name = "One Big Sea", values = {1, 0.4, 0.0065} },
	-- 		[6] = { name = "Random", values = "keys" },
	-- 	}
	-- },
	{ name = "Land at Poles", keys = { "polarMaxLandRatio" }, default = 1,
	values = {
			[1] = { name = "Yes", values = {0.5} },
			[2] = { name = "No", values = {0} },
			[3] = { name = "Random", values = "keys" },
 		}
	},
	{ name = "Granularity", keys = { "polygonCount" }, default = 3,
	values = {
			[1] = { name = "Very Low", values = {100} },
			[2] = { name = "Low", values = {150} },
			[3] = { name = "Fair", values = {200} },
			[4] = { name = "High", values = {250} },
			[5] = { name = "Very High", values = {300} },
			[6] = { name = "Random", values = "values", lowValues = {100}, highValues = {300} },
		}
	},
	{ name = "Climate Realism", keys = { "useMapLatitudes" }, default = 1,
	values = {
			[1] = { name = "Off", values = {false} },
			[2] = { name = "On", values = {true} },
			[3] = { name = "Random", values = "keys" },
 		}
	},
	{ name = "World Age", keys = { "mountainRatio", "hillynessMax", "hillChance" }, default = 4,
	values = {
			[1] = { name = "1 Billion Years", values = {0.25, 75, 5} },
			[2] = { name = "2 Billion Years", values = {0.16, 60, 4} },
			[3] = { name = "3 Billion Years", values = {0.08, 50, 3} },
			[4] = { name = "4 Billion Years", values = {0.04, 40, 3} },
			[5] = { name = "5 Billion Years", values = {0.02, 30, 2} },
			[6] = { name = "6 Billion Years", values = {0.005, 20, 1} },
			[7] = { name = "Random", values = "keys" },
		}
	},
	{ name = "Temperature", keys = { "polarExponent", "temperatureMin", "temperatureMax" }, default = 4,
	values = {
			[1] = { name = "Snowball", values = {1.8, 0, 13} },
			[2] = { name = "Ice Age", values = {1.6, 0, 33} },
			[3] = { name = "Cool", values = {1.4, 0, 71} },
			[4] = { name = "Temperate", values = {1.2, 0, 99} },
			[5] = { name = "Hot", values = {1.1, 6, 99} },
			[6] = { name = "Jurassic", values = {0.9, 26, 99} },
			[7] = { name = "Global Tropics", values = {0.7, 50, 99} },
			[8] = { name = "Random", values = "keys" },
		}
	},
	{ name = "Rainfall", keys = { "rainfallMidpoint" }, default = 4,
	values = {
			[1] = { name = "Arrakis", values = {3} },
			[2] = { name = "Very Arid", values = {28} },
			[3] = { name = "Arid", values = {38} },
			[4] = { name = "Normal", values = {49.5} },
			[5] = { name = "Wet", values = {57} },
			[6] = { name = "Very Wet", values = {67} },
			[7] = { name = "Arboria", values = {84} },
			[8] = { name = "Random", values = "values", lowValues = {3}, highValues = {96} },
		}
	},
	{ name = "Doomsday Age", keys = { "falloutEnabled", "contaminatedWater", "contaminatedSoil", "postApocalyptic", "ancientCitiesCount" }, default = 1,
	values = {
			[1] = { name = "Not Yet (No Ruins or Roads)", values = {false, false, false, false, 0} },
			[2] = { name = "Legend (Ruins & Roads)", values = {false, false, false, false, 4} },
			[3] = { name = "History (Fallout around Ruins)", values = {false, false, false, true, 4} },
			[4] = { name = "Memory (More Fallout)", values = {true, false, false, true, 4} },
			[5] = { name = "A Long While (Fallout in Mountains)", values = {true, false, true, true, 4} },
			[6] = { name = "A While (Fallout in Rivers)", values = {true, true, false, true, 4} },
			[7] = { name = "Yesterday (Fallout Everywhere)", values = {true, true, true, true, 4} },
			[8] = { name = "Random", values = "keys" },
		}
	},
}

local function GetCustomOptions()
	local custOpts = {}
	for i, option in ipairs(OptionDictionary) do
		local opt = { Name = option.name, SortPriority = i, DefaultValue = option.default, Values = {} }
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
		-- EchoDebug("table " .. tableName .. " exists, dropping")
		DatabaseQuery("DROP TABLE " .. tableName)
		-- break
	end
	-- EchoDebug("creating table " .. tableName)
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
local improvementCityRuins
local artOcean, artAmerica, artAsia, artAfrica, artEurope
local resourceSilver, resourceSpices
local climateGrid

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

	featureVolcano = 11 -- FeatureTypes.FEATURE_VOLCANO
	featureReef = 10 -- FeatureTypes.FEATURE_REEF

	for thisFeature in GameInfo.Features() do
		if thisFeature.Type == "FEATURE_ATOLL" then
			featureAtoll = thisFeature.ID
		end
	end

	improvementCityRuins = GameInfo.Improvements.IMPROVEMENT_CITY_RUINS.ID

	TerrainDictionary = {
		[terrainGrass] = { points = {{t=76,r=41}, {t=64,r=41}, {t=61,r=50}}, features = { featureNone, featureForest, featureJungle, featureMarsh, featureFallout } },
		[terrainPlains] = { points = {{t=19,r=41}, {t=21,r=50}}, features = { featureNone, featureForest, featureFallout } },
		[terrainDesert] = { points = {{t=79,r=14}, {t=56,r=12}, {t=19,r=11}}, features = { featureNone, featureOasis, featureFallout }, specialFeature = featureOasis },
		[terrainTundra] = { points = {{t=11,r=41}, {t=8,r=50}, {t=11,r=11}}, features = { featureNone, featureForest, featureFallout } },
		[terrainSnow] = { points = {{t=0,r=41}, {t=1,r=49}, {t=0,r=11}}, features = { featureNone, featureFallout } },
	}

	-- metaPercent is how like it is be a part of a region's collection *at all*
	-- percent is how likely it is to show up in a region's collection on a per-element (tile) basis, if it's the closest rainfall and temperature already
	-- limitRatio is what fraction of a region's hexes at maximum may have this feature (-1 is no limit)

	FeatureDictionary = {
		[featureNone] = { points = {{t=89,r=58}, {t=20,r=23}, {t=18,r=76}, {t=43,r=33}, {t=59,r=39}, {t=40,r=76}, {t=27,r=82}, {t=62,r=53}, {t=29,r=48}, {t=39,r=66}}, percent = 100, limitRatio = -1, hill = true },
		[featureForest] = { points = {{t=0,r=47}, {t=56,r=100}, {t=12,r=76}, {t=44,r=76}, {t=28,r=98}, {t=44,r=66}}, percent = 100, limitRatio = 0.85, hill = true },
		[featureJungle] = { points = {{t=100,r=100}, {t=86,r=100}}, percent = 100, limitRatio = 0.85, hill = true, terrainType = terrainPlains },
		[featureMarsh] = { points = {}, percent = 100, limitRatio = 0.33, hill = false },
		[featureOasis] = { points = {}, percent = 2.4, limitRatio = 0.01, hill = false },
		[featureFallout] = { points = {{t=50,r=0}}, disabled = true, percent = 0, limitRatio = 0.75, hill = true },
	}

	-- doing it this way just so the declarations above are shorter
	for terrainType, terrain in pairs(TerrainDictionary) do
		if terrain.terrainType == nil then terrain.terrainType = terrainType end
		terrain.canHaveFeatures = {}
		for i, featureType in pairs(terrain.features) do
			terrain.canHaveFeatures[featureType] = true
		end
	end
	for featureType, feature in pairs(FeatureDictionary) do
		if feature.featureType == nil then feature.featureType = featureType end
	end

	-- for Alpha Centauri Maps:

	TerrainDictionaryCentauri = {
		[terrainGrass] = { points = {{t=50,r=58}}, features = { featureNone, featureJungle, featureMarsh } },
		[terrainPlains] = { points = {{t=50,r=14}}, features = { featureNone, } },
		[terrainDesert] = { points = {{t=50,r=0}}, features = { featureNone, } },
	}

	FeatureDictionaryCentauri = {
		[featureNone] = { points = {{t=0,r=0}}, percent = 100, limitRatio = -1, hill = true },
		[featureJungle] = { points = {{t=100,r=100}}, percent = 100, limitRatio = 0.95, hill = false },
		[featureMarsh] = { points = {{t=82,r=61}}, percent = 65, limitRatio = 0.9, hill = true },
	}

	-- doing it this way just so the declarations above are shorter
	for terrainType, terrain in pairs(TerrainDictionaryCentauri) do
		if terrain.terrainType == nil then terrain.terrainType = terrainType end
		terrain.canHaveFeatures = {}
		for i, featureType in pairs(terrain.features) do
			terrain.canHaveFeatures[featureType] = true
		end
	end
	for featureType, feature in pairs(FeatureDictionaryCentauri) do
		if feature.featureType == nil then feature.featureType = featureType end
	end

	LabelDefinitions = {
		-- subpolygons
		Sea = { tinyIsland = false, superPolygon = {region = {coastal=true}, sea = {inland=false}} },
		Straights = { tinyIsland = false, coastContinentsTotal = 2, superPolygon = {waterTotal = -2, sea = {inland=false}} },
		Bay = { coast = true, coastTotal = 3, coastContinentsTotal = -1, superPolygon = {coastTotal = 3, coastContinentsTotal = -1, waterTotal = -1, sea = {inland=false}} },
		Cape = { coast = true, coastContinentsTotal = -1, superPolygon = {coastTotal = -1, coastContinentsTotal = 1, oceanIndex = false, sea = {inland=false}} },
		-- regions
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

		-- etc
		InlandSea = { inland = true },
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

	climateGrid = {
	[0] = { [0]={4,-1}, [1]={4,-1}, [2]={4,-1}, [3]={4,-1}, [4]={4,-1}, [5]={4,-1}, [6]={4,-1}, [7]={4,-1}, [8]={4,-1}, [9]={4,-1}, [10]={4,-1}, [11]={4,-1}, [12]={4,-1}, [13]={4,-1}, [14]={4,-1}, [15]={4,-1}, [16]={4,-1}, [17]={4,-1}, [18]={4,-1}, [19]={4,-1}, [20]={4,-1}, [21]={4,-1}, [22]={4,-1}, [23]={4,-1}, [24]={4,-1}, [25]={4,-1}, [26]={4,-1}, [27]={4,-1}, [28]={4,-1}, [29]={4,-1}, [30]={4,-1}, [31]={4,-1}, [32]={4,-1}, [33]={4,-1}, [34]={4,-1}, [35]={4,-1}, [36]={4,-1}, [37]={4,-1}, [38]={4,-1}, [39]={4,-1}, [40]={4,-1}, [41]={4,-1}, [42]={4,-1}, [43]={4,-1}, [44]={4,-1}, [45]={4,-1}, [46]={4,-1}, [47]={4,-1}, [48]={4,-1}, [49]={4,-1}, [50]={4,-1}, [51]={4,-1}, [52]={4,-1}, [53]={4,-1}, [54]={4,-1}, [55]={4,-1}, [56]={4,-1}, [57]={4,-1}, [58]={4,-1}, [59]={4,-1}, [60]={4,-1}, [61]={4,-1}, [62]={4,-1}, [63]={4,-1}, [64]={4,-1}, [65]={4,-1}, [66]={4,-1}, [67]={4,-1}, [68]={4,-1}, [69]={4,-1}, [70]={4,-1}, [71]={4,-1}, [72]={4,-1}, [73]={4,-1}, [74]={4,-1}, [75]={4,-1}, [76]={4,-1}, [77]={4,-1}, [78]={4,-1}, [79]={4,-1}, [80]={4,-1}, [81]={4,-1}, [82]={4,-1}, [83]={4,-1}, [84]={4,-1}, [85]={4,-1}, [86]={4,-1}, [87]={4,-1}, [88]={4,-1}, [89]={4,-1}, [90]={4,-1}, [91]={4,-1}, [92]={4,-1}, [93]={4,-1}, [94]={4,-1}, [95]={4,-1}, [96]={4,-1}, [97]={4,-1}, [98]={4,-1}, [99]={4,-1} },
	[1] = { [0]={4,-1}, [1]={4,-1}, [2]={4,-1}, [3]={4,-1}, [4]={4,-1}, [5]={4,-1}, [6]={4,-1}, [7]={4,-1}, [8]={4,-1}, [9]={4,-1}, [10]={4,-1}, [11]={4,-1}, [12]={4,-1}, [13]={4,-1}, [14]={4,-1}, [15]={4,-1}, [16]={4,-1}, [17]={4,-1}, [18]={4,-1}, [19]={4,-1}, [20]={4,-1}, [21]={4,-1}, [22]={4,-1}, [23]={4,-1}, [24]={4,-1}, [25]={4,-1}, [26]={4,-1}, [27]={4,-1}, [28]={4,-1}, [29]={4,-1}, [30]={4,-1}, [31]={4,-1}, [32]={4,-1}, [33]={4,-1}, [34]={4,-1}, [35]={4,-1}, [36]={4,-1}, [37]={4,-1}, [38]={4,-1}, [39]={4,-1}, [40]={4,-1}, [41]={4,-1}, [42]={4,-1}, [43]={4,-1}, [44]={4,-1}, [45]={4,-1}, [46]={4,-1}, [47]={4,-1}, [48]={4,-1}, [49]={4,-1}, [50]={4,-1}, [51]={4,-1}, [52]={4,-1}, [53]={4,-1}, [54]={4,-1}, [55]={4,-1}, [56]={4,-1}, [57]={4,-1}, [58]={4,-1}, [59]={4,-1}, [60]={4,-1}, [61]={4,-1}, [62]={4,-1}, [63]={4,-1}, [64]={4,-1}, [65]={4,-1}, [66]={4,-1}, [67]={4,-1}, [68]={4,-1}, [69]={4,-1}, [70]={4,-1}, [71]={4,-1}, [72]={4,-1}, [73]={4,-1}, [74]={4,-1}, [75]={4,-1}, [76]={4,-1}, [77]={4,-1}, [78]={4,-1}, [79]={4,-1}, [80]={4,-1}, [81]={4,-1}, [82]={4,-1}, [83]={4,-1}, [84]={4,-1}, [85]={4,-1}, [86]={4,-1}, [87]={4,-1}, [88]={4,-1}, [89]={4,-1}, [90]={4,-1}, [91]={4,-1}, [92]={4,-1}, [93]={4,-1}, [94]={4,-1}, [95]={4,-1}, [96]={4,-1}, [97]={4,-1}, [98]={4,-1}, [99]={4,-1} },
	[2] = { [0]={4,-1}, [1]={4,-1}, [2]={4,-1}, [3]={4,-1}, [4]={4,-1}, [5]={4,-1}, [6]={4,-1}, [7]={4,-1}, [8]={4,-1}, [9]={4,-1}, [10]={4,-1}, [11]={4,-1}, [12]={4,-1}, [13]={4,-1}, [14]={4,-1}, [15]={4,-1}, [16]={4,-1}, [17]={4,-1}, [18]={4,-1}, [19]={4,-1}, [20]={4,-1}, [21]={4,-1}, [22]={4,-1}, [23]={4,-1}, [24]={4,-1}, [25]={4,-1}, [26]={4,-1}, [27]={4,-1}, [28]={4,-1}, [29]={4,-1}, [30]={4,-1}, [31]={4,-1}, [32]={4,-1}, [33]={4,-1}, [34]={4,-1}, [35]={4,-1}, [36]={4,-1}, [37]={4,-1}, [38]={4,-1}, [39]={4,-1}, [40]={4,-1}, [41]={4,-1}, [42]={4,-1}, [43]={4,-1}, [44]={4,-1}, [45]={4,-1}, [46]={4,-1}, [47]={4,-1}, [48]={4,-1}, [49]={4,-1}, [50]={4,-1}, [51]={4,-1}, [52]={4,-1}, [53]={4,-1}, [54]={4,-1}, [55]={4,-1}, [56]={4,-1}, [57]={4,-1}, [58]={4,-1}, [59]={4,-1}, [60]={4,-1}, [61]={4,-1}, [62]={4,-1}, [63]={4,-1}, [64]={4,-1}, [65]={4,-1}, [66]={4,-1}, [67]={4,-1}, [68]={4,-1}, [69]={4,-1}, [70]={4,-1}, [71]={4,-1}, [72]={4,-1}, [73]={4,-1}, [74]={4,-1}, [75]={4,-1}, [76]={4,-1}, [77]={4,-1}, [78]={4,-1}, [79]={4,-1}, [80]={4,-1}, [81]={4,-1}, [82]={4,-1}, [83]={4,-1}, [84]={4,-1}, [85]={4,-1}, [86]={4,-1}, [87]={4,-1}, [88]={4,-1}, [89]={4,-1}, [90]={4,-1}, [91]={4,-1}, [92]={4,-1}, [93]={4,-1}, [94]={4,-1}, [95]={4,-1}, [96]={4,-1}, [97]={4,-1}, [98]={4,-1}, [99]={4,-1} },
	[3] = { [0]={4,-1}, [1]={4,-1}, [2]={4,-1}, [3]={4,-1}, [4]={4,-1}, [5]={4,-1}, [6]={4,-1}, [7]={4,-1}, [8]={4,-1}, [9]={4,-1}, [10]={4,-1}, [11]={4,-1}, [12]={4,-1}, [13]={4,-1}, [14]={4,-1}, [15]={4,-1}, [16]={4,-1}, [17]={4,-1}, [18]={4,-1}, [19]={4,-1}, [20]={4,-1}, [21]={4,-1}, [22]={4,-1}, [23]={4,-1}, [24]={4,-1}, [25]={4,-1}, [26]={4,-1}, [27]={4,-1}, [28]={4,-1}, [29]={4,-1}, [30]={4,-1}, [31]={4,-1}, [32]={4,-1}, [33]={4,-1}, [34]={4,-1}, [35]={4,-1}, [36]={4,-1}, [37]={4,-1}, [38]={4,-1}, [39]={4,-1}, [40]={4,-1}, [41]={4,-1}, [42]={4,-1}, [43]={4,-1}, [44]={4,-1}, [45]={4,-1}, [46]={4,-1}, [47]={4,-1}, [48]={4,-1}, [49]={4,-1}, [50]={4,-1}, [51]={4,-1}, [52]={4,-1}, [53]={4,-1}, [54]={4,-1}, [55]={4,-1}, [56]={4,-1}, [57]={4,-1}, [58]={4,-1}, [59]={4,-1}, [60]={4,-1}, [61]={4,-1}, [62]={4,-1}, [63]={4,-1}, [64]={4,-1}, [65]={4,-1}, [66]={4,-1}, [67]={4,-1}, [68]={4,-1}, [69]={4,-1}, [70]={4,-1}, [71]={4,-1}, [72]={4,-1}, [73]={4,-1}, [74]={4,-1}, [75]={4,-1}, [76]={4,-1}, [77]={4,-1}, [78]={4,-1}, [79]={4,-1}, [80]={4,-1}, [81]={4,-1}, [82]={4,-1}, [83]={4,-1}, [84]={4,-1}, [85]={4,-1}, [86]={4,-1}, [87]={4,-1}, [88]={4,-1}, [89]={4,-1}, [90]={4,-1}, [91]={4,-1}, [92]={4,-1}, [93]={4,-1}, [94]={4,-1}, [95]={4,-1}, [96]={4,-1}, [97]={4,-1}, [98]={4,-1}, [99]={4,-1} },
	[4] = { [0]={4,-1}, [1]={4,-1}, [2]={4,-1}, [3]={4,-1}, [4]={4,-1}, [5]={4,-1}, [6]={4,-1}, [7]={4,-1}, [8]={4,-1}, [9]={4,-1}, [10]={4,-1}, [11]={4,-1}, [12]={4,-1}, [13]={4,-1}, [14]={4,-1}, [15]={4,-1}, [16]={4,-1}, [17]={4,-1}, [18]={4,-1}, [19]={4,-1}, [20]={4,-1}, [21]={4,-1}, [22]={4,-1}, [23]={4,-1}, [24]={4,-1}, [25]={4,-1}, [26]={4,-1}, [27]={4,-1}, [28]={4,-1}, [29]={4,-1}, [30]={4,-1}, [31]={4,-1}, [32]={4,-1}, [33]={4,-1}, [34]={4,-1}, [35]={4,-1}, [36]={4,-1}, [37]={4,-1}, [38]={4,-1}, [39]={4,-1}, [40]={4,-1}, [41]={4,-1}, [42]={4,-1}, [43]={4,-1}, [44]={4,-1}, [45]={4,-1}, [46]={4,-1}, [47]={4,-1}, [48]={4,-1}, [49]={4,-1}, [50]={4,-1}, [51]={4,-1}, [52]={4,-1}, [53]={4,-1}, [54]={4,-1}, [55]={4,-1}, [56]={4,-1}, [57]={4,-1}, [58]={4,-1}, [59]={4,-1}, [60]={4,-1}, [61]={4,-1}, [62]={4,-1}, [63]={4,-1}, [64]={4,-1}, [65]={4,-1}, [66]={4,-1}, [67]={4,-1}, [68]={4,-1}, [69]={4,-1}, [70]={4,-1}, [71]={4,-1}, [72]={4,-1}, [73]={4,-1}, [74]={4,-1}, [75]={4,-1}, [76]={4,-1}, [77]={4,-1}, [78]={4,-1}, [79]={4,-1}, [80]={4,-1}, [81]={4,-1}, [82]={4,-1}, [83]={4,-1}, [84]={4,-1}, [85]={4,-1}, [86]={4,-1}, [87]={4,-1}, [88]={4,-1}, [89]={4,-1}, [90]={4,-1}, [91]={4,-1}, [92]={4,-1}, [93]={4,-1}, [94]={4,-1}, [95]={4,-1}, [96]={4,-1}, [97]={4,-1}, [98]={4,-1}, [99]={4,-1} },
	[5] = { [0]={4,-1}, [1]={4,-1}, [2]={4,-1}, [3]={4,-1}, [4]={4,-1}, [5]={4,-1}, [6]={4,-1}, [7]={4,-1}, [8]={4,-1}, [9]={4,-1}, [10]={4,-1}, [11]={4,-1}, [12]={4,-1}, [13]={4,-1}, [14]={4,-1}, [15]={4,-1}, [16]={4,-1}, [17]={4,-1}, [18]={4,-1}, [19]={4,-1}, [20]={4,-1}, [21]={4,-1}, [22]={4,-1}, [23]={4,-1}, [24]={4,-1}, [25]={4,-1}, [26]={4,-1}, [27]={4,-1}, [28]={4,-1}, [29]={4,-1}, [30]={4,-1}, [31]={4,-1}, [32]={4,-1}, [33]={4,-1}, [34]={4,-1}, [35]={4,-1}, [36]={4,-1}, [37]={4,-1}, [38]={4,-1}, [39]={4,-1}, [40]={4,-1}, [41]={4,-1}, [42]={4,-1}, [43]={4,-1}, [44]={4,-1}, [45]={4,-1}, [46]={4,-1}, [47]={4,-1}, [48]={4,-1}, [49]={4,-1}, [50]={4,-1}, [51]={4,-1}, [52]={4,-1}, [53]={4,-1}, [54]={4,-1}, [55]={4,-1}, [56]={4,-1}, [57]={4,-1}, [58]={4,-1}, [59]={4,-1}, [60]={4,-1}, [61]={4,-1}, [62]={4,-1}, [63]={4,-1}, [64]={4,-1}, [65]={4,-1}, [66]={4,-1}, [67]={4,-1}, [68]={4,-1}, [69]={4,-1}, [70]={4,-1}, [71]={4,-1}, [72]={4,-1}, [73]={4,-1}, [74]={4,-1}, [75]={4,-1}, [76]={4,-1}, [77]={4,-1}, [78]={4,-1}, [79]={4,-1}, [80]={4,-1}, [81]={4,-1}, [82]={4,-1}, [83]={4,-1}, [84]={4,-1}, [85]={4,-1}, [86]={4,-1}, [87]={4,-1}, [88]={4,-1}, [89]={4,-1}, [90]={4,-1}, [91]={4,-1}, [92]={4,-1}, [93]={4,-1}, [94]={4,-1}, [95]={4,-1}, [96]={4,-1}, [97]={4,-1}, [98]={4,-1}, [99]={4,-1} },
	[6] = { [0]={4,-1}, [1]={4,-1}, [2]={4,-1}, [3]={4,-1}, [4]={4,-1}, [5]={4,-1}, [6]={4,-1}, [7]={4,-1}, [8]={4,-1}, [9]={4,-1}, [10]={4,-1}, [11]={4,-1}, [12]={4,-1}, [13]={4,-1}, [14]={4,-1}, [15]={4,-1}, [16]={4,-1}, [17]={4,-1}, [18]={4,-1}, [19]={4,-1}, [20]={4,-1}, [21]={4,-1}, [22]={4,-1}, [23]={4,-1}, [24]={4,-1}, [25]={4,-1}, [26]={4,-1}, [27]={4,-1}, [28]={4,-1}, [29]={4,-1}, [30]={4,-1}, [31]={4,-1}, [32]={4,-1}, [33]={4,-1}, [34]={4,-1}, [35]={4,-1}, [36]={4,-1}, [37]={4,-1}, [38]={4,-1}, [39]={4,-1}, [40]={4,-1}, [41]={4,-1}, [42]={4,-1}, [43]={4,-1}, [44]={4,-1}, [45]={4,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,5}, [78]={3,5}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[7] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={3,-1}, [5]={3,-1}, [6]={4,-1}, [7]={4,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,5}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[8] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={3,-1}, [5]={3,-1}, [6]={3,-1}, [7]={3,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,5}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[9] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={3,-1}, [5]={3,-1}, [6]={3,-1}, [7]={3,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,5}, [78]={3,5}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[10] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={3,-1}, [6]={3,-1}, [7]={3,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,5}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[11] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={3,-1}, [6]={3,-1}, [7]={3,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,5}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[12] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={3,-1}, [7]={3,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,-1}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[13] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={3,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,-1}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[14] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={3,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,-1}, [79]={3,5}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[15] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={3,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,-1}, [79]={3,-1}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[16] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,-1}, [79]={3,-1}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[17] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={3,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,-1}, [79]={3,-1}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[18] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={3,-1}, [63]={3,-1}, [64]={3,-1}, [65]={3,-1}, [66]={3,-1}, [67]={3,-1}, [68]={3,-1}, [69]={3,-1}, [70]={3,-1}, [71]={3,-1}, [72]={3,-1}, [73]={3,-1}, [74]={3,-1}, [75]={3,-1}, [76]={3,-1}, [77]={3,-1}, [78]={3,-1}, [79]={3,-1}, [80]={3,5}, [81]={3,5}, [82]={3,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[19] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={3,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={3,-1}, [61]={3,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={3,5}, [84]={3,5}, [85]={3,5}, [86]={3,5}, [87]={3,5}, [88]={3,5}, [89]={3,5}, [90]={3,5}, [91]={3,5}, [92]={3,5}, [93]={3,5}, [94]={3,5}, [95]={3,5}, [96]={3,5}, [97]={3,5}, [98]={3,5}, [99]={3,5} },
	[20] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={3,-1}, [11]={3,-1}, [12]={3,-1}, [13]={3,-1}, [14]={3,-1}, [15]={3,-1}, [16]={3,-1}, [17]={3,-1}, [18]={3,-1}, [19]={3,-1}, [20]={3,-1}, [21]={3,-1}, [22]={3,-1}, [23]={3,-1}, [24]={3,-1}, [25]={3,-1}, [26]={3,-1}, [27]={3,-1}, [28]={3,-1}, [29]={3,-1}, [30]={3,-1}, [31]={3,-1}, [32]={3,-1}, [33]={3,-1}, [34]={3,-1}, [35]={3,-1}, [36]={3,-1}, [37]={3,-1}, [38]={3,-1}, [39]={3,-1}, [40]={3,-1}, [41]={3,-1}, [42]={3,-1}, [43]={3,-1}, [44]={3,-1}, [45]={3,-1}, [46]={3,-1}, [47]={3,-1}, [48]={3,-1}, [49]={3,-1}, [50]={3,-1}, [51]={3,-1}, [52]={3,-1}, [53]={3,-1}, [54]={3,-1}, [55]={3,-1}, [56]={3,-1}, [57]={3,-1}, [58]={3,-1}, [59]={3,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[21] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={3,-1}, [11]={3,-1}, [12]={1,-1}, [13]={1,-1}, [14]={1,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,5}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[22] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={1,-1}, [12]={1,-1}, [13]={1,-1}, [14]={1,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[23] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={1,-1}, [13]={1,-1}, [14]={1,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[24] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={1,-1}, [13]={1,-1}, [14]={1,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[25] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={1,-1}, [14]={1,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[26] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={1,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[27] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={1,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,5}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[28] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[29] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={1,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,5}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[30] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[31] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={1,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,5}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[32] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[33] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={1,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,5}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[34] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[35] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,5}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[36] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[37] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={1,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[38] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,-1}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[39] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,-1}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[40] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={1,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,-1}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[41] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,-1}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[42] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,-1}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[43] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,-1}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[44] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,-1}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[45] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={1,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[46] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[47] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[48] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[49] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={1,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,5}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[50] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={1,-1}, [81]={1,-1}, [82]={1,5}, [83]={1,5}, [84]={1,5}, [85]={1,5}, [86]={1,5}, [87]={1,5}, [88]={1,5}, [89]={1,5}, [90]={1,5}, [91]={1,5}, [92]={1,5}, [93]={1,5}, [94]={1,5}, [95]={1,5}, [96]={1,5}, [97]={1,5}, [98]={1,5}, [99]={1,5} },
	[51] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={1,-1}, [23]={1,-1}, [24]={1,-1}, [25]={1,-1}, [26]={1,-1}, [27]={1,-1}, [28]={1,-1}, [29]={1,-1}, [30]={1,-1}, [31]={1,-1}, [32]={1,-1}, [33]={1,-1}, [34]={1,-1}, [35]={1,-1}, [36]={1,-1}, [37]={1,-1}, [38]={1,-1}, [39]={1,-1}, [40]={1,-1}, [41]={1,-1}, [42]={1,-1}, [43]={1,-1}, [44]={1,-1}, [45]={1,-1}, [46]={1,-1}, [47]={1,-1}, [48]={1,-1}, [49]={1,-1}, [50]={1,-1}, [51]={1,-1}, [52]={1,-1}, [53]={1,-1}, [54]={1,-1}, [55]={1,-1}, [56]={1,-1}, [57]={1,-1}, [58]={1,-1}, [59]={1,-1}, [60]={1,-1}, [61]={1,-1}, [62]={1,-1}, [63]={1,-1}, [64]={1,-1}, [65]={1,-1}, [66]={1,-1}, [67]={1,-1}, [68]={1,-1}, [69]={1,-1}, [70]={1,-1}, [71]={1,-1}, [72]={1,-1}, [73]={1,-1}, [74]={1,-1}, [75]={1,-1}, [76]={1,-1}, [77]={1,-1}, [78]={1,-1}, [79]={1,-1}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[52] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={0,-1}, [24]={0,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[53] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={0,-1}, [24]={0,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[54] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={0,-1}, [24]={0,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[55] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={0,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[56] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={0,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[57] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={0,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[58] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={0,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[59] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={0,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[60] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[61] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[62] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[63] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,5}, [91]={0,5}, [92]={0,5}, [93]={0,5}, [94]={0,5}, [95]={0,5}, [96]={0,5}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[64] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={0,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,5}, [89]={0,5}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,5}, [98]={0,5}, [99]={0,5} },
	[65] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,5}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[66] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,5}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[67] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,5}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[68] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,5}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[69] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,5}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[70] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={0,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,5}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[71] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,5}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[72] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[73] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,5}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[74] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,5}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[75] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,5}, [78]={0,5}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[76] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,5}, [76]={0,5}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[77] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,5}, [74]={0,5}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[78] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,5}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[79] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,5}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[80] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,5}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,5}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[81] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,5}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,5}, [69]={0,5}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[82] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,5}, [65]={0,5}, [66]={0,5}, [67]={0,5}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[83] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,-1}, [65]={0,5}, [66]={0,5}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[84] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={0,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,-1}, [65]={0,-1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[85] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,-1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[86] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={0,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[87] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[88] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={0,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[89] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[90] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,-1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[91] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={0,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[92] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={2,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,-1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[93] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={2,-1}, [31]={0,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[94] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={2,-1}, [31]={2,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[95] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={2,-1}, [31]={2,-1}, [32]={0,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,-1}, [63]={0,1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[96] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={2,-1}, [31]={2,-1}, [32]={2,-1}, [33]={0,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,1}, [63]={0,1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[97] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={2,-1}, [31]={2,-1}, [32]={2,-1}, [33]={2,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,1}, [63]={0,1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[98] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={2,-1}, [31]={2,-1}, [32]={2,-1}, [33]={2,-1}, [34]={0,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,-1}, [62]={0,1}, [63]={0,1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} },
	[99] = { [0]={2,-1}, [1]={2,-1}, [2]={2,-1}, [3]={2,-1}, [4]={2,-1}, [5]={2,-1}, [6]={2,-1}, [7]={2,-1}, [8]={2,-1}, [9]={2,-1}, [10]={2,-1}, [11]={2,-1}, [12]={2,-1}, [13]={2,-1}, [14]={2,-1}, [15]={2,-1}, [16]={2,-1}, [17]={2,-1}, [18]={2,-1}, [19]={2,-1}, [20]={2,-1}, [21]={2,-1}, [22]={2,-1}, [23]={2,-1}, [24]={2,-1}, [25]={2,-1}, [26]={2,-1}, [27]={2,-1}, [28]={2,-1}, [29]={2,-1}, [30]={2,-1}, [31]={2,-1}, [32]={2,-1}, [33]={2,-1}, [34]={2,-1}, [35]={0,-1}, [36]={0,-1}, [37]={0,-1}, [38]={0,-1}, [39]={0,-1}, [40]={0,-1}, [41]={0,-1}, [42]={0,-1}, [43]={0,-1}, [44]={0,-1}, [45]={0,-1}, [46]={0,-1}, [47]={0,-1}, [48]={0,-1}, [49]={0,-1}, [50]={0,-1}, [51]={0,-1}, [52]={0,-1}, [53]={0,-1}, [54]={0,-1}, [55]={0,-1}, [56]={0,-1}, [57]={0,-1}, [58]={0,-1}, [59]={0,-1}, [60]={0,-1}, [61]={0,1}, [62]={0,1}, [63]={0,1}, [64]={0,1}, [65]={0,1}, [66]={0,1}, [67]={0,1}, [68]={0,1}, [69]={0,1}, [70]={0,1}, [71]={0,1}, [72]={0,1}, [73]={0,1}, [74]={0,1}, [75]={0,1}, [76]={0,1}, [77]={0,1}, [78]={0,1}, [79]={0,1}, [80]={0,1}, [81]={0,1}, [82]={0,1}, [83]={0,1}, [84]={0,1}, [85]={0,1}, [86]={0,1}, [87]={0,1}, [88]={0,1}, [89]={0,1}, [90]={0,1}, [91]={0,1}, [92]={0,1}, [93]={0,1}, [94]={0,1}, [95]={0,1}, [96]={0,1}, [97]={0,1}, [98]={0,1}, [99]={0,1} }
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
	a.index = index or space:GetIndex(x, y)
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
	a.onRiverMile = {}
	a.plot = Map.GetPlotByIndex(a.index-1)
	if space.useMapLatitudes then
		if space.wrapX then
			a.latitude = space:GetPlotLatitude(a.plot)
		else
			a.latitude = space:RealmLatitude(y)
		end
	end
end)

function Hex:Place(relax)
	self.subPolygon = self:ClosestSubPolygon()
	tInsert(self.subPolygon.hexes, self)
end

function Hex:InsidePolygon(polygon)
	if self.x < polygon.minX then polygon.minX = self.x end
	if self.y < polygon.minY then polygon.minY = self.y end
	if self.x > polygon.maxX then polygon.maxX = self.x end
	if self.y > polygon.maxY then polygon.maxY = self.y end
	if self.latitude then
		if self.latitude < polygon.minLatitude then polygon.minLatitude = self.latitude end
		if self.latitude > polygon.maxLatitude then polygon.maxLatitude = self.latitude end
	end
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
	return self.space:ClosestThing(self, self.space.subPolygons, self.space.totalSubPolygons)
end

function Hex:Unstrand()
	local anybodyFriendly
	local others = {}
	for direction, nhex in pairs(self:Neighbors()) do -- 3 and 4 are are never there yet?
		if nhex.subPolygon == self.subPolygon then
			anybodyFriendly = true
		else
			tInsert(others, nhex.subPolygon)
		end
	end
	if not anybodyFriendly and #self.subPolygon.hexes > 1 then
		-- EchoDebug(self.x, self.y)
		self.stranded = true -- for debugging purposes. the idea is this is no longer stranded
		for i = #self.subPolygon.hexes, 1, -1 do
			local hex = self.subPolygon.hexes[i]
			if hex == self then
				tRemove(self.subPolygon.hexes, i)
				break
			end
		end
		self.subPolygon = tGetRandom(others)
		tInsert(self.subPolygon.hexes, self)
		return true
	end
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
	-- if self.polygon.oceanIndex then self.featureType = featureAtoll end -- uncomment to debug ocean rifts
	-- if self.polygon.astronomyBlob then self.featureType = featureFallout end -- uncomment to debug astronomy blobs
	-- if self.polygon.astronomyIndex < 100 then self.featureType = featureReef end -- uncomment to debug astronomy basins
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
	if self.subPolygon.nuked and self.plotType ~= plotOcean and (self.improvementType == improvementCityRuins or mRandom(1, 100) < 67) then
		self.featureType = featureFallout
	end
	if self.polygon.nuked and not self.subPolygon.nuked and self.plotType ~= plotOcean and mRandom(1, 100) < 33 then
		self.featureType = featureFallout
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
	self.plot:SetRouteType(routeRoad)
	EchoDebug("routeType " .. routeRoad .. " at " .. self.x .. "," .. self.y)
end

function Hex:SetImprovement()
	if self.plot == nil then return end
	if not self.improvementType then return end
	EchoDebug("improvementType " .. self.improvementType .. " at " .. self.x .. "," .. self.y)
	self.plot:SetImprovementType(self.improvementType)
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

function Hex:CanBeReef()
	if self.polygon.continent then return end
	if self.polygon.oceanIndex then return end
	if self.y == 0 or self.y == self.space.h then return end
	if not self.space.wrapX and (self.x == 0 or self.x == self.space.w) then return end
	if self.terrainType ~= terrainCoast and self.terrainType ~= terrainOcean then
		return
	end
	if self.featureType == featureIce then return end
	if self.polygon.oceanTemperature and self.polygon.oceanTemperature < self.space.avgOceanTemp * 0.8 then return end
	local coastCount = 0
	for i, neighHex in pairs(self:Neighbors()) do
		if neighHex.polygon.continent then return end
		if neighHex.polygon.oceanIndex then return end
		if neighHex.plot:GetFeatureType() >= 7 then return end -- next to a wonder 
		if neighHex.terrainType ~= terrainCoast and neighHex.terrainType ~= terrainOcean then
			return
		end
		if neighHex.featureType == featureIce then return end
		if neighHex.terrainType == terrainCoast then
			coastCount = coastCount + 1
		end
	end
	if coastCount < 3 then return end
	local secondReefHexes = {}
	local landCount = 0
	for i, neighHex in pairs(self:Neighbors()) do
		local okay = true
		for ii, nnHex in pairs(neighHex:Neighbors()) do
			if nnHex ~= self then
				if nnHex.terrainType ~= terrainOcean and nnHex.terrainType ~= terrainCoast then
					landCount = landCount + 1
				end
				if nnHex.polygon.continent or (nnHex.terrainType ~= terrainCoast and nnHex.terrainType ~= terrainOcean) or nnHex.featureType == featureIce then
					okay = false
				end
			end
		end
		if okay then
			tInsert(secondReefHexes, neighHex)
		end
	end
	if landCount == 0 then return end
	if #secondReefHexes == 0 then return end
	EchoDebug("found place for reef", self:Locate())
	return tGetRandom(secondReefHexes)
end

function Hex:CanBeVolcano()
	if self.polygon.continent then return end
	if self.polygon.oceanIndex then return end
	if self.y == 0 or self.y == self.space.h then return end
	if not self.space.wrapX and (self.x == 0 or self.x == self.space.w) then return end
	if self.terrainType ~= terrainCoast and self.terrainType ~= terrainGrass and self.terrainType ~= terrainOcean then
		return
	end
	if self.featureType == featureIce then return end
	if self.polygon.oceanTemperature and self.polygon.oceanTemperature < self.space.avgOceanTemp * 0.8 then return end
	for i, neighHex in pairs(self:Neighbors()) do
		if neighHex.polygon.continent then return end
		if neighHex.polygon.oceanIndex then return end
		if neighHex.plot:GetFeatureType() >= 7 then return end -- next to a wonder 
		if neighHex.terrainType ~= terrainCoast and neighHex.terrainType ~= terrainOcean then
			return
		end
		if neighHex.featureType == featureIce then return end
	end
	EchoDebug("found place for krakatoa", self:Locate())
	return true
end

function Hex:PlaceNaturalWonder(featureType, pairedHex)
	if featureType == featureVolcano then
		self.terrainType = terrainGrass
		self.plot:SetTerrainType(terrainGrass)
		for i, neighHex in pairs(self:Neighbors()) do
			neighHex.terrainType = terrainCoast
			neighHex.plot:SetTerrainType(terrainCoast)
		end
	elseif featureType == featureReef then
		self.terrainType = terrainCoast
		self.plot:SetTerrainType(terrainCoast)
		pairedHex.terrainType = terrainCoast
		pairedHex.plot:SetTerrainType(terrainCoast)
		pairedHex.featureType = featureType
		pairedHex.plot:SetFeatureType(featureType)
	end
	self.featureType = featureType
	self.plot:SetFeatureType(featureType)
end

function Hex:PlaceNaturalWonderPossibly(featureType)
	if self.y == 0 or self.y == self.space.h then return end
	if not self.space.wrapX and (self.x == 0 or self.x == self.space.w) then return end
	if self.plot:GetFeatureType() >= 7 then return end -- it's already a natural wonder
	if self.plot:GetResourceType(-1) ~= -1 then return end -- it has resources on it
	local placeIt = false
	if featureType == featureReef then
		placeIt = self:CanBeReef()
	elseif featureType == featureVolcano then
		placeIt = self:CanBeVolcano()
	end
	if placeIt then
		self:PlaceNaturalWonder(featureType, placeIt)
		return true
	end
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
	a.minLatitude = 90
	a.maxLatitude = 0
end)

function Polygon:FloodFillAstronomy(astronomyIndex)
	if self.oceanIndex or self.nearOcean then
		self.astronomyIndex = (self.oceanIndex or self.nearOcean) + 100
		return nil
	end
	if self.astronomyIndex then return nil end
	self.astronomyIndex = astronomyIndex
	self.space.astronomyBasins[astronomyIndex] = self.space.astronomyBasins[astronomyIndex] or {}
	tInsert(self.space.astronomyBasins[astronomyIndex], self)
	for i, neighbor in pairs(self.neighbors) do
		neighbor:FloodFillAstronomy(astronomyIndex)
	end
	return true
end

function Polygon:PatchContinent()
	if self.continent then return end
	local continent
	for i, neighbor in pairs(self.neighbors) do
		continent = neighbor.continent
		if continent then break end
	end
	self.continent = continent
	tInsert(continent, self)
end

function Polygon:RemoveFromContinent()
	if not self.continent then return end
	for i, poly in pairs(self.continent) do
		if poly == self then
			tRemove(self.continent, i)
			break
		end
	end
	self.continent = nil
end

function Polygon:FloodFillToWholeContinent(searched, floodFound, sea)
	searched = searched or {}
	if searched[self] then return end
	searched[self] = true
	if not self.continent then return end
	floodFound = floodFound or {}
	tInsert(floodFound, self)
	for i, neighbor in pairs(self.neighbors) do
		sea = sea or neighbor.sea
		neighbor:FloodFillToWholeContinent(searched, floodFound, sea)
	end
	return floodFound, sea
end

function Polygon:FloodFillToOcean(searched)
	searched = searched or {}
	if searched[self] then return end
	searched[self] = true
	if self.continent then return end
	if self.oceanIndex then return self.oceanIndex end
	if self.topY or self.bottomY then return -2 end
	if not self.space.wrapX and (self.topX or self.bottomX) then return -3 end
	for i, neighbor in pairs(self.neighbors) do
		local oceanIndex = neighbor:FloodFillToOcean(searched)
		if oceanIndex then return oceanIndex end
	end
end

function Polygon:FloodFillSea(sea)
	if sea and #sea.polygons >= sea.maxPolygons then return end
	if self.sea or not self.continent then return end
	if (not self.space.wrapY and (self.topY or self.bottomY)) or ((not self.space.wrapX or (self.space.oceanNumber == -1 and self.space.inlandSeasMax == 1)) and (self.topX or self.bottomX)) then return end
	for i, neighbor in pairs(self.neighbors) do
		if neighbor.continent ~= self.continent or (sea and neighbor.sea ~= nil and neighbor.sea ~= sea) then
			return
		end
	end
	sea = sea or { polygons = {}, inland = true, astronomyIndex = self.astronomyIndex, continent = self.continent, maxPolygons = mCeil(#self.continent * self.space.inlandSeaContinentRatio) }
	self.sea = sea
	tInsert(sea.polygons, self)
	for i, neighbor in pairs(self.neighbors) do
		neighbor:FloodFillSea(sea)
	end
	return sea
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
	if self.hexes then self.hexes = {} end
	if self.subPolygons then self.subPolygons = {} end
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
	if y == 1 and self.y < space.halfHeight then
		self.betaBottomY = true
	end
	if y == space.h-1 and self.y >= space.halfHeight then
		self.betaTopY = true
	end
	if self.space.useMapLatitudes and self.space.polarExponent >= 1.0 and hex.latitude > 89 then
		self.polar = true
	end
	self.edgeY = self.bottomY or self.topY
	self.edgeX = self.bottomX or self.topX
	if self.edgeY then
		tInsert(space.edgeYPolygons, self)
	end
	if self.edgeX then
		tInsert(space.edgeXPolygons, self)
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

function Polygon:Flop(superPolygon)
	for ii, subPoly in pairs(self.superPolygon.subPolygons) do
		if subPoly == self then
			tRemove(self.superPolygon.subPolygons, ii)
			break
		end
	end
	self.superPolygon = superPolygon
	tInsert(superPolygon.subPolygons, self)
	self.flopped = true
	self.space.flopCount = (self.space.flopCount or 0) + 1
end

function Polygon:PickTinyIslands()
	if (self.bottomX or self.topX) and self.oceanIndex and not self.space.wrapX then return end
	if (self.bottomY or self.topY) and self.oceanIndex and not self.space.wrapX then return end
	local subPolyBuffer = tDuplicate(self.subPolygons)
	while #subPolyBuffer > 0 do
		local subPolygon = tRemoveRandom(subPolyBuffer)
		local tooCloseForIsland = self.space.wrapX and (subPolygon.bottomY or subPolygon.topY) and mRandom(0, 100) > self.space.polarMaxLandPercent
		if not tooCloseForIsland then
			for i, neighbor in pairs(subPolygon.neighbors) do
				if (neighbor.superPolygon.oceanIndex and not self.oceanIndex) or (not neighbor.superPolygon.oceanIndex and self.oceanIndex) or neighbor.tinyIsland or neighbor.superPolygon.continent then
					tooCloseForIsland = true
					break
				end
				for nn, neighneigh in pairs(neighbor.neighbors) do
					if (neighneigh.superPolygon.oceanIndex and not self.oceanIndex) or (not neighneigh.superPolygon.oceanIndex and self.oceanIndex) then
						tooCloseForIsland = true
						break
					end
				end
				if tooCloseForIsland then break end
			end
		end
		local chance = self.space.tinyIslandChance
		if self.oceanIndex or self.loneCoastal then chance = chance * 2 end
		if not tooCloseForIsland and Map.Rand(100, "tiny island chance") < chance then
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

function Polygon:GiveTemperatureRainfall()
	self.temperature = self.space:GetTemperature()
	self.rainfall = self.space:GetRainfall()
end

function Polygon:GiveFakeLatitude(latitude)
	if not latitude then
		if self.superPolygon and self.superPolygon.fakeSubLatitudes and #self.superPolygon.fakeSubLatitudes > 0 then
			self.latitude = tRemoveRandom(self.superPolygon.fakeSubLatitudes)
		elseif not self.superPolygon then
			if self.continent and #self.space.continentalFakeLatitudes > 0 then
				self.latitude = tRemoveRandom(self.space.continentalFakeLatitudes)
			elseif #self.space.nonContinentalFakeLatitudes > 0 then
				self.latitude = tRemoveRandom(self.space.nonContinentalFakeLatitudes)
			else
				self.latitude = mRandom(0, 90)
			end
		else
			return
		end
	else
		self.latitude = latitude
	end
	self.minLatitude = self.latitude + ((self.minY - self.y) * self.space.yFakeLatitudeConversion)
	self.maxLatitude = self.latitude + ((self.maxY - self.y) * self.space.yFakeLatitudeConversion)
	self.minLatitude = mMin(90, mMax(0, self.minLatitude))
	self.maxLatitude = mMin(90, mMax(0, self.maxLatitude))
	if self.maxLatitude == 90 and self.superPolygon then
		if self.superPolygon.continent and mRandom() > self.space.polarMaxLandRatio then
			local latitudeDist = 90 - self.superPolygon.latitude 
			local upperBound = mMax(0, 80 - latitudeDist)
			self.superPolygon:GiveFakeLatitude(mRandom(0, upperBound))
			return
		else
			self.polar, self.superPolygon.polar = true, true
		end
	end

	self.latitudeRange = self.maxLatitude - self.minLatitude
	self.fakeSubLatitudes = {}
	local count
	if self.superPolygon then count = #self.hexes else count = #self.subPolygons end
	if count == 1 then
		self.fakeSubLatitudes = { (self.minLatitude + self.maxLatitude) / 2 }
	else
		local lInc = self.latitudeRange / (count - 1)
		for i = 1, count do
			local lat = self.minLatitude + ((i-1) * lInc)
			tInsert(self.fakeSubLatitudes, lat)
		end
	end
	if self.superPolygon then
		for i, hex in pairs(self.hexes) do
			hex.latitude = tRemoveRandom(self.fakeSubLatitudes)
		end
	else
		for i, subPolygon in pairs(self.subPolygons) do
			subPolygon:GiveFakeLatitude()
		end
	end
end

------------------------------------------------------------------------------

SubEdge = class(function(a, polygon1, polygon2)
	a.space = polygon1.space
	a.polygons = { polygon1, polygon2 }
	a.hexes = {}
	a.pairings = {}
	a.connections = {}
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
	hex.subEdges[self], pairHex.subEdges[self] = true, true
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
	for neighbor, yes in pairs(mutual) do
		for p, polygon in pairs(self.polygons) do
			local subEdge = neighbor.subEdges[polygon] or polygon.subEdges[neighbor]
			self.connections[subEdge] = true
			subEdge.connections[self] = true
		end
	end
end

------------------------------------------------------------------------------

Edge = class(function(a, polygon1, polygon2)
	a.space = polygon1.space
	a.polygons = { polygon1, polygon2 }
	a.subEdges = {}
	a.connections = {}
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

function Edge:FindConnections()
	local cons = 0
	for i, subEdge in pairs(self.subEdges) do
		for cedge, yes in pairs(subEdge.connections) do
			if cedge.superEdge and cedge.superEdge ~= self then
				self.connections[cedge.superEdge] = true
				cedge.superEdge.connections[self] = true
				cons = cons + 1
			end
		end
	end
	-- EchoDebug(cons .. " edge connections")
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


function Region:GiveLatitude()
	if self.latitude then return end
	self.representativePolygon = tGetRandom(self.polygons)
	self.latitude = self.representativePolygon.latitude
	self.minLatitude, self.maxLatitude = self.representativePolygon.minLatitude, self.representativePolygon.maxLatitude
	for i, polygon in pairs(self.polygons) do
		if polygon.minLatitude < self.minLatitude then
			self.minLatitude = polygon.minLatitude
		end
		if polygon.maxLatitude > self.maxLatitude then
			self.maxLatitude = polygon.maxLatitude
		end
	end
end

function Region:GiveParameters()
	self.blockFeatures = {}
	for featureType, feature in pairs(FeatureDictionary) do
		if feature.metaPercent then
			self.blockFeatures[featureType] = mRandom(1, 100) > feature.metaPercent
		end
	end
	-- get latitude (real or fake)
	self:GiveLatitude()
	self.hillyness = self.space:GetHillyness()
	self.mountainous = mRandom(1, 100) < self.space.mountainousRegionPercent
	self.mountainousness = 0
	if self.mountainous then self.mountainousness = mRandom(self.space.mountainousnessMin, self.space.mountainousnessMax) end
	self.lakey = #self.space.lakeSubPolygons < self.space.minLakes
	self.lakeyness = 0
	if self.lakey then self.lakeyness = mRandom(self.space.lakeynessMin, self.space.lakeynessMax) end
	self.marshy = self.space.marshHexCount < self.space.marshMinHexes
	self.marshyness = 0
	if self.marshy then self.marshyness = mRandom(self.space.marshynessMin, self.space.marshynessMax) end
end

function Region:CreateCollection()
	self:GiveParameters()
	-- determine collection size
	self.size = self.space:GetCollectionSize()
	local subPolys = 0
	for i, polygon in pairs(self.polygons) do
		if polygon.polar then self.polar = true end
		subPolys = subPolys + #polygon.subPolygons
	end
	self.size = mMin(self.size, subPolys) -- make sure there aren't more collections than subpolygons in the region
	self.size = mMin(self.size, #self.point.pixels) -- make sure there aren't more collections than climate pixels
	-- divide pixels into subvoronoi
	local pixelBuffer = tDuplicate(self.point.pixels)
	local subPoints = {}
	for i = 1, self.size do
		local pixel = tRemoveRandom(pixelBuffer)
		local subPoint = {temp = pixel.temp, rain = pixel.rain}
		tInsert(subPoints, subPoint)
	end
	for i, pixel in pairs(self.point.pixels) do
		local bestDist, bestPoint
		for ii, subPoint in pairs(subPoints) do
			local dt = mAbs(pixel.temp - subPoint.temp)
			local dr = mAbs(pixel.rain - subPoint.rain)
			local dist = (dt * dt) + (dr * dr)
			if not bestDist or dist < bestDist then
				bestDist = dist
				bestPoint = subPoint
			end
		end
		bestPoint.pixels = bestPoint.pixels or {}
		tInsert(bestPoint.pixels, pixel)
	end
	-- create collection
	local collection = {}
	self.totalSize = 0
	local hasPolar = false
	for i, subPoint in pairs(subPoints) do
		local elements = {}
		local polar
		local lake = i > 1 and mRandom(1, 100) < self.lakeyness
		local subSize = mMin(self.space:GetSubCollectionSize(), #subPoint.pixels)
		local subPixelBuffer = tDuplicate(subPoint.pixels)
		for ii = 1, subSize do
			local pixel = tRemoveRandom(subPixelBuffer)
			local element = self:CreateElement(pixel.temp, pixel.rain, lake)
			if element.terrainType == terrainSnow then
				polar = true
				hasPolar = true
			end
			tInsert(elements, element)
			self.totalSize = self.totalSize + 1
		end
		local subCollection = { elements = elements, polar = polar, lake = lake, temperature = subPoint.temp, rainfall = subPoint.rain }
		tInsert(collection, subCollection)
	end
	if self.polar and not hasPolar then
		EchoDebug("provide a polar subcollection")
		local rainPixel = tGetRandom(self.point.pixels)
		local elements = { self:CreateElement(0, rainPixel.rain) }
		local subSize = self.space:GetSubCollectionSize()
		if subSize > 1 then
			for i = 2, subSize do
				local rainPixel = tGetRandom(self.point.pixels)
				local element = self:CreateElement(0, rainPixel.rain)
				tInsert(elements, element)
			end
		end
		local subCollection = { elements = elements, polar = true, lake = false, temperature = 0, rainfall = rainPixel.rain }
		tInsert(collection, subCollection)
	end
	self.collection = collection
end

function Region:CreateElement(temperature, rainfall, lake)
	temperature = temperature or mRandom(self.temperatureMin, self.temperatureMax)
	rainfall = rainfall or mRandom(self.rainfallMin, self.rainfallMax)
	local mountain = mRandom(1, 100) < self.mountainousness
	local hill = mRandom(1, 100) < self.hillyness
	local marsh = not hill and not mountain and mRandom(1, 100) < self.marshyness
	if lake then
		mountain = false
		hill = false
	end
	temperature = mFloor(temperature)
	rainfall = mFloor(rainfall)
	local bestTerrain = self.space:NearestTempRainThing(temperature, rainfall, TerrainDictionary)
	local featureList = {}
	for i, featureType in pairs(bestTerrain.features) do
		if FeatureDictionary[featureType] then
			if not FeatureDictionary[featureType].disabled then
				tInsert(featureList, FeatureDictionary[featureType])
			end
			if featureType == featureMarsh and marsh then
				featureList = { FeatureDictionary[featureMarsh] }
				break
			end
		end
	end
	local bestFeature
	if #featureList == 1 then
		bestFeature = featureList[1]
	else
		bestFeature = self.space:NearestTempRainThing(temperature, rainfall, featureList, 2)
	end
	if bestFeature == nil or self.blockFeatures[bestFeature.featureType] or mRandom(1, 100) > bestFeature.percent then bestFeature = FeatureDictionary[bestTerrain.features[1]] end -- default to the first feature in the list
	if bestFeature.featureType == featureNone and bestTerrain.specialFeature then
		local sFeature = FeatureDictionary[bestTerrain.specialFeature]
		if mRandom(1, 100) < sFeature.percent then bestFeature = sFeature end
	end
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
	return { plotType = plotType, terrainType = terrainType, featureType = featureType, temperature = temperature, rainfall = rainfall, lake = lake }
end

function Region:Fill()
	local filledHexes = {}
	for i, polygon in pairs(self.polygons) do
		for spi, subPolygon in pairs(polygon.subPolygons) do
			local subCollection = tGetRandom(self.collection)
			if subPolygon.polar ~= subCollection.polar then
				local subCollectionBuffer = tDuplicate(self.collection)
				repeat
					-- EchoDebug(i, spi, "looking for polar subcoll")
					subCollection = tRemoveRandom(subCollectionBuffer)
				until #subCollectionBuffer == 0 or subPolygon.polar == subCollection.polar
			end
			if subCollection.lake then
				local doNotLake = subPolygon.topY or subPolygon.bottomY or ((subPolygon.topX or subPolygon.bottomX) and not self.space.wrapX)
				if not doNotLake then
					for ni, neighbor in pairs(subPolygon.neighbors) do
						if not neighbor.superPolygon.continent or neighbor.lake then
							-- can't have a lake that's actually a part of the ocean or inland sea
							doNotLake = true
							-- EchoDebug("can't have a lake next to a lake or the ocean")
							break
						end
					end
				end
				if doNotLake then
					-- EchoDebug("cannot lake here")
					local subCollectionBuffer = tDuplicate(self.collection)
					repeat
						subCollection = tRemoveRandom(subCollectionBuffer)
					until not subCollection.lake or #subCollectionBuffer == 0
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
					if hex.featureType == featureMarsh then self.space.marshHexCount = self.space.marshHexCount + 1 end
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
	a.wrapY = false -- globe wraps vertically? (not possible, but this remains hopeful)
	a.polygonCount = 200 -- how many polygons (map scale)
	a.relaxations = 1 -- how many lloyd relaxations (higher number is greater polygon uniformity)
	a.subPolygonCount = 1700 -- how many subpolygons
	a.subPolygonFlopPercent = 10 -- out of 100 subpolygons, how many flop to another polygon
	a.subPolygonRelaxations = 0 -- how many lloyd relaxations for subpolygons (higher number is greater polygon uniformity, also slower)
	a.oceanNumber = 2 -- how many large ocean basins
	a.astronomyBlobNumber = 0
	a.astronomyBlobMinPolygons = 10
	a.astronomyBlobMaxPolygons = 20
	a.astronomyBlobsMustConnectToOcean = false
	a.majorContinentNumber = 1 -- how many large continents per astronomy basin
	a.islandRatio = 0.25 -- what part of the continent polygons are taken up by 1-3 polygon continents
	a.polarMaxLandRatio = 0.5 -- how much of the land in each astronomy basin can be at the poles
	a.useMapLatitudes = false -- should the climate have anything to do with latitude?
	a.collectionSizeMin = 2 -- of how many groups of kinds of tiles does a region consist, at minimum
	a.collectionSizeMax = 3 -- of how many groups of kinds of tiles does a region consist, at maximum
	a.subCollectionSizeMin = 2 -- of how many kinds of tiles does a group consist, at minimum (modified by map size)
	a.subCollectionSizeMax = 4 -- of how many kinds of tiles does a group consist, at maximum (modified by map size)
	a.regionSizeMin = 1 -- least number of polygons a region can have
	a.regionSizeMax = 3 -- most number of polygons a region can have (but most will be limited by their area, which must not exceed half the largest polygon's area)
	a.climateVoronoiRelaxations = 3 -- number of lloyd relaxations for a region's temperature/rainfall. higher number means less region internal variation
	a.riverLandRatio = 0.19 -- how much of the map to have tiles next to rivers. is modified by global rainfall
	a.riverForkRatio = 0.33 -- how much of the river area should be reserved for forks
	a.hillChance = 3 -- how many possible mountains out of ten become a hill when expanding and reducing
	a.mountainRangeMaxEdges = 4 -- how many polygon edges long can a mountain range be
	a.coastRangeRatio = 0.33 -- what ratio of the total mountain ranges should be coastal
	a.mountainRatio = 0.04 -- how much of the land to be mountain tiles
	a.mountainRangeMult = 1.3 -- higher mult means more (globally) scattered mountain ranges
	a.mountainSubPolygonMult = 2 -- higher mult means more (globally) scattered subpolygon mountain clumps
	a.mountainTinyIslandMult = 12
	a.coastalPolygonChance = 1 -- out of ten, how often do water polygons become coastal?
	a.tinyIslandChance = 15 -- out of 100 possible subpolygons, how often do coastal shelves produce tiny islands
	a.freezingTemperature = 19 -- this temperature and below creates ice. temperature is 0 to 100
	a.atollTemperature = 75 -- this temperature and above creates atolls
	a.atollPercent = 4 -- of 100 hexes, how often does atoll temperature produce atolls
	a.polarExponent = 1.2 -- exponent. lower exponent = smaller poles (somewhere between 0 and 2 is advisable)
	a.rainfallMidpoint = 49.5 -- 25 means rainfall varies from 0 to 50, 75 means 50 to 100, 50 means 0 to 100.
	a.temperatureMin = 0 -- lowest temperature possible (plus or minus temperatureMaxDeviation)
	a.temperatureMax = 99 -- highest temperature possible (plus or minus temperatureMaxDeviation)
	a.hillynessMax = 40 -- of 100 how many of a region's tile collection can be hills
	a.mountainousRegionPercent = 3 -- of 100 how many regions will have mountains
	a.mountainousnessMin = 33 -- in those mountainous regions, what's the minimum percentage of mountains in their collection
	a.mountainousnessMax = 66 -- in those mountainous regions, what's the maximum percentage of mountains in their collection
	-- all lake variables scale with global rainfall in Compute()
	a.lakeMinRatio = 0.0065 -- below this fraction of filled subpolygos that are lakes will cause a region to become lakey
	a.lakeynessMin = 5 -- in those lake regions, what's the minimum percentage of water in their collection
	a.lakeynessMax = 50 -- in those lake regions, what's the maximum percentage of water in their collection
	a.marshynessMin = 5
	a.marshynessMax = 50
	a.marshMinHexRatio = 0.015
	a.inlandSeaContinentRatio = 0.02 -- maximum size of each inland sea as a fraction of the polygons of the continent they're inside
	a.inlandSeasMax = 1 -- maximum number of inland seas
	a.ancientCitiesCount = 3
	a.falloutEnabled = false -- place fallout on the map?
	a.postApocalyptic = false -- place fallout around ancient cities
	a.contaminatedWater = false -- place fallout in rainy areas and along rivers?
	a.contaminatedSoil = false -- place fallout in dry areas and in mountains?
	a.mapLabelsEnabled = false -- add place names to the map?
	a.regionLabelsMax = 10 -- maximum number of labelled regions
	a.rangeLabelsMax = 5 -- maximum number of labelled mountain ranges (descending length)
	a.riverLabelsMax = 5 -- maximum number of labelled rivers (descending length)
	a.tinyIslandLabelsMax = 5 -- maximum number of labelled tiny islands
	a.subPolygonLabelsMax = 5 -- maximum number of labelled subpolygons (bays, straights)
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
	a.edgeYPolygons = {}
	a.edgeXPolygons = {}
	a.hexes = {}
    a.mountainHexes = {}
    a.mountainCoreHexes = {}
    a.tinyIslandPolygons = {}
    a.tinyIslandSubPolygons = {}
    a.deepHexes = {}
    a.lakeSubPolygons = {}
    a.inlandSeas = {}
    a.rivers = {}
end)

function Space:SetOptions(optDict)
	local keySetByOption = {}
	for optionNumber, option in ipairs(optDict) do
		local optionChoice = Map.GetCustomOption(optionNumber)
		if option.values[optionChoice].values == "keys" then
			if option.values[optionChoice].randomKeys then
				optionChoice = tGetRandom(option.values[optionChoice].randomKeys)
			else
				optionChoice = mRandom(1, #option.values-1)
			end
		elseif option.values[optionChoice].values == "values" then
			local lowValues =  option.values[optionChoice].lowValues or option.values[1].values
			local highValues = option.values[optionChoice].highValues or option.values[#option.values-1].values
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
		if option.values[optionChoice].values[1] == nil then
			-- each value already has a string-key
			for key, value in pairs(option.values[optionChoice].values) do
				EchoDebug(option.name, option.values[optionChoice].name, key, value)
				self[key] = value
				keySetByOption[key] = true
			end
		else
			-- each value is listed in order of the option's listed keys
	 		for valueNumber, key in ipairs(option.keys) do
				EchoDebug(option.name, option.values[optionChoice].name, key, option.values[optionChoice].values[valueNumber])
				local val = option.values[optionChoice].values[valueNumber]
				if val == nil then
					if type(self[key]) == "number" then
						val = self[key]
					end
				end
				self[key] = val
				keySetByOption[key] = true
			end
		end
	end
	-- for key, value in pairsByKeys(self) do
	-- 	if not keySetByOption[key] and type(value) ~= "table" then
	-- 		EchoDebug(key, value)
	-- 	end
	-- end
end

function Space:DoCentuariIfActivated()
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
			climateGrid = nil
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
end

function Space:PrintClimate()
	-- print out temperature/rainfall voronoi
	local terrainChars = {
		[terrainGrass] = "+",
		[terrainPlains] = '|',
		[terrainDesert] = "~",
		[terrainTundra] = "<",
		[terrainSnow] = "$",
		[terrainCoast] = "C",
		[terrainOcean] = "O",
	}
	local featureChars = {
		[featureNone] = " ",
		[featureForest] = "^",
		[featureJungle] = "%",
		[featureMarsh] = "_",
		[featureIce] = "*",
		[featureFallout] = "@",
		[featureOasis] = "&",
	}
	local terrainLatitudeAreas = {}
	local latitudesByTempRain = {}
	local line = ""
	local numLine = ""
	for l = 0, 90, 1 do
		local t, r = self:GetTemperature(l), self:GetRainfall(l)
		latitudesByTempRain[mFloor(t) .. " " .. mFloor(r)] = l
		numLine = numLine .. mMax(0, mFloor((t-1)/10)) .. mMax(0, mFloor((r-1)/10))
		local terrain = self:NearestTempRainThing(t, r, TerrainDictionary)
		if terrain then
			local terrainType = terrain.terrainType
			local featureList = {}
			for i, featureType in pairs(terrain.features) do
				tInsert(featureList, FeatureDictionary[featureType])
			end
			local feature = self:NearestTempRainThing(t, r, featureList, 2) or FeatureDictionary[featureNone]
			if feature.percent == 0 then feature = FeatureDictionary[featureNone] end
			if terrainLatitudeAreas[terrainType] == nil then terrainLatitudeAreas[terrainType] = 0 end
			terrainLatitudeAreas[terrainType] = terrainLatitudeAreas[terrainType] + 1
			line = line .. terrainChars[terrain.terrainType] .. featureChars[feature.featureType]
		else
			line = line .. "  "
		end
	end
	local terrainAreas = {}
	for r = 100, 0, -3 do
		local line = ""
		for t = 0, 100, 3 do
			local terrain = self:NearestTempRainThing(t, r, TerrainDictionary)
			if terrain then
				local terrainType = terrain.terrainType
				local featureList = {}
				for i, featureType in pairs(terrain.features) do
					tInsert(featureList, FeatureDictionary[featureType])
				end
				local feature = self:NearestTempRainThing(t, r, featureList, 2) or FeatureDictionary[featureNone]
				if feature.percent == 0 then feature = FeatureDictionary[featureNone] end
				if terrainAreas[terrainType] == nil then terrainAreas[terrainType] = 0 end
				terrainAreas[terrainType] = terrainAreas[terrainType] + 1
				local lastChar = " "
				for lr = r-2, r+2 do
					for lt = t-2, t+2 do
						if latitudesByTempRain[lt .. " " ..lr] then
							lastChar = "/"
							break
						end
					end
					if lastChar == "/" then break end
				end
				line = line .. terrainChars[terrain.terrainType] .. featureChars[feature.featureType] .. lastChar
			else
				line = line .. "   "
			end
		end
		EchoDebug(line)
	end
	EchoDebug("latitudes 0 to 90:")
	EchoDebug(line)
	EchoDebug(numLine)
	for i, terrain in pairs(TerrainDictionary) do
		EchoDebug(GameInfo.Terrains[terrain.terrainType].Description, terrainAreas[terrain.terrainType], terrainLatitudeAreas[terrain.terrainType])
	end
end

function Space:CreatePseudoLatitudes()
	local pseudoLatitudes
	local minDist = 3.33
	local avgTemp, avgRain
	local iterations = 0
	repeat
		local latitudeResolution = 0.1
		local protoLatitudes = {}
		for l = 0, mFloor(90/latitudeResolution) do
			local latitude = l * latitudeResolution
			local t, r = self:GetTemperature(latitude, true), self:GetRainfall(latitude, true)
			tInsert(protoLatitudes, { latitude = latitude, t = t, r = r })
		end
		local currentLtr
		local goodLtrs = {}
		local pseudoLatitude = 90
		local totalTemp = 0
		local totalRain = 0
		pseudoLatitudes = {}
		while #protoLatitudes > 0 do
			local ltr = tRemove(protoLatitudes)
			if not currentLtr then
				currentLtr = ltr
			else
				local dist = mSqrt(self:TempRainDist(currentLtr.t, currentLtr.r, ltr.t, ltr.r))
				if dist > minDist then currentLtr = ltr end
			end
			if not goodLtrs[currentLtr] then
				goodLtrs[currentLtr] = true
				pseudoLatitudes[pseudoLatitude] = { temperature = mFloor(currentLtr.t), rainfall = mFloor(currentLtr.r) }
				totalTemp = totalTemp + mFloor(currentLtr.t)
				totalRain = totalRain + mFloor(currentLtr.r)
				pseudoLatitude = pseudoLatitude - 1
			end
		end
		local change = mAbs(pseudoLatitude+1)^1.5 * 0.005
		if pseudoLatitude < -1 then
			minDist = minDist + change
		elseif pseudoLatitude > -1 then
			minDist = minDist - change
		end
		avgTemp = mFloor(totalTemp / (90 - pseudoLatitude))
		avgRain = mFloor(totalRain / (90 - pseudoLatitude))
		iterations = iterations + 1
	until pseudoLatitude == -1 or iterations > 100
	if iterations < 101 then
		EchoDebug("pseudolatitudes created okay after " .. iterations .. " iterations, " .. avgTemp .. " average temp", avgRain .. " average rain")
	else
		EchoDebug("bad pseudolatitudes")
	end
	self.pseudoLatitudes = pseudoLatitudes
end

function Space:Compute()
    self.iW, self.iH = Map.GetGridSize()
    self.iA = self.iW * self.iH
    self.areaMod = mFloor(mSqrt(self.iA) / 30)
    self.coastalMod = self.areaMod
    self.subCollectionSizeMin = self.subCollectionSizeMin + mFloor(self.areaMod/2)
    self.subCollectionSizeMax = self.subCollectionSizeMax + self.areaMod
    EchoDebug("subcollection size: " .. self.subCollectionSizeMin .. " minimum, " .. self.subCollectionSizeMax .. " maximum")
    self.nonOceanArea = self.iA
    self.w = self.iW - 1
    self.h = self.iH - 1
    self.halfWidth = self.w / 2
    self.halfHeight = self.h / 2
    self.smallestHalfDimesionSq = mMin(self.halfWidth, self.halfHeight) ^ 2
    self.diagonalWidthSq = (self.w * self.w) + (self.h * self.h)
    self.diagonalWidth = mSqrt(self.diagonalWidthSq)
    self.halfDiagonalWidth = self.diagonalWidth / 2
    self.halfDiagonalWidthSq = (self.halfWidth * self.halfWidth) + (self.halfHeight * self.halfHeight)

    -- EchoDebug(self:HexDistance(self.halfWidth+5, self.halfHeight, 1, self.h), self.halfWidth+5, self.halfHeight, 1, self.h)
    -- EchoDebug(self:HexDistance(1, self.halfHeight, self.halfWidth-5, self.h), 1, self.halfHeight, self.halfWidth-5, self.h)
    -- EchoDebug(self:HexDistance(self.w, 0, 0, self.h), self.w, 0, 0, self.h)
    -- EchoDebug(self:HexDistance(self.w, 0, 1, self.h), self.w, 0, 1, self.h)

    self.northLatitudeMult = 90 / Map.GetPlot(0, self.h):GetLatitude()
    self.xFakeLatitudeConversion = 180 / self.iW
    self.yFakeLatitudeConversion = 180 / self.iH
    self:DoCentuariIfActivated()
    -- lake generation scales with global rainfall:
    local rainfallScale = self.rainfallMidpoint / 49.5
    self.lakeMinRatio = self.lakeMinRatio * rainfallScale
	self.lakeynessMax = mFloor( self.lakeynessMax * rainfallScale )
	EchoDebug(self.lakeMinRatio .. " minimum lake ratio", self.lakeynessMax .. " maximum region lakeyness")
	if FeatureDictionary[featureForest] and FeatureDictionary[featureForest].metaPercent then
		FeatureDictionary[featureForest].metaPercent = mMin(100, FeatureDictionary[featureForest].metaPercent * (rainfallScale ^ 2.2))
		EchoDebug("forest metapercent: " .. FeatureDictionary[featureForest].metaPercent)
	end
	if FeatureDictionary[featureJungle] and FeatureDictionary[featureJungle].metaPercent then
		FeatureDictionary[featureJungle].metaPercent = mMin(100, FeatureDictionary[featureJungle].metaPercent * (rainfallScale ^ 2.2))
		EchoDebug("jungle metapercent: " .. FeatureDictionary[featureJungle].metaPercent)
	end
    self.freshFreezingTemperature = self.freezingTemperature * 1.12
    if self.useMapLatitudes then
    	self.realmHemisphere = mRandom(1, 2)
    end
	self.polarExponentMultiplier = 90 ^ self.polarExponent
	if self.rainfallMidpoint > 49.5 then
		self.rainfallPlusMinus = 99 - self.rainfallMidpoint
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
	if self.falloutEnabled then
		FeatureDictionary[featureFallout].disabled = nil
		if self.contaminatedWater and self.contaminatedSoil then
	    	FeatureDictionary[featureFallout].percent = 30
	    	FeatureDictionary[featureFallout].points = {{t=50,r=100}, {t=50,r=0}}
	    elseif self.contaminatedWater then
	    	FeatureDictionary[featureFallout].percent = 35
	    	FeatureDictionary[featureFallout].points = {{t=50,r=100}}
	    elseif self.contaminatedSoil then
	    	FeatureDictionary[featureFallout].percent = 35
	    	FeatureDictionary[featureFallout].points = {{t=50,r=0}}
	    else
	    	FeatureDictionary[featureFallout].percent = 25
	    	local l = mRandom(0, 60)
	    	EchoDebug("fallout latitude: " .. l)
			FeatureDictionary[featureFallout].points = {{t=self:GetTemperature(l),r=self:GetRainfall(l)}}
	    end
	end
    if self.useMapLatitudes and self.polarMaxLandRatio == 0 then self.noContinentsNearPoles = true end
    self:CreatePseudoLatitudes()
    -- self:PrintClimate()
    self.subPolygonCount = mFloor(18 * (self.iA ^ 0.5)) + 200
    EchoDebug(self.polygonCount .. " polygons", self.subPolygonCount .. " subpolygons", self.iA .. " hexes")
    EchoDebug("initializing polygons...")
    self:InitPolygons()
    EchoDebug("initializing hexes...")
    self:InitHexes()
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
    EchoDebug("unstranding hexes...")
	self:UnstrandHexes()
	EchoDebug("calculating subpolygon limits..")
	self:CalcSubPolygonLimits()
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
    EchoDebug("determining subpolygon neighbors...")
    self:FindSubPolygonNeighbors()
    EchoDebug("flip-flopping subpolygons...")
    self:FlipFlopSubPolygons()
    EchoDebug((self.flopCount or 0) .. " subpolygons flopped")
    EchoDebug("populating polygon hex tables...")
    self:FillPolygonHexes()
    EchoDebug("culling empty polygons...")
    self:CullPolygons(self.polygons)
    self:GetPolygonSizes()
	EchoDebug("smallest polygon: " .. self.polygonMinArea, "largest polygon: " .. self.polygonMaxArea)
    EchoDebug("finding polygon neighbors...")
    self:FindPolygonNeighbors()
    EchoDebug("finding subedge connections...")
    self:FindSubEdgeConnections()
    EchoDebug("finding edge connections...")
    self:FindEdgeConnections()
    EchoDebug("picking oceans...")
    self:PickOceans()
    EchoDebug("flooding astronomy basins...")
    self:FindAstronomyBasins()
    EchoDebug("picking continents...")
    self:PickContinents()
    EchoDebug("filling in continent gaps...")
    self:PatchContinents()
    EchoDebug("flooding inland seas...")
    self:FindInlandSeas()
    EchoDebug("filling inland seas...")
    self:FillInlandSeas()
    EchoDebug("picking coasts...")
	self:PickCoasts()
	if not self.useMapLatitudes then
		-- EchoDebug("dispersing fake latitude...")
		-- self:DisperseFakeLatitude()
		EchoDebug("dispersing temperatures and rainfalls...")
		self:DisperseTemperatureRainfall()
	end
	EchoDebug("computing seas...")
	self:ComputeSeas()
	EchoDebug("picking regions...")
	self:PickRegions()
	-- EchoDebug("distorting climate grid...")
	-- climateGrid = self:DistortClimateGrid(climateGrid, 1.5, 1)
	EchoDebug("creating climate voronoi...")
	local regionclimatetime = StartDebugTimer()
	self.climateVoronoi = self:CreateClimateVoronoi(#self.regions, self.climateVoronoiRelaxations)
	EchoDebug("region climate voronoi calculations took " .. StopDebugTimer(regionclimatetime))
	EchoDebug("assigning climate voronoi to regions...")
	self:AssignClimateVoronoiToRegions(self.climateVoronoi)
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
	if self.ancientCitiesCount > 0 or self.postApocalyptic then
		EchoDebug("drawing ancient cities and roads...")
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
	self.tinyIslandMountainPercent = mCeil(self.mountainTinyIslandMult * self.mountainRatio * 100)
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
		if hex.subPolygon.tinyIsland and mRandom(1, 100) < self.tinyIslandMountainPercent then
			hex.plotType = plotMountain
			tInsert(self.mountainHexes, hex)
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
		subPolygon.temperature = subPolygon.temperature or subPolygon.superPolygon.temperature or self:GetTemperature(subPolygon.latitude)
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
					subPolygon.oceanTemperature = mCeil(coastTempTotal / coastTotal)
				end
			end
			if subPolygon.polar then
				subPolygon.oceanTemperature = -5 -- self:GetOceanTemperature(self:GetTemperature(90))
			elseif subPolygon.superPolygon.coast and not subPolygon.coast then
				subPolygon.oceanTemperature = subPolygon.superPolygon.oceanTemperature
			end
			subPolygon.oceanTemperature = subPolygon.oceanTemperature or subPolygon.superPolygon.oceanTemperature or subPolygon.temperature or self:GetOceanTemperature(subPolygon.temperature)
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
					if self.polarMaxLandRatio == 0 and self.useMapLatitudes and hex.y ~= 0 and hex.y ~= self.h then
						-- try not to interfere w/ navigation at poles if no land at poles and icy poles
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
	if self.useMapLatitudes then
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
		EchoDebug(self.avgOceanLat .. " is average ocean latitude with temperature of " .. mFloor(self.avgOceanTemp), " temperature at equator: " .. self:GetTemperature(0))
		self.avgOceanTemp = (self.avgOceanTemp * 0.5) + (self:GetTemperature(0) * 0.5)
	else
		local totalTemp = 0
		local tempCount = 0
		for p, polygon in pairs(self.polygons) do
			if polygon.continent == nil then
				tempCount = tempCount + 1
				totalTemp = totalTemp + polygon.temperature
			end
		end
		self.avgOceanTemp = totalTemp / tempCount
		EchoDebug(mFloor(self.avgOceanTemp) .. " is average ocean temperature", "temperature at equator: " .. self:GetTemperature(0))
		self.avgOceanTemp = self.avgOceanTemp * 0.82 -- adjust to simulate realistic map's lower temp
		EchoDebug(mFloor(self.avgOceanTemp) .. " simulated realistic average ocean temp")
		self.avgOceanTemp = (self.avgOceanTemp * 0.5) + (self:GetTemperature(0) * 0.5)
	end
	EchoDebug(" adjusted avg ocean temp: " .. mFloor(self.avgOceanTemp))
	for p, polygon in pairs(self.polygons) do
		polygon.temperature = polygon.temperature or self:GetTemperature(polygon.latitude)
		if polygon.continent == nil then
			local coastTempTotal = 0
			local coastTotal = 0
			local coastalContinents = {}
			polygon.coastContinentsTotal = 0
			polygon.waterTotal = 0
			for ni, neighbor in pairs(polygon.neighbors) do
				if neighbor.continent then
					polygon.coast = true
					coastTempTotal = coastTempTotal + neighbor.region.temperature
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
			polygon.oceanTemperature = polygon.oceanTemperature or self:GetOceanTemperature(polygon.temperature)
		end
	end 
end

function Space:GetOceanTemperature(temperature)
	temperature = (temperature * 0.5) + (self.avgOceanTemp * 0.5)
	if not self.useMapLatitudes then temperature = temperature * 0.94 end
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

function Space:RemoveBadlyPlacedNaturalWonders()
	local removedWonders = {}
	for i, hex in pairs(self.hexes) do
		local featureType = hex.plot:GetFeatureType()
		local removeWonder = false
		local removeFromHereAlso
		if featureType == featureVolcano or featureType == featureReef then
			-- krakatoa and reefs sometime form an astronomy basin leak
			if hex.polygon.oceanIndex then
				removeWonder = true
			end
			for ii, neighHex in pairs(hex:Neighbors()) do
				if neighHex.polygon.oceanIndex then
					removeWonder = true
				end
				if featureType == featureReef and neighHex.plot:GetFeatureType() == featureReef then
					removeFromHereAlso = neighHex
				end
			end
		end
		if removeWonder then
			EchoDebug("removing volcano or reef", featureType)
			tInsert(removedWonders, featureType)
			hex.plot:SetFeatureType(featureNone)
			hex:SetTerrain()
			if removeFromHereAlso then
				removeFromHereAlso.plot:SetFeatureType(featureNone)
				removeFromHereAlso:SetTerrain()
				for ii, neighHex in pairs(removeFromHereAlso:Neighbors()) do
					neighHex:SetTerrain()
				end
			end
			for ii, neighHex in pairs(hex:Neighbors()) do
				neighHex:SetTerrain()
			end
		end
	end
	-- tInsert(removedWonders, featureVolcano); tInsert(removedWonders, featureReef) -- uncomment to test removed wonder replacer
	if #removedWonders == 0 then return end
	-- find new places for removed wonders
	local hexBuffer = tDuplicate(self.hexes)
	while #hexBuffer > 0 do
		local hex = tRemoveRandom(hexBuffer)
		for wi = #removedWonders, 1, -1 do
			local featureType = removedWonders[wi]
			if hex:PlaceNaturalWonderPossibly(featureType) then
				tRemove(removedWonders, wi)
			end
		end
	end
end

function Space:StripResources()
	for i, hex in pairs(self.hexes) do
		hex.plot:SetResourceType(-1)
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
	for i, hex in pairs(self.hexes) do
		hex:SetRoad()
	end
end

function Space:SetImprovements()
	for i, hex in pairs(self.hexes) do
		hex:SetImprovement()
	end
end

function Space:SetContinentArtTypes()
	for i, hex in pairs(self.hexes) do
		hex:SetContinentArtType()
	end
end

function Space:PolygonDebugDisplay()
	local fills = {}
	for terrainType, terrainDef in pairs(TerrainDictionary) do
		for i, featureType in pairs(terrainDef.features) do
			if featureType == featureForest or featureType == featureNone then
				tInsert(fills, {plotType = plotLand, terrainType = terrainType, featureType = featureType})
			end
		end
	end
	tInsert(fills, {plotType = plotOcean, terrainType = terrainOcean, featureType = featureNone})
	tInsert(fills, {plotType = plotOcean, terrainType = terrainOcean, featureType = featureIce})
	tInsert(fills, {plotType = plotOcean, terrainType = terrainCoast, featureType = featureNone})
	EchoDebug(#fills .. " fill types")
	local highestNeighbors = 0
	for i, polygon in pairs(self.polygons) do
		local fillsLeft = tDuplicate(fills)
		if #polygon.neighbors > highestNeighbors then
			highestNeighbors = #polygon.neighbors
		end
		for ii, neighbor in pairs(polygon.neighbors) do
			if neighbor.fill then
				for iii = #fillsLeft, 1, -1 do
					local fill = fillsLeft[iii]
					if fill == neighbor.fill then
						tRemove(fillsLeft, iii)
						break
					end
				end
			end
		end
		local fill = tGetRandom(fillsLeft)
		polygon.fill = fill
		for ii, hex in pairs(polygon.hexes) do
			hex.plot:SetPlotType(fill.plotType)
			hex.plot:SetTerrainType(fill.terrainType)
			hex.plot:SetFeatureType(fill.featureType)
			if hex.stranded then
				hex.plot:SetFeatureType(featureFloodPlains)
			elseif hex.x == polygon.x and hex.y == polygon.y then
				hex.plot:SetFeatureType(featureReef)
			end
		end
	end
	EchoDebug(highestNeighbors .. " most polygon neighbors")
end

    ----------------------------------
    -- INTERNAL METAFUNCTIONS: --

function Space:InitPolygons()
	local XYs = {}
	for x = 0, self.w do
		for y = 0, self.h do
			tInsert(XYs, {x=x, y=y})
		end
	end
	local xyBuffer = tDuplicate(XYs)
	for i = 1, self.subPolygonCount do
		local xy = tRemoveRandom(xyBuffer)
		local subPolygon = Polygon(self, xy.x, xy.y)
		tInsert(self.subPolygons, subPolygon)
		if #xyBuffer == 0 then
			break
		end
	end
	for i = 1, self.polygonCount do
		local polygon = Polygon(self)
		tInsert(self.polygons, polygon)
	end
end

function Space:InitHexes()
	for x = 0, self.w do
		for y = 0, self.h do
			local hex = Hex(self, x, y)
			self.hexes[hex.index] = hex
		end
	end
end

function Space:FillSubPolygons(relax)
	local timer = StartDebugTimer()
	self.totalSubPolygons = #self.subPolygons -- so that closestThing can be sped up
	for i = 1, #self.hexes do
		local hex = self.hexes[i]
		hex:Place(relax)
	end
	EchoDebug("filled subpolygons in " .. StopDebugTimer(timer))
	-- below is to test the distribution of times one subpolygon is picked, to see if getting a random subpolygon when more than one is at the same distance from a hex is worth the performance hit (i say no)
	-- local byTimesPicked = {}
	-- for i, subPolygon in pairs(self.subPolygons) do
	-- 	if subPolygon.pickedFirst then
	-- 		byTimesPicked[subPolygon.pickedFirst] = (byTimesPicked[subPolygon.pickedFirst] or 0) + 1
	-- 	end
	-- end
	-- for timesPicked, count in pairsByKeys(byTimesPicked) do
	-- 	EchoDebug(timesPicked, count)
	-- end
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
	local culled = 0
	for i = #polygons, 1, -1 do -- have to go backwards, otherwise table.remove screws up the iteration
		local polygon = polygons[i]
		if #polygon.hexes == 0 then
			tRemove(polygons, i)
			culled = culled + 1
		end
	end
	EchoDebug(culled .. " polygons culled", #polygons .. " remaining")
end

function Space:UnstrandHexes()
	local strandedCount = 0
	for i, hex in pairs(self.hexes) do
		if hex:Unstrand() then
			strandedCount = strandedCount + 1
		end
	end
	EchoDebug(strandedCount .. " hexes unstranded")
	return strandedCount
end

function Space:FindSubPolygonNeighbors()
	for i, hex in pairs(self.hexes) do
		hex:FindSubPolygonNeighbors()
	end
end

function Space:FlipFlopSubPolygons()
	for i, subPolygon in pairs(self.subPolygons) do
		-- see if it's next to another superpolygon
		local choices = {}
		for n, neighbor in pairs(subPolygon.neighbors) do
			if neighbor.superPolygon ~= subPolygon.superPolygon then
				choices[#choices+1] = neighbor.superPolygon
			end
		end
		if #choices > 0 and mRandom(1, 100) < self.subPolygonFlopPercent then
			-- flop the subpolygon
			subPolygon:Flop(tGetRandom(choices))
		end
	end
	-- fix stranded single subpolygons
	for i, subPolygon in pairs(self.subPolygons) do
		local hasFriendlyNeighbors = false
		local uchoices = {}
		for n, neighbor in pairs(subPolygon.neighbors) do
			if neighbor.superPolygon == subPolygon.superPolygon then
				hasFriendlyNeighbors = true
				break
			else
				uchoices[#uchoices+1] = neighbor.superPolygon
			end
		end
		if not hasFriendlyNeighbors and not subPolygon.flopped and #subPolygon.superPolygon.subPolygons > 1 and #uchoices > 0 then
			subPolygon:Flop(tGetRandom(uchoices))
		end
	end
end

function Space:CalcSubPolygonLimits()
	self.subPolygonMinArea = self.iA
	self.subPolygonMaxArea = 0
	for i, polygon in pairs(self.subPolygons) do
		for ii, hex in pairs(polygon.hexes) do
			hex:InsidePolygon(polygon)
		end
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

function Space:FindEdgeConnections()
	for i, edge in pairs(self.edges) do
		edge:FindConnections()
	end
end

function Space:PickOceans()
	if self.wrapX and self.wrapY then
		self:PickOceansDoughnut() -- the game doesn't support this :-(
	elseif not self.wrapX and not self.wrapY then
		self:PickOceansRectangle()
	elseif self.wrapX and not self.wrapY then
		self:PickOceansCylinder()
	elseif self.wrapY and not self.wrapX then
		print("why have a vertically wrapped map?")
	end
	if self.astronomyBlobNumber > 0 then
		self:PickOceansAstronomyBlobs()
	end
	EchoDebug(#self.oceans .. " oceans")
end

function Space:PickOceansCylinder()
	local xDiv = self.w / mMin(3, self.oceanNumber)
	local x = 0
	local horizOceans = self.oceanNumber - 3
	local rows = mCeil(horizOceans / 3)
	local yDiv = self.h / (rows + 1)
	local y = yDiv
	local firstOcean = mRandom(1, 3)
	local secondOcean = (firstOcean + 1) % 4
	local horizOceanCount = 0
	if secondOcean == 0 then secondOcean = 1 end
	-- if self.oceanNumber == 1 then x = 0 else x = mRandom(0, self.w) end
	for oceanIndex = 1, self.oceanNumber do
		local ocean
		if oceanIndex < 4 then
			ocean = self:PickOceanBottomToTop(x, oceanIndex)
			x = mCeil(x + xDiv) % self.iW
		else
			if not self.oceans[firstOcean] or not self.oceans[secondOcean] then
				EchoDebug("can't pick oceans from #" .. firstOcean .. " to #" .. secondOcean)
				break
			end
			EchoDebug("picking ocean #" .. oceanIndex .. " from #" .. firstOcean .. " to #" .. secondOcean .. "...")
			ocean = self:PickOceanToOcean(self.oceans[firstOcean], self.oceans[secondOcean], y, oceanIndex)
			firstOcean = (firstOcean + 1) % 4
			if firstOcean == 0 then firstOcean = 1 end
			secondOcean = (secondOcean + 1) % 4
			if secondOcean == 0 then secondOcean = 1 end
			horizOceanCount = horizOceanCount + 1
			if horizOceanCount > 3 then
				y = mCeil(y + yDiv) % self.iH
				horizOceanCount = 0
			end
		end
		if ocean and #ocean > 0 then
			tInsert(self.oceans, ocean)
		end
	end
end

function Space:PickOceanToOcean(firstOcean, secondOcean, y, oceanIndex)
	local startPoly
	local bPoly, bDist
	for i, polygon in pairs(firstOcean) do
		if y >= polygon.minY and y <= polygon.maxY then
			startPoly = polygon
			break
		else
			local dist = mAbs(polygon.y - y)
			if not bDist or dist < bDist then
				bPoly = polygon
				bDist = dist
			end
		end
	end
	startPoly = startPoly or bPoly
	if not startPoly then
		EchoDebug("no starting polygon found")
		return
	end
	local targetPoly
	bPoly, bDist = nil, nil
	for i, polygon in pairs(secondOcean) do
		if y >= polygon.minY and y <= polygon.maxY then
			targetPoly = polygon
			break
		else
			local dist = mAbs(polygon.y - y)
			if not bDist or dist < bDist then
				bPoly = polygon
				bDist = dist
			end
		end
	end
	targetPoly = targetPoly or bPoly
	if not targetPoly then
		EchoDebug("no target polygon found")
		return
	end
	local polygon = startPoly
	local ocean = {}
	local chosen = {}
	local iterations = 0
	EchoDebug(self.nonOceanPolygons, self.minNonOceanPolygons)
	while self.nonOceanPolygons > self.minNonOceanPolygons and iterations < 100 do
		chosen[polygon] = true
		if not polygon.oceanIndex then
			polygon.oceanIndex = oceanIndex
			tInsert(ocean, polygon)
			self.nonOceanArea = self.nonOceanArea - #polygon.hexes
			self.nonOceanPolygons = self.nonOceanPolygons - 1
		end
		if polygon == targetPoly then
			EchoDebug("target polygon found, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
			break
		end
		local bestNeigh
		local bestDist
		local neighsByDist = {}
		local betterNeighs = {}
		local myDist = self:HexDistance(polygon.x, polygon.y, targetPoly.x, targetPoly.y)
		for ni, neighbor in pairs(polygon.neighbors) do
			if not chosen[neighbor] then
				local dist = self:HexDistance(neighbor.x, neighbor.y, targetPoly.x, targetPoly.y)
				neighsByDist[dist] = neighsByDist[dist] or {}
				tInsert(neighsByDist[dist], neighbor)
				if not bestDist or dist < bestDist then
					bestDist = dist
					bestNeigh = neighbor
				end
				if dist < myDist then
					tInsert(betterNeighs, neighbor)
				end
			end
		end
		if #betterNeighs == 0 then
			EchoDebug("no neighbors closer to target, stopping ocean #" .. oceanIndex .. " at " .. iterations .. " iterations")
			break
		end
		if #neighsByDist[bestDist] > 1 then
			bestNeigh = tGetRandom(neighsByDist[bestDist])
		end
		polygon = bestNeigh or tGetRandom(betterNeighs)
		iterations = iterations + 1
	end
	return ocean
end

function Space:PickOceanBottomToTop(x, oceanIndex)
	local polygon = self:GetPolygonByXY(x, 0)
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
			if not neighbor:NearOther(oceanIndex, "oceanIndex") and not chosen[neighbor] then
				if neighbor.maxY > polygon.maxY then
					tInsert(upNeighbors, neighbor)
				else
					tInsert(downNeighbors, neighbor)
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
		local highestNeigh
		if #self.oceans == 0 or self.oceanNumber ~= 2 then
			-- local highestY = 0
			-- local neighsByY = {}
			-- for ni, neighbor in pairs(upNeighbors) do
			-- 	neighsByY[neighbor.y] = neighsByY[neighbor.y] or {}
			-- 	tInsert(neighsByY[neighbor.y], neighbor)
			-- 	if neighbor.y > highestY then
			-- 		highestY = neighbor.y
			-- 		highestNeigh = neighbor
			-- 	end
			-- end
			-- if #neighsByY[highestY] > 1 then
			-- 	highestNeigh = tRemoveRandom(neighsByY[highestY])
			-- end
			highestNeigh = tGetRandom(upNeighbors)
		else
			local highestDist = 0
			local neighsByDist = {}
			for ni, neighbor in pairs(upNeighbors) do
				local totalDist = 0
				for oi, ocea in pairs(self.oceans) do
					for pi, poly in pairs(ocea) do
						local dx, dy = self:WrapDistance(neighbor.x, neighbor.y, poly.x, poly.y)
						totalDist = totalDist + dx
					end
				end
				neighsByDist[totalDist] = neighsByDist[totalDist] or {}
				tInsert(neighsByDist[totalDist], neighbor)
				if totalDist > highestDist then
					highestDist = totalDist
					highestNeigh = neighbor
				end
			end
			if #neighsByDist[highestDist] > 1 then
				highestNeigh = tGetRandom(neighsByDist[highestDist])
			end
		end
		polygon = highestNeigh or tGetRandom(upNeighbors)
		iterations = iterations + 1
	end
	return ocean
end

function Space:PickOceansRectangle()
	local sides = {
		{ {0,0}, {0,1} }, -- west
		{ {0,1}, {1,1} }, -- north
		{ {1,0}, {1,1} }, -- east
		{ {0,0}, {1,0} }, -- south
	}
	self.oceanSides = {}
	for oceanIndex = 1, mMin(self.oceanNumber, 4) do
		local sideIndex = mRandom(1, #sides)
		local removeAlsoSide
		if oceanIndex == 1 and self.oceanNumber == 2 then
			local removeAlsoSideIndex = sideIndex + 2
			if removeAlsoSideIndex > #sides then
				removeAlsoSideIndex = removeAlsoSideIndex - #sides
			end
			removeAlsoSide = sides[removeAlsoSideIndex]
			EchoDebug("prevent parallel oceans", sideIndex, removeAlsoSideIndex, removeAlsoSide)
		end
		local side = tRemove(sides, sideIndex)
		if removeAlsoSide then
			for si, s in pairs(sides) do
				EchoDebug(s)
				if s == removeAlsoSide then
					EchoDebug("removing parallel ocean side")
					tRemove(sides, si)
				end
			end
		end
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

function Space:PickOceansAstronomyBlobs()
	local polygonBuffer
	if self.astronomyBlobsMustConnectToOcean then
		local chosen = {}
		polygonBuffer = {}
		if self.wrapX then
			for i, polygon in pairs(self.polygons) do
				if polygon.edgeY then
					tInsert(polygonBuffer, polygon)
					chosen[polygon] = true
				end
			end
		end
		for i, ocean in pairs(self.oceans) do
			for ii, polygon in pairs(ocean) do
				for iii, neighbor in pairs(polygon.neighbors) do
					if not neighbor.oceanIndex and not chosen[neighbor] then
						tInsert(polygonBuffer, neighbor)
						chosen[neighbor] = true
					end
				end
			end
		end
	else
		polygonBuffer = tDuplicate(self.polygons)
	end
	local astronomyBlobCount = 0
	local maxDistRatioFromOceans = 0
	if self.oceanNumber > 0 then 
		maxDistRatioFromOceans =  0.38
	end
	while #polygonBuffer > 0 and astronomyBlobCount < self.astronomyBlobNumber do
		local size = mRandom(self.astronomyBlobMinPolygons, self.astronomyBlobMaxPolygons)
		local polygon
		local minOceanDistRatio = 0
		local iterations = 0
		repeat
			-- polygon = self:GetPolygonByXY(self.halfWidth, self.halfHeight)
			polygon = tRemoveRandom(polygonBuffer)
			if not self.astronomyBlobsMustConnectToOcean and self.oceanNumber > 0 then
				local minOceanDist
				for i, ocean in pairs(self.oceans) do
					for ii, poly in pairs(ocean) do
						local dist = self:HexDistance(polygon.x, polygon.y, poly.x, poly.y)
						if not minOceanDist or dist < minOceanDist then
							minOceanDist = dist
						end
					end
				end
				if self.wrapX then
					for i, poly in pairs(self.edgeYPolygons) do
						local dist = self:HexDistance(polygon.x, polygon.y, poly.x, poly.y)
						if not minOceanDist or dist < minOceanDist then
							minOceanDist = dist
						end
					end
				end
				minOceanDistRatio = minOceanDist / self.smallestHalfDimesionSq
			end
			iterations = iterations + 1
		until (not polygon.oceanIndex and minOceanDistRatio <= maxDistRatioFromOceans) or #polygonBuffer == 0
		EchoDebug("minOceanDistRatio: " .. minOceanDistRatio, "iterations: " .. iterations, "at: " .. polygon.x .. ", " .. polygon.y)
		if #polygonBuffer == 0 then break end
		local blob = { polygon }
		polygon.astronomyBlob = blob
		while #blob < size do
			local candidateCount = 0
			local candidatesByFriendlyCount = {}
			local bestFriendlyCount = 0
			for i, neighbor in pairs(polygon.neighbors) do
				if not neighbor.oceanIndex and not neighbor.astronomyBlob then
					local friendlyCount = 0
					for ii, neighNeigh in pairs(neighbor.neighbors) do
						if neighNeigh.astronomyBlob == blob then
							friendlyCount = friendlyCount + 1
						end
					end
					if friendlyCount > bestFriendlyCount then
						bestFriendlyCount = friendlyCount
					end
					candidatesByFriendlyCount[friendlyCount] = candidatesByFriendlyCount[friendlyCount] or {}
					tInsert(candidatesByFriendlyCount[friendlyCount], neighbor)
					candidateCount = candidateCount + 1
				end
			end
			if candidateCount == 0 then break end
			polygon = tGetRandom(candidatesByFriendlyCount[bestFriendlyCount])
			tInsert(blob, polygon)
			polygon.astronomyBlob = blob
		end
		local oceanIndex = #self.oceans + 1
		local ocean = {}
		for i, poly in pairs(blob) do
			for ii, neighbor in pairs(poly.neighbors) do
				if not neighbor.astronomyBlob and not neighbor.oceanIndex then
					neighbor.oceanIndex = oceanIndex
					tInsert(ocean, neighbor)
				end
			end
		end
		if #ocean > 0 then
			tInsert(self.oceans, ocean)
		end
		astronomyBlobCount = astronomyBlobCount + 1
		EchoDebug("astronomy blob of " .. #blob .. " polygons with ocean #" .. oceanIndex .. " of " .. #ocean .. " polygons")
	end
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
	self.filledSubPolygons = 0
	self.filledPolygons = 0
	if self.oceanNumber == -1 then
		-- option to have no water has been selected
		local continent = {}
		for i, polygon in pairs(self.polygons) do
			polygon.continent = continent
			tInsert(continent, polygon)
			self.filledPolygons = self.filledPolygons + 1
			self.filledSubPolygons = self.filledSubPolygons + #polygon.subPolygons
			self.filledArea = self.filledArea + #polygon.hexes
		end
		tInsert(self.continents, continent)
		EchoDebug("whole-world continent of " .. #continent .. " polygons")
		return
	end
	for astronomyIndex, basin in pairs(self.astronomyBasins) do
		EchoDebug("picking for astronomy basin #" .. astronomyIndex .. ": " .. #basin .. " polygons...")
		self:PickContinentsInBasin(astronomyIndex)
	end
end

function Space:PickContinentsInBasin(astronomyIndex)
	local polygonBuffer = {}
	local polarPolygonsHere = 0
	for i, polygon in pairs(self.astronomyBasins[astronomyIndex]) do
		tInsert(polygonBuffer, polygon)
		if self.wrapX and polygon.edgeY then
			polarPolygonsHere = polarPolygonsHere + 1
		end
	end
	local maxPolarPolygons = mFloor(polarPolygonsHere * self.polarMaxLandRatio)
	-- local sizeMult = 1 - (self.majorContinentNumber * 0.1)
	local sizeMult = ((1 / self.majorContinentNumber) ^ 0.3) * 0.92
	EchoDebug(maxPolarPolygons .. " maximum polar polygons of " .. polarPolygonsHere .. " polar polygons in astronomy basin of " .. #polygonBuffer .. " polygons")
	EchoDebug("theoretical size multiplier: " .. sizeMult)
	local polarPolygonCount = 0
	local maxTotalPolygons = (#polygonBuffer - polarPolygonsHere) + maxPolarPolygons
	local islandPolygons = mCeil(maxTotalPolygons * self.islandRatio)
	local nonIslandPolygons = mMax(1, maxTotalPolygons - islandPolygons)
	EchoDebug(maxTotalPolygons .. " total polygons possible for land", islandPolygons .. " polygons reserved for islands", nonIslandPolygons .. " polygons reserved for continents")
	local filledPolygons = 0
	local continentIndex = 1
	local polygonBufferSides
	if self.oceanSides then
		self.nonOceanSides = {}
		if not self.oceanSides["bottomX"] then tInsert(self.nonOceanSides, "bottomX") end
		if not self.oceanSides["topX"] then tInsert(self.nonOceanSides, "topX") end
		if not self.oceanSides["bottomY"] then tInsert(self.nonOceanSides, "bottomY") end
		if not self.oceanSides["topY"] then tInsert(self.nonOceanSides, "topY") end
	end
	while #polygonBuffer > 0 do
		-- determine theoretical continent size
		local size = mCeil((nonIslandPolygons / self.majorContinentNumber) * sizeMult) -- because of the space left between continents
		if filledPolygons >= nonIslandPolygons * sizeMult then size = mRandom(1, 3) end
		local putTheContinentOnMyGoodSide = size > 3 and self.nonOceanSides and #self.nonOceanSides < 4 and #self.nonOceanSides > 0
		if putTheContinentOnMyGoodSide then
			local goodSidePolygonCount = 0
			for i, side in pairs(self.nonOceanSides) do
				goodSidePolygonCount = goodSidePolygonCount + #self[side .. "Polygons"]
			end
			putTheContinentOnMyGoodSide = mFloor((goodSidePolygonCount / self.majorContinentNumber) * sizeMult)
			-- EchoDebug("put the continent on my good side", putTheContinentOnMyGoodSide)
		end
		-- pick a polygon to start the continent
		local polygon
		repeat
			polygon = tRemoveRandom(polygonBuffer)
			if polygon.continent == nil and not polygon:NearOther(nil, "continent") then
				local nearPole = polygon:NearOther(nil, "topY") or polygon:NearOther(nil, "bottomY")
				if putTheContinentOnMyGoodSide then
						local goodSide = false
						for nosi, side in pairs(self.nonOceanSides) do
							if polygon[side] then
								goodSide = true
								break
							end
						end
						if goodSide then break else polygon = nil end
				elseif (self.wrapY or (not polygon.topY and not polygon.bottomY)) and (self.wrapX or (not polygon.topX and not polygon.bottomX)) and (not nearPole or not self.noContinentsNearPoles) then
					break
				else
					polygon = nil
				end
			else
				polygon = nil
			end
		until #polygonBuffer == 0
		if polygon == nil then break end
		local goodSideThisContinent = 0
		local backlog = {}
		local polarBacklog = {}
		local goodSideBacklog = {}
		self.filledArea = self.filledArea + #polygon.hexes
		self.filledSubPolygons = self.filledSubPolygons + #polygon.subPolygons
		filledPolygons = filledPolygons + 1
		local filledContinentArea = #polygon.hexes
		local continent = { polygon }
		polygon.continent = continent
		repeat
			local candidates = {}
			local polarCandidates = {}
			local goodSideCandidates = {}
			for ni, neighbor in pairs(polygon.neighbors) do
				if neighbor.continent == nil and not neighbor:NearOther(continent, "continent") and neighbor.astronomyIndex < 100 then
					local onGoodSide
					if putTheContinentOnMyGoodSide then
						for si, side in pairs(self.nonOceanSides) do
							if neighbor[side] then
								onGoodSide = true
								break
							end
						end
					end
					local nearPole = neighbor.betaBottomY or neighbor.betaTopY
					if self.wrapX and not self.wrapY and (neighbor.topY or neighbor.bottomY or (self.noContinentsNearPoles and nearPole)) then
						tInsert(polarCandidates, neighbor)
					elseif onGoodSide then
						tInsert(goodSideCandidates, neighbor)
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
				elseif putTheContinentOnMyGoodSide and goodSideThisContinent < putTheContinentOnMyGoodSide and #goodSideCandidates > 0 then
					candidate = tRemoveRandom(goodSideCandidates) -- use a goodside polygon
					goodSideThisContinent = goodSideThisContinent + 1
				else
					-- when there are no immediate candidates
					if putTheContinentOnMyGoodSide and goodSideThisContinent < putTheContinentOnMyGoodSide and #goodSideBacklog > 0 then
						repeat
							candidate = tRemove(goodSideBacklog, #goodSideBacklog)
							if candidate.continent ~= nil then candidate = nil end
						until candidate ~= nil or #goodSideBacklog == 0
						if candidate ~= nil then
							goodSideThisContinent = goodSideThisContinent + 1
						end
					end
					if candidate == nil and #backlog > 0 then
						repeat
							candidate = tRemove(backlog, #backlog) -- pop off the most recent
							if candidate.continent ~= nil then candidate = nil end
						until candidate ~= nil or #backlog == 0
					end
					if candidate == nil and #polarBacklog > 0 then
						repeat
							candidate = tRemove(polarBacklog, #polarBacklog) -- pop off the most recent polar
							if candidate.continent ~= nil then candidate = nil end
						until candidate ~= nil or #polarBacklog == 0
						if candidate ~= nil then
							polarPolygonCount = polarPolygonCount + 1
						end
					end
				end
			else
				if putTheContinentOnMyGoodSide and goodSideThisContinent < putTheContinentOnMyGoodSide and #goodSideCandidates > 0 then
					candidate = tRemoveRandom(goodSideCandidates)
					goodSideThisContinent = goodSideThisContinent + 1
				else
					candidate = tRemoveRandom(candidates)
				end
			end
			if candidate == nil then
				-- EchoDebug(#candidates, #polarCandidates, #goodSideCandidates, #backlog, #polarBacklog, #goodSideBacklog)
				break
			end
			-- put the rest of the candidates in the backlog
			for nothing, polygon in pairs(candidates) do
				tInsert(backlog, polygon)
			end
			for nothing, polygon in pairs(goodSideCandidates) do
				tInsert(goodSideBacklog, polygon)
			end
			for nothing, polygon in pairs(polarCandidates) do
				tInsert(polarBacklog, polygon)
			end
			candidate.continent = continent
			self.filledArea = self.filledArea + #candidate.hexes
			self.filledSubPolygons = self.filledSubPolygons + #candidate.subPolygons
			filledContinentArea = filledContinentArea + #candidate.hexes
			filledPolygons = filledPolygons + 1
			tInsert(continent, candidate)
			polygon = candidate
		until #backlog == 0 or #continent >= size
		EchoDebug("continent of " .. #continent .. " polygons (" .. filledContinentArea .. " hexes) of " .. size .. " theoretical polygons")
		tInsert(self.continents, continent)
		continentIndex = continentIndex + 1
	end
	self.filledPolygons = self.filledPolygons + filledPolygons
end

function Space:PickMountainRanges()
	self.continentMountainEdgeCounts = {}
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
		if edge.polygons[1].continent then
			self.continentMountainEdgeCounts[edge.polygons[1].continent] = (self.continentMountainEdgeCounts[edge.polygons[1].continent] or 0) + 1
		end
		if edge.polygons[2].continent and edge.polygons[2].continent ~= edge.polygons[1].continent then
			self.continentMountainEdgeCounts[edge.polygons[2].continent] = (self.continentMountainEdgeCounts[edge.polygons[2].continent] or 0) + 1
		end
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
						if cedge.mountains and cedge ~= nextEdge and cedge ~= edge then
							-- EchoDebug("would connect to another range")
							okay = false
						end
					end
				end
				-- EchoDebug(okay, coastRange, nextEdge.polygons[1].continent ~= nil, nextEdge.polygons[2].continent ~= nil, (nextEdge.polygons[1].region == nextEdge.polygons[2].region and nextEdge.polygons[2].region ~= nil), nextEdge.mountains)
				if okay then
					tInsert(nextEdges, nextEdge)
				end
			end
			-- EchoDebug(#nextEdges)
			if #nextEdges == 0 then break end
			local nextEdge = tGetRandom(nextEdges)
			nextEdge.mountains = true
			tInsert(range, nextEdge)
			edgeCount = edgeCount + 1
			if coastRange then coastCount = coastCount + 1 else interiorCount = interiorCount + 1 end
			if nextEdge.polygons[1].continent then
				self.continentMountainEdgeCounts[nextEdge.polygons[1].continent] = (self.continentMountainEdgeCounts[nextEdge.polygons[1].continent] or 0) + 1
			end
			if nextEdge.polygons[2].continent and nextEdge.polygons[2].continent ~= nextEdge.polygons[1].continent then
				self.continentMountainEdgeCounts[nextEdge.polygons[2].continent] = (self.continentMountainEdgeCounts[nextEdge.polygons[2].continent] or 0) + 1
			end
			edge = nextEdge
		until #nextEdges == 0 or #range >= self.mountainRangeMaxEdges or coastCount > coastPrescription or interiorCount > interiorPrescription
		EchoDebug("range ", #range, tostring(coastRange))
		for ire, redge in pairs(range) do
			for ise, subEdge in pairs(redge.subEdges) do
				local sides = tDuplicate(subEdge.polygons)
				local subPolygon
				repeat
					subPolygon = tRemoveRandom(sides)
				until #sides == 0 or (subPolygon and not subPolygon.lake and subPolygon.superPolygon.continent)
				if subPolygon and not subPolygon.lake and subPolygon.superPolygon.continent then
					for ih, hex in pairs(subEdge.hexes) do
						if hex.subPolygon == subPolygon and hex.plotType ~= plotOcean then
							hex.mountainRangeCore = true
							hex.mountainRange = true
							tInsert(self.mountainCoreHexes, hex)
						end
					end
					subPolygon.mountainRange = true
					for hi, hex in pairs(subPolygon.hexes) do
						if hex.plotType ~= plotOcean then hex.mountainRange = true end
					end
				end
			end
		end
		tInsert(self.mountainRanges, range)
	end
	EchoDebug(interiorCount .. " interior ranges ", coastCount .. " coastal ranges")
	self:PickMountainSubPolygons()
end

-- add one-subpolygon mountain clumps to continents without any mountains
function Space:PickMountainSubPolygons()
	local chance = mCeil(1 / (self.mountainSubPolygonMult * self.mountainRatio))
	local addedSubPolygons = 0
	for i, continent in pairs(self.continents) do
		if self.continentMountainEdgeCounts[continent] == nil then
			for ii, polygon in pairs(continent) do
				for iii, subPolygon in pairs(polygon.subPolygons) do
					if not subPolygon.lake and mRandom(1, chance) == 1 then
						addedSubPolygons = addedSubPolygons + 1
						subPolygon.mountainRange = true
						local coreHex = false
						local hexBuffer = tDuplicate(subPolygon.hexes)
						while #hexBuffer > 0 do
							local hex = tRemoveRandom(hexBuffer)
							if hex.plotType ~= plotOcean then
								hex.mountainRange = true
								if not coreHex then
									hex.mountainRangeCore = true
									coreHex = true
								end
							end
						end
					end
				end
			end
		end
	end
	EchoDebug(addedSubPolygons .. " subpolygon mountain clumps")
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

function Space:DistortClimateGrid(grid, tempExponent, rainExponent)
	tempExponent = tempExponent or 1
	rainExponent = rainExponent or 1
	local tempExpComp = 99 / (99 ^ tempExponent)
	local rainExpComp = 99 / (99 ^ rainExponent)
	local newGrid = {}
	for t, rains in pairs(grid) do
		local temp = mFloor( tempExpComp * (t ^ tempExponent) )
		newGrid[t] = {}
		for r, pixel in pairs(rains) do
			local rain = mFloor( rainExpComp * (r ^ rainExponent) )
			newGrid[t][r] = grid[temp][rain]
		end
	end
	return newGrid
end

function Space:CreateClimateVoronoi(number, relaxations)
	relaxations = relaxations or 0
	local pixelBuffer = {}
	for t = self.temperatureMin, self.temperatureMax do
		for r = self.rainfallMin, self.rainfallMax do
			tInsert(pixelBuffer, {temp=t, rain=r})
		end
	end
	local climateVoronoi = {}
	for i = 1, number do
		local point = tRemoveRandom(pixelBuffer)
		tInsert(climateVoronoi, point)
	end
	local cullCount = 0
	for iteration = 1, relaxations + 1 do
		-- fill voronoi grid
		for t = self.temperatureMin, self.temperatureMax do
			for r = self.rainfallMin, self.rainfallMax do
				local leastDist
				local nearestPolygon
				for i, point in pairs(climateVoronoi) do
					local dt = mAbs(t - point.temp)
					local dr = mAbs(r - point.rain)
					local dist = (dt * dt) + (dr * dr)
					if not leastDist or dist < leastDist then
						leastDist = dist
						nearestPoint = point
					end
				end
				if iteration <= relaxations then
					nearestPoint.totalT = (nearestPoint.totalT or 0) + t
					nearestPoint.totalR = (nearestPoint.totalR or 0) + r
					nearestPoint.pixelCount = (nearestPoint.pixelCount or 0) + 1
				else
					nearestPoint.pixels = nearestPoint.pixels or {}
					tInsert(nearestPoint.pixels, {temp=t, rain=r})
				end
			end
		end
		-- cull empty points
		for i = #climateVoronoi, 1, -1 do
			local point = climateVoronoi[i]
			if not point.pixelCount and not point.pixels then
				tRemove(climateVoronoi, i)
				cullCount = cullCount + 1
			end
		end
		-- relax points to centroids
		if iteration <= relaxations then
			for i = #climateVoronoi, 1, -1 do
				local point = climateVoronoi[i]
				point.temp = point.totalT / point.pixelCount
				point.rain = point.totalR / point.pixelCount
				if relaxation == relaxations then
					-- integerize at the last relaxation
					point.temp = mFloor(point.temp)
					point.rain = mFloor(point.rain)
				end
				point.totalT = nil
				point.totalR = nil
				point.pixelCount = nil
			end
		end
	end
	EchoDebug(cullCount .. " points culled")
	return climateVoronoi
end

function Space:AssignClimateVoronoiToRegions(climateVoronoi)
	local voronoiBuffer = tDuplicate(climateVoronoi)
	for i, region in pairs(self.regions) do
		if self.useMapLatitudes then
			region:GiveLatitude()
			local temp = self:GetTemperature(region.latitude)
			local rain = self:GetRainfall(region.latitude)
			local bestDist, bestPoint, bestIndex
			for ii, point in pairs(voronoiBuffer) do
				local dt = mAbs(temp - point.temp)
				local dr = mAbs(rain - point.rain)
				local dist = (dt * dt) + (dr * dr * ((90 - region.latitude) / 90))
				if not bestDist or dist < bestDist then
					bestDist = dist
					bestPoint = point
					bestIndex = ii
				end
			end
			region.point = bestPoint
			tRemove(voronoiBuffer, bestIndex)
			if #voronoiBuffer == 0 then
				voronoiBuffer = tDuplicate(climateVoronoi)
			end
		else
			region.point = tRemoveRandom(voronoiBuffer)
			if #voronoiBuffer == 0 then
				voronoiBuffer = tDuplicate(climateVoronoi)
			end
		end
		region.temperature = region.point.temp
		region.rainfall = region.point.rain
	end
end

function Space:TempRainDist(t1, r1, t2, r2)
	local tdist = mAbs(t2 - t1)
	local rdist = mAbs(r2 - r1)
	return tdist^2 + rdist^2
end

function Space:NearestTempRainThing(temperature, rainfall, things, oneTtwoF)
	oneTtwoF = oneTtwoF or 1
	temperature = mMax(self.temperatureMin, temperature)
	temperature = mMin(self.temperatureMax, temperature)
	rainfall = mMax(self.rainfallMin, rainfall)
	rainfall = mMin(self.rainfallMax, rainfall)
	if climateGrid then
		local pixel = climateGrid[temperature][rainfall]
		local typeCode = pixel[oneTtwoF]
		local typeField = "terrainType"
		if oneTtwoF == 2 then
			typeField = "featureType"
		end
		for i, thing in pairs(things) do
			if thing[typeField] == typeCode then
				return thing
			end
		end
	else
		local nearestDist
		local nearest
		local dearest = {}
		for i, thing in pairs(things) do
			if thing.points then
				for p, point in pairs(thing.points) do
					local trdist = self:TempRainDist(point.t, point.r, temperature, rainfall)
					if not nearestDist or trdist < nearestDist then
						nearestDist = trdist
						nearest = thing
					end
				end
			else
				tInsert(dearest, thing)
			end
		end
		nearest = nearest or tGetRandom(dearest)
		return nearest
	end
end

function Space:FillRegions()
	self.minLakes = mCeil(self.lakeMinRatio * self.filledSubPolygons)
	self.marshMinHexes = mFloor(self.marshMinHexRatio * self.filledArea)
	self.marshHexCount = 0
	EchoDebug(self.minLakes .. " minimum lake subpolygons (of " .. self.filledSubPolygons .. ") ", self.marshMinHexes .. " minimum marsh hexes")
	local regionBuffer = tDuplicate(self.regions)
	-- for i, region in pairs(self.regions) do
	while #regionBuffer > 0 do
		local region = tRemoveRandom(regionBuffer)
		region:CreateCollection()
		region:Fill()
	end
	EchoDebug(#self.lakeSubPolygons .. " total lake subpolygons", self.marshHexCount .. " total marsh hexes")
end

function Space:LabelSubPolygonsByPolygon()
	local labelled = 0
	local polygonBuffer = tDuplicate(self.polygons)
	repeat
		local polygon = tRemoveRandom(polygonBuffer)
		local subPolygonBuffer = tDuplicate(polygon.subPolygons)
		repeat
			local subPolygon = tRemoveRandom(subPolygonBuffer)
			if self.centauri or not subPolygon.superPolygon.continent and not subPolygon.tinyIsland and not subPolygon.lake then
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
				if LabelThing(subPolygon) then
					labelled = labelled + 1
					break
				end
			end
		until #subPolygonBuffer == 0
	until #polygonBuffer == 0 -- or (self.subPolygonLabelsMax and labelled >= self.subPolygonLabelsMax)
	EchoDebug(#polygonBuffer)
end

function Space:PatchContinents()
	local patchedPolygonCount = 0
	for i, polygon in pairs(self.polygons) do
		if not polygon.continent and not polygon.oceanIndex then
			if not polygon:FloodFillToOcean() then
				patchedPolygonCount = patchedPolygonCount + 1
				polygon:PatchContinent()
			end
		end
	end
	EchoDebug(patchedPolygonCount .. " non-continent polygons with no route to ocean patched")
	return patchedPolygonCount
end

function Space:FindInlandSeas()
	local polys = tDuplicate(self.polygons)
	while #polys > 0 and #self.inlandSeas < self.inlandSeasMax do
		local polygon = tRemoveRandom(polys)
		local sea = polygon:FloodFillSea()
		if sea then
			sea.size = #sea.polygons
			if sea.inland then
				EchoDebug("found inland sea of " .. sea.size .. "/" .. sea.maxPolygons .. " polygons")
				tInsert(self.inlandSeas, sea)
			else
				EchoDebug("found sea of " .. sea.size .. " polygons")
			end
		end
	end
end

function Space:FillInlandSeas()
	for si, sea in pairs(self.inlandSeas) do
		for pi, polygon in pairs(sea.polygons) do
			polygon:RemoveFromContinent()
		end
	end
	local patchCount = 0
	local timer = StartDebugTimer()
	for i, polygon in pairs(self.polygons) do
		if polygon.continent then
			local found, sea = polygon:FloodFillToWholeContinent()
			if found and sea then
				if #found < #polygon.continent then
					-- EchoDebug(#found .. " stranded polygons from " .. #polygon.continent .. "-polygon continent")
					if #found < #polygon.continent * 0.33 then
						EchoDebug("moving " .. #found .. " stranded polygons from " .. #polygon.continent .. "-polygon continent to " .. sea.size .. "-polygon inland sea")
						for ii, strandedPolygon in pairs(found) do
							strandedPolygon:RemoveFromContinent()
							strandedPolygon.sea = sea
							tInsert(sea.polygons, strandedPolygon)
							sea.size = sea.size + 1
						end
					end
				end
			end
		end
	end
	EchoDebug("patched inland seas in " .. StopDebugTimer(timer))
end

function Space:LabelMap()
	CreateOrOverwriteTable("Fantastical_Map_Labels", "X integer DEFAULT 0, Y integer DEFAULT 0, Type text DEFAULT null, Label text DEFAULT null, ID integer DEFAULT 0")
	if self.centauri then
		EchoDebug("giving centauri labels to subpolygons...")
		LabelSyntaxes, LabelDictionary, LabelDefinitions, SpecialLabelTypes = LabelSyntaxesCentauri, LabelDictionaryCentauri, LabelDefinitionsCentauri, SpecialLabelTypesCentauri
		self.subPolygonLabelsMax = nil
		self:LabelSubPolygonsByPolygon()
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
	EchoDebug("labelling inland seas...")
	for i, sea in pairs(self.inlandSeas) do
		local x, y
		local hexes = {}
		for p, polygon in pairs(sea.polygons) do
			for sp, subPolygon in pairs(polygon.subPolygons) do
				if not x then
					local middle = true
					for n, neighbor in pairs(subPolygon.neighbors) do
						if neighbor.superPolygon.sea and neighbor.superPolygon.sea ~= sea then
							middle = false
							break
						end
					end
					if middle then x, y = subPolygon.x, subPolygon.y end
				end
				for h, hex in pairs(subPolygon.hexes) do tInsert(hexes, hex) end
			end
		end
		if not x then
			local hex = tGetRandom(hexes)
			x, y = hex.x, hex.y
		end
		EchoDebug(sea.size, sea.inland, x, y, #hexes)
		LabelThing(sea, x, y, hexes)
	end
	EchoDebug("labelling lakes...")
	for i, subPolygon in pairs(self.lakeSubPolygons) do
		LabelThing(subPolygon)
	end
	EchoDebug("labelling rivers...")
	local riversByLength = {}
	for i, river in pairs(self.rivers) do
		for t, tributary in pairs(river.tributaries) do
			river.riverLength = river.riverLength + tributary.riverLength
			for tt, tribtrib in pairs(tributary.tributaries) do
				river.riverLength = river.riverLength + tribtrib.riverLengths
			end
		end
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
		-- if n == self.riverLabelsMax then break end
	end
	EchoDebug("labelling regions...")
	local regionsLabelled = 0
	local regionBuffer = tDuplicate(self.regions)
	repeat
		local region = tRemoveRandom(regionBuffer)
		if region:Label() then regionsLabelled = regionsLabelled + 1 end
	until #regionBuffer == 0 -- or regionsLabelled >= self.regionLabelsMax
	EchoDebug("labelling tiny islands...")
	local tinyIslandBuffer = tDuplicate(self.tinyIslandSubPolygons)
	local tinyIslandsLabelled = 0
	repeat
		local subPolygon = tRemoveRandom(tinyIslandBuffer)
		if LabelThing(subPolygon) then tinyIslandsLabelled = tinyIslandsLabelled + 1 end
	until #tinyIslandBuffer == 0 -- or tinyIslandsLabelled >= self.tinyIslandLabelsMax
	EchoDebug("labelling bays, straights, and capes")
	self:LabelSubPolygonsByPolygon()
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
		-- if rangesLabelled == self.rangeLabelsMax then break end
	end
end

function Space:FindRiverSeeds()
	self.lakeRiverSeeds = {}
	self.majorRiverSeeds = {}
	self.minorRiverSeeds = {}
	self.tinyRiverSeeds = {}
	if self.oceanNumber == -1 and #self.lakeSubPolygons == 0 then
		-- no rivers can be drawn if there are no bodies of water on the map
		EchoDebug("no bodies of water on the map and therefore no rivers")
		return
	end
	local lakeCount = 0
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
				local rainfall = mMin(hex.polygon.region.rainfall, nhex.polygon.region.rainfall) -- mFloor((hex.polygon.region.rainfall + nhex.polygon.region.rainfall) / 2)
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
				local oceanSeed, hillSeed, connectsToOcean, connectsToLake
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
					end
					if lakeNeighs[nnhex] then
						connectsToLake = true
					end
				end
				if oceanSeed then
					tInsert(self.minorRiverSeeds, oceanSeed)
				elseif hillSeed and not connectsToOcean and not connectsToLake then
					tInsert(self.minorRiverSeeds, hillSeed)
				end
			end
			for nhex, d in pairs(hexNeighs) do
				local oceanSeed, hillSeed, connectsToOcean, connectsToLake
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
					end
					if lakeNeighs[nnhex] then
						connectsToLake = true
					end
				end
				if oceanSeed then
					tInsert(self.tinyRiverSeeds, oceanSeed)
				elseif hillSeed and not connectsToOcean and not connectsToLake then
					tInsert(self.tinyRiverSeeds, hillSeed)
				end
			end
		end
	end
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
		if lastHex.isRiver then
			-- EchoDebug("WOULD BE TOO CLOSE TO ANOTHER RIVER")
			stop = true
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
					-- EchoDebug("WOULD CONNECT TO ANOTHER RIVER OR ITSELF", it)
					if seed.fork and it > 2 and (hex.onRiver[newHex] == seed.flowsInto or pairHex.onRiver[newHex] == seed.flowsInto) then
						-- EchoDebug("would connect to source")
						stop = true -- unfortunately, the way civ 5 draws rivers doesn't allow rivers to split and join
					else
						stop = true
					end
				end
				if newHex.isRiver then
					if seed.flowsInto then
						for riverThing, yes in pairs(newHex.isRiver) do
							if riverThing ~= seed.flowsInto then
								stop = true
								-- EchoDebug("WOULD BE TOO CLOSE TO ANOTHER RIVER")
								break
							end
						end
					else
						-- EchoDebug("WOULD BE TOO CLOSE TO ANOTHER RIVER")
						stop = true
					end
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
				-- EchoDebug("FOUND HILLS/MOUNTAINS", it)
				done = newHex
				break
			end
		end
		if seed.fork and it > 2 then
			-- none of this comes into play because of the way civ 5 draws rivers
			if hex.onRiver[newHex] == seed.flowsInto or pairHex.onRiver[newHex] == seed.flowsInto then
				-- forks can connect to source
				local sourceRiverMile = hex.onRiverMile[newHex] or pairHex.onRiverMile[newHex]
				if sourceRiverMile < seed.flowsIntoRiverMile then
					seed.reverseFlow = true
				end
				EchoDebug("fork connecting to source", sourceRiverMile, seed.flowsIntoRiverMile, seed.reverseFlow)
				seed.connectsToSource = true
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
				tiny, toHills, avoidConnection, avoidWater, alwaysDraw = true, true, true, true
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
		if (hex.onRiver[newHex] and hex.onRiver[newHex] ~= seed.flowsInto) or onRiver[hex][newHex] then
			useHex = false
		end
		if (pairHex.onRiver[newHex] and pairHex.onRiver[newHex] ~= seed.flowsInto) or onRiver[pairHex][newHex] then
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
	local riverThing = { path = river, seed = seed, done = done, riverLength = #river, tributaries = {} }
	for f, flow in pairs(river) do
		if flow.hex.ofRiver == nil then flow.hex.ofRiver = {} end
		if seed.reverseFlow then flow.flowDirection = GetOppositeFlowDirection(flow.flowDirection) end
		--[[
		if seed.connectsToSource and not seed.reverseFlow and f == #river then
			flow.flowDirection = GetOppositeFlowDirection(flow.flowDirection)
		end
		if seed.connectsToSource and seed.reverseFlow and f == 1 then
			flow.flowDirection = GetOppositeFlowDirection(flow.flowDirection)
		end
		]]--
		flow.hex.ofRiver[flow.direction] = flow.flowDirection
		flow.hex.onRiver[flow.pairHex] = riverThing
		flow.pairHex.onRiver[flow.hex] = riverThing
		local riverMile = f
		if seed.growsDownstream then riverMile = #river - (f-1) end
		flow.hex.onRiverMile[flow.pairHex] = riverMile
		flow.pairHex.onRiverMile[flow.hex] = riverMile
		if not flow.hex.isRiver then self.riverArea = self.riverArea + 1 end
		if not flow.pairHex.isRiver then self.riverArea = self.riverArea + 1 end
		flow.hex.isRiver = flow.hex.isRiver or {}
		flow.pairHex.isRiver = flow.pairHex.isRiver or {}
		flow.hex.isRiver[seed.flowsInto or riverThing] = true
		flow.pairHex.isRiver[seed.flowsInto or riverThing] = true
		-- EchoDebug(flow.hex:Locate() .. ": " .. tostring(flow.hex.plotType) .. " " .. tostring(flow.hex.subPolygon.lake) .. " " .. tostring(flow.hex.mountainRange), " / ", flow.pairHex:Locate() .. ": " .. tostring(flow.pairHex.plotType) .. " " .. tostring(flow.pairHex.subPolygon.lake).. " " .. tostring(flow.pairHex.mountainRange))
	end
	for f, newseeds in pairs(seedSpawns) do
		for nsi, newseed in pairs(newseeds) do
			newseed.flowsInto = riverThing
			local riverMile = f
			if seed.growsDownstream then riverMile = #river - (f-1) end
			newseed.flowsIntoRiverMile = riverMile
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
	if seed.flowsInto then tInsert(seed.flowsInto.tributaries, riverThing) end
	tInsert(self.rivers, riverThing)
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
	local mainSeedBoxes = { "majorRiverSeeds", "minorRiverSeeds", "tinyRiverSeeds" }
	local forkSeedBoxes = { "minorForkSeeds", "tinyForkSeeds" }
	self.riverLandRatio = self.riverLandRatio * (self.rainfallMidpoint / 50)
	local prescribedRiverArea = self.riverLandRatio * self.filledArea
	local prescribedForkArea = prescribedRiverArea * self.riverForkRatio
	local prescribedMainArea = prescribedRiverArea - prescribedForkArea
	local inked = 0
	local lastCycleInked = 0
	local recycles = 0
	local riversByRainfall = {}
	local maxRiverRainfall = 0
	local maxRiverData
	local preInkRivers = 0
	local preInkCompared = 0
	local boxes = mainSeedBoxes
	while self.riverArea < prescribedRiverArea do
		local anySeedsAtAll
		for i, box in pairs(boxes) do
			local seeds = self[box]
			if #seeds > 0 then
				anySeedsAtAll = true
				local seed = tRemoveRandom(seeds)
				-- local list = ""
				-- for key, value in pairs(seed) do list = list .. key .. ": " .. tostring(value) .. ", " end
				-- EchoDebug("drawing river seed #" .. si, list)
				local river, done, seedSpawns, endRainfall = self:DrawRiver(seed)
				local rainfall = endRainfall or seed.rainfall
				if (seed.doneAnywhere or done) and river and #river > 0 then
					-- if seed.minor and seed.fork and river then EchoDebug("minor fork is " .. #river .. " long") end
					-- if seed.tiny and seed.fork and river then EchoDebug("tiny fork is " .. #river .. " long") end
					-- if alwaysDraw then rainfall = 101 end
					if rainfall > maxRiverRainfall then
						if maxRiverData then tInsert(laterRiverSeeds, maxRiverData.seed) end
						maxRiverRainfall = rainfall
						maxRiverData = {river = river, seed = seed, seedSpawns = seedSpawns, done = done}
						preInkCompared = preInkCompared + 1
					else
						tInsert(laterRiverSeeds, seed)
					end
					preInkRivers = preInkRivers + 1
				else --if not seed.retries or seed.retries < 2 then
					tInsert(laterRiverSeeds, seed)
				end
			end
		end
		if (preInkCompared > 1 or preInkRivers > 3) and maxRiverData then
			EchoDebug(preInkRivers, preInkCompared, "rainfall: " .. maxRiverRainfall, " length: " .. #maxRiverData.river)
			local riverData = maxRiverData
			local river, seed, seedSpawns, done = riverData.river, riverData.seed, riverData.seedSpawns, riverData.done
			self:InkRiver(river, seed, seedSpawns, done)
			inked = inked + 1
			lastCycleInked = lastCycleInked + 1
			if self.riverArea >= prescribedRiverArea then break end
			if boxes == mainSeedBoxes and self.riverArea >= prescribedMainArea then
				EchoDebug(self.riverArea .. " meets non-fork prescription of " .. mFloor(prescribedMainArea))
				EchoDebug(inked .. " rivers inked so far")
				EchoDebug(#self.minorForkSeeds .. " minor fork seeds", #self.tinyForkSeeds .. " tiny fork seeds")
				boxes = forkSeedBoxes
				laterRiverSeeds = {}
				recycles = 0
				lastCycleInked = 0
			end
			maxRiverData = nil
			maxRiverRainfall = 0
			preInkRivers = 0
			preInkCompared = 0
		end
		if not anySeedsAtAll then
			if #laterRiverSeeds > 0 then
				if recycles > 5 and lastCycleInked == 0 then
					EchoDebug("none inked after five cycles")
					if boxes == mainSeedBoxes then
						EchoDebug(self.riverArea .. " does not meet non-fork prescription of " .. mFloor(prescribedMainArea))
						EchoDebug(inked .. " rivers inked so far")
						EchoDebug(#self.minorForkSeeds .. " minor fork seeds", #self.tinyForkSeeds .. " tiny fork seeds")
						boxes = forkSeedBoxes
						laterRiverSeeds = {}
						recycles = 0
						lastCycleInked = 0
					else
						break
					end
				elseif recycles > 5 and #laterRiverSeeds > 1000 then
					EchoDebug("too many recycles")
					if boxes == mainSeedBoxes then
						EchoDebug(self.riverArea .. " does not meet non-fork prescription of " .. mFloor(prescribedMainArea))
						EchoDebug(inked .. " rivers inked so far")
						EchoDebug(#self.minorForkSeeds .. " minor fork seeds", #self.tinyForkSeeds .. " tiny fork seeds")
						boxes = forkSeedBoxes
						laterRiverSeeds = {}
						recycles = 0
						lastCycleInked = 0
					else
						break
					end
				else
					EchoDebug("recycling " .. #laterRiverSeeds .. " unused river seeds (" .. lastCycleInked ..  " rivers inked last cycle" .. ")...")
					EchoDebug("current river area: " .. self.riverArea .. " of " .. mFloor(prescribedRiverArea) .. " prescribed")
					for si, seed in pairs(laterRiverSeeds) do
						seed.retries = (seed.retries or 0) + 1
						if seed.retries < 4 then
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
					end
					lastCycleInked = 0
					recycles = recycles + 1
				end
			else
				EchoDebug("no seeds available at all")			
				if boxes == mainSeedBoxes then
					EchoDebug(self.riverArea .. " does not meet non-fork prescription of " .. mFloor(prescribedMainArea))
					EchoDebug(inked .. " rivers inked so far")
					EchoDebug(#self.minorForkSeeds .. " minor fork seeds", #self.tinyForkSeeds .. " tiny fork seeds")
					boxes = forkSeedBoxes
					laterRiverSeeds = {}
					recycles = 0
					lastCycleInked = 0
				else
					break
				end
			end
			laterRiverSeeds = {}
		end
	end
	local rlpercent = mFloor( (self.riverArea / self.filledArea) * 100 )
	local rpercent = mFloor( (self.riverArea / self.iA) * 100 )
	EchoDebug(inked .. " inked ", " river area: " .. self.riverArea, "(" .. rlpercent .. "% of land, " .. rpercent .. "% of map)")
end

function Space:DrawRoad(origHex, destHex)
	local it = 0
	local picked = { [destHex] = true }
	local rings = { {destHex} }
	local containsOrig = false
	-- collect rings
	repeat
		local ring = {}
		for i, hex in pairs(rings[#rings]) do
			for direction, nhex in pairs(hex:Neighbors()) do
				if not picked[nhex] and (nhex.plotType == plotLand or nhex.plotType == plotHills) then
					picked[nhex] = true
					tInsert(ring, nhex)
					if nhex == origHex then
						containsOrig = true
						break
					end
				end
			end
			if containsOrig then break end
		end
		if containsOrig then break end
		if #ring == 0 then break end
		tInsert(rings, ring)
		it = it + 1
	until it > 1000
	-- find path through rings and draw road
	if containsOrig then
		local hex = origHex
		for ri = #rings, 1, -1 do
			hex.road = true
			self.markedRoads = self.markedRoads or {}
			self.markedRoads[origHex.polygon.continent] = self.markedRoads[origHex.polygon.continent] or {}
			tInsert(self.markedRoads[origHex.polygon.continent], hex)
			local ring = rings[ri]
			if #ring == 1 then
				hex = ring[1]
			else
				local isNeigh = {}
				for d, nhex in pairs(hex:Neighbors()) do isNeigh[nhex] = d end
				for i, rhex in pairs(ring) do
					if isNeigh[rhex] then
						hex = rhex
						break
					end
				end
			end
		end
		EchoDebug("road from " .. origHex.x .. "," .. origHex.y .. " to " .. destHex.x .. "," .. destHex.y, tostring(#rings) .. " long, vs hex distance of " .. self:HexDistance(origHex.x, origHex.y, destHex.x, destHex.y))
	else
		EchoDebug("no path for road ")
	end
end

function Space:DrawRoadsOnContinent(continent, cityNumber)
	cityNumber = cityNumber or 2
	-- pick city polygons
	local cityPolygons = {}
	local polygonBuffer = tDuplicate(continent)
	while #cityPolygons < cityNumber and #polygonBuffer > 0 do
		local polygon = tRemoveRandom(polygonBuffer)
		local farEnough = true
		for i, toPolygon in pairs(cityPolygons) do
			local dist = self:HexDistance(polygon.x, polygon.y, toPolygon.x, toPolygon.y)
			if dist < 3 then
				farEnough = false
				break
			end
		end
		if farEnough then
			tInsert(cityPolygons, polygon)
			-- draw city ruins and potential fallout
			local origHex = self:GetHexByXY(polygon.x, polygon.y)
			if origHex.plotType ~= plotMountain and origHex.plotType ~= plotOcean then
				origHex.improvementType = improvementCityRuins
				if self.postApocalyptic then
					polygon.nuked = true
					origHex.subPolygon.nuked = true
				end
			end
		end
	end
	if #cityPolygons < 2 or (self.postApocalyptic and self.ancientCitiesCount == 0) then return #cityPolygons end
	-- find the two cities with longest distance
	local maxDist = 0
	local maxDistPolygons
	local cityBuffer = tDuplicate(cityPolygons)
	while #cityBuffer > 0 do
		local polygon = tRemove(cityBuffer)
		for i, toPolygon in pairs(cityBuffer) do
			local dist = self:HexDistance(polygon.x, polygon.y, toPolygon.x, toPolygon.y)
			if dist > maxDist then
				maxDist = dist
				maxDistPolygons = {polygon, toPolygon}
			end
		end
	end
	-- draw the longest road
	local origHex = self:GetHexByXY(maxDistPolygons[1].x, maxDistPolygons[1].y)
	local destHex = self:GetHexByXY(maxDistPolygons[2].x, maxDistPolygons[2].y)
	self:DrawRoad(origHex, destHex)
	-- origHex.road = nil
	-- destHex.road = nil
	-- draw the other connecting roads
	for i, polygon in pairs(cityPolygons) do
		if polygon ~= maxDistPolygons[1] and polygon ~= maxDistPolygons[2] then
			-- find the nearest part of the continent's road network
			local leastDist = 99999
			local leastHex
			if self.markedRoads and self.markedRoads[continent] then
				for h, hex in pairs(self.markedRoads[continent]) do
					local dist = self:HexDistance(polygon.x, polygon.y, hex.x, hex.y)
					if dist < leastDist then
						leastDist = dist
						leastHex = hex
					end
				end
			end
			local origHex = self:GetHexByXY(polygon.x, polygon.y)
			-- draw road
			if leastHex then self:DrawRoad(origHex, leastHex) end
			-- origHex.road = nil
		end
	end
	return #cityPolygons
end

function Space:DrawRoads()
	local cityNumber = self.ancientCitiesCount
	if self.postApocalyptic and self.ancientCitiesCount == 0 then
		cityNumber = 3
	end
	local cities = 0
	local continentBuffer = tDuplicate(self.continents)
	while #continentBuffer > 0 do
		local continent = tRemoveRandom(continentBuffer)
		local drawn = self:DrawRoadsOnContinent(continent, cityNumber)
		cities = cities + (drawn or 0)
		EchoDebug(drawn .. " cities in continent")
	end
	EchoDebug(cities .. " ancient cities")
end

function Space:PickCoasts()
	self.coastalPolygonCount = 0
	self.polarMaxLandPercent = self.polarMaxLandRatio * 100
	for i, polygon in pairs(self.polygons) do
		if polygon.continent == nil then
			if polygon.oceanIndex == nil and Map.Rand(10, "coastal polygon dice") < self.coastalPolygonChance then
				polygon.coastal = true
				self.coastalPolygonCount = self.coastalPolygonCount + 1
				if not polygon:NearOther(nil, "continent") then polygon.loneCoastal = true end
			end
			polygon:PickTinyIslands()
			if polygon.hasTinyIslands then
				tInsert(self.tinyIslandPolygons, polygon)
			end
		end
	end
	EchoDebug(self.coastalPolygonCount .. " coastal polygons")
end

function Space:DisperseTemperatureRainfall()
	for i, polygon in pairs(self.polygons) do
		polygon:GiveTemperatureRainfall()
	end
end

function Space:DisperseFakeLatitude()
	self.continentalFakeLatitudes = {}
	local increment = 90 / (self.filledPolygons - 1)
    for i = 1, self.filledPolygons do
    	tInsert(self.continentalFakeLatitudes, increment * (i-1))
    end
	self.nonContinentalFakeLatitudes = {}
    increment = 90 / ((#self.polygons - self.filledPolygons) - 1)
    for i = 1, (#self.polygons - self.filledPolygons) do
    	tInsert(self.nonContinentalFakeLatitudes, increment * (i-1))
    end
	for i, polygon in pairs(self.polygons) do
		polygon:GiveFakeLatitude()
	end
end

function Space:ResizeMountains(prescribedArea)
	local iterationsPossible = mMax(#self.mountainHexes, prescribedArea) * 3
	local iterations = 0
	local coreHexesLeft = #self.mountainCoreHexes
	if #self.mountainHexes > prescribedArea then
		repeat
			local hex = tRemoveRandom(self.mountainHexes)
			if hex.mountainRangeCore and #self.mountainCoreHexes > 0 and coreHexesLeft < prescribedArea and #self.mountainHexes > coreHexesLeft then
				tInsert(self.mountainHexes, hex)
			else
				if hex.mountainRangeCore then
					coreHexesLeft = coreHexesLeft - 1
				end
				if Map.Rand(10, "hill dice") < self.hillChance then
					hex.plotType = plotHills
					if hex.featureType and not FeatureDictionary[hex.featureType].hill then
						hex.featureType = featureNone
					end
				else
					hex.plotType = plotLand
				end
			end
			iterations = iterations + 1
		until #self.mountainHexes <= prescribedArea or iterations > iterationsPossible
		EchoDebug("mountains reduced to " .. #self.mountainHexes .. " after " .. iterations .. " iterations ", coreHexesLeft .. " core hexes remaining")
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
			iterations = iterations + 1
		until #self.mountainHexes >= prescribedArea or noNeighbors > 20
		EchoDebug("mountains increased to " .. #self.mountainHexes .. " after " .. iterations .. " iterations ", coreHexesLeft .. " core hexes remaining")
	end
end

function Space:AdjustMountains()
	self.mountainArea = mCeil(self.mountainRatio * self.filledArea)
	EchoDebug(#self.mountainHexes .. " base mountain hexes", self.mountainArea .. " prescribed mountain hexes", #self.mountainCoreHexes .. " mountain core hexes")
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

function Space:RealmLatitude(y)
	if self.realmHemisphere == 2 then y = self.h - y end
	return mCeil(y * (90 / self.h))
end

function Space:GetTemperature(latitude, noFloor)
	local temp
	if self.pseudoLatitudes and self.pseudoLatitudes[latitude] then
		temp = self.pseudoLatitudes[latitude].temperature
	else
		if latitude and not self.crazyClimate then
			local rise = self.temperatureMax - self.temperatureMin
			local distFromPole = (90 - latitude) ^ self.polarExponent
			temp = (rise / self.polarExponentMultiplier) * distFromPole + self.temperatureMin
		else
			temp = mRandom(self.temperatureMin, self.temperatureMax)
		end
	end
	if noFloor then return temp end
	return mFloor(temp)
end

function Space:GetRainfall(latitude, noFloor)
	local rain
	if self.pseudoLatitudes and self.pseudoLatitudes[latitude] then
		rain = self.pseudoLatitudes[latitude].rainfall
	else
		if latitude and not self.crazyClimate then
			rain = self.rainfallMidpoint + (self.rainfallPlusMinus * mCos(latitude * (mPi/29)))
		else
			rain = mRandom(self.rainfallMin, self.rainfallMax)
		end
	end
	if noFloor then return rain end
	return mFloor(rain)
end

function Space:GetHillyness()
	return mRandom(0, self.hillynessMax)
end

function Space:GetCollectionSize()
	return mRandom(self.collectionSizeMin, self.collectionSizeMax)
end

function Space:GetSubCollectionSize()
	return mRandom(self.subCollectionSizeMin, self.subCollectionSizeMax)
end

function Space:ClosestThing(this, things, thingsCount)
	local closestDist
	local closestThing
	-- local thingsByDist = {}
	for i = 1, thingsCount or #things do
		local thing = things[i]
		-- local dist = self:SquaredDistance(thing.x, thing.y, this.x, this.y)
		-- local dist = self:ManhattanDistance(thing.x, thing.y, this.x, this.y)
		-- local dist = self:MinkowskiDistance(thing.x, thing.y, this.x, this.y, 1.5)
		local dist = self:HexDistance(thing.x, thing.y, this.x, this.y)
		if not closestDist or dist < closestDist then
			closestDist = dist
			closestThing = thing
		end
		-- thingsByDist[dist] = thingsByDist[dist] or {}
		-- thingsByDist[dist][#thingsByDist[dist]+1] = thing
	end
	-- if #thingsByDist[closestDist] > 1 then
		-- closestThing = tGetRandom(thingsByDist[closestDist])
		-- EchoDebug(#thingsByDist[closestDist] .. " things at same closest distance")
	-- end
	closestThing.pickedFirst = (closestThing.pickedFirst or 0) + 1
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
				xdist = x1 + (self.iW - x2)
			else
				xdist = x2 + (self.iW - x1)
			end
		end
	end
	if self.wrapY then
		if ydist > self.halfHeight then
			if y1 < y2 then
				ydist = y1 + (self.iH - y2)
			else
				ydist = y2 + (self.iH - y1)
			end
		end
	end
	return xdist, ydist
end

function Space:SquaredDistance(x1, y1, x2, y2)
	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
	return (xdist * xdist) + (ydist * ydist)
end

function Space:ManhattanDistance(x1, y1, x2, y2)
	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
	return xdist + ydist
end

function Space:MinkowskiDistance(x1, y1, x2, y2, p)
	local xdist, ydist = self:WrapDistance(x1, y1, x2, y2)
	return ((xdist ^ p) + (ydist ^ p)) ^ (1 / p)
end

function Space:EucDistance(x1, y1, x2, y2)
	return mSqrt(self:SquaredDistance(x1, y1, x2, y2))
end

function Space:HexDistance(x1, y1, x2, y2)
	-- x1 = int(x1)
	-- y1 = int(y1)
	-- x2 = int(x2)
	-- y2 = int(y2)
	local cx1, cy1, cz1 = OddRToCube(x1, y1)
	local cx2, cy2, cz2 = OddRToCube(x2, y2)
	local xdist = mAbs(cx1 - cx2)
	local ydist = mAbs(cy1 - cy2)
	local zdist = mAbs(cz1 - cz2)
	if self.wrapX then
		xdist = mMin(xdist, self.iW - xdist)
		ydist = mMin(ydist, self.iW - ydist)
	end
	local dist = mMax(xdist, ydist, zdist)
	-- local dist = int( (xdist + ydist + zdist) / 2 )
	return dist
end

function Space:GetPolygonByXY(x, y)
	local hex = self:GetHexByXY(x, y)
	return hex.polygon
end

function Space:GetSubPolygonByXY(x, y)
	local hex = self:GetHexByXY()
	return hex.subPolygon
end

function Space:GetHexByXY(x, y)
	x = mFloor(x)
	y = mFloor(y)
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
	local activatedMods = Modding.GetActivatedMods()
	if activatedMods then
		for i,v in ipairs(activatedMods) do
			local title = Modding.GetModProperty(v.ID, v.Version, "Name")
			if title == "Alpha Centauri Maps" then
				EchoDebug("Alpha Centauri Maps enabled, changing default map options...")
				OptionDictionary[1].default = 8 -- centauri-like
				OptionDictionary[2].default = 2 -- no land at poles
				OptionDictionary[4].default = 2 -- climate realism on
				break
			end
		end
	end
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
		-- Folder = "MAP_FOLDER_ROOT",
	}
end

function GetMapInitData(worldSize)
	-- i have to use Map.GetCustomOption because this is called before everything else
	-- if Map.GetCustomOption(1) == 2 then
	if Map.GetCustomOption(1) > 12 then
		-- for Realm maps
		-- create a random map aspect ratio for the given map size
		local areas = {
			[GameInfo.Worlds.WORLDSIZE_DUEL.ID] = 40 * 24,
			[GameInfo.Worlds.WORLDSIZE_TINY.ID] = 56 * 36,
			[GameInfo.Worlds.WORLDSIZE_SMALL.ID] = 66 * 42,
			[GameInfo.Worlds.WORLDSIZE_STANDARD.ID] = 80 * 52,
			[GameInfo.Worlds.WORLDSIZE_LARGE.ID] = 104 * 64,
			[GameInfo.Worlds.WORLDSIZE_HUGE.ID] = 128 * 80,
		}
		local grid_area = areas[worldSize]
		local grid_width = mCeil( mSqrt(grid_area) * ((mRandom() * 0.67) + 0.67) )
		local grid_height = mCeil( grid_area / grid_width )
		EchoDebug(grid_width .. "x" .. grid_height .. " realm map")
		local world = GameInfo.Worlds[worldSize]
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
	--[[
	for row in GameInfo.Map_Sizes() do
		for k, v in pairs(row) do
			print(k, v)
		end
		print('end of row\n')
	end
	]]--
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
	-- print("Setting roads instead (Fantastical) ...")
	-- mySpace:SetRoads()
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
	EchoDebug("removing badly placed natural wonders...")
	mySpace:RemoveBadlyPlacedNaturalWonders()
	print('setting Fantastical routes and improvements...')
	mySpace:SetRoads()
	mySpace:SetImprovements()
	-- mySpace:StripResources()-- uncomment to remove all resources for world builder screenshots
	-- mySpace:PolygonDebugDisplay()-- uncomment to debug polygons
end