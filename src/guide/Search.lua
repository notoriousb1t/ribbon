-- Guide search: a forgiving text match for the guide panel's search box. Pure: strings in, true or false out.
--
-- A query is split into words and every word has to match somewhere in the text. A word matches when it
--   - is found as it is ("cross" in "Crossroads"),
--   - is a word's letters with some left out ("crssrods" for "crossroads": the letters appear in order, starting with
--     the word's own first letter and not spread over much more than their own length), or
--   - is one slip away from a word: a letter wrong, missing, extra or two swapped ("crosroads", "croosroads",
--     "crossraods").
-- A single letter only has to start a word, so typing the first letter of a long query does not match everything.
local ADDON, ns = ...

local S = {}
ns.guideSearch = S

-- Lower case, with anything that is not a letter or a digit turned into a space.
function S.normalize(text)
  return (tostring(text or ""):lower():gsub("[^%w]+", " "))
end

local function words(text)
  local out = {}
  for w in text:gmatch("%S+") do out[#out + 1] = w end
  return out
end
S.words = words

-- The letters of `term` appear in `word` in order, from the word's first letter, within a window of the term's length
-- plus about 60% (more room for a longer word with more letters left out).
local function spreadMatch(term, word)
  if term:sub(1, 1) ~= word:sub(1, 1) then return false end
  local pos, first = 1, nil
  for i = 1, #term do
    local at = word:find(term:sub(i, i), pos, true)
    if not at then return false end
    first = first or at
    pos = at + 1
  end
  return (pos - 1) - first + 1 <= #term + math.max(3, math.ceil(#term * 0.6))
end

-- True when a and b are within one edit of each other: a substitution, an insertion, a deletion or two letters swapped.
local function withinOne(a, b)
  local la, lb = #a, #b
  if math.abs(la - lb) > 1 then return false end
  local i = 1
  while i <= la and i <= lb and a:byte(i) == b:byte(i) do i = i + 1 end
  if i > la and i > lb then return true end            -- equal
  if la == lb then
    if a:sub(i + 1) == b:sub(i + 1) then return true end                                   -- one letter wrong
    return a:sub(i, i) == b:sub(i + 1, i + 1) and a:sub(i + 1, i + 1) == b:sub(i, i) and a:sub(i + 2) == b:sub(i + 2)   -- swapped
  end
  if la > lb then return a:sub(i + 1) == b:sub(i) end       -- one letter extra
  return a:sub(i) == b:sub(i + 1)                           -- one letter missing
end

-- Does one query word match the (normalised) text?
local function termMatches(term, text, list)
  if text:find(term, 1, true) then return true end
  if #term < 2 then return false end
  for _, w in ipairs(list) do
    if #term >= 3 and spreadMatch(term, w) then return true end
    if #term >= 4 and withinOne(term, w) then return true end
  end
  return false
end

-- Does the text match the query? An empty query matches everything.
function S.matches(query, text)
  local q = words(S.normalize(query))
  if #q == 0 then return true end
  local t = S.normalize(text)
  local list = words(t)
  for _, term in ipairs(q) do
    if #term == 1 then
      -- a single letter has to start a word
      if not (" " .. t):find(" " .. term, 1, true) then return false end
    elseif not termMatches(term, t, list) then
      return false
    end
  end
  return true
end

-- The items (a list) whose text, from textOf(item), matches the query, in their order.
function S.filter(items, query, textOf)
  if #words(S.normalize(query)) == 0 then return items end
  local out = {}
  for _, item in ipairs(items) do
    if S.matches(query, textOf(item)) then out[#out + 1] = item end
  end
  return out
end
