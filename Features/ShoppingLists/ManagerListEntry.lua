---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

SimscraftShoppingListManagerListEntryMixin = {};

function SimscraftShoppingListManagerListEntryMixin:OnLoad()
	self.DeleteButton:SetScript("OnClick", function()
		self:OnDeleteButtonPressed();
	end);

	self.NameText:SetTextScale(1.2);
end

function SimscraftShoppingListManagerListEntryMixin:Init(data)
	local name = data.Name;
	self.NameText:SetText(name);
	self.Name = name;

	self.SizeText:SetFormattedText("%d unique items", data.UniqueItems);

	if name == internal.Constants.WISHLIST_NAME then
		self.DateText:SetText("");
		self.DeleteButton:Hide();
	else
		local formattedDate = date("%m/%d/%y", data.ImportedAt);
		self.DateText:SetFormattedText("Created on %s", formattedDate);
		self.DeleteButton:Show();
	end
end

function SimscraftShoppingListManagerListEntryMixin:OnEnter()
end

function SimscraftShoppingListManagerListEntryMixin:OnLeave()
end

function SimscraftShoppingListManagerListEntryMixin:OnMouseDown()
end

function SimscraftShoppingListManagerListEntryMixin:OnMouseUp()
	Registry:TriggerEvent(Events.SHOPPING_LIST_SELECTED, self.Name);
end

function SimscraftShoppingListManagerListEntryMixin:OnDeleteButtonPressed()
	if not IsShiftKeyDown() then
		internal.ShoppingListManager.ConfirmShoppingListDeletion(self.Name);
	else
		internal.ShoppingListManager.RemoveShoppingList(self.Name);
	end
end
