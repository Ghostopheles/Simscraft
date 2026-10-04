---@class SimscraftInternal
local internal = select(2, ...);

local Events = internal.Events;
local Registry = internal.Registry;

------------

--- shopping list import code format
--- creatureID1,creatureID2:itemID1-quantity,itemID2-quantity

---@class SimscraftShoppingListItemEntry
---@field ItemID number
---@field Quantity number
---@field AddedAt number Timestamp at which the item was added to the shopping list
---@field OrderIndex number

---@class SimscraftShoppingList
---@field Items table<number, SimscraftShoppingListItemEntry> maps itemID to item entry
---@field Name string Unique name
---@field ImportedAt number Timestamp at which the list was first imported
---@field LastUpdatedAt number Timestsamp Timestamp for which the list was last updated
---@field IsFulfilled boolean Whether or not the list is 'completed'
---@field MaxOrderIndex number

---@class SimscraftShoppingListUtil
local ShoppingListUtil = {};

---@param shoppingListStr string
---@param name string
local function ParseImportString(shoppingListStr, name)
	local list = {};
	local lastOrderIndex = 0;

	local timestamp = time();

    local split = strsplittable(";", shoppingListStr);
    for _, entry in ipairs(split) do
        local _, iids = strsplit(":", entry); -- creature ids (ignored) and item ids

        -- parsing out itemIDs and quantities
        local items = strsplittable(",", iids);
        for _, itemEntry in ipairs(items) do
            local itemID, quantity = strsplit("-", itemEntry);
			itemID = tonumber(itemID);
            quantity = tonumber(quantity) or 1;


			if not list[itemID] then
				local orderIndex = lastOrderIndex + 1;
				list[itemID] = {
					ItemID = itemID,
					Quantity = quantity,
					AddedAt = timestamp,
					OrderIndex = orderIndex
				};
				lastOrderIndex = orderIndex;
			end
        end
    end

	local shoppingList = {
		Items = list,
		Name = name,
		ImportedAt = timestamp,
		LastUpdatedAt = timestamp,
		IsFulfilled = false,
		MaxOrderIndex = lastOrderIndex
	};
	return shoppingList;
end

local function CollapseOrderIndices(shoppingList, start)
	for _, entry in pairs(shoppingList.Items) do
		if entry.OrderIndex > start then
			entry.OrderIndex = entry.OrderIndex - 1;
		end
	end
end

local function UpdateLastUpdatedTimestamp(shoppingList)
	shoppingList.LastUpdatedAt = time();
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
	local timestamp = time();
	local shoppingList = {
		Items = {},
		Name = name,
		ImportedAt = timestamp,
		LastUpdatedAt = timestamp,
		IsFulfilled = false,
		MaxOrderIndex = 0
	};
	return shoppingList;
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
---@param quantity number
function ShoppingListUtil.SetTargetItemQuantityByID(shoppingList, itemID, quantity)
	if shoppingList.Items[itemID] then
		shoppingList.Items[itemID].Quantity = quantity;
		UpdateLastUpdatedTimestamp(shoppingList);
	end
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
---@param amount number
function ShoppingListUtil.AdjustTargetItemQuantityByID(shoppingList, itemID, amount)
	shoppingList.Items[itemID].Quantity = (shoppingList.Items[itemID].Quantity or 0) + amount;
	UpdateLastUpdatedTimestamp(shoppingList);
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
---@return number
function ShoppingListUtil.GetTargetItemQuantityByID(shoppingList, itemID)
	local entry = shoppingList.Items[itemID];
	if entry then
		return entry.Quantity or 0;
	end
	return 0;
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
function ShoppingListUtil.RemoveItemFromListByID(shoppingList, itemID)
	local entry = shoppingList.Items[itemID];
	local orderIndex = entry.OrderIndex;
	shoppingList.Items[itemID] = nil;

	shoppingList.MaxOrderIndex = shoppingList.MaxOrderIndex - 1;
	CollapseOrderIndices(shoppingList, orderIndex);
	UpdateLastUpdatedTimestamp(shoppingList);
end

---@param shoppingList SimscraftShoppingList
---@param itemID number
---@param quantity? number
function ShoppingListUtil.AddItemToListByID(shoppingList, itemID, quantity)
	quantity = quantity or 1;

	local entry = shoppingList.Items[itemID];
	if entry and entry.Quantity > 0 then
		ShoppingListUtil.AdjustTargetItemQuantityByID(shoppingList, itemID, quantity);
		return;
	end

	local orderIndex = shoppingList.MaxOrderIndex + 1;
	local newEntry = {
		ItemID = itemID,
		Quantity = quantity,
		AddedAt = time(),
		OrderIndex = orderIndex
	};
	shoppingList.MaxOrderIndex = orderIndex;
	shoppingList.Items[itemID] = newEntry;
	UpdateLastUpdatedTimestamp(shoppingList);
end

---@param shoppingList SimscraftShoppingList
function ShoppingListUtil.IsListFulfilled(shoppingList)
	for itemID, itemEntry in pairs(shoppingList.Items) do
		local _, totalStored = internal.DecorUtil.GetAmountOwnedByItem(itemID);
		if totalStored < itemEntry.Quantity then
			return false;
		end
	end

	return true;
end

---@param itemID number
function ShoppingListUtil.AddItemToWishlistByItemID(itemID)
	local wishlist = internal.ShoppingListManager.GetShoppingList(internal.Constants.WISHLIST_NAME);
	ShoppingListUtil.AddItemToListByID(wishlist, itemID);
	Registry:TriggerEvent(Events.SHOPPING_LIST_UPDATED, wishlist);
end

------------

internal.ShoppingListUtil = ShoppingListUtil;
