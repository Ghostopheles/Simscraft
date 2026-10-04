---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;
local Catalog = internal.Catalog;

------------

--- duplicated from Manager.lua because I hate myself
local bCornerOffset = 2;
local SELECTION_HIGHLIGHT_NINESLICE = {
	mirrorLayout = true,
	TopLeftCorner =	{
		atlas = "editmode-actionbar-selected-nineslice-corner",
		x = -bCornerOffset,
		y = bCornerOffset,
	},
	TopRightCorner = {
		atlas = "editmode-actionbar-selected-nineslice-corner",
		x = bCornerOffset,
		y = bCornerOffset,
	},
	BottomLeftCorner = {
		atlas = "editmode-actionbar-selected-nineslice-corner",
		x = -bCornerOffset,
		y = -bCornerOffset,
	},
	BottomRightCorner = {
		atlas = "editmode-actionbar-selected-nineslice-corner",
		x = bCornerOffset,
		y = -bCornerOffset,
	},
	TopEdge = {
		atlas = "_editmode-actionbar-selected-nineslice-edgetop",
	},
	BottomEdge = {
		atlas = "_editmode-actionbar-selected-nineslice-edgebottom",
		mirrorLayout = false,
	},
	LeftEdge = {
		atlas = "!editmode-actionbar-selected-nineslice-edgeleft",
		mirrorLayout = false,
	},
	RightEdge = {
		atlas = "!editmode-actionbar-selected-nineslice-edgeright",
		mirrorLayout = false,
	},
};

---@alias SimscraftDecorItemSearchResultData HousingCatalogEntryID

SimscraftDecorItemSearchResultMixin = {};

function SimscraftDecorItemSearchResultMixin:OnLoad()
	self.Name:SetTextScale(1.2);

	self:SetOnUpdateMode(Enum.OnUpdateMode.RunWhenVisible);

	self.FadeIn.Alpha:SetTarget(self.FocusedBackground);
	self.FadeOut.Alpha:SetTarget(self.Background);

	NineSliceUtil.ApplyLayout(self.SelectionHighlight, SELECTION_HIGHLIGHT_NINESLICE);
end

function SimscraftDecorItemSearchResultMixin:OnHide()
	if GameTooltip:IsOwned(self) then
		self:HideItemTooltip();
	end
end

function SimscraftDecorItemSearchResultMixin:OnEnter()
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

function SimscraftDecorItemSearchResultMixin:OnLeave()
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

function SimscraftDecorItemSearchResultMixin:OnUpdate()
	if self.MouseOverChild and not self:IsMouseOver() then
		self:OnLeave();
	end
end

function SimscraftDecorItemSearchResultMixin:OnMouseUp(buttonName)
	SimscraftDecorItemSearchFrame:OnSearchResultClicked(self:GetData(), buttonName);
end

function SimscraftDecorItemSearchResultMixin:ShowItemTooltip(owner, anchor)
	if not self.ItemID then
		return;
	end

	anchor = anchor or "ANCHOR_RIGHT";
	GameTooltip:SetOwner(owner or self, anchor);
	GameTooltip:SetItemByID(self.ItemID);
	GameTooltip:Show();
end

function SimscraftDecorItemSearchResultMixin:HideItemTooltip()
	GameTooltip:Hide();
end

---@param data SimscraftDecorItemSearchResultData
function SimscraftDecorItemSearchResultMixin:Init(data)
	local info = C_HousingCatalog.GetCatalogEntryInfo(data);
	self.Name:SetText(info.name);

	self:SetItem(info.itemID);
end

function SimscraftDecorItemSearchResultMixin:SetItem(itemID)
	assert(itemID, "No item ID for search result");

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

------------

SimscraftDecorItemSearchMixin = {};

function SimscraftDecorItemSearchMixin:OnLoad()
	local eb = self.SearchBox;

	local function Hook(script)
		eb:HookScript(script, function(_, ...)
			self[script](self, ...);
		end);
	end

	Hook("OnArrowPressed");
	Hook("OnEnterPressed");
	Hook("OnEscapePressed");

	eb:HookScript(
		"OnTextChanged",
		internal.Debounce(internal.Constants.DECOR_SEARCH_DEBOUNCE, function()
			self:OnTextChanged();
	end));

	Registry:RegisterCallback(Events.CATALOG_SEARCH_RESULTS_UPDATED, self.OnSearchResultsUpdated, self);

	local content = self.SearchResults;
	local anchorsWithScrollBar = {
        CreateAnchor("TOPLEFT", content, "TOPLEFT", 10, -5),
        CreateAnchor("TOPRIGHT", content.ScrollBar, "TOPLEFT", -5, -5),
        CreateAnchor("BOTTOM", content, "BOTTOM", 0, 5);
    };

    local anchorsWithoutScrollBar = {
        anchorsWithScrollBar[1],
        CreateAnchor("TOPRIGHT", content, "TOPRIGHT", -5, -30),
        anchorsWithScrollBar[3],
    };

    ScrollUtil.AddManagedScrollBarVisibilityBehavior(content.ScrollBox, content.ScrollBar, anchorsWithScrollBar, anchorsWithoutScrollBar);

    content.ScrollView = CreateScrollBoxListLinearView();

	self.SelectionBehavior = ScrollUtil.AddSelectionBehavior(content.ScrollBox, SelectionBehaviorFlags.Intrusive);
	local function SelectionCallback(_, elementData, isSelected)
		local frame = content.ScrollBox:FindFrame(elementData);
		if frame then
			frame.SelectionHighlight:SetShown(isSelected);
		end
	end
	self.SelectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged, SelectionCallback, self);


    local function Initializer(frame, data)
        frame:Init(data);
		frame.SelectionHighlight:SetShown(self.SelectionBehavior:IsElementDataSelected(data));
    end
    content.ScrollView:SetElementInitializer("SimscraftDecorItemSearchResultTemplate", Initializer);

	content.ScrollBar.canInterpolateScroll = true;
	content.ScrollBox.canInterpolateScroll = true;

    ScrollUtil.InitScrollBoxListWithScrollBar(content.ScrollBox, content.ScrollBar, content.ScrollView);

	Registry:RegisterCallback(Events.DECOR_SEARCH_SHOW, self.OnDecorSearchShow, self);
	Registry:RegisterCallback(Events.DECOR_SEARCH_HIDE, self.OnDecorSearchHide, self);

	self.SearchBox.Instructions:SetText("Search for a decor item by name");

	local helpText = GRAY_FONT_COLOR:WrapTextInColorCode("Use the search box to search for decor items by name.|nNavigate results with your arrows keys or mouse.");
	self.HelpText:SetText(helpText);
end

function SimscraftDecorItemSearchMixin:OnTextChanged()
	local query = self.SearchBox:GetText();
	if query == "" then
		self:ResetDataProvider();
		return;
	end

	self:RunSearch(query);
end

function SimscraftDecorItemSearchMixin:OnArrowPressed(key)
	local selection = self.SelectionBehavior;
	local scrollBox = self.SearchResults.ScrollBox;

	if not selection:HasSelection() then
		return;
	end

	if key == "LEFT" or key == "RIGHT" then
		return;
	end

	if selection:IsFirstElementDataSelected() and key == "UP" then
		selection:SelectLastElementData();
	elseif selection:IsLastElementDataSelected() and key == "DOWN" then
		selection:SelectFirstElementData();
	else
		local offset = key == "DOWN" and 1 or -1;
		selection:SelectOffsetElementData(offset);
	end

	local selections = selection:GetSelectedElementData();
	local selected = selections[1];
	if selected then
		local alignment = ScrollBoxConstants.AlignNearest;
		scrollBox:ScrollToElementData(selected, alignment);
	end
end

function SimscraftDecorItemSearchMixin:OnEnterPressed()
	local selections = self.SelectionBehavior:GetSelectedElementData();
	local selected = selections[1];
	if selected then
		self:AddItemToListByRecordID(selected.recordID)
	end
	self:Hide();
end

function SimscraftDecorItemSearchMixin:OnSearchResultClicked(elementData, buttonName)
	if buttonName ~= "LeftButton" then
		return;
	end

	self:AddItemToListByRecordID(elementData.recordID);
	self:Hide();
end

function SimscraftDecorItemSearchMixin:OnEscapePressed()
	self:Hide();
end

function SimscraftDecorItemSearchMixin:OnSearchResultsUpdated()
	if not self:IsShown() then
		return;
	end

	self:ResetDataProvider();

	local results = Catalog.GetSearchResults();
	for _, result in ipairs(results) do
		if result.entryType == Enum.HousingCatalogEntryType.Decor and result.recordID then
			self.DataProvider:Insert(result);
		end
	end

	self.SelectionBehavior:SelectFirstElementData();

	self:UpdateHelpTextVisibility();
end

function SimscraftDecorItemSearchMixin:OnDecorSearchShow()
	self:ResetDataProvider();
	self:Show();
	self.SearchBox:SetText("");
	self.SearchBox:SetFocus();
end

function SimscraftDecorItemSearchMixin:OnDecorSearchHide()
	self:Hide();
end

function SimscraftDecorItemSearchMixin:AddItemToListByRecordID(recordID)
	local itemID = internal.DecorUtil.GetDecorItemIDByRecordID(recordID);
	if itemID then
		Registry:TriggerEvent(Events.SHOPPING_LIST_ADD_ITEM, itemID, 1);
		PlaySound(SOUNDKIT.UI_GARRISON_TOAST_MISSION_COMPLETE);
	end
end

function SimscraftDecorItemSearchMixin:ResetDataProvider()
	self.DataProvider = CreateDataProvider();
	self.SearchResults.ScrollView:SetDataProvider(self.DataProvider);
	self:UpdateHelpTextVisibility();
end

function SimscraftDecorItemSearchMixin:RunSearch(query)
	local searchText = query or self.SearchBox:GetText();
	Catalog.Search(searchText);
end

function SimscraftDecorItemSearchMixin:UpdateHelpTextVisibility()
	if not self.DataProvider then
		return;
	end

	local size = self.DataProvider:GetSize();
	self.HelpText:SetShown(size == 0);
end
