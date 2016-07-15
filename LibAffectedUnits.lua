local playerGUID

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

-- global: referenced from XML
function LibAffectedUnits_OnLoad ()
  playerGUID = UnitGUID("player")
end

local function LibAffectedUnits_OnEvent (self, event, ...)
  local timestamp, eventtype, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags = select(1, ...)

  -- only want our own actions, not anyone else's
  if srcGUID ~= playerGUID then return end

  -- only process useful events
  if not tContains(usefulEventTypes, eventtype) then return end

  -- print("LibAffectedUnits_OnEvent() " .. srcGUID)
end

local eventFrame = CreateFrame("Frame");
eventFrame:SetScript("OnEvent", LibAffectedUnits_OnEvent);

eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
