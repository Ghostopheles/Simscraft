---@class SimscraftDyeColorMixin : Frame
---@field StartColorTexture Texture
---@field EndColorTexture Texture
---@field Highlight Texture
---@field SelectedBorder Texture
SimscraftDyeColorMixin = {};

---@alias SimscraftDyeColorFrame SimscraftDyeColorMixin

function SimscraftDyeColorMixin:OnEnter()
    local displayInfo = self:GetDisplayInfo();
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT");
    GameTooltip_AddHighlightLine(GameTooltip, displayInfo.name);
    GameTooltip_AddInstructionLine(GameTooltip, format("Available: %d", displayInfo.numOwned));
    GameTooltip:Show();

    --self.Highlight:Show();
end

function SimscraftDyeColorMixin:OnLeave()
    GameTooltip:Hide();

    --self.Highlight:Hide();
end

function SimscraftDyeColorMixin:OnClick()
    SimscraftDyeWheel:SelectDye(self);
end

function SimscraftDyeColorMixin:Select()
    local dyeSlotInfo = DyeSelectionPopout.dyeSlotInfo;
    local dyeInfo = self:GetDisplayInfo();
    local decorInfo = C_HousingCustomizeMode.GetSelectedDecorInfo();
    if not decorInfo then
        return;
    end

    C_HousingCustomizeMode.ApplyDyeToSelectedDecor(dyeSlotInfo.ID, dyeInfo.ID);

    self.SelectedBorder:Show();
end

function SimscraftDyeColorMixin:Deselect()
    self.SelectedBorder:Hide();
end

---@param data DyeColorDisplayInfo
function SimscraftDyeColorMixin:Init(data)
    self:SetDisplayInfo(data);
    self:SetColor(data.swatchColorStart, data.swatchColorEnd);
end

---@param displayInfo DyeColorDisplayInfo
function SimscraftDyeColorMixin:SetDisplayInfo(displayInfo)
    self.DisplayInfo = displayInfo;
end

---@return DyeColorDisplayInfo displayInfo
function SimscraftDyeColorMixin:GetDisplayInfo()
    return self.DisplayInfo;
end

---@param startColor ColorMixin
---@param endColor ColorMixin
function SimscraftDyeColorMixin:SetColor(startColor, endColor)
    self.StartColor = startColor;
    self.EndColor = endColor;

    self.StartColorTexture:SetVertexColor(startColor:GetRGB());
    self.EndColorTexture:SetVertexColor(endColor:GetRGB());
end

---@return ColorMixin startColor
---@return ColorMixin endColor
function SimscraftDyeColorMixin:GetColor()
    return self.StartColor, self.EndColor;
end