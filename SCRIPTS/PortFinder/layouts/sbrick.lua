-- PortFinder layout: SBrick / SBrick Plus (top view)
-- by MisterCreators Custom MOCs
--
-- The top of the SBrick is four Power Functions connectors in a 2 x 2 grid.
-- Each one: a raised part with the contact slot at the top, two hollow
-- square studs below. A top left, B top right, C bottom left, D bottom right.
-- Channels: A-D = the next 4 channels.
-- Used with the MC Brick Bridge (internal CRSF module), see Brick Connect.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  case     = lcd.RGB(214, 217, 220),   -- light grey / white housing
  caseEdge = lcd.RGB(176, 180, 184),
  gap      = lcd.RGB(150, 154, 158),
  raised   = lcd.RGB(238, 240, 242),
  raisedHi = lcd.RGB(252, 252, 252),
  shadow   = lcd.RGB(160, 164, 168),
  slot     = lcd.RGB(178, 182, 186),
  slotAct  = lcd.RGB(255, 205, 70),
  contact  = lcd.RGB(70, 72, 76),
  stud     = lcd.RGB(232, 234, 236),
  studHole = lcd.RGB(168, 172, 176),
  studAct  = lcd.RGB(255, 225, 140),
}

-- port positions (layout units): left/top corner of each 230 x 230 quarter
-- change here if your SBrick is turned differently
local POS = {
  { "A", 10, 10 },      -- top left
  { "B", 260, 10 },     -- top right
  { "C", 10, 260 },     -- bottom left
  { "D", 260, 260 },    -- bottom right
}
local Q = 230

local ports = {}
for i, p in ipairs(POS) do
  local x, y = p[2], p[3]
  ports[#ports + 1] = { name = "Port " .. p[1], label = p[1], kind = "pf", ch = i, q = { x, y },
    hit = { x, y, x + Q, y + Q },
    num = { x + Q / 2, y + 60 }, align = "center", dy = 7 }
end

local function draw(g)
  g.R(0, 0, 500, 500, C.case)
  g.frame(0, 0, 500, 500, C.caseEdge, 2)
  -- grooves between the four connectors
  g.R(244, 6, 256, 494, C.gap)
  g.R(6, 244, 494, 256, C.gap)
end

local function drawPort(g, p, active)
  local x, y = p.q[1], p.q[2]
  -- raised part with the contact slot
  g.R(x + 20, y + 18, x + 214, y + 108, C.shadow)
  g.R(x + 14, y + 12, x + 208, y + 102, C.raised)
  g.line(x + 14, y + 12, x + 208, y + 12, C.raisedHi)
  g.line(x + 14, y + 12, x + 14, y + 102, C.raisedHi)
  g.R(x + 38, y + 32, x + 184, y + 88, active and C.slotAct or C.slot)
  g.pin(x + 82, y + 42, 6, C.contact)
  g.pin(x + 140, y + 42, 6, C.contact)
  -- two hollow square studs
  for _, sx in ipairs({ 28, 124 }) do
    g.R(x + sx + 4, y + 128, x + sx + 82, y + 206, C.shadow)
    g.R(x + sx, y + 124, x + sx + 78, y + 202, active and C.studAct or C.stud)
    g.R(x + sx + 22, y + 146, x + sx + 56, y + 180, C.studHole)
  end
end

return {
  id = "sbrick",
  name = "SBrick / SBrick Plus",
  short = "SBrick",
  author = "MisterCreators Custom MOCs",
  version = "1.1",
  x0 = 0, y0 = 0, w = 500, h = 500,
  channels = 4,
  numbers = "channel",
  numColor = lcd.RGB(30, 32, 36),
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 60,
  -- up to 4 SBrick (16 channels)
  extras = { { label = "SBrick", device = "sbrick", max = 3 } },
}
