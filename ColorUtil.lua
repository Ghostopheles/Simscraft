---@class SimscraftInternal
local internal = select(2, ...);

---@class SimscraftColorUtil
local ColorUtil = {};

---@param r number
---@param g number
---@param b number
function ColorUtil.RGBtoHSV(r, g, b)
    local max = math.max(r, g, b);
    local min = math.min(r, g, b);
    local delta = max - min;

    local h, s, v;

    v = max;
    s = (max == 0) and 0 or (delta / max);

    if delta == 0 then
        h = 0;
    elseif max == r then
        h = 60 * (((g - b) / delta) % 6);
    elseif max == g then
        h = 60 * (((b - r) / delta) + 2);
    else
        h = 60 * (((r - g) / delta) + 4);
    end

    return h, s, v;
end

------------

internal.ColorUtil = ColorUtil;