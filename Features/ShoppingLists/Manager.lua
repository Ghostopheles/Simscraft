---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftShoppingListManager
local Manager = {};
internal.ShoppingListManager = Manager;

------------

if not SimscraftShoppingLists then
    SimscraftShoppingLists = {};
end

function Manager:AddShoppingList(name, shoppingList)
    if SimscraftShoppingLists[name] then
        error(("A shopping list with the name '%s' already exists."):format(name));
    end

    SimscraftShoppingLists[name] = shoppingList;
end

function Manager:RemoveShoppingList(name)
    SimscraftShoppingLists[name] = nil;
end

function Manager:GetShoppingLists()
    return SimscraftShoppingLists;
end

------------

SimscraftShoppingListManagerFrameMixin = {};

function SimscraftShoppingListManagerFrameMixin:OnLoad()
    ButtonFrameTemplate_HidePortrait(self);
end
