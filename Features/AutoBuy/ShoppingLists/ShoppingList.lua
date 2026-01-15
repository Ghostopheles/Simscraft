-- example shopping list:
-- 112338:262619-1;193015,252312:256168-1

---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftAutoBuy
local AutoBuy = internal.AutoBuy;

------------

local LIST_IMPORT_SUCCESS_SOUNDKIT = SOUNDKIT.UI_GARRISON_TOAST_MISSION_COMPLETE;

------------

---@class SimscraftShoppingListMixin
local ShoppingListMixin = {};

function ShoppingListMixin:Init(list)
    self.RawList = list;
    self.Vendors = {};
    self.Items = {};

    for cid, items in pairs(self.RawList) do
        local vendor = {};

        for _, item in ipairs(items) do
            if not self.Items[item.ItemID] then
                self.Items[item.ItemID] = item.Quantity;
            end
            tinsert(vendor, item.ItemID);
        end

        self.Vendors[cid] = vendor;
    end
end

---@param itemID number
---@return number
function ShoppingListMixin:GetRequestedItemQuantityByID(itemID)
    return self.Items[itemID];
end

---@param itemID number
---@param amount number
function ShoppingListMixin:SetRequestedItemQuantityByID(itemID, amount)
    self.Items[itemID] = amount;
end

---@param itemID number
---@param amount number
function ShoppingListMixin:AdjustRequestedQuantityForItem(itemID, amount)
    local oldCount = self:GetRequestedItemQuantityByID(itemID);
    if oldCount then
        self:SetRequestedItemQuantityByID(itemID, oldCount + amount);
    end
end

---@param creatureID number
---@return number[]?
function ShoppingListMixin:GetItemsForVendor(creatureID)
    return self.Vendors[creatureID];
end

---@param creatureID number
---@return boolean
function ShoppingListMixin:IsVendorInShoppingList(creatureID)
    return self:GetItemsForVendor(creatureID) ~= nil;
end

---@param creatureID number
function ShoppingListMixin:ClearItemsForVendor(creatureID)
    self.Vendors[creatureID] = nil;
end

function ShoppingListMixin:UpdateVendors()
    local newVendors = {};
    for vendor, items in pairs(self.Vendors) do
        local newItems = {};
        for _, itemID in ipairs(items) do
            if self:GetRequestedItemQuantityByID(itemID) > 0 then
                tinsert(newItems, itemID);
            end
        end
        newVendors[vendor] = newItems;
    end

    if #newVendors == 0 then
        newVendors = nil;
    end

    self.Vendors = newVendors;
end

------------

---@param shoppingListStr string
---@return SimscraftShoppingListMixin
local function ParseShoppingList(shoppingListStr)
    local list = {};

    local split = strsplittable(";", shoppingListStr);
    for _, entry in ipairs(split) do
        local cids, iids = strsplit(":", entry); -- creature ids and item ids

        -- parsing out itemIDs and quantities
        local allItems = {};
        local items = strsplittable(",", iids);
        for _, itemEntry in ipairs(items) do
            local itemID, quantity = strsplit("-", itemEntry);
            local item = {
                ItemID = tonumber(itemID),
                Quantity = tonumber(quantity)
            };
            tinsert(allItems, item);
        end

        -- parsing out creature IDs
        local creatures = strsplittable(",", cids);
        for _, creature in ipairs(creatures) do
            local cid = tonumber(creature);
            assert(cid, "Invalid shopping list creatureID");
            list[cid] = allItems;
        end
    end

    return CreateAndInitFromMixin(ShoppingListMixin, list);
end

------------

SimscraftShoppingListImportFrameMixin = {};

function SimscraftShoppingListImportFrameMixin:OnLoad()
    ButtonFrameTemplate_HidePortrait(self);
    self:SetTitle("Housing Shopping List Import");
    tinsert(UISpecialFrames, self:GetName());

    self.EditBox:SetScript("OnEnterPressed", function()
        self:OnEditBoxEnterPressed();
    end);

    local wowdbLink = YELLOW_FONT_COLOR:WrapTextInColorCode("housing.wowdb.com");
    local helpText = format("Paste in a shopping list from %s and press enter to import it.", wowdbLink);
    self.HelpText:SetTextToFit(helpText);
end

function SimscraftShoppingListImportFrameMixin:OnShow()
    self.EditBox:SetText("");
end

function SimscraftShoppingListImportFrameMixin:OnEditBoxEnterPressed()
    self:Submit();
end

function SimscraftShoppingListImportFrameMixin:Submit()
    print(self.EditBox:GetText());
    self:Hide();
    PlaySound(LIST_IMPORT_SUCCESS_SOUNDKIT);
end