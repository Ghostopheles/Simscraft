-- TODO: add on OnTabPressed handler to the entries to enable tabbing down the list via the editboxes
-- TODO: handle showing/hiding the shopping cart frame
-- TODO: maybe enable hyperlinks on the item labels?
-- TODO: add support for item currencies

-- NOTE: you may run into issues shift-clicking on things if they support stack purchasing. too bad!

local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

local ASYNC_PURCHASE_STEP = 0.5; -- in seconds
local MAX_PURCHASE_ACTIONS_PER_TICK = 5;
local HIGH_COST_THRESHOLD = 25000000; -- 2,500 gold

local function IsAutoBuyEnabled()
    return internal.Settings.GetSetting("EnableAutoBuy");
end

------------

local Cart = {};

StaticPopupDialogs["SIMSCRAFT_CLEAR_CART_CONFIRM"] = {
    text = 	PERKS_PROGRAM_CART_CLEAR_POPUP_TEXT,
    button1 = PERKS_PROGRAM_CART_CLEAR_POPUP_CONFIRMATION,
    button2 = CANCEL,
    OnAccept = function() Cart.Flush(); end,
    hideOnEscape = true,
    timeout = 0,
    exclusive = true,
    showAlert = true
};

StaticPopupDialogs["SIMSCRAFT_PURCHASE_CONFIRM"] = {
    text = 	PERKS_PROGRAM_CART_PURCHASE_POPUP_TEXT,
    button1 = YES,
    button2 = NO,
    OnAccept = function() Cart.AsyncFinalizePurchase(); end,
    hideOnEscape = true,
    timeout = 0,
    exclusive = true,
    showAlert = true
};

------------

ShoppingCartEntryMixin = {};

function ShoppingCartEntryMixin:OnLoad()
    self.RemoveButton:SetScript("OnClick", function()
        self:OnRemoveButtonClicked();
    end);

    self.QuantityEditBox:SetScript("OnEditFocusLost", function()
        self:OnEditBoxFocusLost();
    end);

    self.QuantityEditBox:SetScript("OnEnterPressed", function()
        self:OnEditBoxEnterPressed();
    end);
end

function ShoppingCartEntryMixin:Init(data)
    local itemLink = GetMerchantItemLink(data.Index);
    self.ItemButton:SetItem(itemLink);
    self.ItemLabel:SetText(itemLink);
    self.QuantityEditBox:SetNumber(data.Quantity);

    local itemCost = C_MerchantFrame.GetItemInfo(data.Index).price;
    if itemCost then
        local itemCostString = C_CurrencyInfo.GetCoinTextureString(itemCost);
        self.ItemCost:SetText("x " .. itemCostString);
    else
        self.ItemCost:SetText("");
    end
end

function ShoppingCartEntryMixin:UpdateQuantityFromEditBox()
    local data = self:GetData();
    local newQuantity = self.QuantityEditBox:GetNumber();
    if newQuantity == 0 then
        Cart.RemoveItemFromCartByIndex(data.Index);
    else
        Cart.SetQuantityForItemInCartByIndex(data.Index, newQuantity);
    end
end

function ShoppingCartEntryMixin:OnRemoveButtonClicked()
    local data = self:GetData();
    Cart.RemoveItemFromCartByIndex(data.Index);
end

function ShoppingCartEntryMixin:OnEditBoxFocusLost()
    self:UpdateQuantityFromEditBox();
end

function ShoppingCartEntryMixin:OnEditBoxEnterPressed()
    self.QuantityEditBox:ClearFocus();
end

------------

local ShoppingCartFrame = CreateFrame("Frame", "SimscraftShoppingCartFrame", MerchantFrame, "PortraitFrameFlatTemplate");
ButtonFrameTemplate_HidePortrait(ShoppingCartFrame);
ShoppingCartFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 10, 0);
ShoppingCartFrame:SetTitle(addonName .. " Shopping Cart");
ShoppingCartFrame:SetSize(350, 400);

local PURCHASE_BUTTON_DEFAULT_TEXT = PERKS_PROGRAM_CART_PURCHASE_TOOLTIP;

local PurchaseButton = CreateFrame("Button", nil, ShoppingCartFrame, "SharedGoldRedButtonLargeTemplate");
PurchaseButton:SetPoint("BOTTOMRIGHT", -18, 8);
PurchaseButton:SetHeight(40);
PurchaseButton:SetText(PURCHASE_BUTTON_DEFAULT_TEXT);
PurchaseButton:SetScript("OnClick", function()
    Cart.ConfirmPurchase();
end);
PurchaseButton:SetScript("OnShow", function()
    PurchaseButton:SetText(PURCHASE_BUTTON_DEFAULT_TEXT);
end);

local ClearCartButton = CreateFrame("Button", nil, ShoppingCartFrame, "SimscraftClearCartButtonTemplate");
ClearCartButton:SetPoint("BOTTOMLEFT", 18, 8);
ClearCartButton:SetScript("OnClick", function()
    Cart.ShowClearCartPopup();
end);
ClearCartButton.tooltipText = PERKS_PROGRAM_CART_CLEAR_TOOLTIP;

PurchaseButton:SetPoint("LEFT", ClearCartButton, "RIGHT", 10, 0);

local HelpText = ShoppingCartFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
HelpText:SetPoint("CENTER", 0, 15);
HelpText:SetJustifyH("CENTER");
HelpText:SetJustifyV("MIDDLE");
HelpText:SetTextColor(GRAY_FONT_COLOR:GetRGBA());
HelpText:SetText("Your shopping cart is currently empty.");

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
    local self = OverlayProgressBar;
    self:SetMinMaxSmoothedValue(0, maxValue);
    self:SetSmoothedValue(0);
    self.ProgressText:SetTextToFit("");
    self.PurchasingText:SetTextToFit("Purchasing");
end

local function UpdateOverlayProgressBar(current)
    local self = OverlayProgressBar;
    self:SetSmoothedValue(current);
    local _, max = self:GetMinMaxValues()
    local progress = format("%d/%d", current, max);
    self.ProgressText:SetTextToFit(progress);
end

local OverlayTextTicker;
local OverlayTextStep = 1;
local function ShowPurchaseOverlay(numItemsInCart)
    PurchasingOverlay:Show();
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

local function HidePurchaseOverlay()
    if OverlayTextTicker then
        OverlayTextTicker:Cancel();
        OverlayTextTicker = nil;
        OverlayTextStep = 1;
    end

    PurchasingOverlay:Hide();
end

------

local ScrollBox = CreateFrame("Frame", nil, ShoppingCartFrame, "WowScrollBoxList");

local ScrollBar = CreateFrame("EventFrame", nil, ShoppingCartFrame, "MinimalScrollBar");
ScrollBar:SetPoint("TOPRIGHT", -5, -30);
ScrollBar:SetPoint("BOTTOMRIGHT", -5, 5);

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

------

---@class ShoppingCartEntry
---@field MerchantIndex number
---@field Quantity number

function Cart.Flush()
    DataProvider = CreateDataProvider();
    ScrollView:SetDataProvider(DataProvider);
end

function Cart.Refresh()
    local hasItemsInCart = DataProvider:GetSize() > 0;
    local totalCartCost = Cart.CalculateTotalCartPrice();
    local canAfford = Cart.CanPlayerAffordPurchase();

    PurchaseButton:SetEnabled(hasItemsInCart and canAfford);

    local purchaseText;
    if hasItemsInCart then
        local coinTextureString = WHITE_FONT_COLOR:WrapTextInColorCode(C_CurrencyInfo.GetCoinTextureString(totalCartCost));
        purchaseText = PURCHASE_BUTTON_DEFAULT_TEXT .. " " .. coinTextureString;
    else
        purchaseText = PURCHASE_BUTTON_DEFAULT_TEXT;
    end
    PurchaseButton:SetText(purchaseText);

    ClearCartButton:SetEnabled(hasItemsInCart);

    HelpText:SetShown(not hasItemsInCart);
    ScrollView:ReinitializeFrames();
end

function Cart.GetItemByIndex(index)
    local _, entry = DataProvider:FindByPredicate(function(data)
        return data.Index == index;
    end);
    return entry;
end

function Cart.IsItemInCartByIndex(index)
    return Cart.GetItemByIndex(index) ~= nil;
end

function Cart.IncrementQuantityForItemInCartByIndex(index, amount)
    amount = amount or 1;
    local entry = Cart.GetItemByIndex(index);
    if entry then
        entry.Quantity = entry.Quantity + amount;
        Cart.Refresh();
    end
end

function Cart.SetQuantityForItemInCartByIndex(index, newQuantity)
    local entry = Cart.GetItemByIndex(index);
    if entry then
        entry.Quantity = newQuantity;
        Cart.Refresh();
    end
end

function Cart.AddItemToCartByIndex(index)
    if Cart.IsItemInCartByIndex(index) then
        Cart.IncrementQuantityForItemInCartByIndex(index);
        local entry = Cart.GetItemByIndex(index);
        ScrollBox:ScrollToElementData(entry);
    else
        local entry = {
            Index = index,
            Quantity = 1
        };
        DataProvider:Insert(entry);
        ScrollBox:ScrollToEnd();
    end
end

function Cart.RemoveItemFromCartByIndex(index)
    DataProvider:RemoveByPredicate(function(data)
        return data.Index == index;
    end);
end

function Cart.GetGoldCostForItemEntry(itemEntry)
    local info = C_MerchantFrame.GetItemInfo(itemEntry.Index);
    return info.price * itemEntry.Quantity;
end

function Cart.CalculateTotalCartPrice()
    local totalCost = 0;
    DataProvider:ReverseForEach(function(itemEntry)
        local itemCost = Cart.GetGoldCostForItemEntry(itemEntry);
        totalCost = totalCost + itemCost;
    end);

    return totalCost;
end

function Cart.GetTotalNumberOfItemsInCart()
    local totalItems = 0;
    DataProvider:ReverseForEach(function(itemEntry)
        totalItems = totalItems + itemEntry.Quantity;
    end);

    return totalItems;
end

function Cart.PurchaseItem(itemEntry)
    local numPurchaseActions = 0;
    local maxStack = GetMerchantItemMaxStack(itemEntry.Index);
    if maxStack >= itemEntry.Quantity then
        BuyMerchantItem(itemEntry.Index, itemEntry.Quantity);
        numPurchaseActions = numPurchaseActions + 1;
    else
        for _=1, itemEntry.Quantity do
            BuyMerchantItem(itemEntry.Index);
            numPurchaseActions = numPurchaseActions + 1;
        end
    end
end

function Cart.FinalizePurchase()
    DataProvider:ReverseForEach(Cart.PurchaseItem);
    Cart.Flush();
end

function Cart.GeneratePurchaseActions()
    local purchaseActions = {};

    local itemsInCart = CopyTable(DataProvider:GetCollection());
    for _, entry in ipairs(itemsInCart) do
        local maxStack = GetMerchantItemMaxStack(entry.Index);
        local quantity = entry.Quantity;
        while quantity > 0 do
            local purchaseQuantity = math.min(maxStack, quantity);
            tinsert(purchaseActions, {
                Index = entry.Index,
                Quantity = purchaseQuantity
            });
            quantity = quantity - purchaseQuantity;
        end
    end

    return purchaseActions;
end

function Cart.GenerateAsyncPurchaseOrder()
    local purchaseActions = Cart.GeneratePurchaseActions();

    local purchaseOrder = {};
    local tick = {};
    for i, action in ipairs(purchaseActions) do
        tinsert(tick, action);
        if #tick == MAX_PURCHASE_ACTIONS_PER_TICK or i == #purchaseActions then
            tinsert(purchaseOrder, tick);
            tick = {};
        end
    end

    return purchaseOrder;
end

local CartAsyncPurchaseTicker;
function Cart.AsyncFinalizePurchase()
    PurchaseButton:Disable();
    ClearCartButton:Disable();

    local purchaseOrder = Cart.GenerateAsyncPurchaseOrder();

    local numItemsInCart = Cart.GetTotalNumberOfItemsInCart();
    ShowPurchaseOverlay(numItemsInCart);

    local step = 1;
    local itemsBought = 0;
    local function Tick()
        local orders = purchaseOrder[step];
        if not orders then
            internal.Print("Done purchasing!");
            Cart.OnAsyncPurchaseComplete();
            return;
        end

        for _, itemEntry in ipairs(orders) do
            Cart.PurchaseItem(itemEntry);
        end

        step = step + 1;
        itemsBought = itemsBought + #orders;
        UpdateOverlayProgressBar(itemsBought);
    end
    CartAsyncPurchaseTicker = C_Timer.NewTicker(ASYNC_PURCHASE_STEP, Tick);
end

function Cart.OnAsyncPurchaseComplete()
    Cart.Flush();
    Cart.StopAsyncPurchase();
    HidePurchaseOverlay();
end

function Cart.StopAsyncPurchase()
    if not CartAsyncPurchaseTicker then
        return;
    end
    CartAsyncPurchaseTicker:Cancel();
    CartAsyncPurchaseTicker = nil;
end

function Cart.CanPlayerAffordPurchase()
    local totalCost = Cart.CalculateTotalCartPrice();
    return totalCost <= GetMoney();
end

function Cart.ShowClearCartPopup()
    local numItemsInCart = Cart.GetTotalNumberOfItemsInCart();
    StaticPopup_Show("SIMSCRAFT_CLEAR_CART_CONFIRM", numItemsInCart);
end

function Cart.ConfirmPurchase()
    local totalCost = Cart.CalculateTotalCartPrice();
    if totalCost > HIGH_COST_THRESHOLD then
        local numItemsInCart = Cart.GetTotalNumberOfItemsInCart();
        StaticPopup_Show("SIMSCRAFT_PURCHASE_CONFIRM", "uwu", numItemsInCart);
    else
        Cart.AsyncFinalizePurchase();
    end
end

------

ScrollView:RegisterCallback("OnDataChanged", Cart.Refresh);

------------

local HookedButtons = {};
local function HookItemButtons()
    for i=1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem"..i.."ItemButton"];
        if not HookedButtons[button] then
            HookedButtons[button] = true;
            button:HookScript("OnClick", function(self, mouseButton)
                if not IsAutoBuyEnabled() then
                    return;
                end

                if IsShiftKeyDown() and mouseButton == "RightButton" then
                    local index = ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i;
                    Cart.AddItemToCartByIndex(index);
                end
            end);
        end
    end
end

local function OnMerchantShow()
    if not IsAutoBuyEnabled() then
        ShoppingCartFrame:Hide();
        return;
    end

    ShoppingCartFrame:Show();
    Cart.Flush();
    HookItemButtons();
    HidePurchaseOverlay();
end

local function OnMerchantClosed()
    Cart.StopAsyncPurchase();
    Cart.Flush();
end

EventRegistry:RegisterFrameEventAndCallback("MERCHANT_SHOW", OnMerchantShow);
EventRegistry:RegisterFrameEventAndCallback("MERCHANT_CLOSED", OnMerchantClosed);