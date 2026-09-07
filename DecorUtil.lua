---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftDecorUtil
local DecorUtil = {};

function DecorUtil.GetAmountOwnedByItemID(itemID)
	local entryInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID);
	if entryInfo then
		local stored = entryInfo.totalNumStored;
		local placed = entryInfo.totalNumPlaced;
		local total = stored + placed;
		return total, stored, placed;
	end
	return 0, 0, 0;
end

------------

internal.DecorUtil = DecorUtil;
