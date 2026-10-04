---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------
local timeFormatter = CreateFromMixins(SecondsFormatterMixin);
timeFormatter:Init(
	SecondsFormatterConstants.ZeroApproximationThreshold,
	SecondsFormatter.Abbreviation.None,
	SecondsFormatterConstants.DontRoundUpLastUnit,
	SecondsFormatterConstants.ConvertToLower,
	SecondsFormatterConstants.RoundUpIntervals
);
timeFormatter:SetDesiredUnitCount(2);
timeFormatter:SetMinInterval(SecondsFormatter.Interval.Minutes);
timeFormatter:SetStripIntervalWhitespace(false);

local function FormatTimestamp(timestamp)
	local diff = time() - timestamp;
	return timeFormatter:Format(diff);
end

------------

SimscraftShoppingListManagerListEntryMixin = {};

function SimscraftShoppingListManagerListEntryMixin:OnLoad()
	self.DeleteButton:SetScript("OnClick", function()
		self:OnDeleteButtonPressed();
	end);

	self.NameText:SetTextScale(1.2);

	self.FulfillmentIcon.tooltipText = internal.ThemeColor:WrapTextInColorCode("This list has been completed!");
	internal.AddTooltip(self.FulfillmentIcon, "ANCHOR_TOP");
end

function SimscraftShoppingListManagerListEntryMixin:Init(data)
	local name = data.Name;
	self.NameText:SetText(name);
	self.SizeText:SetFormattedText("%d unique items", data.UniqueItems);

	local isWishlist = name == internal.Constants.WISHLIST_NAME;
	self.DeleteButton:SetShown(not isWishlist);
	self.LastUpdatedText:SetShown(isWishlist);

	local shoppingList = internal.ShoppingListManager.GetShoppingList(name);

	if isWishlist then
		self:UpdateTimestamp(shoppingList.LastUpdatedAt);
	end

	self:UpdateFulfillmentState(shoppingList.IsFulfilled);
end

function SimscraftShoppingListManagerListEntryMixin:OnShow()
	if not self.GetData then
		return;
	end

	local data = self:GetData();
	local name = data.Name;
	local shoppingList = internal.ShoppingListManager.GetShoppingList(name);
	self:UpdateTimestamp(shoppingList.LastUpdatedAt);
	self:UpdateFulfillmentState(shoppingList.IsFulfilled);
end

function SimscraftShoppingListManagerListEntryMixin:OnMouseUp()
	local data = self:GetData();
	local name = data.Name;
	Registry:TriggerEvent(Events.SHOPPING_LIST_SELECTED, name);
end

function SimscraftShoppingListManagerListEntryMixin:OnDeleteButtonPressed()
	local data = self:GetData();
	local name = data.Name;
	if not IsShiftKeyDown() then
		internal.ShoppingListManager.ConfirmShoppingListDeletion(name);
	else
		internal.ShoppingListManager.RemoveShoppingList(name);
	end
end

function SimscraftShoppingListManagerListEntryMixin:UpdateTimestamp(timestamp)
	local lastUpdatedAt = FormatTimestamp(timestamp);
	self.LastUpdatedText:SetFormattedText("Last updated %s ago", lastUpdatedAt);
end

function SimscraftShoppingListManagerListEntryMixin:UpdateFulfillmentState(isFulfilled)
	self.FulfillmentIcon:SetShown(isFulfilled);
end
