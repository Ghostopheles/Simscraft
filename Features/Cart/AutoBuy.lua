-- TODO: add some graphic or progress indicator when performing an async purchase
-- TODO: add on OnTabPressed handler to the entries to enable tabbing down the list via the editboxes
-- TODO: add a confirmation dialog when the total purchase cost is high
-- TODO: handle showing/hiding the shopping cart frame
-- TODO: maybe enable hyperlinks on the item labels?
-- TODO: add gold cost per entry

-- NOTE: you may run into issues shift-clicking on things if they support stack purchasing. too bad!

local ASYNC_PURCHASE_STEP = 1; -- in seconds
local MAX_PURCHASE_ACTIONS_PER_SECOND = 5;

------------

local Cart = {};

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

local ShoppingCartFrame = CreateFrame("Frame", "ShoppingCartFrame", MerchantFrame, "PortraitFrameFlatTemplate");
ButtonFrameTemplate_HidePortrait(ShoppingCartFrame);
ShoppingCartFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 10, 0);
ShoppingCartFrame:SetTitle("Shopping Cart");
ShoppingCartFrame:SetSize(300, 400);

local PurchaseButton = CreateFrame("Button", nil, ShoppingCartFrame, "SharedGoldRedButtonLargeTemplate");
PurchaseButton:SetPoint("BOTTOM", 0, 20);
PurchaseButton:SetSize(150, 50);
PurchaseButton:SetText(PURCHASE);
PurchaseButton:SetScript("OnClick", function()
    Cart.AsyncFinalizePurchase();
end);

ShoppingCartFrame.PurchaseButton = PurchaseButton;

local MoneyFrame = CreateFrame("Frame", nil, ShoppingCartFrame, "SmallMoneyFrameTemplate");
MoneyFrame:SetPoint("TOP", PurchaseButton, "BOTTOM", 40, -1);
MoneyFrame_SetType(MoneyFrame, "STATIC");
MoneyFrame_Update(MoneyFrame, 0);

local MoneyFrameLabel = MoneyFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
MoneyFrameLabel:SetPoint("RIGHT", MoneyFrame, "LEFT", -5, 0);
MoneyFrameLabel:SetText(ITEM_UPGRADE_COST_LABEL);

local HelpText = ShoppingCartFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
HelpText:SetPoint("CENTER", 0, 15);
HelpText:SetJustifyH("CENTER");
HelpText:SetJustifyV("MIDDLE");
HelpText:SetTextColor(GRAY_FONT_COLOR:GetRGBA());
HelpText:SetText("Your shopping cart is currently empty.");

------

local ScrollBox = CreateFrame("Frame", nil, ShoppingCartFrame, "WowScrollBoxList");
ScrollBox:SetInterpolateScroll(true);

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

local topPadding = 0;
local bottomPadding = 0;
local leftPadding = 2;
local rightPadding = 0;
local spacing = 5;

local ScrollView = CreateScrollBoxListLinearView(topPadding, bottomPadding, leftPadding, rightPadding, spacing);
ScrollUtil.InitScrollBoxListWithScrollBar(ScrollBox, ScrollBar, ScrollView);

local function InitializeCartEntry(frame, itemLink)
    frame:Init(itemLink);
end

ScrollView:SetElementInitializer("ShoppingCartEntryTemplate", InitializeCartEntry);

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
    else
        local entry = {
            Index = index,
            Quantity = 1
        };
        DataProvider:Insert(entry);
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
        if #tick == MAX_PURCHASE_ACTIONS_PER_SECOND or i == #purchaseActions then
            tinsert(purchaseOrder, tick);
            tick = {};
        end
    end

    return purchaseOrder;
end

function Cart.AsyncFinalizePurchase()
    PurchaseButton:Disable();

    local purchaseOrder = Cart.GenerateAsyncPurchaseOrder();

    local step = 1;
    local function Tick()
        local orders = purchaseOrder[step];
        if not orders then
            print("Done purchasing!");
            Cart.OnAsyncPurchaseComplete();
            return;
        end

        for _, itemEntry in ipairs(orders) do
            Cart.PurchaseItem(itemEntry);
        end

        step = step + 1;
        C_Timer.After(ASYNC_PURCHASE_STEP, Tick);
    end

    Tick();
end

function Cart.OnAsyncPurchaseComplete()
    Cart.Flush();
end

function Cart.CanPlayerAffordPurchase()
    local totalCost = Cart.CalculateTotalCartPrice();
    return totalCost <= GetMoney();
end

------

local function OnDataChanged()
    local hasItemsInCart = DataProvider:GetSize() > 0;
    local totalCartCost = Cart.CalculateTotalCartPrice();
    local canAfford = Cart.CanPlayerAffordPurchase();

    MoneyFrame:SetShown(hasItemsInCart);
    MoneyFrame_Update(MoneyFrame, totalCartCost);

    PurchaseButton:SetEnabled(hasItemsInCart and canAfford);
    HelpText:SetShown(not hasItemsInCart);
end
ScrollView:RegisterCallback("OnDataChanged", OnDataChanged);

------------

local HookedButtons = {};
local function HookItemButtons()
    for i=1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem"..i.."ItemButton"];
        if not HookedButtons[button] then
            HookedButtons[button] = true;
            button:HookScript("OnClick", function(self, mouseButton)
                if IsShiftKeyDown() and mouseButton == "RightButton" then
                    local index = ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i;
                    Cart.AddItemToCartByIndex(index);
                end
            end);
        end
    end
end

local function OnMerchantShow()
    Cart.Flush();
    HookItemButtons();
end

EventRegistry:RegisterFrameEventAndCallback("MERCHANT_SHOW", OnMerchantShow);