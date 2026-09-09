---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

local SEARCHER = C_HousingCatalog.CreateCatalogSearcher();
SEARCHER:SetResultsUpdatedCallback(function()
	Registry:TriggerEvent(Events.CATALOG_SEARCH_RESULTS_UPDATED);
end);

------------

---@class SimscraftCatalog
local Catalog = {};

function Catalog.SetSearchText(searchText)
	SEARCHER:SetSearchText(searchText);
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

------------

internal.Catalog = Catalog;
