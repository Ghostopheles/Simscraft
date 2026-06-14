---@class SimscraftInternal
local internal = select(2, ...);

local IgnoreNextKeyUp = false;
local function OnModifierStateChanged(key, down)
    if not internal.Settings.GetSetting(internal.Setting.EnableAltGridSnapToggle) then
        return;
    end

    if not C_HouseEditor.IsHouseEditorActive() then
        return;
    end

    if key == "LALT" then
        if IgnoreNextKeyUp then
            IgnoreNextKeyUp = false;
            return;
        end

        if down == 1 and not C_HousingBasicMode.IsGridSnapEnabled() then
            IgnoreNextKeyUp = true;
        end

        local enabled = down == 0 and true or false;
        C_HousingBasicMode.SetGridSnapEnabled(enabled);
    end
end

local Events = internal.Events;
internal.RegisterCallback(Events.MODIFIER_STATE_CHANGED, OnModifierStateChanged);
