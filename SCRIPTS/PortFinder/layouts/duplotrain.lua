-- PortFinder layout: LEGO DUPLO train (push & go train hub), top view
-- by MisterCreators Custom MOCs
--
-- The train hub has no plugs, the bridge gives it 3 channels:
--   1 = drive motor, 2 = front light (up white, down red), 3 = sound (up horn, down steam)
-- Used with the MC Brick Bridge (internal CRSF module), see Brick Connect.
-- Layout format: see rcboxmini.lua or README.md

local C = {
  body     = lcd.RGB(200, 40, 40),     -- red
  bodyHi   = lcd.RGB(230, 80, 70),
  cab      = lcd.RGB(160, 30, 30),
  roof     = lcd.RGB(240, 200, 40),
  wheel    = lcd.RGB(30, 30, 32),
  wheelHi  = lcd.RGB(80, 82, 86),
  chimney  = lcd.RGB(30, 30, 32),
  light    = lcd.RGB(250, 235, 160),
  act      = lcd.RGB(255, 210, 90),
  shadow   = lcd.RGB(30, 31, 34),
  txt      = lcd.RGB(255, 255, 255),
}

local ports = {
  { name = "Motor", label = "M", kind = "motor", ch = 1, hit = { 60, 250, 520, 330 },
    num = { 290, 290 }, align = "center", dy = 7 },
  { name = "Light", label = "L", kind = "light", ch = 2, hit = { 510, 90, 610, 230 },
    num = { 560, 160 }, align = "center", dy = 7 },
  { name = "Sound", label = "S", kind = "sound", ch = 3, hit = { 360, 80, 490, 240 },
    num = { 425, 160 }, align = "center", dy = 7 },
}

local function draw(g)
  -- wheels on both sides (seen from above)
  for _, x in ipairs({ 140, 290, 440 }) do
    g.R(x - 50, 10, x + 50, 50, C.wheel)
    g.R(x - 40, 16, x + 40, 44, C.wheelHi)
  end
  -- body, cab and front
  g.R(60, 40, 530, 280, C.body)
  g.R(60, 40, 530, 60, C.bodyHi)
  g.R(70, 50, 260, 270, C.cab)
  g.R(90, 70, 240, 250, C.roof)
end

local function drawPort(g, p, active)
  if p.kind == "motor" then
    for _, x in ipairs({ 140, 290, 440 }) do
      g.R(x - 50, 270, x + 50, 315, active and C.act or C.wheel)
      g.R(x - 40, 276, x + 40, 309, active and C.act or C.wheelHi)
    end
  elseif p.kind == "light" then
    g.R(520, 100, 560, 220, C.body)
    g.circle(560, 160, 38, C.shadow)
    g.circle(560, 160, 34, active and C.act or C.light)
  else
    g.circle(425, 160, 52, C.shadow)
    g.circle(425, 160, 48, active and C.act or C.chimney)
  end
end

return {
  id = "duplotrain",
  name = "LEGO DUPLO Train",
  short = "DUPLO",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 50, y0 = 0, w = 570, h = 330,
  channels = 3,
  numbers = "channel",
  numColor = lcd.RGB(20, 20, 20),
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 85,
  extras = { { label = "DUPLO", device = "duplotrain", max = 3 } },
}
