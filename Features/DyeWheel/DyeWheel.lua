---@class SimscraftInternal
local internal = select(2, ...);

local ColorUtil = internal.ColorUtil;

local NEUTRAL_THRESHOLD = 0.20;
local COLOR_CELL_SIZE = 40;
local FRAME_SIZE_SPACING = 20;
local MAX_DYE_COLORS = 62;
local WHEEL_RADIUS = ceil(sqrt(MAX_DYE_COLORS / math.pi));

local DECOR_CUSTOMIZATION_FRAME;

------------

local function ShouldEnableDyePicker()
    return internal.Settings.GetSetting(internal.Setting.UseNewDyePicker);
end

------------

SimscraftRemoveDyeButtonMixin = {};

function SimscraftRemoveDyeButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT");
    GameTooltip_AddHighlightLine(GameTooltip, HOUSING_DECOR_CUSTOMIZATION_DEFAULT_COLOR);
    GameTooltip:Show();
end

function SimscraftRemoveDyeButtonMixin:OnLeave()
    GameTooltip:Hide();
end

function SimscraftRemoveDyeButtonMixin:OnClick()
    SimscraftDyeWheel:SelectDye(self);
end

function SimscraftRemoveDyeButtonMixin:Select()
    self.SelectedBorder:Show();

    local dyeSlotInfo = DyeSelectionPopout.dyeSlotInfo;
    C_HousingCustomizeMode.ApplyDyeToSelectedDecor(dyeSlotInfo.ID);
end

function SimscraftRemoveDyeButtonMixin:Deselect()
    self.SelectedBorder:Hide();
end

------------

SimscraftDyeWheelMixin = {};

function SimscraftDyeWheelMixin:OnLoad()
    self.ColorFrames = {};
    tinsert(self.ColorFrames, 0, self.RemoveDyeButton);
    self.SwatchPool = CreateFramePool("Button", self, "SimscraftDyeColorTemplate");

    local size = ((WHEEL_RADIUS * 2) * COLOR_CELL_SIZE) + FRAME_SIZE_SPACING;
    self:SetSize(size, size);
end

function SimscraftDyeWheelMixin:OnShow()
    if not ShouldEnableDyePicker() then
        self:Hide();
        return;
    end

    if not self.Loaded then
        self:Populate();

        local parent = DECOR_CUSTOMIZATION_FRAME;
        if not parent then
            DECOR_CUSTOMIZATION_FRAME = HouseEditorFrame.CustomizeModeFrame.DecorCustomizationsPane;
            parent = DECOR_CUSTOMIZATION_FRAME;
        end

        self:SetPoint("TOPRIGHT", parent, "TOPLEFT", -15, 0);

        hooksecurefunc(DyeSelectionPopout, "SetDyeSlotInfo", function()
            -- since the selected dye info doesn't seem to be updated when this hook runs, i'm just gonna wait till the next frame owo
            RunNextFrame(function()
                self:UpdateSelectedDye();
            end);
        end);
    end

    self:UpdateSelectedDye();
end

function SimscraftDyeWheelMixin:UpdateSelectedDye()
    local selectedDyeSlot = DyeSelectionPopout.dyeSlotInfo;
    local dyeButton = self.ColorFrames[selectedDyeSlot.dyeColorID];
    if dyeButton then
        self:SelectDye(dyeButton);
    end
    self:UpdateRecentDyes();
end

---@param dyeInfo DyeColorDisplayInfo
---@return SimscraftDyeColorFrame
function SimscraftDyeWheelMixin:AcquireColorFrame(dyeInfo)
    local pool = self.SwatchPool;

    ---@class SimscraftDyeColorFrame
    local f = pool:Acquire();
    f:SetSize(COLOR_CELL_SIZE, COLOR_CELL_SIZE);
    f:Init(dyeInfo);
    f:Show();

    self.ColorFrames[dyeInfo.ID] = f;
    return f;
end

NUM_EXTRA_CELLS = 0;
function SimscraftDyeWheelMixin:GenerateCells(neutralCount, chromaticCount)
    local TWO_PI = 2 * math.pi;
    local maxCount = neutralCount + chromaticCount;

    local extraRings = - 1;
    local maxRadius = ceil(sqrt(maxCount / math.pi)) + extraRings;

    local allCells = {};
    local seenPositions = {};
    for row = -maxRadius, maxRadius do
        for col = -maxRadius, maxRadius do
            local d = sqrt(col * col + row * row);
            if d <= maxRadius + 0.5 then
                local key = col .. "," .. row;
                if not seenPositions[key] then
                    seenPositions[key] = true;
                    local angle = atan2(row, col);
                    if angle < 0 then
                        angle = angle + TWO_PI;
                    end
                    tinsert(allCells, {
                        col=col, row=row,
                        angle=angle, dist=d
                    });
                end
            end
        end
    end

    sort(allCells, function(a, b)
        if abs(a.dist - b.dist) > 0.1 then
            return a.dist < b.dist;
        end
        return a.angle < b.angle;
    end);

    local usedPositions = {};
    local centerCells = {};
    for _, cell in ipairs(allCells) do
        local key = cell.col .. "," .. cell.row;
        if not usedPositions[key] then
            usedPositions[key] = true;
            tinsert(centerCells, cell);
            if #centerCells >= neutralCount then
                break;
            end
        end
    end

    local candidates = {};
    for _, cell in ipairs(allCells) do
        local key = cell.col .. "," .. cell.row;
        if not usedPositions[key] then
            tinsert(candidates, cell);
        end
    end

    local usedIndices = {};
    local outerCells = {};

    for slot = 0, chromaticCount - 1 do
        local idealAngle = (slot / chromaticCount) * TWO_PI;

        local bestIdx = nil;
        local bestScore = math.huge;
        for i, cell in ipairs(candidates) do
            if not usedIndices[i] then
                local diff = abs(cell.angle - idealAngle);
                if diff > math.pi then
                    diff = TWO_PI - diff;
                end
                local score = diff * 10 + cell.dist * 3.0;
                if score < bestScore then
                    bestScore = score;
                    bestIdx = i;
                end
            end
        end

        if bestIdx then
            usedIndices[bestIdx] = true;
            tinsert(outerCells, candidates[bestIdx]);
        end
    end

    local sorted = {};
    for _, c in ipairs(centerCells) do
        tinsert(sorted, c);
    end
    for _, c in ipairs(outerCells) do
        tinsert(sorted, c);
    end
    return sorted;
end

function SimscraftDyeWheelMixin:GetAverageColor(startColor, endColor)
    local curve = C_CurveUtil.CreateColorCurve();
    curve:SetType(Enum.LuaCurveType.Linear);
    curve:AddPoint(0, CreateColor(startColor.r, startColor.g, startColor.b));
    curve:AddPoint(1, CreateColor(endColor.r, endColor.g, endColor.b));
    return curve:Evaluate(0.5);
end

function SimscraftDyeWheelMixin:SortColors(colorFrames)
    local neutrals = {};
    local chromatic = {};

    for _, colorFrame in ipairs(colorFrames) do
        local color = colorFrame:GetColors();
        local h, s, v = ColorUtil.RGBtoHSV(color.r, color.g, color.b);
        local band = ColorUtil.GetHueBand(h);
        local entry = {
            frame = colorFrame,
            h = h, s = s, v = v,
            band = band
        };
        if s < NEUTRAL_THRESHOLD then
            tinsert(neutrals, entry);
        else
            tinsert(chromatic, entry);
        end
    end

    sort(neutrals, function(a, b)
        return a.v > b.v;
    end);

    sort(chromatic, function(a, b)
        if a.band ~= b.band then
            return a.band < b.band;
        end

        if abs(a.h - b.h) > 1 then
            return a.h < b.h;
        end

        if abs(a.v - b.v) > 0.1 then
            return a.v > b.v;
        end

        return a.s > b.s;
    end);

    local sorted = {};
    for _, e in ipairs(neutrals) do
        tinsert(sorted, e.frame);
    end
    for _, e in ipairs(chromatic) do
        tinsert(sorted, e.frame);
    end
    return sorted, #neutrals, #chromatic;
end

---@param colorFrames SimscraftDyeColorFrame[]
function SimscraftDyeWheelMixin:SetupColorWheel(colorFrames)
    local sortedColors, numNeutral, numChromatic = self:SortColors(colorFrames);
    local cells = self:GenerateCells(numNeutral, numChromatic);

    for i, entry in ipairs(sortedColors) do
        local cell = cells[i];
        if not cell then
            break;
        end

        local offsetX = cell.col * COLOR_CELL_SIZE;
        local offsetY = cell.row * COLOR_CELL_SIZE;
        entry:SetPoint("CENTER", self, "CENTER", offsetX, offsetY);
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

    self:SetupColorWheel(colorFrames);
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

function SimscraftDyeWheelMixin:UpdateRecentDyes()
    self.RecentDyesPanel:Update();
end

------------

local popoutHidden = false;
local function ReplaceDyePanel()
    local maliciousParent = CreateFrame("Frame");

    local popout = DyeSelectionPopout;
    local originalParent = popout:GetParent();
    local originalPoints = {};
    for i = 1, popout:GetNumPoints() do
        local point = CreateAnchor(popout:GetPoint(i));
        tinsert(originalPoints, point);
    end

    popout:HookScript("OnShow", function()
        if ShouldEnableDyePicker() then
            if not popoutHidden then
                popout:SetParent(maliciousParent);
                popout:ClearAllPoints();
                popoutHidden = true;
            end

            SimscraftDyeWheel:Show();
        elseif popoutHidden then
            popout:SetParent(originalParent);
            for _, point in ipairs(originalPoints) do
                point:SetPoint(popout);
            end

            popout:SetDyeSlotInfo(popout.dyeSlotInfo);
            popoutHidden = false;
        end
    end);

    popout:HookScript("OnHide", function()
        SimscraftDyeWheel:Hide();
    end);
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_HouseEditor", ReplaceDyePanel);