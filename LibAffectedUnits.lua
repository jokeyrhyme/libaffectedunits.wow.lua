
local function HelloWorld()
  print("Hello, world!");
end

HelloWorld();

function LibAffectedUnits_OnEvent ()
  print("PLAYER_ENTERING_WORLD");
end

local eventFrame = CreateFrame("Frame");
eventFrame:SetScript("OnEvent", LibAffectedUnits_OnEvent);

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
