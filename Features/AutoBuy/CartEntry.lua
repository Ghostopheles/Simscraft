---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

SimscraftShoppingCartEntryItemButtonMixin = CreateFromMixins(ItemButtonMixin);

function SimscraftShoppingCartEntryItemButtonMixin:OnUpdate(deltaTime)
    if self:IsMouseOver() then
        if IsModifiedClick("DRESSUP") then
            ShowInspectCursor();
        else
            ResetCursor();
        end
    end
end

function SimscraftShoppingCartEntryItemButtonMixin:OnClick(button)
    if IsModifiedClick("DRESSUP") then
        DressUpLink(self:GetItemLink());
    end
end

------------

ShoppingCartEntryMixin = {};

function ShoppingCartEntryMixin:OnLoad()
    self.RemoveButton:SetScript("OnClick", function()
        self:OnRemoveButtonClicked();
    end);

	self.RemoveButton.tooltipText = "Remove item from cart";
	internal.AddTooltip(self.RemoveButton);

    self.QuantityEditBox:SetScript("OnEditFocusLost", function()
        self:OnEditBoxFocusLost();
    end);

    self.QuantityEditBox:SetScript("OnEnterPressed", function()
        self:OnEditBoxEnterPressed();
    end);

	self.QuantityEditBox:SetScript("OnArrowPressed", function(_, ...)
        self:OnEditBoxArrowPressed(...);
    end);

	self.AddItemButton:SetScript("OnClick", function(_, ...)
		self:OnAddItemButtonClicked(...);
	end);

	local color = internal.ThemeColor;
	local firstLine = color:WrapTextInColorCode("[Click]") .. " to add 1.";
	local secondLine = color:WrapTextInColorCode("[Shift+Click]") .. " to add 10.";
	local thirdLine = color:WrapTextInColorCode("[Shift+Right Click]") .. " to add the amount required by your shopping lists.";
	local fourthLine = "\nYou may also use the " .. color:WrapTextInColorCode("up") .. " or " .. color:WrapTextInColorCode("down") .. " arrow keys in the editbox to adjust the quantity.";
	self.AddItemButton.tooltipText = format("%s\n%s\n%s\n%s", firstLine, secondLine, thirdLine, fourthLine);
	internal.AddTooltip(self.AddItemButton);
end

function ShoppingCartEntryMixin:Init(data)
    local itemLink = GetMerchantItemLink(data.Index);
    self.ItemButton:SetItem(itemLink);
    self.ItemLabel:SetText(itemLink);
    self.QuantityEditBox:SetNumber(data.Quantity);

    local itemCostString = internal.Cart.GenerateCostString(data);
    if itemCostString ~= "" then
        self.ItemCost:SetText("x " .. itemCostString);
    else
        self.ItemCost:SetText("");
    end
end

function ShoppingCartEntryMixin:UpdateQuantityFromEditBox()
    local data = self:GetData();
    local newQuantity = self.QuantityEditBox:GetNumber();
    if newQuantity == 0 then
        Registry:TriggerEvent(Events.CART_REMOVE_ITEM_BY_INDEX, data.Index);
    else
		Registry:TriggerEvent(Events.CART_SET_QUANTITY_BY_INDEX, data.Index, newQuantity);
    end
end

function ShoppingCartEntryMixin:OnRemoveButtonClicked()
    local data = self:GetData();
	Registry:TriggerEvent(Events.CART_REMOVE_ITEM_BY_INDEX, data.Index);
end

function ShoppingCartEntryMixin:OnEditBoxFocusLost()
    self:UpdateQuantityFromEditBox();
end

function ShoppingCartEntryMixin:OnEditBoxEnterPressed()
    self.QuantityEditBox:ClearFocus();
end

function ShoppingCartEntryMixin:OnEditBoxArrowPressed(key)
	local data = self:GetData();
	local index = data.Index;

	local amount = IsShiftKeyDown() and 10 or 1;
	if key == "DOWN" then
		amount = -amount;
		if (data.Quantity + amount) <= 0 then
			return;
		end
	end
	Registry:TriggerEvent(Events.CART_ADJUST_QUANTITY_BY_INDEX, index, amount);
end

function ShoppingCartEntryMixin:OnAddItemButtonClicked(buttonName)
	local data = self:GetData();
	local index = data.Index;
	local shiftKeyDown = IsShiftKeyDown();

	if shiftKeyDown and buttonName == "RightButton" then
		Registry:TriggerEvent(Events.CART_SET_QUANTITY_FROM_SHOPPING_LIST, index);
	else
		local amount = shiftKeyDown and 10 or 1;
		Registry:TriggerEvent(Events.CART_ADJUST_QUANTITY_BY_INDEX, index, amount);
	end
end
