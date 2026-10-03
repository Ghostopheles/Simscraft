# v1.1.0

## Added
- Added shopping lists
	- You can open the shopping list frame with `/sims` or `/simscraft`.
	- Shopping lists allow you to import a list of housing items from [housing.wowdb.com](https://housing.wowdb.com/), then keep track of any items you're missing.
	- Items on your shopping lists will have a special icon on them when you see them on a vendor.
	- You can also shift-click on items on your shopping list to track their source, if available.
	- By default you'll start with a wishlist. Still very much a WIP.
		- The wishlist might be horrendous to actually use because you have to add items one by one. I'm working on it.
		- Clicking the plus in the top right will open an editbox you can use to search for decor items. Navigate the search results with the arrow keys or the mouse.
- Added a button for editing the number of items in your shopping cart.
	- You can also use the up or down arrow keys while the quantity editbox is focused to change the quantity.

## Fixes
- Improved autobuy error handling
	- You will now be alerted when you don't have enough special currency to complete a purchase, or if you don't have enough bag space.
