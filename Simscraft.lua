local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

internal.ThemeColor = CreateColorFromHexString("ffa6e329");

---@param msg string
function internal.Print(msg)
    local prefix = internal.ThemeColor:WrapTextInColorCode(addonName) .. ": ";
    print(prefix .. msg);
end

function internal.AddTooltip(object, anchor, gateFunc)
    object:HookScript("OnEnter", function()
		if gateFunc and (not gateFunc()) then
			return;
		end
        if object.tooltipText then
            GameTooltip:SetOwner(object, anchor or "ANCHOR_RIGHT");
            GameTooltip:SetText(object.tooltipText);
            GameTooltip:Show();
        end
    end);

    object:HookScript("OnLeave", function()
        if GameTooltip:IsOwned(object) then
            GameTooltip:Hide();
        end
    end);
end

---@param timeout number
---@param callback function
---@return function
function internal.Debounce(timeout, callback)
    local calls = 0;

	local function Decrement()
		calls = calls - 1;

		if calls == 0 then
			callback();
		end
	end

	return function()
		C_Timer.After(timeout, Decrement);
		calls = calls + 1;
	end
end

SLASH_SIMSCRAFT1, SLASH_SIMSCRAFT2 = "/simscraft", "/sims";
function SlashCmdList.SIMSCRAFT(msg)
	internal.ShoppingListManager.ToggleManagerFrame();
end
