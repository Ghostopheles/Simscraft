---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftAutoBuy
local AutoBuy = internal.AutoBuy;

------------

SimscraftShoppingListDisplayMixin = {};

function SimscraftShoppingListDisplayMixin:OnLoad()
end

function SimscraftShoppingListDisplayMixin:OnShow()
    self:UpdateMetadata();
end

function SimscraftShoppingListDisplayMixin:UpdateMetadata()
    local md = self.MetadataContainer;
    md.Title:SetText("Title: N/A");
    md.LastEditedAt:SetText("Last Edited: N/A");
    md.Size:SetText("Size: N/A");
end