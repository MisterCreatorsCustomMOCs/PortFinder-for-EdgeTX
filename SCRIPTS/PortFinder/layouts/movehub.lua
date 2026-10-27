-- PortFinder layout: LEGO BOOST Move Hub 88006 (top view)
-- by MisterCreators Custom MOCs
--
-- A and B are the two built-in motors (orange outputs on the sides),
-- C and D are Powered Up ports. Channels: A, B, C, D = the next 4 channels.
-- Used with the MC Brick Bridge (internal CRSF module), see Brick Connect.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  body     = lcd.RGB(232, 234, 236),   -- white
  bodyEdge = lcd.RGB(200, 204, 208),
  top      = lcd.RGB(160, 165, 170),
  stud     = lcd.RGB(175, 180, 185),
  studHi   = lcd.RGB(200, 204, 208),
  dark     = lcd.RGB(88, 92, 98),
  shadow   = lcd.RGB(30, 31, 34),
  sock     = lcd.RGB(52, 54, 58),
  slot     = lcd.RGB(24, 25, 27),
  act      = lcd.RGB(255, 210, 90),
  orange   = lcd.RGB(235, 130, 40),
  orangeIn = lcd.RGB(190, 95, 20),
  btn      = lcd.RGB(40, 42, 46),
  led      = lcd.RGB(90, 200, 120),
  engTxt   = lcd.RGB(120, 124, 130),
}

-- port positions (layout units)
local MOTORS = {
  { "A", 40, 300 },               -- built-in motor, left side (output centre)
  { "B", 600, 300 },              -- built-in motor, right side
}
local SOCKETS = {
  { "C", 130, 0, 270, 96 },       -- rear end, left
  { "D", 370, 0, 510, 96 },       -- rear end, right
}

local ports = {}
for i, p in ipairs(MOTORS) do
  local x, y = p[2], p[3]
  ports[#ports + 1] = { name = "Motor " .. p[1], label = p[1], kind = "motor", ch = i, c = { x, y },
    hit = (x < 320) and { x - 50, y - 110, x + 120, y + 110 } or { x - 120, y - 110, x + 50, y + 110 },
    num = { x, y }, align = "center", dy = 7 }
end
for i, p in ipairs(SOCKETS) do
  local b = { p[2], p[3], p[4], p[5] }
  ports[#ports + 1] = { name = "Port " .. p[1], label = p[1], kind = "pu", ch = 2 + i, box = b,
    hit = { b[1] - 20, 0, b[3] + 20, 170 },
    num = { (b[1] + b[3]) / 2, (b[2] + b[4]) / 2 }, align = "center", dy = 7 }
end

local function draw(g)
  g.R(40, 80, 600, 410, C.body)
  g.frame(40, 80, 600, 410, C.bodyEdge, 2)
  g.R(120, 80, 520, 240, C.top)
  for x = 170, 470, 60 do
    for _, y in ipairs({ 130, 200 }) do
      g.circle(x, y, 20, C.stud)
      g.circle(x - 3, y - 3, 12, C.studHi)
    end
  end
  -- button and status light at the front
  g.circle(320, 330, 40, C.dark)
  g.circle(320, 330, 30, C.btn)
  g.circle(320, 330, 8, C.led)
  for _, p in ipairs(ports) do
    if p.kind == "motor" then
      g.text(p.c[1] < 320 and 130 or 510, 290, p.label, CENTER + C.engTxt)
    else
      g.text((p.box[1] + p.box[3]) / 2, 245, p.label, CENTER + C.engTxt)
    end
  end
end

local function drawPort(g, p, active)
  if p.kind == "motor" then
    local x, y = p.c[1], p.c[2]
    g.circle(x + 4, y + 4, 46, C.shadow)
    g.circle(x, y, 46, active and C.act or C.orange)
    g.circle(x, y, 30, C.orangeIn)
    -- axle cross
    g.R(x - 22, y - 6, x + 22, y + 6, C.dark)
    g.R(x - 6, y - 22, x + 6, y + 22, C.dark)
  else
    local b = p.box
    g.R(b[1] + 5, b[2] + 5, b[3] + 5, b[4] + 5, C.shadow)
    g.R(b[1], b[2], b[3], b[4], C.sock)
    g.R(b[1] + 12, b[2] + 12, b[3] - 12, b[4] - 12, active and C.act or C.slot)
  end
end

return {
  id = "movehub",
  name = "LEGO BOOST Move Hub",
  short = "BOOST Hub",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = -10, y0 = 0, w = 660, h = 420,
  channels = 4,
  numbers = "channel",
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 80,
  extras = { { label = "BOOST", device = "movehub", max = 3 } },
}
