local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

internal.ThemeColor = CreateColorFromHexString("ffa6e329");

---@enum SimscraftEvents
local Events = {
    SettingChanged = "SettingChanged",
    HouseEditorModeChanged = "HouseEditorModeChanged",
    ModifierStateChanged = "ModifierStateChanged",
};

---@class SimscraftRegistry : CallbackRegistryMixin
local Registry = CreateFromMixins(CallbackRegistryMixin);
Registry:OnLoad();
Registry:GenerateCallbackEvents(GetKeysArray(Events));

---@param event SimscraftEvents
---@param callback function
---@param owner any
function internal.RegisterCallback(event, callback, owner)
    assert(callback, "A callback function is required.");
    if not owner then
        local newCallback = function(_, ...)
            callback(...);
        end
        Registry:RegisterCallback(event, newCallback, owner);
    else
        Registry:RegisterCallback(event, callback, owner);
    end
end

internal.Events = Events;
internal.Registry = Registry;

local f = CreateFrame("Frame");
f:RegisterEvent("HOUSE_EDITOR_MODE_CHANGED");
f:RegisterEvent("MODIFIER_STATE_CHANGED");
f:SetScript("OnEvent", function(self, event, ...)
    if event == "HOUSE_EDITOR_MODE_CHANGED" then
        Registry:TriggerEvent(Events.HouseEditorModeChanged, ...);
    elseif event == "MODIFIER_STATE_CHANGED" then
        Registry:TriggerEvent(Events.ModifierStateChanged, ...);
    end
end);

---@param msg string
function internal.Print(msg)
    local prefix = internal.ThemeColor:WrapTextInColorCode(addonName) .. ": ";
    print(prefix .. msg);
end

function internal.AddTooltip(object, anchor)
    object:HookScript("OnEnter", function()
        if object.tooltipText then
            GameTooltip:SetOwner(object, anchor or "ANCHOR_TOPLEFT");
            GameTooltip:SetText(object.tooltipText);
            GameTooltip:Show();
        end
    end);

    object:HookScript("OnLeave", function()
        if GameTooltip:IsOwned(object) then
            GameTooltip:Hide();
        end
    end);
end