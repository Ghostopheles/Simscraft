if not SimscraftShoppingLists then
	return;
end

-- purge old shopping lists from alpha version
for name, list in pairs(SimscraftShoppingLists) do
	if list.RawList then
		SimscraftShoppingLists[name] = nil;
	end
end
