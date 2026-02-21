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

    local color = RED_FONT_COLOR;
    local available = HOUSING_DECOR_CUSTOMIZATION_DYE_NUM_OWNED:format(displayInfo.numOwned);
    if displayInfo.numOwned > 0 then
        color = GREEN_FONT_COLOR;
    end
    GameTooltip_AddColoredLine(GameTooltip, available, color);
    GameTooltip:Show();

    if not self.Selected then
        PlaySound(SOUNDKIT.HOUSING_CUSTOMIZE_DYE_HOVER);
    end
end

function SimscraftDyeColorMixin:OnLeave()
    GameTooltip:Hide();
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

    PlaySound(SOUNDKIT.HOUSING_CUSTOMIZE_DYE_SELECT);
    self.Selected = true;
end

function SimscraftDyeColorMixin:Deselect()
    self.SelectedBorder:Hide();
    self.Selected = false;
end

---@param data DyeColorDisplayInfo
function SimscraftDyeColorMixin:Init(data)
    self:SetDisplayInfo(data);
    self:SetColors(data.swatchColorStart, data.swatchColorEnd);
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
function SimscraftDyeColorMixin:SetColors(startColor, endColor)
    self.StartColor = startColor;
    self.EndColor = endColor;

    self.StartColorTexture:SetVertexColor(startColor:GetRGB());
    self.EndColorTexture:SetVertexColor(endColor:GetRGB());
end

---@return ColorMixin startColor
---@return ColorMixin endColor
function SimscraftDyeColorMixin:GetColors()
    return self.StartColor, self.EndColor;
end