---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftAutoBuy
local AutoBuy = internal.AutoBuy;

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

    self.QuantityEditBox:SetScript("OnEditFocusLost", function()
        self:OnEditBoxFocusLost();
    end);

    self.QuantityEditBox:SetScript("OnEnterPressed", function()
        self:OnEditBoxEnterPressed();
    end);
end

function ShoppingCartEntryMixin:Init(data)
    local itemLink = GetMerchantItemLink(data.Index);
    self.ItemButton:SetItem(itemLink);
    self.ItemLabel:SetText(itemLink);
    self.QuantityEditBox:SetNumber(data.Quantity);

    local itemCostString = AutoBuy.Cart.GenerateCostString(data);
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
        AutoBuy.Cart.RemoveItemFromCartByIndex(data.Index);
    else
        AutoBuy.Cart.SetQuantityForItemInCartByIndex(data.Index, newQuantity);
    end
end

function ShoppingCartEntryMixin:OnRemoveButtonClicked()
    local data = self:GetData();
    AutoBuy.Cart.RemoveItemFromCartByIndex(data.Index);
end

function ShoppingCartEntryMixin:OnEditBoxFocusLost()
    self:UpdateQuantityFromEditBox();
end

function ShoppingCartEntryMixin:OnEditBoxEnterPressed()
    self.QuantityEditBox:ClearFocus();
end