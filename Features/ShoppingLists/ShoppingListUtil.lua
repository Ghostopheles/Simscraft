---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

local function GetCurrentDate()
	local format = "%m/%d/%y";
	return date(format);
end

------------

--- shopping list import code format
--- creatureID1,creatureID2:itemID1-quantity,itemID2-quantity

---@class SimscraftShoppingListVendorTable
---@field ItemID number
---@field Quantity number

---@class SimscraftShoppingList
---@field Items table<number, number> maps itemID to quantity
---@field Name string Unique name
---@field ImportedAt string | osdate Date in which the list was first imported
---@field IsFulfilled boolean Whether or not the list is 'completed'

---@class SimscraftShoppingListUtil
local ShoppingListUtil = {};

---@param shoppingListStr string
---@param name string
local function ParseImportString(shoppingListStr, name)
	local list = {};

    local split = strsplittable(";", shoppingListStr);
    for _, entry in ipairs(split) do
        local _, iids = strsplit(":", entry); -- creature ids (ignored) and item ids

        -- parsing out itemIDs and quantities
        local items = strsplittable(",", iids);
        for _, itemEntry in ipairs(items) do
            local itemID, quantity = strsplit("-", itemEntry);
            list[itemID] = tonumber(quantity) or 1;
        end
    end

	local shoppingList = {
		Items = list,
		Name = name,
		ImportedAt = GetCurrentDate(),
		IsFulfilled = false
	};
	return shoppingList;
end

---@param shoppingListStr string
---@param name string
---@return SimscraftShoppingList?
function ShoppingListUtil.ParseShoppingListImport(shoppingListStr, name)
	local success, result = pcall(ParseImportString, shoppingListStr, name);
	if not success then
		internal.Print("An error occurred while importing this shopping list: " .. result);
		return;
	end
	return result;
end

---@param name string
---@return SimscraftShoppingList
function ShoppingListUtil.CreateShoppingList(name)
	local shoppingList = {
		Items = {},
		Name = name,
		ImportedAt = GetCurrentDate(),
		IsFulfilled = false
	};
	return shoppingList;
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
---@param amount number
function ShoppingListUtil.SetTargetItemQuantityByID(shoppingList, itemID, amount)
	shoppingList.Items[itemID] = amount;
end

---@param shoppingList SimscraftShoppingList
function ShoppingListUtil.AdjustTargetItemQuantityByID(shoppingList, itemID, amount)
	shoppingList.Items[itemID] = (shoppingList.Items[itemID] or 0) + amount;
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
function ShoppingListUtil.GetTargetItemQuantityByID(shoppingList, itemID)
	return shoppingList.Items[itemID] or 0;
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
function ShoppingListUtil.RemoveItemFromListByID(shoppingList, itemID)
	ShoppingListUtil.SetTargetItemQuantityByID(shoppingList, itemID, 0);
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
---@param quantity? number
function ShoppingListUtil.AddItemToListByID(shoppingList, itemID, quantity)
	quantity = quantity or 1;
	ShoppingListUtil.SetTargetItemQuantityByID(shoppingList, itemID, quantity);
end

------------

internal.ShoppingListUtil = ShoppingListUtil;
