-- PortFinder layout: RC Box Mini (top view)
-- by MisterCreators Custom MOCs
--
-- Layout format (see README.md):
--   id, name, short, author, version
--   x0, y0, w, h   area of the box in layout units (here: pixels of a photo)
--   channels       channels used by one box
--   numbers        "channel" = show the channel number, "label" = show port.label
--   numColor       colour of the port numbers (optional)
--   ports          { name, label, kind, ch (1..channels), hit = {x1,y1,x2,y2},
--                    num = {x,y}, align = "center"|"left", dx, dy }
--   draw(g)        draws the box, g has helpers in layout units (see PortFinder.lua)
--   drawPort(g, port, active)   draws one port (optional)
--   order          position in the box list
--   extras         extra boxes switched on in the title bar:
--                  { label, device = layout id, max = how many } (max > 1 shows a counter)
--   titles         names of the boxes when several of the same box are used (optional)

local C = {
  case     = lcd.RGB(60, 62, 59),
  caseEdge = lcd.RGB(88, 90, 86),
  raised   = lcd.RGB(70, 72, 68),
  shadow   = lcd.RGB(34, 35, 33),
  hi       = lcd.RGB(98, 100, 95),
  engrave  = lcd.RGB(38, 39, 37),
  engTxt   = lcd.RGB(25, 26, 25),
  pin      = lcd.RGB(225, 195, 130),
  window   = lcd.RGB(16, 16, 16),
  housing  = lcd.RGB(44, 45, 44),
  housAct  = lcd.RGB(120, 90, 0),
  xt30     = lcd.RGB(245, 175, 30),
  xt30Side = lcd.RGB(200, 135, 15),
  xt30In   = lcd.RGB(225, 150, 20),
  gold     = lcd.RGB(205, 145, 50),
  goldHi   = lcd.RGB(240, 200, 120),
}

-- PF ports: PF1 top left, PF2 bottom left, PF3 bottom right, PF4 top right
local PF = {
  { side = { 20, 195, 75, 610 }, outer = { 70, 115, 165, 720 }, inner = { 320, 140, 390, 705 },
    pins = { { 158, 320 }, { 158, 445 }, { 328, 385 }, { 328, 505 } },
    label = { 243, 420 }, hit = { 20, 100, 410, 730 } },
  { side = { 20, 1015, 75, 1415 }, outer = { 70, 905, 165, 1520 }, inner = { 325, 920, 395, 1505 },
    pins = { { 160, 1115 }, { 160, 1245 }, { 330, 1175 }, { 330, 1305 } },
    label = { 245, 1210 }, hit = { 20, 890, 410, 1530 } },
  { side = { 1895, 965, 1980, 1365 }, outer = { 1810, 860, 1900, 1475 }, inner = { 1600, 875, 1670, 1475 },
    pins = { { 1665, 1075 }, { 1665, 1195 }, { 1830, 1130 }, { 1830, 1255 } },
    label = { 1740, 1165 }, hit = { 1590, 850, 1980, 1490 } },
  { side = { 1885, 190, 1980, 610 }, outer = { 1795, 85, 1890, 680 }, inner = { 1580, 110, 1650, 685 },
    pins = { { 1645, 290 }, { 1645, 410 }, { 1805, 345 }, { 1805, 465 } },
    label = { 1722, 380 }, hit = { 1570, 75, 1980, 695 } },
}

local CROSSES = {
  { 590, 215 }, { 590, 600 }, { 600, 1000 }, { 605, 1395 },
  { 1385, 195 }, { 1390, 590 }, { 1405, 975 }, { 1410, 1385 },
}

local SERVO_ROWS = { 1055, 1185, 1310, 1440 }

local ports = {}
for i = 1, 4 do
  local p = PF[i]
  ports[#ports + 1] = { name = "PF " .. i, label = tostring(i), kind = "pf", ch = i, geo = p,
    hit = p.hit, num = p.label, align = "center", dy = 7 }
end
for i = 1, 4 do
  local cy = SERVO_ROWS[i]
  ports[#ports + 1] = { name = "Servo " .. (4 + i), label = tostring(4 + i), kind = "servo", ch = 4 + i,
    cy = cy, hit = { 805, cy - 62, 1360, cy + 62 }, num = { 1192, cy }, align = "left", dx = 2, dy = 10 }
end

local function raised(g, r) g.raised(r, C.raised, C.shadow, C.hi) end

local function draw(g)
  -- housing
  g.R(20, 20, 1980, 1600, C.case)
  g.frame(20, 20, 1980, 1600, C.caseEdge)

  -- raised Technic crosses
  local a, t, sh = 125, 40, 14
  for _, c in ipairs(CROSSES) do
    local cx, cy = c[1], c[2]
    g.R(cx - a + sh, cy - t + sh, cx + a + sh, cy + t + sh, C.shadow)
    g.R(cx - t + sh, cy - a + sh, cx + t + sh, cy + a + sh, C.shadow)
  end
  for _, c in ipairs(CROSSES) do
    local cx, cy = c[1], c[2]
    g.R(cx - a, cy - t, cx + a, cy + t, C.raised)
    g.R(cx - t, cy - a, cx + t, cy + a, C.raised)
    g.line(cx - t, cy - a, cx + t, cy - a, C.hi)
    g.line(cx - t, cy - a, cx - t, cy - t, C.hi)
    g.line(cx - a, cy - t, cx - t, cy - t, C.hi)
    g.line(cx + t, cy - t, cx + a, cy - t, C.hi)
    g.line(cx - a, cy - t, cx - a, cy + t, C.hi)
    g.line(cx - t, cy + t, cx - t, cy + a, C.hi)
  end

  -- small engraved cross below the XT30
  g.R(940, 709, 1070, 721, C.engrave)
  g.R(999, 650, 1011, 780, C.engrave)

  -- XT30 main power
  g.R(840, 90, 1140, 640, C.shadow)
  g.R(825, 75, 1125, 625, C.xt30)
  g.R(1105, 195, 1130, 610, C.xt30Side)
  g.chamfer(825, 75, 75, 1, C.case)
  g.chamfer(1125, 75, 75, 2, C.case)
  g.R(875, 115, 1080, 580, C.xt30In)
  g.chamfer(875, 115, 45, 1, C.xt30)
  g.chamfer(1080, 115, 45, 2, C.xt30)
  g.circle(980, 245, 58, C.gold)
  g.circle(980, 490, 58, C.gold)
  g.circle(970, 232, 22, C.goldHi)
  g.circle(970, 477, 22, C.goldHi)

  -- servo header labels and window
  lcd.drawText(g.PX(870), g.PY(915) - 7, "SGN", CENTER + SMLSIZE + C.engTxt)
  lcd.drawText(g.PX(1135), g.PY(915) - 7, "GND", CENTER + SMLSIZE + C.engTxt)
  g.R(805, 955, 1215, 1600, C.window)
end

local function drawPort(g, p, active)
  if p.kind == "pf" then
    local geo = p.geo
    raised(g, geo.side)
    raised(g, geo.outer)
    raised(g, geo.inner)
    for _, pp in ipairs(geo.pins) do g.pin(pp[1], pp[2], 13, C.pin) end
  else
    local cy = p.cy
    local hc = active and C.housAct or C.housing
    g.R(835, cy - 55, 1065, cy + 55, hc)
    g.R(1078, cy - 55, 1192, cy + 55, hc)
    g.pin(885, cy, 16, C.pin)
    g.pin(1005, cy, 16, C.pin)
    g.pin(1125, cy, 16, C.pin)
  end
end

return {
  id = "rcboxmini",
  name = "RC Box Mini",
  short = "RC Box Mini",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 20, y0 = 20, w = 1960, h = 1580,
  channels = 8,
  numbers = "channel",
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 10,
  -- the "Slave Box" switch adds a second RC Box Mini on CH9-16
  extras = { { label = "Slave Box", device = "rcboxmini", max = 1 } },
  titles = { "Master", "Slave" },
}
