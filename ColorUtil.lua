---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftColorUtil
local ColorUtil = {};

---@param r number
---@param g number
---@param b number
function ColorUtil.RGBtoHSV(r, g, b)
    local max = max(r, g, b);
    local min = min(r, g, b);
    local d = max - min;

    local h, s, v;
    v = max;

    if max == 0 then
        s = 0;
    else
        s = d / max;
    end

    if d == 0 then
        h = 0;
    else
        if max == r then
            h = ((g - b) / d) % 6;
        elseif max == g then
            h = ((b - r) / d) + 2;
        else
            h = ((r - g) / d) + 4;
        end
        h = h * 60;
    end

    return h, s, v;
end

------------

internal.ColorUtil = ColorUtil;