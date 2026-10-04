---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

local SEARCHER = C_HousingCatalog.CreateCatalogSearcher();
SEARCHER:SetAutoUpdateOnParamChanges(false);
SEARCHER:SetBaseVariantOnly(true);
SEARCHER:SetResultsUpdatedCallback(function()
	Registry:TriggerEvent(Events.CATALOG_SEARCH_RESULTS_UPDATED);
end);

------------

---@class SimscraftCatalog
local Catalog = {};
internal.Catalog = Catalog;

function Catalog.SetSearchText(searchText)
	if searchText ~= SEARCHER:GetSearchText() then
		SEARCHER:SetSearchText(searchText);
	end
end

---@param searchText? string
function Catalog.Search(searchText)
	Catalog.SetSearchText(searchText);
	SEARCHER:RunSearch();
end

---@return HousingCatalogEntryID[]
function Catalog.GetSearchResults()
	return SEARCHER:GetCatalogSearchResults();
end

---@param decorID number
function Catalog.TrackDecorByID(decorID)
	Blizzard_HousingCatalogUtil.TrackHousingDecorID(decorID);
end

---@param itemInfo ItemInfo
function Catalog.TrackDecorByItem(itemInfo)
	local decorID = internal.DecorUtil.GetDecorRecordIDByItem(itemInfo);
	Catalog.TrackDecorByID(decorID);
end

------------

local function OnCatalogEntryInteract(_, entry, buttonName, isDrag)
	if isDrag or not IsControlKeyDown() then
		return;
	end

	local data = entry:GetEntryData();
	if data.entryType ~= Enum.HousingCatalogEntryType.Decor then
		return;
	end

	local itemID = data.itemID;
	internal.ShoppingListUtil.AddItemToWishlistByItemID(itemID);

	PlaySound(SOUNDKIT.HOUSING_BLUEPRINTS_EXPORT_SUCCESS);

	local _, itemLink = C_Item.GetItemInfo(itemID);
	local msg = format("Added %s to your wishlist!", itemLink);
	internal.Print(msg);
end

EventRegistry:RegisterCallback("HousingCatalogEntry.OnInteract", OnCatalogEntryInteract);

local function OnCatalogEntryTooltipCreated(_, entry, tooltip)
	local data = entry:GetEntryData();
	if data.entryType ~= Enum.HousingCatalogEntryType.Decor then
		return;
	end

	local rightClickText = YELLOW_FONT_COLOR:WrapTextInColorCode("[Control+Click]");
	local line = internal.ThemeColor:WrapTextInColorCode(format("%s to add this item to your wishlist", rightClickText));
	GameTooltip_AddBodyLine(tooltip, line);
end

EventRegistry:RegisterCallback("HousingCatalogEntry.TooltipCreated", OnCatalogEntryTooltipCreated);
