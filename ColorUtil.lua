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

local HUE_BANDS = {
    { name="Red",        min=0,   max=15  },
    { name="Red-Orange", min=15,  max=30  },
    { name="Orange",     min=30,  max=50  },
    { name="Yellow",     min=50,  max=70  },
    { name="Yellow-Green",min=70, max=100 },
    { name="Green",      min=100, max=150 },
    { name="Teal",       min=150, max=185 },
    { name="Cyan",       min=185, max=210 },
    { name="Blue",       min=210, max=255 },
    { name="Indigo",     min=255, max=285 },
    { name="Violet",     min=285, max=320 },
    { name="Magenta",    min=320, max=345 },
    { name="Red",        min=345, max=360 },
};

function ColorUtil.GetHueBand(h)
    if not h then
        return 1;
    end
    for i, band in ipairs(HUE_BANDS) do
        if h >= band.min and h < band.max then
            return i;
        end
    end
    return 1;
end

------------

internal.ColorUtil = ColorUtil;