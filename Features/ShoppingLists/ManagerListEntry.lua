---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

SimscraftShoppingListManagerListEntryMixin = {};

function SimscraftShoppingListManagerListEntryMixin:OnLoad()
end

function SimscraftShoppingListManagerListEntryMixin:Init(data)
	local name = data.Name;
	self.NameText:SetText(name);
	self.Name = name;
end

function SimscraftShoppingListManagerListEntryMixin:OnEnter()
end

function SimscraftShoppingListManagerListEntryMixin:OnLeave()
end

function SimscraftShoppingListManagerListEntryMixin:OnMouseDown()
end

function SimscraftShoppingListManagerListEntryMixin:OnMouseUp()
	Registry:TriggerEvent(Events.SHOPPING_LIST_SELECTED, self);
end
