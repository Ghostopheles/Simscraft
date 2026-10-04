local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;
local ShoppingListUtil = internal.ShoppingListUtil;

local WISHLIST_NAME = internal.Constants.WISHLIST_NAME;

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

local frameOffset = 23;
local FRAME_BORDER_NINESLICE = {
	TopLeftCorner =	{
		atlas = "GenericMetal2-NineSlice-CornerTopLeft",
		x = -frameOffset,
		y = frameOffset,
	},
	TopRightCorner = {
		atlas = "GenericMetal2-NineSlice-CornerTopRight",
		x = frameOffset,
		y = frameOffset,
	},
	BottomLeftCorner = {
		atlas = "GenericMetal2-NineSlice-CornerBottomLeft",
		x = -frameOffset,
		y = -frameOffset,
	},
	BottomRightCorner = {
		atlas = "GenericMetal2-NineSlice-CornerBottomRight",
		x = frameOffset,
		y = -frameOffset,
	},
	TopEdge = {
		atlas = "_GenericMetal2-NineSlice-EdgeTop",
	},
	BottomEdge = {
		atlas = "_GenericMetal2-NineSlice-EdgeBottom",
	},
	LeftEdge = {
		atlas = "!GenericMetal2-NineSlice-EdgeLeft",
	},
	RightEdge = {
		atlas = "!GenericMetal2-NineSlice-EdgeRight",
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
		local itemEntry = list.Items[itemID];
		if itemEntry then
			local listQuantity = itemEntry.Quantity;
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

local function OnShoppingListUpdated(_, shoppingList)
	InvalidateItemCache();
end

Registry:RegisterCallback(Events.SHOPPING_LIST_ADDED, OnShoppingListUpdated);
Registry:RegisterCallback(Events.SHOPPING_LIST_REMOVED, OnShoppingListUpdated);
Registry:RegisterCallback(Events.SHOPPING_LIST_RENAMED, OnShoppingListUpdated);
Registry:RegisterCallback(Events.SHOPPING_LIST_UPDATED, OnShoppingListUpdated);

------------

StaticPopupDialogs["SIMSCRAFT_DELETE_SHOPPING_LIST_CONFIRM"] = {
    text =  "Are you sure you want to remove this shopping list?",
    button1 = PERKS_PROGRAM_CART_CLEAR_POPUP_CONFIRMATION,
    button2 = CANCEL,
    OnAccept = function(dialog)
		Manager.RemoveShoppingList(dialog.data);
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

---@param name string
---@param shoppingList SimscraftShoppingList
function Manager.RegisterShoppingList(name, shoppingList)
    if SimscraftShoppingLists[name] then
        error(("A shopping list with the name '%s' already exists."):format(name));
    end

    SimscraftShoppingLists[name] = shoppingList;
	Registry:TriggerEvent(Events.SHOPPING_LIST_ADDED, shoppingList);
end

---@param name string
---@return SimscraftShoppingList
function Manager.CreateShoppingList(name)
	if SimscraftShoppingLists[name] then
		error(("A shopping list with the name '%s' already exists."):format(name));
	end

	local shoppingList = ShoppingListUtil.CreateShoppingList(name);
	Manager.RegisterShoppingList(name, shoppingList);
	return shoppingList;
end

---@param name string
function Manager.RemoveShoppingList(name)
    SimscraftShoppingLists[name] = nil;
	Registry:TriggerEvent(Events.SHOPPING_LIST_REMOVED, name);
end

function Manager.GetShoppingLists()
    return SimscraftShoppingLists;
end

---@param name string
---@return SimscraftShoppingList
function Manager.GetShoppingList(name)
	return SimscraftShoppingLists[name];
end

---@param name string
function Manager.ShowShoppingList(name)
	local list = SimscraftShoppingLists[name];
	if list then
		SimscraftShoppingListManagerFrame:Show();
		Registry:TriggerEvent(Events.SHOPPING_LIST_SHOW, list);
	end
end

---@param name string
---@param shoppingList SimscraftShoppingList
function Manager.SaveShoppingList(name, shoppingList)
	SimscraftShoppingLists[name] = shoppingList;
end

---@param name string
function Manager.IsShoppingListNameAvailable(name)
	return SimscraftShoppingLists[name] == nil;
end

---@param name string
function Manager.ConfirmShoppingListDeletion(name)
	StaticPopup_Show("SIMSCRAFT_DELETE_SHOPPING_LIST_CONFIRM", nil, nil, name);
end

---@param oldName string
---@param newName string
function Manager.RenameShoppingList(oldName, newName)
	local oldList = SimscraftShoppingLists[oldName];
	local renamed = CopyTable(oldList);
	renamed.Name = newName;

	SimscraftShoppingLists[newName] = renamed;
	SimscraftShoppingLists[oldName] = nil;
	Registry:TriggerEvent(Events.SHOPPING_LIST_RENAMED, oldName, newName);
end

---@param itemID number
---@return number, table<string, number>, number
function Manager.GetRequestedQuantityForItemID(itemID)
	return GetQuantityForItem(itemID);
end

function Manager.ToggleManagerFrame()
	local f = SimscraftShoppingListManagerFrame;
	f:SetShown(not f:IsShown());
end

function Manager.ForEachShoppingList(func)
	for _, shoppingList in pairs(SimscraftShoppingLists) do
		local success, result = pcall(func, shoppingList);
		if success and not result then
			break;
		end
	end
end

------------

---@param shoppingList SimscraftShoppingList
local function CheckShoppingListFulfillment(shoppingList)
	local isFulfilled = ShoppingListUtil.IsListFulfilled(shoppingList);
	if isFulfilled ~= shoppingList.IsFulfilled then
		shoppingList.IsFulfilled = isFulfilled;
		Registry:TriggerEvent(Events.SHOPPING_LIST_FULFILLMENT_STATE_UPDATED, shoppingList);
	end
end

local function TryCreateWishlist()
	if not Manager.IsShoppingListNameAvailable(WISHLIST_NAME) then
		-- player already has a wishlist
		return;
	end

	Manager.CreateShoppingList(WISHLIST_NAME);
end

local function UpdateListFulfillments()
	Manager.ForEachShoppingList(CheckShoppingListFulfillment);
end

local function OnAddonLoaded()
	TryCreateWishlist();
	UpdateListFulfillments();
end

EventUtil.ContinueOnAddOnLoaded(addonName, OnAddonLoaded);

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
	Registry:RegisterCallback(Events.SHOPPING_LIST_UPDATED, self.OnShoppingListUpdated, self);
	Registry:RegisterCallback(Events.NEW_HOUSING_ITEM_ACQUIRED, self.OnNewHousingItemAcquired,self);

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

	tinsert(UISpecialFrames, self:GetName());

	NineSliceUtil.ApplyLayout(self.NineSlice, FRAME_BORDER_NINESLICE);
end

function SimscraftShoppingListManagerFrameMixin:OnShow()
	self:Populate();
	PlaySound(SOUNDKIT.HOUSING_DASHBOARD_OPEN);
end

function SimscraftShoppingListManagerFrameMixin:OnHide()
	Registry:TriggerEvent(Events.DECOR_SEARCH_HIDE);
	PlaySound(SOUNDKIT.HOUSING_DASHBOARD_CLOSE);
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListAdded(newList)
	self:Populate();
	Registry:TriggerEvent(Events.SHOPPING_LIST_SELECTED, newList.Name);
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListRemoved(name)
	self:Populate();
	local selection = self.SelectionBehavior;

	local selected = selection:GetFirstSelectedElementData();
	if selected and selected.Name == name then
		selection:SelectOffsetElementData(-1);
		self:ScrollToSelection();
	end
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListUpdated(shoppingList)
	if not self:IsShown() then
		return;
	end

	CheckShoppingListFulfillment(shoppingList);
	self:Populate();
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListRenamed(oldName, newName)
	self:Populate();
	Registry:TriggerEvent(Events.SHOPPING_LIST_SELECTED, newName);
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListSelected(name)
	if not self:IsShown() then
		return;
	end

	self:SelectListByName(name);
end

function SimscraftShoppingListManagerFrameMixin:OnNewHousingItemAcquired(recordID)
	local itemID = internal.DecorUtil.GetDecorItemIDByRecordID(recordID);
	if itemID then
		Manager.ForEachShoppingList(function(shoppingList)
			local targetQuantity = ShoppingListUtil.GetTargetItemQuantityByID(shoppingList, itemID);
			if targetQuantity > 0 then
				self:OnShoppingListUpdated(shoppingList);
				return false;
			end
			return true;
		end);
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

	local lists = lists or Manager.GetShoppingLists();
	local items = {};
	for name, list in pairs(lists) do
		local keys = GetKeysArray(list.Items);
		tinsert(items, {
			Name = name,
			UniqueItems = #keys,
		});
	end

	table.sort(items, function(a, b)
		if a.Name == internal.Constants.WISHLIST_NAME or not b then
			return true;
		end

		return a.Name < b.Name;
	end);

	self.DataProvider:InsertTable(items);

	self:CheckSelectionAfterLoad();
end

function SimscraftShoppingListManagerFrameMixin:SetFrameSelected(frame)
	self.SelectionHighlight:SetAllPoints(frame);
	self.SelectionHighlight:Show();
	self.SelectedFrame = frame;
end

function SimscraftShoppingListManagerFrameMixin:ScrollToSelection()
	local selection = self.SelectionBehavior;
	local scrollBox = self.Content.ScrollBox;

	local selected = selection:GetFirstSelectedElementData();
	if selected then
		local alignment = ScrollBoxConstants.AlignNearest;
		scrollBox:ScrollToElementData(selected, alignment);
	end
end

function SimscraftShoppingListManagerFrameMixin:SelectListByName(name)
	local selection = self.SelectionBehavior;
	selection:SelectFirstElementData(function(elementData)
		return elementData.Name == name;
	end);
	self:ScrollToSelection();
	Manager.ShowShoppingList(name);
end

function SimscraftShoppingListManagerFrameMixin:CheckSelectionAfterLoad()
	if not self.SelectedFrame then
		local first = self.DataProvider:Find(1);
		if first then
			Registry:TriggerEvent(Events.SHOPPING_LIST_SELECTED, first.Name);
		end
	end
end
