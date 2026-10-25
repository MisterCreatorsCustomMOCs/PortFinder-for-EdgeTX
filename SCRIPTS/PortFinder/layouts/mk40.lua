-- PortFinder layout: Mould King 4.0 (top view)
-- by MisterCreators Custom MOCs
--
-- Driven by a 4in1 multiprotocol module with the Mould King protocol:
-- ports A-D react to the next 4 channels. Up to 4 boxes.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  case    = lcd.RGB(222, 224, 228),
  rim     = lcd.RGB(176, 179, 184),
  stud    = lcd.RGB(196, 199, 204),
  studIn  = lcd.RGB(238, 239, 242),
  port    = lcd.RGB(150, 153, 158),
  portIn  = lcd.RGB(246, 247, 249),
  portAct = lcd.RGB(255, 236, 150),
  rail    = lcd.RGB(170, 173, 178),
  pin     = lcd.RGB(215, 175, 85),
  usb     = lcd.RGB(40, 40, 44),
  usbIn   = lcd.RGB(170, 172, 178),
  green   = lcd.RGB(40, 170, 100),
  greenHi = lcd.RGB(120, 220, 160),
  print   = lcd.RGB(150, 152, 158),
}

-- B top left, A bottom left, C top right, D bottom right
local POS = { A = { 78, 140 }, B = { 78, 55 }, C = { 308, 55 }, D = { 308, 140 } }
local LBL = { A = { 14, 176 }, B = { 14, 22 }, C = { 373, 22 }, D = { 373, 176 } }

-- studs that don't belong to a port
local STUDS = {
  { 168, 37 }, { 213, 37 }, { 168, 168 }, { 213, 168 },
}
-- the two studs of each port, next to it
local PSTUDS = {
  A = { { 122, 125 }, { 122, 168 } }, B = { { 122, 37 }, { 122, 80 } },
  C = { { 258, 37 }, { 258, 80 } }, D = { { 258, 125 }, { 258, 168 } },
}

local ports = {}
for i, l in ipairs({ "A", "B", "C", "D" }) do
  local cx, cy = POS[l][1], POS[l][2]
  ports[#ports + 1] = {
    name = "Port " .. l, label = l, kind = "pf", ch = i, cx = cx, cy = cy, studs = PSTUDS[l],
    hit = (cx < 194) and { cx - 40, cy - 40, 140, cy + 40 } or { 240, cy - 40, cx + 40, cy + 40 },
    num = LBL[l], align = "center", dy = 7,
  }
end

local function draw(g)
  g.R(4, 4, 384, 191, C.case)
  g.frame(4, 4, 384, 191, C.rim, 2)
  for _, s in ipairs(STUDS) do
    g.circle(s[1], s[2], 13, C.stud)
    g.circle(s[1], s[2], 9, C.studIn)
  end
  -- micro USB and green power button in the middle
  g.R(151, 91, 181, 109, C.usb)
  g.R(156, 96, 176, 104, C.usbIn)
  g.R(190, 82, 226, 118, C.green)
  g.R(197, 89, 219, 111, C.greenHi)
end

local function drawPort(g, p, active)
  local cx, cy = p.cx, p.cy
  for _, st in ipairs(p.studs) do
    g.circle(st[1], st[2], 13, C.stud)
    g.circle(st[1], st[2], 9, C.studIn)
  end
  g.R(cx - 24, cy - 30, cx + 24, cy + 30, C.port)
  g.R(cx - 20, cy - 26, cx + 20, cy + 26, active and C.portAct or C.portIn)
  g.R(cx - 30, cy - 12, cx - 24, cy + 12, C.port)
  g.R(cx + 24, cy - 12, cx + 30, cy + 12, C.port)
  -- two rails with 4 gold contacts, like the PF ports of the RC Box Mini
  g.R(cx - 12, cy - 21, cx - 7, cy + 21, C.rail)
  g.R(cx + 7, cy - 21, cx + 12, cy + 21, C.rail)
  g.R(cx - 7, cy - 13, cx - 3, cy - 7, C.pin)
  g.R(cx - 7, cy + 1, cx - 3, cy + 7, C.pin)
  g.R(cx + 3, cy - 7, cx + 7, cy - 1, C.pin)
  g.R(cx + 3, cy + 7, cx + 7, cy + 13, C.pin)
end

return {
  id = "mk40",
  name = "Mould King 4.0",
  short = "MK 4.0",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 0, y0 = 0, w = 388, h = 195,
  channels = 4,
  numbers = "label",
  numColor = lcd.RGB(120, 122, 128),
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 30,
  -- up to 4 MK 4.0 (Mould King protocol)
  extras = { { label = "MK 4.0", device = "mk40", max = 3 } },

}
