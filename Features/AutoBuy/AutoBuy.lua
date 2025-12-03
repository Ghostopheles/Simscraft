-- TODO: add on OnTabPressed handler to the entries to enable tabbing down the list via the editboxes
-- TODO: add an OnEscapePressed handler to the cart items edit box
-- TODO: maybe enable hyperlinks on the item labels?

local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

local ASYNC_PURCHASE_STEP = 0.75; -- in seconds
local MAX_PURCHASE_ACTIONS_PER_TICK = 5;
local HIGH_COST_THRESHOLD = 25000000; -- 2,500 gold
local PURCHASE_COMPLETION_SOUNDKIT = SOUNDKIT.UI_GARRISON_TOAST_MISSION_COMPLETE;
local ITEM_COUNT_LOW_LIMIT = 5;

local function IsAutoBuyEnabled()
    return internal.Settings.GetSetting("EnableAutoBuy");
end

local function IsItemCountsEnabled()
    return internal.Settings.GetSetting("EnableDecorItemCounts");
end

local function IsNewItemIconEnabled()
    return internal.Settings.GetSetting("EnableDecorNewItemIcon");
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

    local itemCostString = Cart.GenerateCostString(data);
    if itemCostString ~= "" then
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

local UpdateCartToggleEnableState;
local UpdateModelPreviewFrameAnchors;

local ShoppingCartFrame = CreateFrame("Frame", "SimscraftShoppingCartFrame", MerchantFrame, "PortraitFrameFlatTemplate");
ButtonFrameTemplate_HidePortrait(ShoppingCartFrame);
ShoppingCartFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 10, 0);
ShoppingCartFrame:SetTitle(internal.ThemeColor:WrapTextInColorCode(addonName) .. " Shopping Cart");
ShoppingCartFrame:SetSize(350, 400);
ShoppingCartFrame:SetScript("OnShow", function()
    UpdateCartToggleEnableState();
    UpdateModelPreviewFrameAnchors();
    SimscraftConfig.CartShown = true;
end);
ShoppingCartFrame.CloseButton:HookScript("OnClick", function()
    UpdateCartToggleEnableState();
    SimscraftConfig.CartShown = false;
end);

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
HelpText:SetText("Your shopping cart is currently empty.|n" .. WARDROBE_SHORTCUTS_TUTORIAL_2 .. " to add an item to your cart.");

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
    self:SetValue(0);
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

local ErrorText = ShoppingCartFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
ErrorText:SetPoint("TOP", ScrollBox, "BOTTOM", 0, 7);
ErrorText:SetText(RED_FONT_COLOR:WrapTextInColorCode(ERR_NOT_ENOUGH_MONEY));
ErrorText:Hide();

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
    local canAfford = Cart.CanPlayerAffordPurchase();

    PurchaseButton:SetEnabled(hasItemsInCart and canAfford);
    ErrorText:SetShown(not canAfford);

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

function Cart.GetCostForItemEntry(itemEntry, stackCost)
    local index = itemEntry.Index;
    local info = C_MerchantFrame.GetItemInfo(index);
    local fullGoldCost = info.price;
    if stackCost then
        fullGoldCost = info.price * itemEntry.Quantity;
    end

    local extendedCost = {};
    if info.hasExtendedCost then
        local numExtendedItems = GetMerchantItemCostInfo(index);
        for i=1, numExtendedItems do
            local itemTexture, itemValue, itemLink, currencyName = GetMerchantItemCostItem(index, i);
            local fullAmount = itemValue;
            if stackCost then
                fullAmount = itemValue * itemEntry.Quantity;
            end

            extendedCost[itemTexture] = {
                Amount = fullAmount,
                ItemLink = itemLink,
                CurrencyName = currencyName
            };
        end
    end

    return fullGoldCost, extendedCost;
end

function Cart.CalculateTotalCartPrice()
    local totalCost = 0;
    local totalExtendedCost = {};
    DataProvider:ReverseForEach(function(itemEntry)
        local stackCost = true;
        local itemCost, extendedCost = Cart.GetCostForItemEntry(itemEntry, stackCost);
        totalCost = totalCost + itemCost;
        for texture, cost in pairs(extendedCost) do
            if totalExtendedCost[texture] then
                local newAmount = totalExtendedCost[texture].Amount + cost.Amount;
                totalExtendedCost[texture].Amount = newAmount;
            else
                totalExtendedCost[texture] = cost;
            end
        end
    end);

    return totalCost, totalExtendedCost;
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
            internal.Print("Done purchasing! If the server is overloaded, it may have skipped some items.");
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
    PlaySound(PURCHASE_COMPLETION_SOUNDKIT);
    FlashClientIcon();
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

function Cart.GenerateCostString(itemEntry)
    local goldCost, extendedCost;
    if itemEntry then
        goldCost, extendedCost = Cart.GetCostForItemEntry(itemEntry);
    else
        goldCost, extendedCost = Cart.CalculateTotalCartPrice();
    end

    local goldString = "";
    if goldCost > 0 then
        goldString = C_CurrencyInfo.GetCoinTextureString(goldCost);
    end

    local extendedCostString = "";
    for texture, cost in pairs(extendedCost) do
        local str = format("|T%d:0|t %d ", texture, cost.Amount);
        extendedCostString = extendedCostString .. str;
    end
    extendedCostString = strtrim(extendedCostString);

    return WHITE_FONT_COLOR:WrapTextInColorCode(goldString .. extendedCostString);
end

function Cart.ShowClearCartPopup()
    local numItemsInCart = Cart.GetTotalNumberOfItemsInCart();
    StaticPopup_Show("SIMSCRAFT_CLEAR_CART_CONFIRM", numItemsInCart);
end

function Cart.ConfirmPurchase()
    local totalCost, totalExtendedCost = Cart.CalculateTotalCartPrice();
    local hasExtendedCost = next(totalExtendedCost) ~= nil;
    if totalCost > HIGH_COST_THRESHOLD or hasExtendedCost then
        local numItemsInCart = Cart.GetTotalNumberOfItemsInCart();
        local costString = Cart.GenerateCostString();
        StaticPopup_Show("SIMSCRAFT_PURCHASE_CONFIRM", costString, numItemsInCart);
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
        local button = _G["MerchantItem".. i .."ItemButton"];
        if not HookedButtons[button] then
            HookedButtons[button] = true;
            button:HookScript("OnClick", function(self, mouseButton)
                if not IsAutoBuyEnabled() then
                    return;
                end

                if internal.Settings.IsAddToCartModifierDown() and mouseButton == "RightButton" then
                    local index = ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i;
                    local itemID = GetMerchantItemID(index);
                    if not C_Item.IsDecorItem(itemID) then
                        return;
                    end

                    ShoppingCartFrame:Show();
                    Cart.AddItemToCartByIndex(index);
                end
            end);
        end
    end
end

local function ShowAutoBuy()
    if ShoppingCartFrame:IsShown() then
        return;
    end

    ShoppingCartFrame:SetShown(SimscraftConfig.CartShown);
    Cart.Flush();
    HookItemButtons();
    HidePurchaseOverlay();
end

local function CheckDecorItemsAndShowFrame()
    for i=1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(i);
        local item = Item:CreateFromItemID(itemID);
        item:ContinueOnItemLoad(function()
            if C_Item.IsDecorItem(itemID) then
                ShowAutoBuy();
            end
        end);
    end
end

local function OnMerchantShow()
    if not IsAutoBuyEnabled() then
        return;
    end

    ShoppingCartFrame:Hide();
    CheckDecorItemsAndShowFrame();
end

local function OnMerchantClosed()
    Cart.StopAsyncPurchase();
    Cart.Flush();
end

EventRegistry:RegisterFrameEventAndCallback("MERCHANT_SHOW", OnMerchantShow);
EventRegistry:RegisterFrameEventAndCallback("MERCHANT_CLOSED", OnMerchantClosed);

local function OnTooltipSetItem(tooltip)
    if not C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Merchant) then
        return;
    end

    if tooltip.GetItem then
        local itemID = select(3, tooltip:GetItem());
        if itemID and C_Item.IsDecorItem(itemID) then
            local text = internal.ThemeColor:WrapTextInColorCode(WARDROBE_SHORTCUTS_TUTORIAL_2 .. " to add this item to your cart");
            tooltip:AddLine(text);
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem);

------------

local CartToggle = CreateFrame("Button", nil, MerchantFrameCloseButton, "SimscraftToggleCartButtonTemplate");
CartToggle:SetPoint("TOPRIGHT", MerchantFrameCloseButton, "TOPLEFT", -1, 0);

function UpdateCartToggleEnableState()
    local enabled = not ShoppingCartFrame:IsShown();
    CartToggle:SetEnabled(enabled);

    if enabled then
        CartToggle.tooltipText = "Show the Simscraft Shopping Cart";
    else
        CartToggle.tooltipText = nil;
    end
end

CartToggle:SetScript("OnClick", function(self)
    ShoppingCartFrame:SetShown(not ShoppingCartFrame:IsShown());
    UpdateCartToggleEnableState();
end);

------------

local anchorsTouched = false;
function UpdateModelPreviewFrameAnchors()
    if HousingModelPreviewFrame then
        if ShoppingCartFrame:IsShown() then
            HousingModelPreviewFrame:SetPoint("TOPLEFT", ShoppingCartFrame, "TOPRIGHT", 10, 0);
            anchorsTouched = true;
        elseif anchorsTouched and not MerchantFrame:IsShown() then
            anchorsTouched = false;
            HousingModelPreviewFrame:ClearAllPoints();
            HideUIPanel(HousingModelPreviewFrame);
            ShowUIPanel(HousingModelPreviewFrame);
        end
    end
end

-- hook item preview window so it doesn't cover up our cart
EventUtil.ContinueOnAddOnLoaded("Blizzard_HousingModelPreview", function()
    HousingModelPreviewFrame:HookScript("OnShow", function(self)
        UpdateModelPreviewFrameAnchors();
    end);
end);

------------
--- number owned doohickey

--- need to create a catalog searcher to refresh the 'number of owned decor items' cache (???)
--- also need to refresh it on the HOUSING_CATALOG_SEARCHER_RELEASED event
C_HousingCatalog.CreateCatalogSearcher();

local CACHE_WAIT_TIME = 0.1;

local function GetDecorNumOwnedFromItemID(itemID)
    local tryGetOwnedInfo = true;
    local catalogEntryInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, tryGetOwnedInfo);
    if not catalogEntryInfo then
        return;
    end

    return catalogEntryInfo.numStored, catalogEntryInfo.firstAcquisitionBonus;
end

local NewItemIcons = {};
local newItemIconsSetup = false;
local function SetupNewItemIcons()
    if newItemIconsSetup then
        return;
    end

    for i=1, MERCHANT_ITEMS_PER_PAGE do
        local parent = _G["MerchantItem"..i.."ItemButton"];
        local icon = parent:CreateTexture(nil, "OVERLAY", nil, 2);
        icon:SetSize(24, 24);
        icon:SetPoint("CENTER", parent, "TOPLEFT");
        icon:SetAtlas("wowlabs_spellbucketicon-sword");

        tinsert(NewItemIcons, icon);
    end

    newItemIconsSetup = true;
end

local ItemCountTextColors = {
    NONE = RED_FONT_COLOR;
    LOW = YELLOW_FONT_COLOR;
    OKAY = WHITE_FONT_COLOR;
};

local ItemCountFormat = CreateAtlasMarkup("house-chest-icon", 16, 16) .. " %s";

local ItemCountWidgets = {};
local function CreateItemCountWidget(parent)
    local str = parent:CreateFontString(nil, "ARTWORK", "GameFontWhite");
    str:SetJustifyH("RIGHT");
    str:SetJustifyV("MIDDLE");

    tinsert(ItemCountWidgets, str);
    return str;
end

local function UpdateItemWidgetsForItemID(widget, itemID, nonPagedIndex)
    local numStored, firstAcquisitionBonus = GetDecorNumOwnedFromItemID(itemID);
    if not numStored then
        return;
    end

    local color;
    if numStored == 0 or not numStored then
        color = ItemCountTextColors.NONE;
    elseif numStored < ITEM_COUNT_LOW_LIMIT then
        color = ItemCountTextColors.LOW;
    else
        color = ItemCountTextColors.OKAY;
    end

    local text = format(ItemCountFormat, color:WrapTextInColorCode(numStored));
    widget:SetTextToFit(text);
    widget:SetShown(IsItemCountsEnabled());

    local icon = NewItemIcons[nonPagedIndex];
    local showIcon = (firstAcquisitionBonus and firstAcquisitionBonus > 0 and IsNewItemIconEnabled()) or false;
    icon:SetShown(showIcon);
end

--- creating our widgets

local widgetsCreated = false;
local function CreateAllItemCountWidgets()
    if widgetsCreated then
        return;
    end

    for i=1, MERCHANT_ITEMS_PER_PAGE do
        local itemFrame = _G["MerchantItem"..i];
        local countString = CreateItemCountWidget(itemFrame);
        countString:SetPoint("BOTTOMRIGHT");
    end
    widgetsCreated = true;
end

local function OnMerchantFrameUpdate()
    if not widgetsCreated then
        CreateAllItemCountWidgets();
    end

    for i, widget in ipairs(ItemCountWidgets) do
        local index = ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i;
        local itemID = GetMerchantItemID(index);
        widget:Hide();
        local icon = NewItemIcons[i];
        if icon then
            icon:Hide();
        end
        if itemID then
            local isDecorItem = itemID and C_Item.IsDecorItem(itemID);
            if isDecorItem then
                local currentPage = MerchantFrame.page;
                C_Timer.After(CACHE_WAIT_TIME, function()
                    if MerchantFrame.page ~= currentPage then
                        return;
                    end
                    UpdateItemWidgetsForItemID(widget, itemID, i);
                end);
            end
        end
    end
end

local function RefreshSearcher()
    C_HousingCatalog.CreateCatalogSearcher();
end

hooksecurefunc("MerchantFrame_Update", OnMerchantFrameUpdate);
EventRegistry:RegisterFrameEventAndCallback("NEW_HOUSING_ITEM_ACQUIRED", OnMerchantFrameUpdate);
EventRegistry:RegisterFrameEventAndCallback("ZONE_CHANGED", RefreshSearcher);
EventRegistry:RegisterFrameEventAndCallback("ZONE_CHANGED_NEW_AREA", RefreshSearcher);
EventRegistry:RegisterFrameEventAndCallback("HOUSING_CATALOG_SEARCHER_RELEASED", RefreshSearcher);
EventUtil.RegisterOnceFrameEventAndCallback("MERCHANT_SHOW", SetupNewItemIcons);