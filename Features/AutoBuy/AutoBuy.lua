-- TODO: add on OnTabPressed handler to the entries to enable tabbing down the list via the editboxes
-- TODO: add an OnEscapePressed handler to the cart items edit box
-- TODO: maybe enable hyperlinks on the item labels?
-- TODO: maybe auto-focus the edit box when adding an item to the cart
-- TODO: can't ctrl-click allegedly???
-- TODO: fix clipping issues on the 'total owned' string
-- TODO: correctly check if the player can afford using currencies other than gold
-- TODO: calculate free bag space for refundable items

---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftAutoBuy
local AutoBuy = internal.AutoBuy;

local Events = AutoBuy.Events;
local Registry = AutoBuy.Registry;

local ITEM_COUNT_LOW_LIMIT = 5;

local function IsAutoBuyEnabled()
    return internal.Settings.GetSetting("EnableAutoBuy");
end

local function IsItemCountEnabled()
    return internal.Settings.GetSetting("EnableDecorItemCounts");
end

local function IsNewItemIconEnabled()
    return internal.Settings.GetSetting("EnableDecorNewItemIcon");
end

------------

StaticPopupDialogs["SIMSCRAFT_CLEAR_CART_CONFIRM"] = {
    text = 	PERKS_PROGRAM_CART_CLEAR_POPUP_TEXT,
    button1 = PERKS_PROGRAM_CART_CLEAR_POPUP_CONFIRMATION,
    button2 = CANCEL,
    OnAccept = function() Registry:TriggerEvent(Events.CART_CLEAR); end,
    hideOnEscape = true,
    timeout = 0,
    exclusive = true,
    showAlert = true
};

StaticPopupDialogs["SIMSCRAFT_PURCHASE_CONFIRM"] = {
    text = 	PERKS_PROGRAM_CART_PURCHASE_POPUP_TEXT,
    button1 = YES,
    button2 = NO,
    OnAccept = function() Registry:TriggerEvent(Events.CART_TRY_PURCHASE); end,
    hideOnEscape = true,
    timeout = 0,
    exclusive = true,
    showAlert = true
};

------------

local function GetItemFrameForIndex(index)
    return _G["MerchantItem"..index];
end

local function GetPagedIndex(nonPagedIndex)
    return ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + nonPagedIndex;
end

local HookedButtons = {};
local function HookItemButtons()
    for i=1, MERCHANT_ITEMS_PER_PAGE do
        local button = GetItemFrameForIndex(i).ItemButton;
        if not HookedButtons[button] then
            HookedButtons[button] = true;
            button:HookScript("OnClick", function(_, mouseButton)
                if not IsAutoBuyEnabled() then
                    return;
                end

                if internal.Settings.IsAddToCartModifierDown() and mouseButton == "RightButton" then
                    local index = GetPagedIndex(i);
                    local itemID = GetMerchantItemID(index);
                    if not C_Item.IsDecorItem(itemID) then
                        return;
                    end

                    Registry:TriggerEvent(Events.CART_ADD_ITEM_BY_INDEX, index);
                end
            end);
        end
    end
end

local function ShowAutoBuy()
    local cartFrame = AutoBuy.GetShoppingCartFrame();
    if cartFrame:IsShown() then
        return;
    end

    cartFrame:SetShown(SimscraftConfig.CartShown);
    Registry:TriggerEvent(Events.CART_CLEAR);
    HookItemButtons();
end

-- checks if the vendor has any decor items - if so, shows the shopping cart UI
local function CheckDecorItemsAndShowFrame()
    for i=1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(i);
        if itemID then
            local item = Item:CreateFromItemID(itemID);
            item:ContinueOnItemLoad(function()
                if C_Item.IsDecorItem(itemID) then
                    ShowAutoBuy();
                end
            end);
        end
    end
end

local function OnMerchantShow()
    if not IsAutoBuyEnabled() then
        return;
    end

    local cartFrame = AutoBuy.GetShoppingCartFrame();
    cartFrame:Hide();
    CheckDecorItemsAndShowFrame();
end
Registry:RegisterCallback(Events.MERCHANT_SHOW, OnMerchantShow);

local function OnMerchantClosed()
    Registry:TriggerEvent(Events.CART_END_PURCHASE);
    Registry:TriggerEvent(Events.CART_CLEAR);
end
Registry:RegisterCallback(Events.MERCHANT_CLOSED, OnMerchantClosed);

------ tooltip hint

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
--- handle the ctrl-click decor model preview - don't let it cover our shopping cart

local anchorsTouched = false;
local function UpdateModelPreviewFrameAnchors()
    local cartFrame = AutoBuy.GetShoppingCartFrame();
    if HousingModelPreviewFrame then
        if cartFrame:IsShown() then
            HousingModelPreviewFrame:SetPoint("TOPLEFT", cartFrame, "TOPRIGHT", 10, 0);
            anchorsTouched = true;
        elseif anchorsTouched and not MerchantFrame:IsShown() then
            anchorsTouched = false;
            HousingModelPreviewFrame:ClearAllPoints();
            HideUIPanel(HousingModelPreviewFrame);
            ShowUIPanel(HousingModelPreviewFrame);
        end
    end
end
Registry:RegisterCallback(Events.CART_FRAME_SHOW, UpdateModelPreviewFrameAnchors);

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

local CACHE_WAIT_TIME = 0.05;

local function GetDecorInfoByItemID(itemID)
    local tryGetOwnedInfo = true;
    local catalogEntryInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, tryGetOwnedInfo);
    if not catalogEntryInfo then
        return;
    end

    return catalogEntryInfo.quantity, catalogEntryInfo.firstAcquisitionBonus;
end

local itemQuantityColors = {
    NONE = RED_FONT_COLOR;
    LOW = YELLOW_FONT_COLOR;
    OKAY = WHITE_FONT_COLOR;
};

local function GetItemCountColorForQuantity(quantity)
    if quantity == 0 or not quantity then
        return itemQuantityColors.NONE;
    elseif quantity < ITEM_COUNT_LOW_LIMIT then
        return itemQuantityColors.LOW;
    else
        return itemQuantityColors.OKAY;
    end
end

local function ForEachMerchantItemFrame(predicate)
    for i=1, MERCHANT_ITEMS_PER_PAGE do
        local f = GetItemFrameForIndex(i);
        predicate(f);
    end
end

local function ForEachMerchantItemIndex(predicate)
    for i=1, MERCHANT_ITEMS_PER_PAGE do
        predicate(i);
    end
end

local function SetupFirstAcquisitonIcon(itemFrame)
    local parent = itemFrame.ItemButton;
    local icon = parent:CreateTexture(nil, "OVERLAY", nil, 2);
    icon:SetSize(24, 24);
    icon:SetPoint("CENTER", parent, "TOPLEFT");
    icon:SetAtlas("wowlabs_spellbucketicon-sword");

    icon.tooltipText = "This item's first acquisition bonus is available.";
    internal.AddTooltip(icon);

    --TODO: add a tooltip that explains wtf this icon is

    itemFrame.FirstAcquisitionIcon = icon;
    return icon;
end

local function SetupItemCountString(itemFrame)
    local str = itemFrame:CreateFontString(nil, "ARTWORK", "GameFontWhite");
    str:SetJustifyH("LEFT");
    str:SetJustifyV("MIDDLE");
    str:SetPoint("BOTTOMRIGHT");

    str.tooltipText = "Number of this item currently in storage.";
    internal.AddTooltip(str);

    itemFrame.ItemCountString = str;
    return str;
end

local itemCountFormat = CreateAtlasMarkup("house-chest-icon", 16, 16) .. " %s";
local function UpdateWidgetsByMerchantIndex(nonPagedIndex)
    local itemFrame = GetItemFrameForIndex(nonPagedIndex);
    local str = itemFrame.ItemCountString;
    local icon = itemFrame.FirstAcquisitionIcon;

    local pagedIndex = GetPagedIndex(nonPagedIndex);
    local itemID = GetMerchantItemID(pagedIndex);

    if str then
        str:Hide();
    end
    if icon then
        icon:Hide();
    end

    if not itemID then
        return;
    end

    local numStored, firstAcquisitionBonus = GetDecorInfoByItemID(itemID);

    if numStored then
        -- update item count
        if IsItemCountEnabled() and str then
            local color = GetItemCountColorForQuantity(numStored);
            local text = format(itemCountFormat, color:WrapTextInColorCode(numStored));
            str:SetTextToFit(text);
            str:Show();
        end

        -- update new item icon
        if IsNewItemIconEnabled() and icon then
            local showIcon = (firstAcquisitionBonus and firstAcquisitionBonus > 0) or false;
            if showIcon then
                icon:Show();
            end
        end
    end
end

--- creating our widgets

local widgetsCreated = false;
local function CreateItemWidgets()
    if widgetsCreated then
        return;
    end

    ForEachMerchantItemFrame(function(itemFrame)
        SetupItemCountString(itemFrame);
        SetupFirstAcquisitonIcon(itemFrame);
    end);

    widgetsCreated = true;
end

local function OnMerchantUpdate()
    if not C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Merchant) then
        return;
    end

    if not widgetsCreated then
        CreateItemWidgets();
    end

    local startingPage = MerchantFrame.page;
    C_Timer.After(CACHE_WAIT_TIME, function()
        if MerchantFrame.page ~= startingPage then
            return;
        end
        ForEachMerchantItemIndex(UpdateWidgetsByMerchantIndex);
    end);
end
Registry:RegisterCallback(Events.MERCHANT_UPDATE, OnMerchantUpdate);
Registry:RegisterCallback(Events.NEW_HOUSING_ITEM_ACQUIRED, OnMerchantUpdate);

--- necessary to populate the quantity data in the HousingCatalogEntryInfo struct
local function RefreshSearcher()
    if C_HousingCatalog.CreateCatalogSearcher then
        RunNextFrame(function() C_HousingCatalog.CreateCatalogSearcher() end);
    end
end
Registry:RegisterCallback("MERCHANT_SHOW", RefreshSearcher);
Registry:RegisterCallback("ZONE_CHANGED", RefreshSearcher);
Registry:RegisterCallback("ZONE_CHANGED_NEW_AREA", RefreshSearcher);