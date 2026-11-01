-- PortFinder layout: Generic 16 channels (no real box)
-- by MisterCreators Custom MOCs
--
-- 16 plain fields for the channels CH1-CH16, two rows of eight.
-- Works with every receiver or module (Brick Bridge, 4in1, ...), for testing
-- channels without a box layout.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  body   = lcd.RGB(44, 46, 52),
  edge   = lcd.RGB(92, 96, 104),
  field  = lcd.RGB(64, 67, 74),
  fieldA = lcd.RGB(250, 130, 55),     -- MisterCreators orange
  rowTxt = lcd.RGB(150, 154, 160),
}

local COLS, ROWS = 8, 2
local FW, FH, GAP = 170, 190, 20        -- field size and gap (layout units)
local X0, Y0 = 30, 30
local W = X0 * 2 + COLS * FW + (COLS - 1) * GAP
local H = Y0 * 2 + ROWS * FH + (ROWS - 1) * GAP

local ports = {}
for i = 1, COLS * ROWS do
  local c = (i - 1) % COLS
  local r = math.floor((i - 1) / COLS)
  local x1 = X0 + c * (FW + GAP)
  local y1 = Y0 + r * (FH + GAP)
  ports[i] = {
    name = "Port " .. i, label = tostring(i), kind = "pf", ch = i,
    box = { x1, y1, x1 + FW, y1 + FH },
    hit = { x1 - GAP / 2, y1 - GAP / 2, x1 + FW + GAP / 2, y1 + FH + GAP / 2 },
    num = { x1 + FW / 2, y1 + FH / 2 }, align = "center", dy = 7,
  }
end

local function draw(g)
  g.R(0, 0, W, H, C.body)
  g.frame(0, 0, W, H, C.edge, 2)
end

local function drawPort(g, p, active)
  local b = p.box
  g.R(b[1], b[2], b[3], b[4], active and C.fieldA or C.field)
  g.frame(b[1], b[2], b[3], b[4], C.edge, 1)
end

return {
  id = "generic16",
  name = "Generic 16 CH",
  short = "Generic",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 0, y0 = 0, w = W, h = H,
  channels = 16,
  numbers = "channel",
  numColor = lcd.RGB(235, 236, 240),
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 90,
}
