---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftAutoBuy
internal.AutoBuy = {};

function internal.AutoBuy.GetShoppingCartFrame()
    return SimscraftShoppingCartFrame;
end

---@enum SimscraftAutoBuyEvents
local Events = {
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
    HOUSING_CATALOG_SEARCHER_RELEASED = "HOUSING_CATALOG_SEARCHER_RELEASED"
};

---@class SimscraftAutoBuyEventRegistry : CallbackRegistryMixin
local Registry = CreateFromMixins(CallbackRegistryMixin);
Registry:OnLoad();
Registry:GenerateCallbackEvents(GetKeysArray(Events));

local function OnCartVisibiltyToggled()
    Registry:TriggerEvent(Events.CART_FRAME_VISIBILITY_CHANGED, SimscraftShoppingCartFrame:IsShown());
end

Registry:RegisterCallback(Events.CART_FRAME_SHOW, OnCartVisibiltyToggled);
Registry:RegisterCallback(Events.CART_FRAME_HIDE, OnCartVisibiltyToggled);

internal.AutoBuy.Events = Events;
internal.AutoBuy.Registry = Registry;

------------

local FrameEvents = {
    "MERCHANT_SHOW",
    "MERCHANT_UPDATE",
    "MERCHANT_CLOSED",
    "ZONE_CHANGED",
    "ZONE_CHANGED_NEW_AREA",
    "HOUSING_CATALOG_SEARCHER_RELEASED"
};

local EventFrame = CreateFrame("Frame");
FrameUtil.RegisterFrameForEvents(EventFrame, FrameEvents);
EventFrame:SetScript("OnEvent", function(self, event, ...)
    Registry:TriggerEvent(event, ...);
end);

hooksecurefunc("MerchantFrame_Update", function(self) Registry:TriggerEvent(Events.MERCHANT_UPDATE, self); end);