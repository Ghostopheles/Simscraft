---@class SimscraftInternal
local internal = select(2, ...);

local Settings = internal.Settings;

---@class SimscraftSettingNames
local Setting = {
    PlayHouseEditorMusic = "PlayHouseEditorMusic",
    EnableAltGridSnapToggle = "EnableAltGridSnapToggle",
    EnableAutoBuy = "EnableAutoBuy"
};
internal.Setting = Setting;

local defaultConfig = {
    [internal.Setting.PlayHouseEditorMusic] = true,
    [internal.Setting.EnableAltGridSnapToggle] = true,
    [internal.Setting.EnableAutoBuy] = true
};

if not SimscraftConfig then
    SimscraftConfig = {};

    for k, v in pairs(defaultConfig) do
        SimscraftConfig[k] = v;
    end
end

------------

local category = Settings.GetCategory();

do
    local variable = internal.Setting.PlayHouseEditorMusic;
    local name = "Play Music while in House Editor";
    local tooltip = "Toggles music playback while in the House Editor.";

    local setting = Settings.CreateSetting(category, variable, name, defaultConfig[variable]);
    Settings.CreateCheckbox(category, setting, tooltip);
end

do
    local variable = internal.Setting.EnableAltGridSnapToggle;
    local name = "Enable " .. ALT_KEY .. " grid snap toggle";
    local tooltip = "Disables grid snapping while the " .. ALT_KEY .. " is held.";

    local setting = Settings.CreateSetting(category, variable, name, defaultConfig[variable]);
    Settings.CreateCheckbox(category, setting, tooltip);
end

do
    local variable = internal.Setting.EnableAutoBuy;
    local name = "Enable Vendor AutoBuy";
    local tooltip = "Toggles the vendor decor AutoBuy feature.";

    local setting = Settings.CreateSetting(category, variable, name, defaultConfig[variable]);
    Settings.CreateCheckbox(category, setting, tooltip);
end