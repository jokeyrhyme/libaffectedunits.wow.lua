
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

-- for debugging only
local function dumpRings ()
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
end

-- generating our set of monitored event types
local usefulEventTypePrefixes = {
  "SWING", "RANGE", "SPELL", "SPELL_PERIODIC", "SPELL_BUILDING"
}
local usefulEventTypeSuffixes = {
  "_DAMAGE", "_HEAL", "_INTERRUPT"
}
local usefulEventTypes = {}
for i, prefix in ipairs(usefulEventTypePrefixes) do
  for i, suffix in ipairs(usefulEventTypeSuffixes) do
    tinsert(usefulEventTypes, prefix .. suffix)
  end
end

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
  bumpRingsIfNecessary(time());
  -- dumpRings();
end
