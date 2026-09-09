---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftDecorUtil
local DecorUtil = {};

---@param itemInfo ItemInfo
function DecorUtil.GetAmountOwnedByItem(itemInfo)
	local entryInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(itemInfo);
	if entryInfo then
		local stored = entryInfo.totalNumStored;
		local placed = entryInfo.totalNumPlaced;
		local total = stored + placed;
		return total, stored, placed;
	end
	return 0, 0, 0;
end

---@param itemInfo ItemInfo
function DecorUtil.GetDecorRecordIDByItem(itemInfo)
	local entryInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(itemInfo);
	if entryInfo then
		return entryInfo.recordID;
	end
end

------------

internal.DecorUtil = DecorUtil;
