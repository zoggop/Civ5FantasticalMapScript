-- uses civ's Map.Rand function to generate random numbers so that multiplayer works
local randomNumbers = 1
local function mRandom(lower, upper)
  local hundredth
  if lower and upper then
    if math.floor(lower) ~= lower or math.floor(upper) ~= upper then
      lower = math.floor(lower * 100)
      upper = math.floor(upper * 100)
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

------------------------------------------------------------------------------
-- FOR CREATING FANTASY NAMES: MARKOV CHAINS
-- ADAPTED FROM drow <drow@bin.sh> http://donjon.bin.sh/code/name/
-- http://creativecommons.org/publicdomain/zero/1.0/

local name_set
local name_types
local chain_cache = {}

local function splitIntoWords(s)
  local words = {}
  for w in s:gmatch("%S+") do table.insert(words, w) end
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

function GetAllCityNames()
  local civTypeGot = {}
  local civTypes = {}
  for value in GameInfo.Civilization_CityNames() do
    for k, v in pairs(value) do
      if k == "CivilizationType" then
        if not civTypeGot[v] then table.insert(civTypes, v) end
        civTypeGot[v] = true
      end
    end
  end
  local cityNames = {}
  local civs = {}
  local n = 0
  repeat
    local cNames = {}
    local civType = table.remove(civTypes, mRandom(1, #civTypes))
    for value in GameInfo.Civilization_CityNames("CivilizationType='" .. civType .. "'") do
      for k, v in pairs(value) do
        -- TXT_KEY_CITY_NAME_ARRETIUM
        local begOfCrap, endOfCrap = string.find(v, "CITY_NAME_")
        if endOfCrap then
          local name = string.sub(v, endOfCrap+1)
          name = string.gsub(name, "_", " ")
          name = string.lower(name)
          name = name:gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
          -- if k == "CityName" then print(name) end
          table.insert(cNames, name)
        end
      end
    end
    if #cNames > 5 then
      -- print(civType)
      cityNames[civType] = cNames
      table.insert(civs, civType)
      n = n + 1
    end
  until #civTypes == 0
  return cityNames, civs
end

function GetCiv(civName)
  if civName then
    local uCivName = string.upper(civName)
    for i, c in pairs(name_types) do
      if string.find(c, uCivName) then
        -- print(c)
        return c
      end
    end
  end
  return name_types[mRandom(1, #name_types)]
end

function GetName(civName)
  if not name_set or not name_types then
    name_set, name_types = GetAllCityNames()
  end
  local civ = GetCiv(civName)
  return generate_name(civ)
end

function GetNames(civName)
  if not name_set or not name_types then
    name_set, name_types = GetAllCityNames()
  end
  local civ = GetCiv(civName)
  return name_list(civ)
end