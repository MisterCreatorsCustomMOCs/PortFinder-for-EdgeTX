-- PortFinder layout: LEGO City / Powered Up Hub 88009 (top view, lying on its side)
-- by MisterCreators Custom MOCs
--
-- Two Powered Up ports A and B on the same end = the next 2 channels.
-- Used with the MC Brick Bridge (internal CRSF module), see Brick Connect.
-- Up to 8 City Hubs per model through the bridge.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  body     = lcd.RGB(160, 165, 170),
  bodyEdge = lcd.RGB(190, 194, 198),
  stud     = lcd.RGB(175, 180, 185),
  studHi   = lcd.RGB(200, 204, 208),
  dark     = lcd.RGB(88, 92, 98),
  shadow   = lcd.RGB(30, 31, 34),
  sock     = lcd.RGB(52, 54, 58),
  slot     = lcd.RGB(24, 25, 27),
  slotAct  = lcd.RGB(255, 210, 90),
  btn      = lcd.RGB(40, 42, 46),
  led      = lcd.RGB(90, 200, 120),
}

-- port positions (layout units): socket box x1, y1, x2, y2
-- turned by 90 degrees: the end with the ports is on the left
local POS = {
  { "A", 8, 30, 108, 140 },     -- port end, top
  { "B", 8, 170, 108, 280 },    -- port end, bottom
}

local ports = {}
for i, p in ipairs(POS) do
  local b = { p[2], p[3], p[4], p[5] }
  ports[#ports + 1] = { name = "Port " .. p[1], label = p[1], kind = "pu", ch = i, box = b,
    hit = { 0, b[2] - 12, 200, b[4] + 12 },
    num = { (b[1] + b[3]) / 2, (b[2] + b[4]) / 2 }, align = "center", dy = 7 }
end

local function draw(g)
  g.R(100, 10, 560, 300, C.body)
  g.frame(100, 10, 560, 300, C.bodyEdge, 2)
  g.R(100, 10, 124, 300, C.dark)
  for _, p in ipairs(ports) do
    g.text(150, (p.box[2] + p.box[4]) / 2 - 10, p.label, CENTER + C.dark)
  end
  -- button with status light
  g.circle(300, 155, 70, C.dark)
  g.circle(300, 155, 56, C.btn)
  g.circle(300, 155, 14, C.led)
  -- studs on the far end
  for _, x in ipairs({ 430, 500 }) do
    for y = 50, 270, 55 do
      g.circle(x, y, 22, C.stud)
      g.circle(x - 3, y - 3, 13, C.studHi)
    end
  end
end

local function drawPort(g, p, active)
  local b = p.box
  g.R(b[1] + 5, b[2] + 5, b[3] + 5, b[4] + 5, C.shadow)
  g.R(b[1], b[2], b[3], b[4], C.sock)
  g.R(b[1] + 12, b[2] + 12, b[3] - 12, b[4] - 12, active and C.slotAct or C.slot)
end

return {
  id = "cityhub",
  name = "LEGO City Hub",
  short = "City Hub",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 0, y0 = 0, w = 570, h = 310,
  channels = 2,
  numbers = "channel",
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 75,
  -- PortFinder shows up to 4 boxes without the bridge (8 with the bridge)
  extras = { { label = "City Hub", device = "cityhub", max = 3 } },
}
