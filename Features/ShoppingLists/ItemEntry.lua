---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

SimscraftShoppingListItemEntryMixin = {};

function SimscraftShoppingListItemEntryMixin:OnLoad()
	self.UpButton:SetScript("OnClick", function() self:OnUpButtonClicked(); end);
	self.DownButton:SetScript("OnClick", function() self:OnDownButtonClicked(); end);
	self.DeleteButton:SetScript("OnClick", function() self:OnDeleteButtonClicked(); end);

	self.Name:SetPoint("RIGHT", self.QuantityText, "LEFT", -10, 0);
	self.Name:SetTextScale(1.2);

	self.QuantityText:SetTextScale(1.2);
end

function SimscraftShoppingListItemEntryMixin:OnEnter()
	self.FadeIn.Alpha:SetTarget(self.FocusedBackground);
	self.FadeOut.Alpha:SetTarget(self.Background);

	self.FadeIn:Play();
	self.FadeOut:Play();
end

function SimscraftShoppingListItemEntryMixin:OnLeave()
	self.FadeIn.Alpha:SetTarget(self.Background);
	self.FadeOut.Alpha:SetTarget(self.FocusedBackground);

	self.FadeIn:Play();
	self.FadeOut:Play();
end

function SimscraftShoppingListItemEntryMixin:Init(data)
	local itemID = data.ItemID;
	self:SetItem(itemID);

	local quantity = data.Quantity;
	self:SetRequiredQuantity(quantity);
end

function SimscraftShoppingListItemEntryMixin:OnUpButtonClicked()
	Registry:TriggerEvent(Events.SHOPPING_LIST_MOVE_ITEM, self.ItemID, 1);
end

function SimscraftShoppingListItemEntryMixin:OnDownButtonClicked()
	Registry:TriggerEvent(Events.SHOPPING_LIST_MOVE_ITEM, self.ItemID, -1);
end

function SimscraftShoppingListItemEntryMixin:OnDeleteButtonClicked()
	Registry:TriggerEvent(Events.SHOPPING_LIST_DELETE_ITEM, self.ItemID);
end

function SimscraftShoppingListItemEntryMixin:SetItem(itemID)
	self.ItemID = itemID;

	local item = Item:CreateFromItemID(itemID);
	item:ContinueOnItemLoad(function()
		local itemInfo = {C_Item.GetItemInfo(itemID)};

		local itemLink = itemInfo[2];
		self.Name:SetText(itemLink);

		local itemTexture = itemInfo[10];
		self.ItemButton.Icon:SetTexture(itemTexture);
	end);
end

function SimscraftShoppingListItemEntryMixin:SetRequiredQuantity(quantity)
	self.RequiredQuantity = quantity;
	local owned = 0;

	local text = format("%d/%d", owned, quantity);
	self.QuantityText:SetTextToFit(text);
end

function SimscraftShoppingListItemEntryMixin:UpdateOwnedQuantity()

end
