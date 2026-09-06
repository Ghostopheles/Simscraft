-- example shopping list:
-- 112338:262619-1;193015,252312:256168-1

---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;
local ShoppingListUtil = internal.ShoppingListUtil;

------------

local LIST_IMPORT_SUCCESS_SOUNDKIT = SOUNDKIT.UI_GARRISON_TOAST_MISSION_COMPLETE;

------------

SimscraftShoppingListImportFrameMixin = {};

function SimscraftShoppingListImportFrameMixin:OnLoad()
    ButtonFrameTemplate_HidePortrait(self);
    self:SetTitle("Housing Shopping List Import");
    tinsert(UISpecialFrames, self:GetName());

	self.NameEditBox:SetScript("OnEnterPressed", function()
        self:OnNameEditBoxEnterPressed();
    end);

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

	self.NameEditBox:SetScript("OnTabPressed", function()
		self.NameEditBox:ClearFocus();
		self.EditBox:SetFocus();
	end);

	self.EditBox:SetScript("OnTabPressed", function()
		self.EditBox:ClearFocus();
		self.NameEditBox:SetFocus();
	end);
end

function SimscraftShoppingListImportFrameMixin:OnShow()
	self.NameEditBox:SetText("");
    self.EditBox:SetText("");
	Registry:TriggerEvent(Events.SHOPPING_LIST_IMPORT_FRAME_VISIBILITY_CHANGED, true);
	self.NameEditBox:SetFocus();
end

function SimscraftShoppingListImportFrameMixin:OnHide()
	Registry:TriggerEvent(Events.SHOPPING_LIST_IMPORT_FRAME_VISIBILITY_CHANGED, false);
end

function SimscraftShoppingListImportFrameMixin:OnNameEditBoxEnterPressed()
    self.NameEditBox:ClearFocus();
	self.EditBox:SetFocus();
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
    local list = ShoppingListUtil.ParseShoppingListImport(self.EditBox:GetText(), name);
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
	Registry:RegisterCallback(Events.SHOPPING_LIST_DELETE_ITEM, self.OnShoppingListDeleteItem, self);

	self.RenameButton:SetScript("OnClick", function()
		self:OnRenameButtonClicked();
	end);

	local header = self.Header;
	header.RenameEditBox:SetScript("OnEnterPressed", function()
		self:OnRenameEditBoxEnterPressed();
	end);
end

function SimscraftShoppingListFrameMixin:OnShoppingListAdded(list)
	if not self.ActiveList and self:IsShown() then
		self:OnShoppingListShow(list);
	end
end

function SimscraftShoppingListFrameMixin:OnShoppingListShow(list)
	self.ActiveList = list;
	self:SetTitle(list.Name);
	self:RefreshItems(list.Items);

	self:SetNameEditModeEnabled(false);
end

function SimscraftShoppingListFrameMixin:OnShoppingListRenamed(oldName, newName)
	self:SetTitle(newName);
	self:SetNameEditModeEnabled(false);
end

function SimscraftShoppingListFrameMixin:RefreshItems(items)
	local scrollPercentage = self.Content.ScrollBox:CalculateScrollPercentage();

	self.DataProvider = nil;
	self:AddItems(items);

	local noInterpolation = true;
	self.Content.ScrollBox:SetScrollPercentage(scrollPercentage, noInterpolation);
end

function SimscraftShoppingListFrameMixin:SetTitle(title)
	local text = WHITE_FONT_COLOR:WrapTextInColorCode(title);
	self.Header.Title:SetText(text);
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

function SimscraftShoppingListFrameMixin:OnRenameButtonClicked()
	self:SetNameEditModeEnabled(true);
end

function SimscraftShoppingListFrameMixin:OnRenameEditBoxEnterPressed()
	local header = self.Header;
	local newName = header.RenameEditBox:GetText();
	local isValidName = internal.ShoppingListManager:IsShoppingListNameAvailable(newName);
	if not isValidName then
		internal.Print("Invalid name"); --TODO: make this a good error
		return;
	end

	internal.ShoppingListManager:RenameShoppingList(self.ActiveList.Name, newName);
end

function SimscraftShoppingListFrameMixin:SetNameEditModeEnabled(enabled)
	local header = self.Header;
	local title = header.Title;
	local editBox = header.RenameEditBox;
	local renameButton = self.RenameButton;
	if enabled then
		title:Hide();
		editBox:Show();
		editBox:SetFocus(true);
		editBox:SetText(self.ActiveList.Name);
		renameButton:Hide();
	else
		title:Show();
		editBox:Hide();
		renameButton:Show();
	end
end

function SimscraftShoppingListFrameMixin:OnShoppingListDeleteItem(itemID)
	local shoppingList = internal.ShoppingListManager:GetShoppingList(self.ActiveList.Name);
	ShoppingListUtil.RemoveItemFromListByID(shoppingList, itemID);
	self:RefreshItems(shoppingList.Items);
end
