---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftEnums
local Enums = {};
internal.Enums = Enums;

---@enum SimscraftPurchaseErrorType
Enums.PURCHASE_ERROR_TYPE = {
	MISSING_GOLD = 1,
	MISSING_CURRENCY = 2,
	MISSING_BAG_SPACE = 3
};

------------
