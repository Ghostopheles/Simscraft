---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftAutoBuy
local AutoBuy = internal.AutoBuy;

local Events = AutoBuy.Events;
local Registry = AutoBuy.Registry;

------------

local ASYNC_PURCHASE_STEP = 0.75; -- in seconds
local MAX_PURCHASE_ACTIONS_PER_TICK = 5;
local HIGH_COST_THRESHOLD = 25000000; -- 2,500 gold
local PURCHASE_COMPLETION_SOUNDKIT = SOUNDKIT.UI_GARRISON_TOAST_MISSION_COMPLETE;

------------

local function GetScrollBox()
    local f = AutoBuy.GetShoppingCartFrame();
    return f.ScrollBox;
end

local function GetDataProvider()
    local sb = GetScrollBox();
    return sb:GetDataProvider();
end

---@class SimscraftShoppingCart
local Cart = {};

AutoBuy.Cart = Cart;

---@class SimscraftShoppingCartEntry
---@field MerchantIndex number
---@field Quantity number

function Cart.Flush()
    Registry:TriggerEvent(Events.CART_CLEAR);
end

function Cart.Refresh()
    Registry:TriggerEvent(Events.CART_REFRESH);
end

function Cart.GetNumUniqueItemsInCart()
    local dataProvider = GetDataProvider();
    return dataProvider:GetSize();
end

function Cart.GetItemByIndex(index)
    local dataProvider = GetDataProvider();
    local _, entry = dataProvider:FindByPredicate(function(data)
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
    SimscraftShoppingCartFrame:Show();

    local scrollBox = GetScrollBox();
    local dataProvider = GetDataProvider();

    if Cart.IsItemInCartByIndex(index) then
        Cart.IncrementQuantityForItemInCartByIndex(index);
        local entry = Cart.GetItemByIndex(index);
        scrollBox:ScrollToElementData(entry);
    else
        local entry = {
            Index = index,
            Quantity = 1
        };
        dataProvider:Insert(entry);
        scrollBox:ScrollToEnd();
    end
end
Registry:RegisterCallback(Events.CART_ADD_ITEM_BY_INDEX, function(_, index) Cart.AddItemToCartByIndex(index); end);

function Cart.RemoveItemFromCartByIndex(index)
    local dataProvider = GetDataProvider();
    dataProvider:RemoveByPredicate(function(data)
        return data.Index == index;
    end);
end
Registry:RegisterCallback(Events.CART_REMOVE_ITEM_BY_INDEX, function(_, index) Cart.RemoveItemFromCartByIndex(index); end);

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
    local dataProvider = GetDataProvider();
    local totalCost = 0;
    local totalExtendedCost = {};
    dataProvider:ReverseForEach(function(itemEntry)
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
    local dataProvider = GetDataProvider();
    local totalItems = 0;
    dataProvider:ReverseForEach(function(itemEntry)
        totalItems = totalItems + itemEntry.Quantity;
    end);

    return totalItems;
end

function Cart.PurchaseItem(itemEntry)
    local numPurchaseActions = 0;
    local maxStack = GetMerchantItemMaxStack(itemEntry.Index);
    if maxStack >= itemEntry.Quantity then
        BuyMerchantItem(itemEntry.Index, itemEntry.Quantity);
        Registry:TriggerEvent(Events.CART_ITEM_PURCHASED, itemEntry);
        numPurchaseActions = numPurchaseActions + 1;
    else
        for _=1, itemEntry.Quantity do
            BuyMerchantItem(itemEntry.Index);
            Registry:TriggerEvent(Events.CART_ITEM_PURCHASED, itemEntry);
            numPurchaseActions = numPurchaseActions + 1;
        end
    end
end

function Cart.FinalizePurchase()
    local dataProvider = GetDataProvider();
    dataProvider:ReverseForEach(Cart.PurchaseItem);
    Cart.Flush();
end

function Cart.GeneratePurchaseActions()
    local dataProvider = GetDataProvider();
    local purchaseActions = {};

    local itemsInCart = CopyTable(dataProvider:GetCollection());
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
    local purchaseOrder = Cart.GenerateAsyncPurchaseOrder();
    local numItemsInCart = Cart.GetTotalNumberOfItemsInCart();
    Registry:TriggerEvent(Events.CART_BEGIN_PURCHASE, numItemsInCart);

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
        Registry:TriggerEvent(Events.CART_TICK_PURCHASE, itemsBought);
    end
    Tick();
    CartAsyncPurchaseTicker = C_Timer.NewTicker(ASYNC_PURCHASE_STEP, Tick);
end
Registry:RegisterCallback(Events.CART_TRY_PURCHASE, Cart.AsyncFinalizePurchase);

function Cart.OnAsyncPurchaseComplete()
    Cart.Flush();
    Cart.StopAsyncPurchase();
    PlaySound(PURCHASE_COMPLETION_SOUNDKIT);
    FlashClientIcon();
    Registry:TriggerEvent(Events.CART_END_PURCHASE, true);
end

function Cart.StopAsyncPurchase()
    if not CartAsyncPurchaseTicker then
        return;
    end
    CartAsyncPurchaseTicker:Cancel();
    CartAsyncPurchaseTicker = nil;
    Registry:TriggerEvent(Events.CART_END_PURCHASE, false);
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