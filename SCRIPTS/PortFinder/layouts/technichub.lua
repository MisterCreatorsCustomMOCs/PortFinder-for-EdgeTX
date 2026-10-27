-- PortFinder layout: LEGO Technic Hub 88012 (Control+), top view
-- by MisterCreators Custom MOCs
--
-- Four Powered Up ports A-D = the next 4 channels.
-- Used with the MC Brick Bridge (internal CRSF module), see Brick Connect.
-- Ports with an encoder motor can be switched to servo mode in Brick Connect.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  body     = lcd.RGB(160, 165, 170),   -- light bluish grey
  bodyEdge = lcd.RGB(190, 194, 198),
  dark     = lcd.RGB(88, 92, 98),      -- dark bluish grey
  hole     = lcd.RGB(60, 63, 68),
  shadow   = lcd.RGB(30, 31, 34),
  sock     = lcd.RGB(52, 54, 58),
  slot     = lcd.RGB(24, 25, 27),
  slotAct  = lcd.RGB(255, 210, 90),
  btn      = lcd.RGB(60, 160, 70),
  btnHi    = lcd.RGB(120, 210, 120),
  engTxt   = lcd.RGB(60, 63, 68),
}

-- port positions (layout units): socket box x1, y1, x2, y2
-- change here if the letters on your hub are in other places
local POS = {
  { "A", 8, 60, 88, 170 },      -- left end, top
  { "B", 8, 210, 88, 320 },     -- left end, bottom
  { "C", 612, 60, 692, 170 },   -- right end, top
  { "D", 612, 210, 692, 320 },  -- right end, bottom
}

local ports = {}
for i, p in ipairs(POS) do
  local b = { p[2], p[3], p[4], p[5] }
  local left = b[1] < 350
  ports[#ports + 1] = { name = "Port " .. p[1], label = p[1], kind = "pu", ch = i, box = b,
    hit = left and { 0, b[2] - 14, 190, b[4] + 14 } or { 510, b[2] - 14, 700, b[4] + 14 },
    num = { (b[1] + b[3]) / 2, (b[2] + b[4]) / 2 }, align = "center", dy = 7,
    tx = left and 125 or 575, ty = (b[2] + b[4]) / 2 - 10 }
end

local function draw(g)
  g.R(80, 20, 620, 360, C.body)
  g.frame(80, 20, 620, 360, C.bodyEdge, 2)
  -- dark ends and Technic pin holes along both long sides
  g.R(80, 20, 150, 360, C.dark)
  g.R(550, 20, 620, 360, C.dark)
  for x = 190, 510, 40 do
    g.circle(x, 48, 13, C.hole)
    g.circle(x, 332, 13, C.hole)
  end
  -- green button with light ring
  g.circle(350, 190, 52, C.btnHi)
  g.circle(350, 190, 40, C.btn)
  -- port letters
  for _, p in ipairs(ports) do
    g.text(p.tx, p.ty, p.label, CENTER + C.bodyEdge)
  end
end

local function drawPort(g, p, active)
  local b = p.box
  g.R(b[1] + 5, b[2] + 5, b[3] + 5, b[4] + 5, C.shadow)
  g.R(b[1], b[2], b[3], b[4], C.sock)
  g.R(b[1] + 12, b[2] + 12, b[3] - 12, b[4] - 12, active and C.slotAct or C.slot)
end

return {
  id = "technichub",
  name = "LEGO Technic Hub",
  short = "Technic Hub",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 0, y0 = 10, w = 700, h = 360,
  channels = 4,
  numbers = "channel",
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 70,
  -- up to 4 Technic Hubs (16 channels)
  extras = { { label = "Technic", device = "technichub", max = 3 } },
}
