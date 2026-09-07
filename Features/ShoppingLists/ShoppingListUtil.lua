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

---@class SimscraftShoppingList
---@field RawList table<number, {ItemID: number, Quantity: number}[]> maps creatureID to list of itemIDs and quantities
---@field Vendors table<number, number[]> maps creatureID to list of itemIDs
---@field Items table<number, number> maps itemID to quantity
---@field Name string Unique name
---@field ImportedAt string Date in which the list was first imported

---@class SimscraftShoppingListUtil
local ShoppingListUtil = {};

---@param shoppingListStr string
---@return SimscraftShoppingList
function ShoppingListUtil.ParseShoppingListImport(shoppingListStr, name)
    local list = {};

    local split = strsplittable(";", shoppingListStr);
    for _, entry in ipairs(split) do
        local cids, iids = strsplit(":", entry); -- creature ids and item ids

        -- parsing out itemIDs and quantities
        local allItems = {};
        local items = strsplittable(",", iids);
        for _, itemEntry in ipairs(items) do
            local itemID, quantity = strsplit("-", itemEntry);
            local item = {
                ItemID = tonumber(itemID),
                Quantity = tonumber(quantity)
            };
            tinsert(allItems, item);
        end

        -- parsing out creature IDs
        local creatures = strsplittable(",", cids);
        for _, creature in ipairs(creatures) do
            local cid = tonumber(creature);
            assert(cid, "Invalid shopping list creatureID");
            list[cid] = allItems;
        end
    end

	local shoppingList = {
		RawList = list,
		Vendors = {},
		Items = {},
		Name = name,
		ImportedAt = GetCurrentDate(),
	};
	ShoppingListUtil.UpdateFromRawList(shoppingList);
	return shoppingList;
end

function ShoppingListUtil.UpdateFromRawList(shoppingList)
	shoppingList.Vendors = {};
	shoppingList.Items = {};

	for cid, items in pairs(shoppingList.RawList) do
        local vendor = {};

        for i, item in ipairs(items) do
            if not shoppingList.Items[item.ItemID] and item.Quantity > 0 then
                shoppingList.Items[item.ItemID] = item.Quantity;
            end
            tinsert(vendor, item.ItemID);
        end

        shoppingList.Vendors[cid] = vendor;
    end

	return shoppingList;
end

function ShoppingListUtil.CreateShoppingListFromRawList(rawList, name)
	local shoppingList = {
		RawList = rawList,
		Vendors = {},
		Items = {},
		Name = name
	};
	ShoppingListUtil.UpdateFromRawList(shoppingList);
	return shoppingList;
end

function ShoppingListUtil.SetTargetItemQuantityByID(shoppingList, itemID, amount)
	local raw = shoppingList.RawList;
	for _, items in ipairs(raw) do
		for _, itemEntry in ipairs(items) do
			if itemEntry.ItemID == itemID then
				itemEntry.Quantity = amount;
			end
		end
	end
	ShoppingListUtil.UpdateFromRawList(shoppingList);
end

function ShoppingListUtil.AdjustTargetItemQuantityByID(shoppingList, itemID, amount)
	local raw = shoppingList.RawList;
	for _, items in ipairs(raw) do
		for _, itemEntry in ipairs(items) do
			if itemEntry.ItemID == itemID then
				itemEntry.Quantity = itemEntry.Quantity + amount;
			end
		end
	end
	ShoppingListUtil.UpdateFromRawList(shoppingList);
end

function ShoppingListUtil.GetTargetItemQuantityByID(shoppingList, itemID)
	local raw = shoppingList.RawList;
	for _, items in ipairs(raw) do
		for _, itemEntry in ipairs(items) do
			if itemEntry.ItemID == itemID then
				return itemEntry.Quantity;
			end
		end
	end
	ShoppingListUtil.UpdateFromRawList(shoppingList);
end

function ShoppingListUtil.RemoveItemFromListByID(shoppingList, itemID)
	ShoppingListUtil.SetTargetItemQuantityByID(shoppingList, itemID, 0);
	shoppingList.Items[itemID] = nil;
end

function ShoppingListUtil.GetItemsForVendor(shoppingList, creatureID)
	return shoppingList.Vendors[creatureID];
end

function ShoppingListUtil.IsVendorInShoppingList(shoppingList, creatureID)
	return ShoppingListUtil.GetItemsForVendor(shoppingList, creatureID) ~= nil;
end

function ShoppingListUtil.UpdateVendors(shoppingList)
	local newVendors = {};
    for vendor, items in pairs(shoppingList.Vendors) do
        local newItems = {};
        for _, itemID in ipairs(items) do
            if ShoppingListUtil.GetTargetItemQuantityByID(shoppingList, itemID) > 0 then
                tinsert(newItems, itemID);
            end
        end
        newVendors[vendor] = newItems;
    end

    if #newVendors == 0 then
        newVendors = nil;
    end

    shoppingList.Vendors = newVendors;
end

------------

internal.ShoppingListUtil = ShoppingListUtil;
