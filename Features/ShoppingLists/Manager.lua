---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;
local ShoppingListUtil = internal.ShoppingListUtil;

---@class SimscraftShoppingListManager
local Manager = {};
internal.ShoppingListManager = Manager;

------------

local bCornerOffset = 2;
local SELECTION_HIGHLIGHT_NINESLICE = {
	mirrorLayout = true,
	TopLeftCorner =	{
		atlas = "editmode-actionbar-selected-nineslice-corner",
		x = -bCornerOffset,
		y = bCornerOffset,
	},
	TopRightCorner = {
		atlas = "editmode-actionbar-selected-nineslice-corner",
		x = bCornerOffset,
		y = bCornerOffset,
	},
	BottomLeftCorner = {
		atlas = "editmode-actionbar-selected-nineslice-corner",
		x = -bCornerOffset,
		y = -bCornerOffset,
	},
	BottomRightCorner = {
		atlas = "editmode-actionbar-selected-nineslice-corner",
		x = bCornerOffset,
		y = -bCornerOffset,
	},
	TopEdge = {
		atlas = "_editmode-actionbar-selected-nineslice-edgetop",
	},
	BottomEdge = {
		atlas = "_editmode-actionbar-selected-nineslice-edgebottom",
		mirrorLayout = false,
	},
	LeftEdge = {
		atlas = "!editmode-actionbar-selected-nineslice-edgeleft",
		mirrorLayout = false,
	},
	RightEdge = {
		atlas = "!editmode-actionbar-selected-nineslice-edgeright",
		mirrorLayout = false,
	},
};

------------

---@type table<number, number>
local CACHED_ITEMS = {};

---@type table<number, table<string, number>>
local CACHED_LIST_TO_ITEMS = {};


---@type table<number, number>
local CACHED_NUM_LISTS_PER_ITEM = {};

local function CacheQuantityForItem(itemID)
	local quantity = 0;
	local numListsForItem = 0;
	for name, list in pairs(SimscraftShoppingLists) do
		local listQuantity = list.Items[itemID];
		if listQuantity then
			quantity = quantity + listQuantity;
			numListsForItem = numListsForItem + 1;

			if not CACHED_LIST_TO_ITEMS[itemID] then
				CACHED_LIST_TO_ITEMS[itemID] = {};
			end
			CACHED_LIST_TO_ITEMS[itemID][name] = listQuantity;
		end
	end
	CACHED_ITEMS[itemID] = quantity;
	CACHED_NUM_LISTS_PER_ITEM[itemID] = numListsForItem;
	return quantity, CACHED_LIST_TO_ITEMS[itemID], numListsForItem;
end

---@param itemID number
---@return number, table<string, number>, number
local function GetQuantityForItem(itemID)
	local quantity = CACHED_ITEMS[itemID];
	if not quantity then
		quantity = CacheQuantityForItem(itemID);
	end
	local quantityByList = CACHED_LIST_TO_ITEMS[itemID];
	local numListsForItem = CACHED_NUM_LISTS_PER_ITEM[itemID];
	return quantity, quantityByList, numListsForItem;
end

local function InvalidateItemCache()
	CACHED_ITEMS = {};
	CACHED_LIST_TO_ITEMS = {};
	CACHED_NUM_LISTS_PER_ITEM = {};
end

Registry:RegisterCallback(Events.SHOPPING_LIST_ADDED, InvalidateItemCache);
Registry:RegisterCallback(Events.SHOPPING_LIST_REMOVED, InvalidateItemCache);
Registry:RegisterCallback(Events.SHOPPING_LIST_DELETE_ITEM, InvalidateItemCache);

------------

StaticPopupDialogs["SIMSCRAFT_DELETE_SHOPPING_LIST_CONFIRM"] = {
    text =  "Are you sure you want to remove this shopping list?",
    button1 = PERKS_PROGRAM_CART_CLEAR_POPUP_CONFIRMATION,
    button2 = CANCEL,
    OnAccept = function(dialog)
		Manager:RemoveShoppingList(dialog.data);
	end,
    hideOnEscape = true,
    timeout = 0,
    exclusive = true,
    showAlert = true
};

------------

if not SimscraftShoppingLists then
    SimscraftShoppingLists = {};
end

function Manager:AddShoppingList(name, shoppingList)
    if SimscraftShoppingLists[name] then
        error(("A shopping list with the name '%s' already exists."):format(name));
    end

    SimscraftShoppingLists[name] = shoppingList;
	Registry:TriggerEvent(Events.SHOPPING_LIST_ADDED, shoppingList);
end

function Manager:RemoveShoppingList(name)
    SimscraftShoppingLists[name] = nil;
	Registry:TriggerEvent(Events.SHOPPING_LIST_REMOVED, name);
end

function Manager:GetShoppingLists()
    return SimscraftShoppingLists;
end

---@param name string
---@return SimscraftShoppingList
function Manager:GetShoppingList(name)
	return SimscraftShoppingLists[name];
end

function Manager:ShowShoppingList(name)
	local list = SimscraftShoppingLists[name];
	if name then
		Registry:TriggerEvent(Events.SHOPPING_LIST_SHOW, list);
	end
end

function Manager:SaveShoppingList(name, shoppingList)
	SimscraftShoppingLists[name] = shoppingList;
end

function Manager:IsShoppingListNameAvailable(name)
	return SimscraftShoppingLists[name] == nil;
end

function Manager:ConfirmShoppingListDeletion(name)
	StaticPopup_Show("SIMSCRAFT_DELETE_SHOPPING_LIST_CONFIRM", nil, nil, name);
end

function Manager:RenameShoppingList(oldName, newName)
	local oldList = SimscraftShoppingLists[oldName];
	local renamed = CopyTable(oldList);
	renamed.Name = newName;

	SimscraftShoppingLists[newName] = renamed;
	SimscraftShoppingLists[oldName] = nil;
	Registry:TriggerEvent(Events.SHOPPING_LIST_RENAMED, oldName, newName);
end

---@param creatureID number
---@return bool
function Manager.IsVendorRelevant(creatureID)
	for name, list in pairs(SimscraftShoppingLists) do
		if ShoppingListUtil.IsVendorInShoppingList(list, creatureID) then
			return true;
		end
	end
	return false;
end

---@param creatureID number
---@return table<number, number>
function Manager.GetTargetItemsForVendor(creatureID)
	local items = {};
	for name, list in pairs(SimscraftShoppingLists) do
		local allListItems = list.Items;
		local vendorItems = ShoppingListUtil.GetItemsForVendor(list, creatureID);
		for _, itemID in pairs(vendorItems) do
			local quantity = allListItems[itemID];
			if quantity and quantity > 0 then
				if items[itemID] then
					items[itemID] = items[itemID] + quantity;
				else
					items[itemID] = quantity;
				end
			end
		end
	end
	return items;
end

---@param itemID number
---@return number, table<string, number>, number
function Manager.GetRequestedQuantityForItemID(itemID)
	return GetQuantityForItem(itemID);
end

------------

SimscraftShoppingListManagerFrameMixin = {};

function SimscraftShoppingListManagerFrameMixin:OnLoad()
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

    content.ScrollView = CreateScrollBoxListLinearView(5, 5, 5, 5, 8);

    local function Initializer(frame, data)
        frame:Init(data);
    end
    content.ScrollView:SetElementInitializer("SimscraftShoppingListManagerListEntryTemplate", Initializer);

	content.ScrollBar.canInterpolateScroll = true;
	content.ScrollBox.canInterpolateScroll = true;

    ScrollUtil.InitScrollBoxListWithScrollBar(content.ScrollBox, content.ScrollBar, content.ScrollView);

	self.ContentBorder:SetAllPoints(content);

	self.HeaderText:SetPoint("CENTER", self.HeaderBackground, "CENTER", 0, -3);

	local themeColor = internal.ThemeColor;
	local headerText = themeColor:WrapTextInColorCode("Simscraft") .. WHITE_FONT_COLOR:WrapTextInColorCode(" Shopping Lists");
	self.HeaderText:SetText(headerText);

	self.ImportButton:SetText("Import New List");

	self.ImportBackground:SetPoint("TOPLEFT", content, "BOTTOMLEFT");
	self.ImportBackground:SetPoint("BOTTOMRIGHT", self.ShoppingList, "BOTTOMLEFT");

	Registry:RegisterCallback(Events.SHOPPING_LIST_ADDED, self.OnShoppingListAdded, self);
	Registry:RegisterCallback(Events.SHOPPING_LIST_REMOVED, self.OnShoppingListRemoved, self);
	Registry:RegisterCallback(Events.SHOPPING_LIST_SELECTED, self.OnShoppingListSelected, self);
	Registry:RegisterCallback(Events.SHOPPING_LIST_RENAMED, self.OnShoppingListRenamed, self);
	Registry:RegisterCallback(Events.SHOPPING_LIST_IMPORT_FRAME_VISIBILITY_CHANGED, self.OnImportFrameVisibilityChanged, self);

	local highlight = content.ScrollBox.SelectionHighlight;
	self.SelectionHighlight = highlight;
	NineSliceUtil.ApplyLayout(highlight, SELECTION_HIGHLIGHT_NINESLICE);

	self.SelectionBehavior = ScrollUtil.AddSelectionBehavior(content.ScrollBox, SelectionBehaviorFlags.Intrusive);
	local function SelectionCallback(_, elementData, isSelected)
		if not isSelected then
			highlight:Hide();
		else
			local button = content.ScrollBox:FindFrame(elementData);
			if button then
				self:SetFrameSelected(button);
			end
		end
	end
	self.SelectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, SelectionCallback, self);
end

function SimscraftShoppingListManagerFrameMixin:OnShow()
	self:Populate();
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListAdded(newList)
	self:Populate();
	local frame = self.Content.ScrollBox:FindFrameByPredicate(function(data)
		return data.Name == newList.Name;
	end);
	if frame then
		local scrollToFrame = true;
		self:OnShoppingListSelected(frame, scrollToFrame);
	end
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListRemoved()
	self:Populate();
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListRenamed(oldName, newName)
	self:Populate();
	local frame = self.Content.ScrollBox:FindFrameByPredicate(function(data)
		return data.Name == newName;
	end);
	if frame then
		local scrollToFrame = true;
		self:OnShoppingListSelected(frame, scrollToFrame);
	end
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListSelected(listFrame, scrollToFrame)
	self.SelectionBehavior:Select(listFrame);
	local data = listFrame:GetData();
	Manager:ShowShoppingList(data.Name);
	self.LastSelected = data.Name;

	if scrollToFrame then
		self.Content.ScrollBox:ScrollToFrame(listFrame);
	end
end

function SimscraftShoppingListManagerFrameMixin:OnImportButtonClicked()
	SimscraftShoppingListImportFrame:Show();
end

function SimscraftShoppingListManagerFrameMixin:OnImportFrameVisibilityChanged(isShown)
	self.ImportButton:SetEnabled(not isShown);
end

function SimscraftShoppingListManagerFrameMixin:ResetDataProvider()
	self.DataProvider = CreateDataProvider();
	self.Content.ScrollView:SetDataProvider(self.DataProvider);
end

function SimscraftShoppingListManagerFrameMixin:Populate(lists)
	self:ResetDataProvider();

	local lists = lists or Manager:GetShoppingLists();
	local items = {};
	for name, list in pairs(lists) do
		local keys = GetKeysArray(list.Items);
		tinsert(items, {
			Name = name,
			UniqueItems = #keys,
			ImportedAt = list.ImportedAt,
		});
	end

	table.sort(items, function(a, b)
		return a.Name > b.Name;
	end);

	self.DataProvider:InsertTable(items);

	self:CheckSelectionAfterLoad();
end

function SimscraftShoppingListManagerFrameMixin:SetFrameSelected(frame)
	self.SelectionHighlight:SetAllPoints(frame);
	self.SelectionHighlight:Show();
end

function SimscraftShoppingListManagerFrameMixin:CheckSelectionAfterLoad()
	local scrollBox = self.Content.ScrollBox;
	if not self.SelectionBehavior:HasSelection() then
		if self.LastSelected then
			local frame = scrollBox:FindFrameByPredicate(function(data)
				return data.Name == self.LastSelected;
			end);
			if frame then
				local scrollToFrame = true;
				self:OnShoppingListSelected(frame, scrollToFrame);
				return;
			end
		end

		local numFrames = scrollBox:GetFrameCount();
		if numFrames > 0 then
			local firstFrame = self.Content.ScrollBox:GetFrames()[1];
			if firstFrame then
				self:OnShoppingListSelected(firstFrame);
				self.Content.ScrollBox:ScrollToBegin();
			end
		end
	end
end
