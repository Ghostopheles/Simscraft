---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftAutoBuy
local AutoBuy = internal.AutoBuy;

if not SimscraftShoppingLists then
    SimscraftShoppingLists = {};
end

------------

SimscraftShoppingListManagerListFrameMixin = {};

function SimscraftShoppingListManagerListFrameMixin:OnLoad()
    local anchorsWithScrollBar = {
        CreateAnchor("TOPLEFT", self, "TOPLEFT"),
        CreateAnchor("TOPRIGHT", self.ScrollBar, "TOPLEFT", -5, 0),
        CreateAnchor("BOTTOM", self, "BOTTOM");
    };

    local anchorsWithoutScrollBar = {
        anchorsWithScrollBar[1],
        CreateAnchor("TOPRIGHT", self, "TOPRIGHT", -5, -30),
        anchorsWithScrollBar[3],
    };

    ScrollUtil.AddManagedScrollBarVisibilityBehavior(self.ScrollBox, self.ScrollBar, anchorsWithScrollBar, anchorsWithoutScrollBar);

    self.ScrollView = CreateScrollBoxListLinearView();

    local function Initializer(frame, data)
        frame:Init(data);
    end
    self.ScrollView:SetElementInitializer(Initializer);

    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, self.ScrollView);

    -- title frame friend
    self.TitleFrame.Title:SetTextToFit("Shopping Lists");
end

function SimscraftShoppingListManagerListFrameMixin:OnShow()
    if not self.Loaded then
        self:LoadShoppingLists();
        self.Loaded = true;
    end
end

function SimscraftShoppingListManagerListFrameMixin:LoadShoppingLists()
    if self.Loaded then
        return;
    end

    self.DataProvider = CreateDataProvider(SimscraftShoppingLists);
    self.ScrollView:SetDataProvider(self.DataProvider);
end

------------

SimscraftShoppingListManagerFrameMixin = {};

function SimscraftShoppingListManagerFrameMixin:OnLoad()
    ButtonFrameTemplate_HidePortrait(self);
    self:SetTitle("Shopping List Manager");
end