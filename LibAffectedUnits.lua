
local lib = LibStub("AceAddon-3.0"):NewAddon("LibAffectedUnits", "AceTimer-3.0")

-- Rudimentary and use-case-specific ring buffer...

-- We have 2 numeric-index tables of the same length.
-- This length corresponds to the maximum history we want.
local MAX_POSITION = 10;
local MIN_POSITION = 1;
local currentRingPosition = 0;

-- e.g. { 1468720080, 1468720081, 1468720083, ... }
local secondsRing = {};

-- e.g. { { ["harm"] = { ... }; ["help"] = { ... } }, ... }
local affectedRing = {};

-- e.g.
-- {
--   {
--     ["harm"] = { ["min"] = 0; ["max"] = 0; ["avg"] = 0 },
--     ["help"] = { ["min"] = 0; ["max"] = 0; ["avg"] = 0 }
--   },
--   ...
-- }
local aggregates = {};

local function wipeAffected (affected)
  -- e.g. affected = { ["harm"] = { ... }; ["help"] = { ... } }
  if affected == nil then
    return { ["harm"] = {}; ["help"] = {} };
  end
  wipe(affected["harm"]);
  wipe(affected["help"]);
  return affected
end

-- ensures ring-buffers and current position are ready for use
-- currently breaks if not executed at least once per second
local function bumpRingsIfNecessary (now)
  if secondsRing[currentRingPosition] ~= now then
    currentRingPosition = currentRingPosition + 1;
    if currentRingPosition > MAX_POSITION then
      currentRingPosition = MIN_POSITION;
    end
    secondsRing[currentRingPosition] = now;
    affectedRing[currentRingPosition] = wipeAffected(affectedRing[currentRingPosition]);
  end
end

local aggregateGUIDs = { ["harm"] = {}; ["help"] = {} };

local function reduceAggregates (aggregates, index, affected)
  local aggregate = aggregates[index] or { ["harm"] = 0; ["help"] = 0 };

  if not affected then
    aggregate["harm"] = 0;
    aggregate["help"] = 0;
    return aggregate;
  end

  for i, affect in ipairs({ "harm", "help" }) do
    for j, harmGUID in ipairs(affected[affect]) do
      if not tContains(aggregateGUIDs[affect], harmGUID) then
        tinsert(aggregateGUIDs[affect], harmGUID);
      end
    end

    aggregate[affect] = # aggregateGUIDs[affect];
  end

  return aggregate;
end

local function bumpAggregates ()
  local aggregatesIndex = 1;
  local aggregatesRingPosition = currentRingPosition;
  local output = "";
  wipe(aggregateGUIDs["harm"]);
  wipe(aggregateGUIDs["help"]);
  while aggregatesRingPosition >= MIN_POSITION do
    output = output .. " " .. date("%S", secondsRing[aggregatesRingPosition] or 0);
    aggregates[aggregatesIndex] = reduceAggregates(aggregates, aggregatesIndex, affectedRing[aggregatesRingPosition])
    aggregatesIndex = aggregatesIndex + 1;
    aggregatesRingPosition = aggregatesRingPosition - 1;
  end
  aggregatesRingPosition = MAX_POSITION;
  while aggregatesRingPosition > currentRingPosition do
    output = output .. " " .. date("%S", secondsRing[aggregatesRingPosition] or 0);
    aggregates[aggregatesIndex] = reduceAggregates(aggregates, aggregatesIndex, affectedRing[aggregatesRingPosition])
    aggregatesIndex = aggregatesIndex + 1;
    aggregatesRingPosition = aggregatesRingPosition - 1;
  end
end

-- for debugging only
local function dumpState ()
  local output = "";
  for i, timestamp in ipairs(secondsRing) do
    output = output .. " " .. date("%S", timestamp);
  end
  print("LibAffectedUnits:" .. output);

  output = "";
  for i, affected in ipairs(affectedRing) do
    output = output .. " " .. # affected["harm"] .. ":" .. # affected["help"];
  end
  print("LibAffectedUnits:" .. output);

  output = "";
  for i, aggregate in ipairs(aggregates) do
    output = output .. " " .. aggregate["harm"] .. ":" .. aggregate["help"];
  end
  print("LibAffectedUnits:" .. output);
end

local usefulEventTypes;

local function recordAffectedGUID (dstGUID, dstFlags)
  local guids;
  if bit.band(dstFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) > 0 then
    -- assumption: friendlies (green) are the only ones we can help
    guids = affectedRing[currentRingPosition]["help"];
  else
    -- assumption: we're always harming neutral and hostile units
    guids = affectedRing[currentRingPosition]["harm"];
  end

  if not tContains(guids, dstGUID) then
    tinsert(guids, dstGUID);
  end
end

local playerGUID;

local function LibAffectedUnits_OnEvent (self, event, ...)
  local timestamp, eventtype, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags = select(1, ...)
  -- assumption: events are delivered in order, and at least nearly on time

  -- only want our own actions, not anyone else's
  if srcGUID ~= playerGUID then return end

  -- only process useful events
  if not tContains(usefulEventTypes, eventtype) then return end

  bumpRingsIfNecessary(time());
  recordAffectedGUID(dstGUID, dstFlags);
end

local eventFrame;

function lib:OnInitialize()
  playerGUID = UnitGUID("player");

  -- generating our set of monitored event types
  local usefulEventTypePrefixes = {
    "SWING", "RANGE", "SPELL", "SPELL_PERIODIC", "SPELL_BUILDING"
  }
  local usefulEventTypeSuffixes = {
    "_DAMAGE", "_HEAL", "_INTERRUPT"
  }
  usefulEventTypes = {}
  for i, prefix in ipairs(usefulEventTypePrefixes) do
    for i, suffix in ipairs(usefulEventTypeSuffixes) do
      tinsert(usefulEventTypes, prefix .. suffix)
    end
  end
end

function lib:OnEnable()
  lib:ScheduleRepeatingTimer("TimerFeedback", 1)
  bumpRingsIfNecessary(time());

  eventFrame = CreateFrame("FRAME", "LibAffectedUnits_Frame");
  eventFrame:Hide();
  eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
  eventFrame:SetScript("OnEvent", LibAffectedUnits_OnEvent);
end

function lib:OnDisable()
  eventFrame:UnregisterAllEvents();
  eventFrame:SetParent(nil);
  lib:CancelAllTimers();
end

function lib:TimerFeedback()
  local now = time();
  bumpRingsIfNecessary(now);
  bumpAggregates();
  -- dumpState();
end
