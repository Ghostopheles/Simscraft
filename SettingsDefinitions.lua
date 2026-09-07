---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftSettings
local S = internal.Settings;

---@class SimscraftSettingNames
local Setting = {
    PlayHouseEditorMusic = "PlayHouseEditorMusic",
    EnableAltGridSnapToggle = "EnableAltGridSnapToggle",
    EnableAutoBuy = "EnableAutoBuy",
    EnableDecorItemCounts = "EnableDecorItemCounts",
    EnableDecorNewItemIcon = "EnableDecorNewItemIcon",
    AddToCartModifier = "AddToCartModifier",
    UseNewDyePicker = "UseNewDyePicker",
	ShowTotalShoppingListMissingCount = "ShowTotalShoppingListMissingCount",
	EnableDecorShoppingListIcon = "EnableDecorShoppingListIcon",
};
internal.Setting = Setting;

local defaultConfig = {
    [internal.Setting.PlayHouseEditorMusic] = false,
    [internal.Setting.EnableAltGridSnapToggle] = false,
    [internal.Setting.EnableAutoBuy] = true,
    [internal.Setting.EnableDecorItemCounts] = true,
    [internal.Setting.EnableDecorNewItemIcon] = true,
    [internal.Setting.AddToCartModifier] = "SHIFT",
    [internal.Setting.UseNewDyePicker] = false,
	[internal.Setting.ShowTotalShoppingListMissingCount] = false,
	[internal.Setting.EnableDecorShoppingListIcon] = true
};

if not SimscraftConfig then
    SimscraftConfig = {};

    for k, v in pairs(defaultConfig) do
        SimscraftConfig[k] = v;
    end
end

------------

local category = S.GetCategory();

S.CreateHeader(category, "House Editor");

do
    local variable = internal.Setting.PlayHouseEditorMusic;
    local name = "Play Music while in House Editor";
    local tooltip = "Toggles music playback while in the House Editor.";

    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateCheckbox(category, setting, tooltip);
end

do
    local variable = internal.Setting.EnableAltGridSnapToggle;
    local name = "Enable " .. ALT_KEY .. " grid snap toggle";
    local tooltip = "Disables grid snapping while the " .. ALT_KEY .. " is held.";

    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateCheckbox(category, setting, tooltip);
end

do
    local variable = internal.Setting.UseNewDyePicker;
    local name = "Enable Simscraft dye picker";
    local tooltip = "Enables the color wheel-styled dye picker.";

    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateCheckbox(category, setting, tooltip);
end

S.CreateHeader(category, "Shopping Cart");

do
    local variable = internal.Setting.EnableAutoBuy;
    local name = "Enable Decor Shopping Cart";
    local tooltip = "Toggles the vendor decor shopping cart feature.";

    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateCheckbox(category, setting, tooltip);
end

do
    local variable = internal.Setting.EnableDecorItemCounts;
    local name = "Enable Decor Item Counts";
    local tooltip = "Displays a number showing the amount of each decor item you currently have in storage, in the vendor frame.";

    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateCheckbox(category, setting, tooltip);
end

do
    local variable = internal.Setting.EnableDecorNewItemIcon;
    local name = "Enable New Decor Icon";
    local tooltip = "Shows an icon when the first acquisition bonus is available for a decor item.";

    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateCheckbox(category, setting, tooltip);
end

do
    local variable = internal.Setting.AddToCartModifier;
    local name = "Add to Cart Modifier";
    local tooltip = "The modifier that must be held down when right-clicking an item to add it to the cart.";

    local optionTooltips = {
        [1] = "Add an item to the cart using an Alt Right-click",
        [2] = "Add an item to the cart using an Ctrl Right-click",
        [3] = "Add an item to the cart using an Shift Right-click",
    };

    local options = Settings.CreateModifiedClickOptions(optionTooltips, true); -- using Blizzard Settings here
    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateDropdown(category, setting, options, tooltip);
end

function S.IsAddToCartModifierDown()
    local key = S.GetSetting(internal.Setting.AddToCartModifier);
    if key == "ALT" then
        return IsAltKeyDown();
    elseif key == "CTRL" then
        return IsControlKeyDown();
    elseif key == "SHIFT" then
        return IsShiftKeyDown();
    end
end

S.CreateHeader(category, "Shopping Lists");

do
    local variable = internal.Setting.EnableDecorShoppingListIcon;
    local name = "Show Shopping List Item Icon";
    local tooltip = "Shows an icon on vendor items if the item is on one or more of your shopping lists.";

    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateCheckbox(category, setting, tooltip);
end

do
    local variable = internal.Setting.ShowTotalShoppingListMissingCount;
    local name = "Show Total Missing Count";
    local tooltip = "Show the total missing count for an item instead of a per-shopping list breakdown.";

    local setting = S.CreateSetting(category, variable, name, defaultConfig[variable]);
    S.CreateCheckbox(category, setting, tooltip);
end
