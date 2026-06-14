---@class SimscraftInternal
local internal = select(2, ...);

---@enum SimscraftEvents
local Events = {
	SETTING_CHANGED = "SETTING_CHANGED",
	HOUSE_EDITOR_MODE_CHANGED = "HOUSE_EDITOR_MODE_CHANGED",
	MODIFIER_STATE_CHANGED = "MODIFIER_STATE_CHANGED",
    CART_ADD_ITEM_BY_INDEX = "CART_ADD_ITEM_BY_INDEX",
    CART_REMOVE_ITEM_BY_INDEX = "CART_REMOVE_ITEM_BY_INDEX",
    CART_UPDATE_QUANTITY_BY_INDEX = "CART_UPDATE_QUANTITY_BY_INDEX",
    CART_REFRESH = "CART_REFRESH",
    CART_CLEAR = "CART_CLEAR", -- verify popup
    CART_FRAME_SHOW = "CART_FRAME_SHOW",
    CART_FRAME_HIDE = "CART_FRAME_HIDE",
    CART_FRAME_CLOSE_BUTTON_CLICKED = "CART_FRAME_CLOSE_BUTTON_CLICKED", -- fired when the user clicks the X to close the window
    CART_FRAME_VISIBILITY_CHANGED = "CART_FRAME_VISIBILITY_CHANGED",
    CART_TRY_PURCHASE = "CART_TRY_PURCHASE", -- verify popup
    CART_BEGIN_PURCHASE = "CART_BEGIN_PURCHASE", -- user has confirmed and purchasing has begun, includes the total number of items
    CART_ITEM_PURCHASED = "CART_ITEM_PURCHASED",
    CART_TICK_PURCHASE = "CART_TICK_PURCHASE",
    CART_END_PURCHASE = "CART_END_PURCHASE", -- args: success
    MERCHANT_SHOW = "MERCHANT_SHOW",
    MERCHANT_UPDATE = "MERCHANT_UPDATE",
    MERCHANT_CLOSED = "MERCHANT_CLOSED",
    NEW_HOUSING_ITEM_ACQUIRED = "NEW_HOUSING_ITEM_ACQUIRED",
    ZONE_CHANGED = "ZONE_CHANGED",
    ZONE_CHANGED_NEW_AREA = "ZONE_CHANGED_NEW_AREA",
	SHOPPING_LIST_SHOW = "SHOPPING_LIST_SHOW",
	SHOPPING_LIST_ADDED = "SHOPPING_LIST_ADDED",
	SHOPPING_LIST_REMOVED = "SHOPPING_LIST_REMOVED",
	SHOPPING_LIST_MOVE_ITEM = "SHOPPING_LIST_MOVE_ITEM",
	SHOPPING_LIST_DELETE_ITEM = "SHOPPING_LIST_DELETE_ITEM"
};

---@class SimscraftEventRegistry : CallbackRegistryMixin
local Registry = CreateFromMixins(CallbackRegistryMixin);
Registry:OnLoad();
Registry:GenerateCallbackEvents(GetKeysArray(Events));

internal.Events = Events;
internal.Registry = Registry;

local f = CreateFrame("Frame");
f:RegisterEvent("HOUSE_EDITOR_MODE_CHANGED");
f:RegisterEvent("MODIFIER_STATE_CHANGED");
f:SetScript("OnEvent", function(self, event, ...)
    if event == "HOUSE_EDITOR_MODE_CHANGED" then
        Registry:TriggerEvent(Events.HOUSE_EDITOR_MODE_CHANGED, ...);
    elseif event == "MODIFIER_STATE_CHANGED" then
        Registry:TriggerEvent(Events.HOUSE_EDITOR_MODE_CHANGED, ...);
    end
end);

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

------------

local FrameEvents = {
    "MERCHANT_SHOW",
    "MERCHANT_UPDATE",
    "MERCHANT_CLOSED",
    "ZONE_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
};

local EventFrame = CreateFrame("Frame");
FrameUtil.RegisterFrameForEvents(EventFrame, FrameEvents);
EventFrame:SetScript("OnEvent", function(self, event, ...)
    Registry:TriggerEvent(event, ...);
end);

hooksecurefunc("MerchantFrame_Update", function(self) Registry:TriggerEvent(Events.MERCHANT_UPDATE, self); end);
