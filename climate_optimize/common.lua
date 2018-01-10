require "class"
require "config"

mRandom = math.random
mCeil = math.ceil
mFloor = math.floor
mMin = math.min
mMax = math.max
mAbs = math.abs
mSqrt = math.sqrt
mSin = math.sin
mCos = math.cos
mPi = math.pi
mTwicePi = math.pi * 2
mAtan2 = math.atan2
tInsert = table.insert
tRemove = table.remove

function tRemoveRandom(fromTable)
	return tRemove(fromTable, mRandom(1, #fromTable))
end

function tGetRandom(fromTable)
	return fromTable[mRandom(1, #fromTable)]
end

-- simple duplicate, does not handle nesting
function tDuplicate(sourceTable)
	local duplicate = {}
	for k, v in pairs(sourceTable) do
		duplicate[k] = v
	end
	return duplicate
end

function TempRainDist(t1, r1, t2, r2)
	local tdist = mAbs(t2 - t1)
	local rdist = mAbs(r2 - r1)
	return tdist^2 + rdist^2
end

function DisplayToGrid(x, y)
	local t = mFloor( x / displayMult )
	local r = mFloor( (displayMultHundred - y) / displayMult  )
	return t, r
end

function splitIntoWords(s)
  local words = {}
  for w in s:gmatch("%S+") do tInsert(words, w) end
  return words
end

function string:split( inSplitPattern, outResults )
  if not outResults then
    outResults = { }
  end
  local theStart = 1
  local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  while theSplitStart do
    table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
    theStart = theSplitEnd + 1
    theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  end
  table.insert( outResults, string.sub( self, theStart ) )
  return outResults
end

function stringCapitalize(string)
	local first = string:sub(1,1)
	first = string.upper(first)
	return first .. string:sub(2)
end

function serialize(o, out)
  out = out or ""
  if type(o) == "number" then
  	out = out .. o
  elseif type(o) == "boolean" then
  	out = out .. tostring(o)
  elseif type(o) == "string" then
  	out = out .. string.format("%q", o)
  elseif type(o) == "table" then
  	out = out .. "{\n"
    for k,v in pairs(o) do
      out = out .. "  ["
      out = serialize(k, out)
      out = out .. "] = "
      out = serialize(v, out)
      out = out .. ",\n"
    end
    out = out .. "}\n"
  else
    error("cannot serialize a " .. type(o))
  end
  return out
end