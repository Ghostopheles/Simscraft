---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

SimscraftShoppingListItemEntryMixin = {};

function SimscraftShoppingListItemEntryMixin:OnLoad()
	self.DeleteButton:SetScript("OnClick", function() self:OnDeleteButtonClicked(); end);

	self.Name:SetPoint("RIGHT", self.QuantityDisplay, "LEFT", -5, 0);
	self.Name:SetTextScale(1.2);

	self.InspectButton:SetScript("OnClick", function() self:OnInspectButtonClicked(); end);
	self.InspectButton.tooltipText = "View this decor item in the housing catalog.";
	internal.AddTooltip(self.InspectButton);

	self:SetOnUpdateMode(Enum.OnUpdateMode.RunWhenVisible);

	self.FadeIn.Alpha:SetTarget(self.FocusedBackground);
	self.FadeOut.Alpha:SetTarget(self.Background);
end

function SimscraftShoppingListItemEntryMixin:OnShow()
	self:UpdateOwnedQuantity();
end

function SimscraftShoppingListItemEntryMixin:OnHide()
	if GameTooltip:IsOwned(self) then
		self:HideItemTooltip();
	end
end

function SimscraftShoppingListItemEntryMixin:OnEnter()
	if self.MouseOverChild then
		self:ShowItemTooltip();
		return;
	end

	self.FadeIn.Alpha:SetDuration(0.25);
	self.FadeOut.Alpha:SetDuration(0.35);

	self.FadeIn:Play();
	self.FadeOut:Play();

	self.Highlight:Show();
	self.HighlightBorder:Show();

	self:ShowItemTooltip();
end

function SimscraftShoppingListItemEntryMixin:OnLeave()
	if not self:IsMouseOver() then
		self.FadeIn.Alpha:SetDuration(0.35);
		self.FadeOut.Alpha:SetDuration(0.25);

		local reverse = true;
		self.FadeIn:Play(reverse);
		self.FadeOut:Play(reverse);

		self.Highlight:Hide();
		self.HighlightBorder:Hide();

		self:HideItemTooltip();
		self.MouseOverChild = false;
	else
		self.MouseOverChild = true;
	end
end

function SimscraftShoppingListItemEntryMixin:OnUpdate()
	if self.MouseOverChild and not self:IsMouseOver() then
		self:OnLeave();
	end
end

function SimscraftShoppingListItemEntryMixin:OnMouseUp(buttonName)
	if IsModifiedClick("CHATLINK") and ACTIVE_CHAT_EDIT_BOX then
		HandleModifiedItemClick(self.Name:GetText());
	elseif ContentTrackingUtil.IsTrackingModifierDown() then
		internal.Catalog.TrackDecorByItem(self.ItemID);
	end
end

function SimscraftShoppingListItemEntryMixin:ShowItemTooltip(owner, anchor, noTrackingLine)
	anchor = anchor or "ANCHOR_RIGHT";
	GameTooltip:SetOwner(owner or self, anchor);
	GameTooltip:SetItemByID(self.ItemID);

	if not noTrackingLine then
		local recordID = internal.DecorUtil.GetDecorRecordIDByItem(self.ItemID);
		Blizzard_HousingCatalogUtil.AddDecorEntryTooltipTrackingText(GameTooltip, recordID);
	end

	GameTooltip:Show();
end

function SimscraftShoppingListItemEntryMixin:HideItemTooltip()
	GameTooltip:Hide();
end

function SimscraftShoppingListItemEntryMixin:Init(data)
	local itemID = data.ItemID;
	self:SetItem(itemID);

	local quantity = data.Quantity;
	self:SetRequiredQuantity(quantity);

	self:UpdateOwnedQuantity();
	self:UpdateQuantityDisplay();
end

function SimscraftShoppingListItemEntryMixin:OnDeleteButtonClicked()
	Registry:TriggerEvent(Events.SHOPPING_LIST_DELETE_ITEM, self.ItemID);
end

function SimscraftShoppingListItemEntryMixin:OnInspectButtonClicked()
	C_AddOns.LoadAddOn("Blizzard_HousingDashboard");

	local recordID = internal.DecorUtil.GetDecorRecordIDByItem(self.ItemID);
	EventRegistry:TriggerEvent("HousingCatalogFrame.OpenToDecorID", recordID);
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

function SimscraftShoppingListItemEntryMixin:GetItemID()
	return self.ItemID;
end

function SimscraftShoppingListItemEntryMixin:SetRequiredQuantity(quantity)
	self.RequiredQuantity = quantity;
end

function SimscraftShoppingListItemEntryMixin:UpdateOwnedQuantity()
	if not self.ItemID then
		return;
	end

	local _, stored, placed = internal.DecorUtil.GetAmountOwnedByItem(self.ItemID);
	self.StoredQuantity = stored;
	self.PlacedQuantity = placed;
end

function SimscraftShoppingListItemEntryMixin:UpdateQuantityDisplay()
	self.QuantityDisplay:SetQuantities(self.PlacedQuantity, self.StoredQuantity, self.RequiredQuantity);
	self.QuantityDisplay:SetEditable(false);
end

------------

SimscraftShoppingListItemEntryQuantityDisplayMixin = {};

function SimscraftShoppingListItemEntryQuantityDisplayMixin:OnLoad()
	self.Editable = false;
	self.PlacedQuantity = 0;
	self.StoredQuantity = 0;
	self.RequiredQuantity = 0;

	self.EditBox:HookScript("OnEnterPressed", function()
		self:Commit();
		self:SetEditable(false);
	end);

	self.EditBox:HookScript("OnEscapePressed", function()
		self:SetEditable(false);
	end);

	self.EditBox:HookScript("OnEditFocusLost", function()
		self:SetEditable(false);
	end);

	internal.AddTooltip(self, "ANCHOR_TOP");

	self.Text:SetTextScale(1.2);
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:OnMouseUp(buttonName)
	if buttonName ~= "RightButton" or self.Editable then
		return;
	end

	self:SetEditable(true);
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:SetText(text)
	self.Text:SetText(text);
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:SetEditBoxText(text)
	self.EditBox:SetText(text);
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:SetEditable(editable)
	if editable == self.Editable then
		return;
	end

	if editable then
		PlaySound(SOUNDKIT.ACCOUNT_STORE_ITEM_SELECT);
	else
		PlaySound(SOUNDKIT.ACCOUNT_STORE_ITEM_REFUND);
	end

	self.Editable = editable;
	self:Update();
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:Commit()
	local newQuantity = self.EditBox:GetNumber();
	if newQuantity == self.RequiredQuantity then
		return;
	end

	if newQuantity <= 0 then
		newQuantity = 1;
	end

	local itemID = self:GetParent():GetItemID();
	Registry:TriggerEvent(Events.SHOPPING_LIST_SET_TARGET_QUANTITY, itemID, newQuantity);

	PlaySound(SOUNDKIT.ACCOUNT_STORE_CATEGORY_SELECT);
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:UpdateText()
	local owned = self.StoredQuantity;
	local required = self.RequiredQuantity;
	local text = format("%d/%d", owned, required);

	if owned >= required then
		text = GREEN_FONT_COLOR:WrapTextInColorCode(text);
	end

	local icon = CreateAtlasMarkup("house-chest-icon", 20, 20);
	text = format("%s %s", icon, text);
	self.Text:SetTextToFit(text);

	local requiredFmt = "Required: ";
	local requiredColor = owned < required and RED_FONT_COLOR or GREEN_FONT_COLOR;
	requiredFmt = requiredFmt .. requiredColor:WrapTextInColorCode("%d");

	local tooltipText = format("Placed: %d\nStorage: %d\n\n" .. requiredFmt, self.PlacedQuantity, self.StoredQuantity, self.RequiredQuantity);

	local rightClickText = YELLOW_FONT_COLOR:WrapTextInColorCode("[Right-click]");
	tooltipText = tooltipText .. internal.ThemeColor:WrapTextInColorCode(format("\n%s to edit quantity", rightClickText));

	self.tooltipText = WHITE_FONT_COLOR:WrapTextInColorCode(tooltipText);
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:UpdateEditBox()
	self.EditBox:SetNumber(self.RequiredQuantity);
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:Update()
	self:UpdateText();
	self:UpdateEditBox();

	self.Text:SetShown(not self.Editable);
	self.EditBox:SetShown(self.Editable);
end

function SimscraftShoppingListItemEntryQuantityDisplayMixin:SetQuantities(placed, stored, required)
	self.PlacedQuantity = placed;
	self.StoredQuantity = stored;
	self.RequiredQuantity = required;

	self:Update();
end
