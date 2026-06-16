local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;
local Cart = internal.Cart;

------------

local function GetHelpTextModifier()
    local fmt = "Hold the " .. NORMAL_FONT_COLOR:WrapTextInColorCode("[%s]") .. " and right-click";
    local key = internal.Settings.GetSetting(internal.Setting.AddToCartModifier);
    return format(fmt, _G[key .. "_KEY"]);
end

------------

local CART_FRAME_SIZE_X = 350;
local CART_FRAME_SIZE_Y = 400;

local ShoppingCartFrame = CreateFrame("Frame", "SimscraftShoppingCartFrame", MerchantFrame, "PortraitFrameFlatTemplate");
ButtonFrameTemplate_HidePortrait(ShoppingCartFrame);
ShoppingCartFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 10, 0);
ShoppingCartFrame:SetTitle(internal.ThemeColor:WrapTextInColorCode(addonName) .. " Shopping Cart");
ShoppingCartFrame:SetSize(CART_FRAME_SIZE_X, CART_FRAME_SIZE_Y);
ShoppingCartFrame:SetScript("OnShow", function()
    Registry:TriggerEvent(Events.CART_FRAME_SHOW);
end);
ShoppingCartFrame:SetScript("OnHide", function()
    Registry:TriggerEvent(Events.CART_FRAME_HIDE);
end);
ShoppingCartFrame.CloseButton:HookScript("OnClick", function()
    Registry:TriggerEvent(Events.CART_FRAME_CLOSE_BUTTON_CLICKED);
end);

------------

local PURCHASE_BUTTON_DEFAULT_TEXT = PERKS_PROGRAM_CART_PURCHASE_TOOLTIP;

local PurchaseButton = CreateFrame("Button", nil, ShoppingCartFrame, "SharedGoldRedButtonLargeTemplate");
PurchaseButton:SetPoint("BOTTOMRIGHT", -18, 8);
PurchaseButton:SetHeight(40);
PurchaseButton:SetText(PURCHASE_BUTTON_DEFAULT_TEXT);
PurchaseButton:SetScript("OnClick", function()
    Cart.ConfirmPurchase();
end);
PurchaseButton:Disable();

------------

local ClearCartButton = CreateFrame("Button", nil, ShoppingCartFrame, "SimscraftClearCartButtonTemplate");
ClearCartButton:SetPoint("BOTTOMLEFT", 18, 8);
ClearCartButton:SetScript("OnClick", function()
    Cart.ShowClearCartPopup();
end);
ClearCartButton.tooltipText = PERKS_PROGRAM_CART_CLEAR_TOOLTIP;

PurchaseButton:SetPoint("LEFT", ClearCartButton, "RIGHT", 10, 0);

local HelpText = ShoppingCartFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
HelpText:SetWidth(CART_FRAME_SIZE_X - 25);
HelpText:SetPoint("CENTER", 0, 15);
HelpText:SetJustifyH("CENTER");
HelpText:SetJustifyV("MIDDLE");
HelpText:SetTextColor(GRAY_FONT_COLOR:GetRGBA());
HelpText:SetScript("OnShow", function()
    HelpText:SetText("Your shopping cart is currently empty.|n" .. GetHelpTextModifier() .. " to add an item to your cart.");
end);

------

local PurchasingOverlay = CreateFrame("Frame", nil, ShoppingCartFrame);
PurchasingOverlay:SetPoint("TOPLEFT", 5, -15);
PurchasingOverlay:SetPoint("BOTTOMRIGHT", 0, 4);
PurchasingOverlay:Hide();

local OverlayTexture = PurchasingOverlay:CreateTexture(nil, "OVERLAY");
OverlayTexture:SetColorTexture(0, 0, 0, 0.75);
OverlayTexture:SetAllPoints();

local OverlayProgressBar = CreateFrame("StatusBar", nil, PurchasingOverlay, "SimscraftPurchaseOverlayProgressBarTemplate");
OverlayProgressBar:SetPoint("CENTER");

local function InitOverlayProgressBar(maxValue)
    OverlayProgressBar:SetMinMaxSmoothedValue(0, maxValue);
    OverlayProgressBar:SetValue(0);
    OverlayProgressBar.ProgressText:SetTextToFit("");
    OverlayProgressBar.PurchasingText:SetTextToFit("Purchasing");
end

local function UpdateOverlayProgressBar(self, current)
    self:SetSmoothedValue(current);
    local _, max = self:GetMinMaxValues()
    local progress = format("%d/%d", current, max);
    self.ProgressText:SetTextToFit(progress);
end
Registry:RegisterCallback(Events.CART_TICK_PURCHASE, UpdateOverlayProgressBar, OverlayProgressBar);

local OverlayTextTicker;
local OverlayTextStep = 1;
local function ShowPurchaseOverlay(self, numItemsInCart)
    self:Show();
    InitOverlayProgressBar(numItemsInCart);
    OverlayTextTicker = C_Timer.NewTicker(1, function()
        local text = "Purchasing" .. strrep(".", OverlayTextStep);
        OverlayProgressBar.PurchasingText:SetTextToFit(text);
        OverlayTextStep = OverlayTextStep + 1;
        if OverlayTextStep > 3 then
            OverlayTextStep = 1;
        end
    end);
end
Registry:RegisterCallback(Events.CART_BEGIN_PURCHASE, ShowPurchaseOverlay, PurchasingOverlay);

local function HidePurchaseOverlay(self)
    if OverlayTextTicker then
        OverlayTextTicker:Cancel();
        OverlayTextTicker = nil;
        OverlayTextStep = 1;
    end

    self:Hide();
end
Registry:RegisterCallback(Events.CART_END_PURCHASE, HidePurchaseOverlay, PurchasingOverlay);
Registry:RegisterCallback(Events.CART_REFRESH, HidePurchaseOverlay, PurchasingOverlay);

------

local ScrollBox = CreateFrame("Frame", nil, ShoppingCartFrame, "WowScrollBoxList");
ScrollBox:SetParentKey("ScrollBox");

local ScrollBar = CreateFrame("EventFrame", nil, ShoppingCartFrame, "MinimalScrollBar");
ScrollBar:SetPoint("TOPRIGHT", -5, -30);
ScrollBar:SetPoint("BOTTOMRIGHT", -5, 5);
ScrollBar:SetParentKey("ScrollBar");

local anchorsWithScrollBar = {
    CreateAnchor("TOPLEFT", ShoppingCartFrame, "TOPLEFT", 5, -30),
    CreateAnchor("TOPRIGHT", ScrollBar, "TOPLEFT", -5, 0),
    CreateAnchor("BOTTOM", PurchaseButton, "TOP", 0, 5),
};

local anchorsWithoutScrollBar = {
    anchorsWithScrollBar[1],
    CreateAnchor("TOPRIGHT", ShoppingCartFrame, "TOPRIGHT", -5, -30),
    anchorsWithScrollBar[3],
};

ScrollUtil.AddManagedScrollBarVisibilityBehavior(ScrollBox, ScrollBar, anchorsWithScrollBar, anchorsWithoutScrollBar);

------

local topPadding = 3;
local bottomPadding = 3;
local leftPadding = 3;
local rightPadding = 3;
local spacing = 5;

local ScrollView = CreateScrollBoxListLinearView(topPadding, bottomPadding, leftPadding, rightPadding, spacing);
ScrollUtil.InitScrollBoxListWithScrollBar(ScrollBox, ScrollBar, ScrollView);

local function InitializeCartEntry(frame, itemLink)
    frame:Init(itemLink);
end

ScrollView:SetElementInitializer("SimscraftShoppingCartEntryTemplate", InitializeCartEntry);

local DataProvider = CreateDataProvider();
ScrollView:SetDataProvider(DataProvider);

------------

local ErrorText = ShoppingCartFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
ErrorText:SetPoint("TOP", ScrollBox, "BOTTOM", 0, 7);
ErrorText:SetText(RED_FONT_COLOR:WrapTextInColorCode(ERR_NOT_ENOUGH_MONEY));
ErrorText:Hide();

------------

ScrollView:RegisterCallback("OnDataChanged", function()
    Registry:TriggerEvent(Events.CART_REFRESH);
end);

---@class SimscraftAutoBuyUI
local UI = {};


------------

local CartToggle = CreateFrame("Button", nil, MerchantFrameCloseButton, "SimscraftToggleCartButtonTemplate");
CartToggle:SetPoint("TOPRIGHT", MerchantFrameCloseButton, "TOPLEFT", -1, 0);

local function UpdateCartToggleEnableState()
    local enabled = not ShoppingCartFrame:IsShown();
    CartToggle:SetEnabled(enabled);

    if enabled then
        CartToggle.tooltipText = "Show the Simscraft Shopping Cart";
    else
        CartToggle.tooltipText = nil;
    end
end
Registry:RegisterCallback(Events.CART_FRAME_VISIBILITY_CHANGED, UpdateCartToggleEnableState);

CartToggle:SetScript("OnClick", function()
    local isShown = ShoppingCartFrame:IsShown();
    if isShown then
        Registry:TriggerEvent(Events.CART_FRAME_CLOSE_BUTTON_CLICKED);
    end

    ShoppingCartFrame:SetShown(not isShown);
end);

------------
--- config

local function OnShoppingCartShow()
    SimscraftConfig.CartShown = true;
end
Registry:RegisterCallback(Events.CART_FRAME_SHOW, OnShoppingCartShow);

local function OnShoppingCartCloseButtonClicked()
    SimscraftConfig.CartShown = false;
end
Registry:RegisterCallback(Events.CART_FRAME_CLOSE_BUTTON_CLICKED, OnShoppingCartCloseButtonClicked);

------------
--- UI updating!

local function RefreshButtonsAndTexts()
    local hasItemsInCart = DataProvider:GetSize() > 0;
    local canAfford = Cart.CanPlayerAffordPurchase();

    PurchaseButton:SetEnabled(hasItemsInCart and canAfford);
    ErrorText:SetShown(hasItemsInCart and not canAfford);

    local purchaseText;
    if hasItemsInCart then
        local costString = Cart.GenerateCostString();
        purchaseText = PURCHASE_BUTTON_DEFAULT_TEXT .. " " .. costString;
    else
        purchaseText = PURCHASE_BUTTON_DEFAULT_TEXT;
    end
    PurchaseButton:SetText(purchaseText);

    ClearCartButton:SetEnabled(hasItemsInCart);

    HelpText:SetShown(not hasItemsInCart);
    ScrollView:ReinitializeFrames();
end
Registry:RegisterCallback(Events.CART_REFRESH, RefreshButtonsAndTexts);

local function OnBeginPurchase()
    PurchaseButton:Disable();
    ClearCartButton:Disable();
end
Registry:RegisterCallback(Events.CART_BEGIN_PURCHASE, OnBeginPurchase);

local function OnClearCart()
    DataProvider = CreateDataProvider();
    ScrollView:SetDataProvider(DataProvider);
end
Registry:RegisterCallback(Events.CART_CLEAR, OnClearCart);
