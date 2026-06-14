local addonName = ...;

---@class SimscraftInternal
local internal = select(2, ...);

internal.ThemeColor = CreateColorFromHexString("ffa6e329");

---@param msg string
function internal.Print(msg)
    local prefix = internal.ThemeColor:WrapTextInColorCode(addonName) .. ": ";
    print(prefix .. msg);
end

function internal.AddTooltip(object, anchor)
    object:HookScript("OnEnter", function()
        if object.tooltipText then
            GameTooltip:SetOwner(object, anchor or "ANCHOR_TOPLEFT");
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
