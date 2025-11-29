local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

---@class SimscraftSettings
internal.Settings = {};

local function OnSettingChanged(_, setting, value)
    local variable = setting:GetVariable();
    Registry:TriggerEvent(Events.SettingChanged, variable, value);
end

local function CreateSetting(category, variable, name, defaultValue)
    local variableType = type(defaultValue);
    local setting = Settings.RegisterAddOnSetting(category, variable, variable, SimscraftConfig, variableType, name, defaultValue);

    Settings.SetOnValueChangedCallback(variable, OnSettingChanged);

    return setting;
end
internal.Settings.CreateSetting = CreateSetting;

local function CreateCheckbox(category, setting, tooltip)
    return Settings.CreateCheckbox(category, setting, tooltip);
end
internal.Settings.CreateCheckbox = CreateCheckbox;

local function CreateDropdown(category, setting, options, tooltip)
    local initializer = Settings.CreateDropdownInitializer(setting, options, tooltip);
    local layout = SettingsPanel:GetLayout(category);
    layout:AddInitializer(initializer);

    return initializer;
end
internal.Settings.CreateDropdown = CreateDropdown;

local function CreateHeader(category, name)
    local initializer = Settings.CreateSettingsInitializer("SettingsListSectionHeaderTemplate", { name = name });
    local layout = SettingsPanel:GetLayout(category);
    layout:AddInitializer(initializer);

    return initializer;
end
internal.Settings.CreateHeader = CreateHeader;

------------

local category = Settings.RegisterVerticalLayoutCategory(addonName);
Settings.RegisterAddOnCategory(category);

local function GetCategory()
    return category;
end
internal.Settings.GetCategory = GetCategory;

local function GetSetting(name)
    return Settings.GetValue(name);
end
internal.Settings.GetSetting = GetSetting;

local function OpenSettings(categoryID)
    Settings.OpenToCategory(categoryID or category:GetID());
end
internal.Settings.OpenSettings = OpenSettings;