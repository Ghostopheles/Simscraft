---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

local function FormatTimestamp(timestamp)
	return date("%m/%d/%y", timestamp);
end

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

local function FormatLastUpdatedTimestamp(timestamp)
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
end

function SimscraftShoppingListManagerListEntryMixin:Init(data)
	local name = data.Name;
	self.NameText:SetText(name);
	self.Name = name;

	self.SizeText:SetFormattedText("%d unique items", data.UniqueItems);

	local isWishlist = name == internal.Constants.WISHLIST_NAME;
	self.DeleteButton:SetShown(not isWishlist);
	self.LastUpdatedText:SetShown(isWishlist);

	if isWishlist then
		self:UpdateLastUpdatedTimestamp(data);
	end
end

function SimscraftShoppingListManagerListEntryMixin:OnShow()
	if not self.GetData then
		return;
	end

	local data = self:GetData();
	self:UpdateLastUpdatedTimestamp(data);
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

function SimscraftShoppingListManagerListEntryMixin:UpdateLastUpdatedTimestamp(data)
	local lastUpdatedAt = FormatLastUpdatedTimestamp(data.LastUpdatedAt);
	self.LastUpdatedText:SetFormattedText("Last updated %s ago", lastUpdatedAt);
end
