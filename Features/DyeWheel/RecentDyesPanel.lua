local MAX_NUM_RECENT_DYES = 10;
local COLOR_CELL_SIZE = 40;
local PADDING = 15;

------------

SimscraftRecentDyesPanelMixin = {};

function SimscraftRecentDyesPanelMixin:OnLoad()
    self.RecentSwatchPool = CreateFramePool("Button", self, "SimscraftDyeColorTemplate");
    self.ColorFrames = {};

    self.InitialAnchor = AnchorUtil.CreateAnchor("LEFT", self, "LEFT", 8, 0);

    local direction = GridLayoutMixin.Direction.LeftToRight;
    local stride = MAX_NUM_RECENT_DYES;

    self.GridLayout = AnchorUtil.CreateGridLayout(direction, stride);

    local width = (COLOR_CELL_SIZE * MAX_NUM_RECENT_DYES) + PADDING;
    self:SetWidth(width);

    self.HeaderText:SetTextScale(1.25);
end

---@param dyeInfo DyeColorDisplayInfo
---@return SimscraftDyeColorFrame
function SimscraftRecentDyesPanelMixin:AcquireColorFrame(dyeInfo)
    ---@class SimscraftDyeColorFrame
    local f = self.RecentSwatchPool:Acquire();
    f:SetSize(COLOR_CELL_SIZE, COLOR_CELL_SIZE);
    f:Init(dyeInfo);
    f:Show();

    self.ColorFrames[dyeInfo.ID] = f;
    return f;
end

function SimscraftRecentDyesPanelMixin:Update()
    self.RecentSwatchPool:ReleaseAll();
    self.RecentDyeSwatches = {};

    local dyeColorIDs = C_HousingCustomizeMode.GetRecentlyUsedDyes();
    if #dyeColorIDs == 0 then
        self:Hide();
        return;
    end

    if not self.RecentDyeSwatches then
        self.RecentDyeSwatches = {};
    end

    for index, dyeColorID in ipairs(dyeColorIDs) do
        if index > 10 then
            break;
        end

        local dyeColorInfo = C_DyeColor.GetDyeColorInfo(dyeColorID);
        local dyeFrame = self:AcquireColorFrame(dyeColorInfo);
        dyeFrame.layoutIndex = #dyeColorIDs - index;
        tinsert(self.RecentDyeSwatches, dyeFrame);
    end

    self:Show();
    self:Layout();
end

function SimscraftRecentDyesPanelMixin:Layout()
    AnchorUtil.GridLayout(self.RecentDyeSwatches, self.InitialAnchor, self.GridLayout);
end