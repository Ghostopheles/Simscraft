-- example shopping list:
-- 112338:262619-1;193015,252312:256168-1

---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

local LIST_IMPORT_SUCCESS_SOUNDKIT = SOUNDKIT.UI_GARRISON_TOAST_MISSION_COMPLETE;

------------

---@class SimscraftShoppingListMixin
---@field RawList table<number, {ItemID: number, Quantity: number}[]> maps creatureID to list of itemIDs and quantities
---@field Vendors table<number, number[]> maps creatureID to list of itemIDs
---@field Items table<number, number> maps itemID to quantity
---@field Name string Unique name
local ShoppingListMixin = {};

function ShoppingListMixin:Init(list, name)
    self.RawList = list;
    self.Vendors = {};
    self.Items = {};
	self.Name = name;

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
local function ParseShoppingList(shoppingListStr, name)
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

    return CreateAndInitFromMixin(ShoppingListMixin, list, name);
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
    local helpText = format("Give your list a name, then paste in the code from %s and press enter to import it.", wowdbLink);
    self.HelpText:SetTextToFit(helpText);

	local labelScale = 0.9;

	self.NameEditBox.Label:SetText("Name");
	self.NameEditBox.Label:SetTextScale(labelScale);

	self.EditBox.Label:SetText("Import String");
	self.EditBox.Label:SetTextScale(labelScale);
end

function SimscraftShoppingListImportFrameMixin:OnShow()
    self.EditBox:SetText("");
end

function SimscraftShoppingListImportFrameMixin:OnEditBoxEnterPressed()
    self:Submit();
end

function SimscraftShoppingListImportFrameMixin:Validate()
	local name = strtrim(self.NameEditBox:GetText());
	if not name or name == "" then
		PlaySound(SOUNDKIT.ACCOUNT_STORE_CATEGORY_SELECT);
		internal.Print("A name is required in order to import a shopping list.");
		return false;
	end

	local nameAvailable = internal.ShoppingListManager:IsShoppingListNameAvailable(name);
	if not nameAvailable then
		PlaySound(SOUNDKIT.ACCOUNT_STORE_CATEGORY_SELECT);
		internal.Print(format("Shopping list name '%s' is already taken or is invalid.", name));
		return false;
	end

	local importString = strtrim(self.EditBox:GetText());
	if not importString or importString == "" then
		PlaySound(SOUNDKIT.ACCOUNT_STORE_CATEGORY_SELECT);
		internal.Print("Shopping list import string is missing or invalid.");
		return false;
	end

	return true;
end

function SimscraftShoppingListImportFrameMixin:Submit()
	local valid = self:Validate();
	if not valid then
		return;
	end

	local name = strtrim(self.NameEditBox:GetText());
    local list = ParseShoppingList(self.EditBox:GetText(), name);
    internal.ShoppingListManager:AddShoppingList(name, list);
    self:Hide();
    PlaySound(LIST_IMPORT_SUCCESS_SOUNDKIT);
end

------------

SimscraftShoppingListFrameMixin = {};

function SimscraftShoppingListFrameMixin:OnLoad()
	local content = self.Content;
	local anchorsWithScrollBar = {
        CreateAnchor("TOPLEFT", content, "TOPLEFT", 10, -5),
        CreateAnchor("TOPRIGHT", content.ScrollBar, "TOPLEFT", -5, -5),
        CreateAnchor("BOTTOM", content, "BOTTOM", 0, 5);
    };

    local anchorsWithoutScrollBar = {
        anchorsWithScrollBar[1],
        CreateAnchor("TOPRIGHT", content, "TOPRIGHT", -5, -30),
        anchorsWithScrollBar[3],
    };

    ScrollUtil.AddManagedScrollBarVisibilityBehavior(content.ScrollBox, content.ScrollBar, anchorsWithScrollBar, anchorsWithoutScrollBar);

    content.ScrollView = CreateScrollBoxListLinearView();

    local function Initializer(frame, data)
        frame:Init(data);
    end
    content.ScrollView:SetElementInitializer("SimscraftShoppingListItemEntryTemplate", Initializer);

	content.ScrollBar.canInterpolateScroll = true;
	content.ScrollBox.canInterpolateScroll = true;

    ScrollUtil.InitScrollBoxListWithScrollBar(content.ScrollBox, content.ScrollBar, content.ScrollView);

	Registry:RegisterCallback(Events.SHOPPING_LIST_ADDED, self.OnShoppingListAdded, self);
	Registry:RegisterCallback(Events.SHOPPING_LIST_SHOW, self.OnShoppingListShow, self);

	self.ActiveList = nil;
end

function SimscraftShoppingListFrameMixin:OnShoppingListAdded(list)
	if not self.ActiveList and self:IsShown() then
		self:OnShoppingListShow(list);
	end
end

function SimscraftShoppingListFrameMixin:OnShoppingListShow(list)
	self.ActiveList = list.Name;
	self:SetTitle(list.Name);
	self.DataProvider = nil;
	self:AddItems(list.Items);
end

function SimscraftShoppingListFrameMixin:SetTitle(title)
	self.Header.Title:SetText(title);
end

function SimscraftShoppingListFrameMixin:AddItems(items)
	if not self.DataProvider then
		self.DataProvider = CreateDataProvider();
		self.Content.ScrollView:SetDataProvider(self.DataProvider);
	end

	for itemID, quantity in pairs(items) do
		self.DataProvider:Insert({
			ItemID = itemID,
			Quantity = quantity
		});
	end
end
