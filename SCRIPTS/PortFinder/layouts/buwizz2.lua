-- PortFinder layout: BuWizz 2.0 (top view)
-- by MisterCreators Custom MOCs
--
-- Four Power Functions outputs: 1 top left, 2 bottom left, 3 bottom right,
-- 4 top right. Channels: outputs 1-4 = the next 4 channels. Up to 4 BuWizz 2.0.
-- Used with the MC BuWizz Bridge (internal CRSF module), see BuWizz Connect.
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
  led      = lcd.RGB(150, 140, 110),
  jst      = lcd.RGB(235, 228, 205),
}

-- studs (layout units = pixels of the photo)
local STUDS = {
  { 443, 95 }, { 615, 95 }, { 788, 95 }, { 960, 95 },
  { 443, 265 }, { 960, 265 }, { 440, 440 }, { 960, 440 },
  { 437, 612 }, { 612, 612 }, { 788, 612 }, { 963, 612 },
}

-- each output: T-shaped part (bar + 2 arms) and a straight bar with 4 contacts
local PF = {
  { raised = { { 215, 45, 255, 315 }, { 165, 100, 255, 128 }, { 165, 213, 255, 241 }, { 318, 45, 356, 318 } },
    pins = { { 245, 140 }, { 245, 196 }, { 326, 160 }, { 326, 228 } },
    num = { 287, 180 }, hit = { 150, 35, 372, 330 } },                       -- 1 top left
  { raised = { { 213, 390, 250, 665 }, { 160, 455, 250, 478 }, { 160, 590, 250, 613 }, { 315, 390, 352, 665 } },
    pins = { { 240, 490 }, { 240, 548 }, { 322, 512 }, { 322, 575 } },
    num = { 283, 528 }, hit = { 148, 380, 370, 680 } },                      -- 2 bottom left
  { raised = { { 1155, 390, 1195, 665 }, { 1155, 455, 1245, 478 }, { 1155, 590, 1245, 613 }, { 1053, 390, 1090, 668 } },
    pins = { { 1165, 512 }, { 1165, 578 }, { 1083, 490 }, { 1083, 548 } },
    num = { 1122, 528 }, hit = { 1038, 380, 1260, 680 } },                   -- 3 bottom right
  { raised = { { 1150, 45, 1190, 315 }, { 1150, 100, 1240, 128 }, { 1150, 213, 1240, 241 }, { 1048, 45, 1085, 318 } },
    pins = { { 1160, 160 }, { 1160, 228 }, { 1078, 140 }, { 1078, 196 } },
    num = { 1117, 180 }, hit = { 1035, 35, 1255, 330 } },                    -- 4 top right
}

local ports = {}
for i = 1, 4 do
  local p = PF[i]
  ports[#ports + 1] = { name = "Port " .. i, label = tostring(i), kind = "pf", ch = i, geo = p,
    hit = p.hit, num = p.num, align = "center", dy = 7 }
end

local function draw(g)
  g.R(12, 22, 1393, 703, C.case)
  g.frame(12, 22, 1393, 703, C.caseEdge)
  for _, s in ipairs(STUDS) do
    local r = 52
    g.circle(s[1] + 12, s[2] + 12, r, C.shadow)
    g.circle(s[1], s[2], r, C.raised)
    g.circle(s[1] - 10, s[2] - 10, r * 0.55, C.studHi)
    g.circle(s[1], s[2], r * 0.55, C.raised)
  end
  -- port numbers printed on the housing
  for _, e in ipairs({ { "1", 80, 40 }, { "2", 70, 625 }, { "3", 1325, 625 }, { "4", 1315, 40 } }) do
    lcd.drawText(g.PX(e[2]), g.PY(e[3]), e[1], CENTER + SMLSIZE + C.engTxt)
  end
  -- micro USB, button, LED and the side connector
  g.R(592, 272, 645, 440, C.window)
  g.R(598, 282, 639, 430, C.usb)
  g.circle(788, 265, 36, C.window)
  g.circle(788, 265, 22, C.button)
  g.circle(788, 410, 28, C.led)
  g.R(62, 240, 165, 470, C.window)
  g.R(92, 248, 165, 462, C.jst)
end

local function drawPort(g, p, active)
  for _, r in ipairs(p.geo.raised) do g.raised(r, C.raised, C.shadow, C.hi, 10) end
  for _, pp in ipairs(p.geo.pins) do g.pin(pp[1], pp[2], 11, C.pin) end
end

return {
  id = "buwizz2",
  name = "BuWizz 2.0",
  short = "BuWizz 2.0",
  author = "MisterCreators Custom MOCs",
  version = "1.0",
  x0 = 10, y0 = 20, w = 1385, h = 685,
  channels = 4,
  numbers = "channel",
  ports = ports,
  draw = draw,
  drawPort = drawPort,
  order = 50,
  -- up to 4 BuWizz 2.0 (16 channels)
  extras = { { label = "BuWizz 2.0", device = "buwizz2", max = 3 } },
}
