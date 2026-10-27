-- PortFinder layout: BuWizz 3.0 (top view, lying on its side)
-- by MisterCreators Custom MOCs
--
-- Turned by 90 degrees, so the four Powered Up ports are in the same corners as
-- on the RC Box Mini and the BuWizz 2.0: 1 top left, 2 bottom left,
-- 3 bottom right, 4 top right. The two Power Functions ports 5 and 6 are in
-- the middle. Channels: ports 1-6 = the next 6 channels.
-- Used with the MC Brick Bridge (internal CRSF module), see Brick Connect.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  case     = lcd.RGB(60, 62, 59),
  caseEdge = lcd.RGB(88, 90, 86),
  raised   = lcd.RGB(70, 72, 68),
  shadow   = lcd.RGB(34, 35, 33),
  hi       = lcd.RGB(98, 100, 95),
  studHi   = lcd.RGB(92, 94, 90),
  engTxt   = lcd.RGB(25, 26, 25),
  pin      = lcd.RGB(225, 195, 130),
  window   = lcd.RGB(16, 16, 16),
  usb      = lcd.RGB(150, 152, 156),
  button   = lcd.RGB(30, 30, 30),
  puRed    = lcd.RGB(190, 60, 60),
  puIn     = lcd.RGB(235, 130, 130),
  puAct    = lcd.RGB(255, 236, 150),
  puDark   = lcd.RGB(120, 30, 30),
}

-- studs (layout units = pixels of the turned photo)
local STUDS = {
  { 112, 215 }, { 175, 215 }, { 238, 215 }, { 297, 215 }, { 355, 215 }, { 415, 215 }, { 476, 215 },
  { 112, 50 }, { 175, 50 }, { 238, 50 }, { 355, 50 }, { 415, 50 }, { 476, 50 },
  { 238, 159 }, { 238, 107 }, { 355, 159 }, { 355, 107 },
}

-- Powered Up ports 1-4
local PU = {
  { box = { 20, 29, 86, 115 }, hit = { 12, 20, 96, 124 } },     -- 1 top left
  { box = { 20, 145, 86, 229 }, hit = { 12, 136, 96, 238 } },   -- 2 bottom left
  { box = { 504, 145, 570, 229 }, hit = { 496, 136, 580, 238 } }, -- 3 bottom right
  { box = { 504, 29, 570, 115 }, hit = { 496, 20, 580, 124 } },   -- 4 top right
}

-- Power Functions ports 5 (left) and 6 (right)
local PF = {
  { raised = { { 150, 92, 160, 178 }, { 128, 106, 150, 116 }, { 128, 154, 150, 164 }, { 184, 92, 196, 178 } },
    pins = { { 156, 122 }, { 156, 148 }, { 188, 112 }, { 188, 158 } },
    num = { 172, 135 }, hit = { 118, 84, 208, 186 } },
  { raised = { { 386, 92, 398, 178 }, { 420, 92, 430, 178 }, { 430, 106, 452, 116 }, { 430, 154, 452, 164 } },
    pins = { { 392, 112 }, { 392, 158 }, { 424, 122 }, { 424, 148 } },
    num = { 409, 135 }, hit = { 376, 84, 462, 186 } },
}

local ports = {}
for i = 1, 4 do
  local p = PU[i]
  local b = p.box
  ports[#ports + 1] = { name = "PU " .. i, label = tostring(i), kind = "pu", ch = i, box = b,
    hit = p.hit, num = { (b[1] + b[3]) / 2, (b[2] + b[4]) / 2 }, align = "center", dy = 7 }
end
for i = 1, 2 do
  local p = PF[i]
  ports[#ports + 1] = { name = "PF " .. (4 + i), label = tostring(4 + i), kind = "pf", ch = 4 + i,
    geo = p, hit = p.hit, num = p.num, align = "center", dy = 7 }
end

local function draw(g)
  g.R(12, 12, 584, 236, C.case)
  g.frame(12, 12, 584, 236, C.caseEdge)
  for _, s in ipairs(STUDS) do
    local r = 22
    g.circle(s[1] + 5, s[2] + 5, r, C.shadow)
    g.circle(s[1], s[2], r, C.raised)
    g.circle(s[1] - 4, s[2] - 4, r * 0.55, C.studHi)
    g.circle(s[1], s[2], r * 0.55, C.raised)
  end
  -- port numbers printed on the housing
  for _, e in ipairs({ { "1", 112, 84 }, { "2", 112, 168 }, { "3", 476, 168 }, { "4", 476, 84 } }) do
    lcd.drawText(g.PX(e[2]), g.PY(e[3]), e[1], CENTER + SMLSIZE + C.engTxt)
  end
  -- USB-C and power button
  g.R(285, 105, 312, 154, C.window)
  g.R(288, 115, 309, 144, C.usb)
  g.circle(297, 50, 18, C.window)
  g.circle(297, 50, 11, C.button)
end

local function drawPort(g, p, active)
  if p.kind == "pu" then
    local b = p.box
    g.R(b[1] + 4, b[2] + 4, b[3] + 4, b[4] + 4, C.shadow)
    g.R(b[1], b[2], b[3], b[4], C.puRed)
    g.R(b[1] + 8, b[2] + 8, b[3] - 8, b[4] - 8, active and C.puAct or C.puIn)
    g.R(b[1] + 16, b[2] + 18, b[3] - 16, b[2] + 26, C.puDark)
    g.R(b[1] + 16, b[4] - 26, b[3] - 16, b[4] - 18, C.puDark)
  else
    for _, r in ipairs(p.geo.raised) do g.raised(r, C.raised, C.shadow, C.hi, 4) end
    for _, pp in ipairs(p.geo.pins) do g.pin(pp[1], pp[2], 4, C.pin) end
  end
end

return {
  id = "buwizz3",
  name = "BuWizz 3.0",
  short = "BuWizz 3.0",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 8, y0 = 8, w = 580, h = 232,
  channels = 6,
  numbers = "channel",
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 40,
  -- up to 2 BuWizz 3.0 plus 1 BuWizz 2.0 (16 channels)
  extras = {
    { label = "+ 3.0", device = "buwizz3", max = 1 },
    { label = "+ 2.0", device = "buwizz2", max = 1 },
  },
}
