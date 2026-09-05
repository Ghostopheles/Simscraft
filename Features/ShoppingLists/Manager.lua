---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

---@class SimscraftShoppingListManager
local Manager = {};
internal.ShoppingListManager = Manager;

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
end

function Manager:GetShoppingLists()
    return SimscraftShoppingLists;
end

function Manager:ShowShoppingList(name)
	local list = SimscraftShoppingLists[name];
	if name then
		Registry:TriggerEvent(Events.SHOPPING_LIST_SHOW, list);
	end
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
	local headerText = themeColor:WrapTextInColorCode("Simscraft") .. WHITE_FONT_COLOR:WrapTextInColorCode(" Shopping List Manager");
	self.HeaderText:SetText(headerText);

	self.ImportButton:SetText("Import New List");

	self.ImportBackground:SetPoint("TOPLEFT", content, "BOTTOMLEFT");
	self.ImportBackground:SetPoint("BOTTOMRIGHT", self.ShoppingList, "BOTTOMLEFT");

	Registry:RegisterCallback(Events.SHOPPING_LIST_ADDED, self.OnShoppingListsChanged, self);
	Registry:RegisterCallback(Events.SHOPPING_LIST_REMOVED, self.OnShoppingListsChanged, self);
end

function SimscraftShoppingListManagerFrameMixin:OnShow()
	self:Populate();
end

function SimscraftShoppingListManagerFrameMixin:OnShoppingListsChanged()
	self:Populate();
end

function SimscraftShoppingListManagerFrameMixin:OnImportButtonClicked()
	SimscraftShoppingListImportFrame:Show();
end

function SimscraftShoppingListManagerFrameMixin:ResetDataProvider()
	self.DataProvider = CreateDataProvider();
	self.Content.ScrollView:SetDataProvider(self.DataProvider);
end

function SimscraftShoppingListManagerFrameMixin:Populate(lists)
	self:ResetDataProvider();

	local lists = lists or Manager:GetShoppingLists();
	for name, list in pairs(lists) do
		self.DataProvider:Insert({
			Name = name
		});
	end
end
