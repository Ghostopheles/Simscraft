---@class SimscraftInternal
local internal = select(2, ...);

local ColorUtil = internal.ColorUtil;

local GRID_SIZE = 9;
local COLOR_CELL_SIZE = 40;
local MAX_DYE_COLORS = 62;

local DECOR_CUSTOMIZATION_FRAME;

------------

SimscraftDyeWheelMixin = {};

function SimscraftDyeWheelMixin:OnLoad()
    self.ColorFrames = {};
    self.SwatchPool = CreateFramePool("Button", self, "SimscraftDyeColorTemplate", nil, nil, nil, MAX_DYE_COLORS);

    local size = (GRID_SIZE * COLOR_CELL_SIZE) + 5;
    self:SetSize(size, size)
end

function SimscraftDyeWheelMixin:OnShow()
    if not self.Loaded then
        self:Populate();
    end

    local parent = DECOR_CUSTOMIZATION_FRAME or HouseEditorFrame.CustomizeModeFrame.DecorCustomizationsPane;
    self:SetPoint("TOPRIGHT", parent, "TOPLEFT", -8, 0);
end

---@param dyeInfo DyeColorDisplayInfo
---@return SimscraftDyeColorFrame
function SimscraftDyeWheelMixin:AcquireColorFrame(dyeInfo)
    ---@type SimscraftDyeColorFrame
    local f = self.SwatchPool:Acquire();
    f:Init(dyeInfo);
    f:Show();

    return f;
end

---@param colorFrames SimscraftDyeColorFrame[]
function SimscraftDyeWheelMixin:SortColorsByColorWheel(colorFrames)
    local tagged = {};
    for _, colorFrame in ipairs(colorFrames) do
        local color = colorFrame:GetColor();
        local h, s, v = ColorUtil.RGBtoHSV(color:GetRGB());
        tinsert(tagged, {
            frame = colorFrame,
            color = color,
            h = h, s = s, v = v
        });
    end

    sort(tagged, function(a, b)
        local aNeutral = a.s < 0.15;
        local bNeutral = b.s < 0.15;
        if aNeutral ~= bNeutral then return bNeutral end
        if aNeutral and bNeutral then return a.v > b.v end

        local hueDiff = a.h - b.h;
        if abs(hueDiff) > 5 then return hueDiff < 0 end
        return a.s > b.s;
    end)

    local half = floor(GRID_SIZE / 2);

    local cells = {};
    for row = -half, half do
        for col = -half, half do
            local dist = sqrt(col * col + row * row);
            if dist <= half + 0.5 then
                local angle = atan2(row, col);
                if angle < 0 then angle = angle + 2 * math.pi end
                tinsert(cells, {
                    col = col, row = row,
                    angle = angle,
                    dist = dist
                });
            end
        end
    end

    sort(cells, function(a, b)
        local aDeg = deg(a.angle);
        local bDeg = deg(b.angle);

        local aBand = floor(aDeg / 10);
        local bBand = floor(bDeg / 10);
        if aBand ~= bBand then return aBand < bBand end
        return a.dist > b.dist;
    end)

    for i, entry in ipairs(tagged) do
        local cell = cells[i];
        if not cell then break end

        local f = entry.frame;
        f:SetPoint("CENTER", self, "CENTER",
            cell.col * COLOR_CELL_SIZE,
           -cell.row * COLOR_CELL_SIZE)
    end
end

function SimscraftDyeWheelMixin:Populate()
    if self.Loaded then
        return;
    end

    local colorFrames = {};

    local onlyOwnedDye = false;
    local allDyeColors = C_DyeColor.GetAllDyeColors(onlyOwnedDye);
    for _, dyeColorID in ipairs(allDyeColors) do
        local dyeInfo = C_DyeColor.GetDyeColorInfo(dyeColorID);
        if dyeInfo then
            local f = self:AcquireColorFrame(dyeInfo);
            tinsert(colorFrames, f);
        end
    end

    self:SortColorsByColorWheel(colorFrames);
    self.Loaded = true;
end

function SimscraftDyeWheelMixin:SelectDye(dyeFrame)
    if not self.SelectedDye then
        self.SelectedDye = dyeFrame;
        dyeFrame:Select();
    elseif self.SelectedDye ~= dyeFrame then
        self.SelectedDye:Deselect();
        self.SelectedDye = dyeFrame;
        dyeFrame:Select();
    end
end

------------

-- hook deez

local function HookDyePanel()
    local maliciousParent = CreateFrame("Frame");

    local popout = DyeSelectionPopout;
    popout:SetParent(maliciousParent);
    popout:ClearAllPoints();

    popout:HookScript("OnShow", function()
        SimscraftDyeWheel:Show();
    end);

    popout:HookScript("OnHide", function()
        SimscraftDyeWheel:Hide();
    end);
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_HouseEditor", HookDyePanel);