-- PortFinder layout: Mould King 6.0 (top view, simplified)
-- by MisterCreators Custom MOCs
--
-- Driven by a 4in1 multiprotocol module with the Mould King protocol:
-- ports A-F react to the channels 1-6. Further boxes follow on the next channels.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  case    = lcd.RGB(58, 60, 66),
  rim     = lcd.RGB(92, 96, 104),
  panel   = lcd.RGB(42, 44, 48),
  hole    = lcd.RGB(28, 29, 32),
  housing = lcd.RGB(24, 24, 26),
  housEdg = lcd.RGB(88, 92, 100),
  housAct = lcd.RGB(120, 90, 0),
  pin     = lcd.RGB(225, 195, 130),
  button  = lcd.RGB(12, 12, 14),
  btnRing = lcd.RGB(110, 114, 120),
  usb     = lcd.RGB(160, 162, 168),
  usbIn   = lcd.RGB(30, 30, 34),
  stud    = lcd.RGB(84, 88, 96),
  studIn  = lcd.RGB(62, 65, 72),
}

-- port columns and rows; top row B D F, bottom row A C E
local COLS = { 430, 760, 1090 }
local TOP_Y, BOT_Y = 185, 650           -- connector centres
local TOP_S, BOT_S = 330, 505           -- stud rows, towards the middle of the box
local STUD_DX = 85
local POS = {
  A = { COLS[1], BOT_Y }, B = { COLS[1], TOP_Y }, C = { COLS[2], BOT_Y },
  D = { COLS[2], TOP_Y }, E = { COLS[3], BOT_Y }, F = { COLS[3], TOP_Y },
}

local ports = {}
for i, l in ipairs({ "A", "B", "C", "D", "E", "F" }) do
  local cx, cy = POS[l][1], POS[l][2]
  local top = cy < 400
  local sy = top and TOP_S or BOT_S
  ports[#ports + 1] = {
    name = "Port " .. l, label = l, kind = "pf", ch = i, cx = cx, cy = cy,
    studs = { { cx - STUD_DX, sy }, { cx + STUD_DX, sy } },
    hit = top and { cx - 150, 45, cx + 150, 395 } or { cx - 150, 440, cx + 150, 805 },
    num = top and { cx, 82 } or { cx, 772 }, align = "center", dy = 7,
  }
end

local function draw(g)
  g.R(0, 0, 1509, 849, C.case)
  g.frame(0, 0, 1509, 849, C.rim, 2)
  g.R(60, 40, 1449, 809, C.panel)
  for _, h in ipairs({ { 255, 80 }, { 1265, 80 }, { 255, 770 }, { 1265, 770 } }) do
    g.circle(h[1], h[2], 20, C.hole)
  end
  -- power button and micro USB on the left
  g.circle(170, 290, 56, C.btnRing)
  g.circle(170, 290, 42, C.button)
  g.R(146, 470, 194, 630, C.usb)
  g.R(158, 486, 182, 614, C.usbIn)
end

local function drawPort(g, p, active)
  local cx, cy = p.cx, p.cy
  for _, st in ipairs(p.studs) do
    g.circle(st[1], st[2], 50, C.stud)
    g.circle(st[1], st[2], 36, C.studIn)
  end
  g.R(cx - 120, cy - 70, cx + 120, cy + 70, C.housEdg)
  g.R(cx - 112, cy - 62, cx + 112, cy + 62, active and C.housAct or C.housing)
  for _, dy in ipairs({ -28, 28 }) do
    for _, dx in ipairs({ -60, 0, 60 }) do
      g.pin(cx + dx, cy + dy, 14, C.pin)
    end
  end
end

return {
  id = "mk60",
  name = "Mould King 6.0",
  short = "MK 6.0",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 0, y0 = 0, w = 1509, h = 849,
  channels = 6,
  numbers = "label",
  numColor = lcd.RGB(225, 226, 230),
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 20,
  -- up to 2 MK 6.0 plus 1 MK 4.0 (Mould King protocol)
  extras = {
    { label = "+ MK 6.0", device = "mk60", max = 1 },
    { label = "+ MK 4.0", device = "mk40", max = 1 },
  },

}
