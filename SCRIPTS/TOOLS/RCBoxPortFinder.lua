-- RC Box PortFinder v1.3 for EdgeTX (Flysky Paladin PL18)
-- RC Box Mini: tap a port -> its channel wiggles; then assign a source
-- (stick, pot, switch, logical switch, channel, GV) right away.
--
-- Master box: PF 1-4 = CH1-4, Servo 5-8 = CH5-8
-- Slave box:  PF 1-4 = CH9-12, Servo 5-8 = CH13-16
-- Layout (top view): PF1 top left, PF2 bottom left,
--                    PF4 top right, PF3 bottom right,
--                    XT30 top center, servo headers center/bottom.
--
-- Install: /SCRIPTS/TOOLS/RCBoxPortFinder.lua
local toolName = "TNS|RC Box PortFinder|TNE"

local APP_NAME = "RC Box PortFinder"
local VERSION  = "v1.3"

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
local CFG = {
  amplitude  = 30,    -- test wiggle in % (added to current position)
  cycles     = 3,     -- number of back-and-forth moves
  halfPeriod = 25,    -- time per direction in 10 ms
  cfgFile    = "/SCRIPTS/TOOLS/RCBoxPortFinder.cfg",
  layout     = "rcboxmini",   -- key into LAYOUTS (more boxes can be added later)
}

-- Channel names to cycle through (max. 6 characters)
local NAMES = {
  de = { "", "Fahrt", "Lenkg", "Licht", "Kran", "Arm", "Winde",
         "Kippe", "Gang", "Turm", "Schild", "Motor", "Pumpe", "Hupe" },
  en = { "", "Drive", "Steer", "Light", "Crane", "Arm", "Winch",
         "Tipper", "Gear", "Turret", "Blade", "Motor", "Pump", "Horn" },
}

---------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------
local TXT = {
  de = {
    warnTitle = "ACHTUNG",
    warn1 = "Propeller ab, Räder frei, Motoren sichern!",
    warn2 = "Getestete Kanäle werden um +/-%d%% bewegt, auch Regler.",
    warn3 = "Der Builder ändert Mixer im aktuellen Modell.",
    start = "Verstanden - Start",
    hint1 = "Tippe auf einen Port: er bewegt sich kurz hin und her.",
    hint2 = "Danach kannst du ihm hier eine Funktion zuweisen.",
    source = "Quelle: ", unused = "nicht belegt",
    test = "Testen", stop = "Stopp", assign = "Belegen",
    buildTitle = "CH%d belegen",
    catSticks = "Sticks", catPots = "Potis", catSw = "Schalter",
    catLs = "Log.Sch", catCh = "Kanäle", catOther = "Andere",
    det1 = "Bewege jetzt einen Stick, ein Poti", det2 = "oder einen Schalter ...  (%d s)",
    cancel = "Abbrechen", inverted = "Invertiert",
    replace = "Ersetzen", add = "Hinzufügen", name = "Name: ",
    detect = "Erkennen", clear = "Leeren", sure = "Wirklich?", apply = "Übernehmen",
    needSrc = "Erst eine Quelle wählen", nothing = "Nichts erkannt",
    detected = "Erkannt: ", cleared = "Alle Mixer auf CH%d entfernt",
  },
  en = {
    warnTitle = "WARNING",
    warn1 = "Remove props, lift wheels, secure motors!",
    warn2 = "Tested channels move by +/-%d%%, ESCs too.",
    warn3 = "The builder edits mixes of the current model.",
    start = "Understood - Start",
    hint1 = "Tap a port: its channel wiggles back and forth.",
    hint2 = "Then you can assign a function to it here.",
    source = "Source: ", unused = "not assigned",
    test = "Test", stop = "Stop", assign = "Assign",
    buildTitle = "Assign CH%d",
    catSticks = "Sticks", catPots = "Pots", catSw = "Switches",
    catLs = "Log.Sw", catCh = "Channels", catOther = "Other",
    det1 = "Move a stick, pot or switch", det2 = "now ...  (%d s)",
    cancel = "Cancel", inverted = "Inverted",
    replace = "Replace", add = "Add", name = "Name: ",
    detect = "Detect", clear = "Clear", sure = "Sure?", apply = "Apply",
    needSrc = "Select a source first", nothing = "Nothing detected",
    detected = "Detected: ", cleared = "All mixes on CH%d removed",
  },
}

local TEMP_MIX = "PFnd"     -- temporary test mix
local OWN_MIX  = "PF"       -- mixes created by the builder
local PER_PAGE = 12         -- source buttons per page (4 x 3)

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local W, H
local C = {}
local maxSrc
local lang = "en"
local screen = "warn"       -- "warn" | "main" | "build"
local slave = false
local ports = {}
local info = {}             -- channel (1-based) -> { mix, name }
local sel                   -- selected port (index into ports)
local active                -- running wiggle test
local lastPort
local buttons = {}
local exitReq = false
local toast, toastUntil = nil, 0

local CATS = {}
local srcName = {}
local B = {}                -- builder state

local function T(k) return TXT[lang][k] or k end

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function F(v) return math.floor(v + 0.5) end
local function Y(v) return F(v * H / 320) end

local function rect(x, y, w, h, c)
  lcd.drawFilledRectangle(F(x), F(y), F(w), F(h), c)
end
local function frame(x, y, w, h, c, t)
  lcd.drawRectangle(F(x), F(y), F(w), F(h), c, t or 1)
end
local function text(x, y, s, fl)
  lcd.drawText(F(x), F(y), s, fl or 0)
end

local function toastMsg(s)
  toast = s
  toastUntil = getTime() + 250
end

local function addBtn(x, y, w, h, fn)
  buttons[#buttons + 1] = { x = x, y = y, w = w, h = h, fn = fn }
end

local function button(x, y, w, h, label, fn, style, small)
  local bg, fg = C.btn, C.white
  if style == "primary" then bg, fg = C.accent, C.black
  elseif style == "on" then bg, fg = C.on, C.black
  elseif style == "danger" then bg, fg = C.danger, C.white
  elseif style == "off" then bg, fg = C.btnOff, C.text end
  rect(x, y, w, h, bg)
  local fsz = small and SMLSIZE or 0
  local th = small and 7 or 9
  text(x + w / 2, y + h / 2 - th, label, CENTER + fsz + fg)
  if fn then addBtn(x, y, w, h, fn) end
end

---------------------------------------------------------------------
-- Config (slave switch + language)
---------------------------------------------------------------------
local function loadCfg()
  local hasLang = false
  local f = io.open(CFG.cfgFile, "r")
  if f then
    local s = io.read(f, 64) or ""
    io.close(f)
    slave = (string.find(s, "slave=1", 1, true) ~= nil)
    if string.find(s, "lang=de", 1, true) then lang = "de"; hasLang = true
    elseif string.find(s, "lang=en", 1, true) then lang = "en"; hasLang = true end
  end
  if not hasLang and getGeneralSettings then
    local ok, gs = pcall(getGeneralSettings)
    if ok and gs and type(gs.language) == "string" and
       string.lower(string.sub(gs.language, 1, 2)) == "de" then
      lang = "de"
    end
  end
end

local function saveCfg()
  local f = io.open(CFG.cfgFile, "w")
  if f then
    io.write(f, (slave and "slave=1" or "slave=0") .. "\nlang=" .. lang)
    io.close(f)
  end
end

---------------------------------------------------------------------
-- Ports
---------------------------------------------------------------------
local function buildPorts()
  ports = {}
  for b = 1, 2 do
    for i = 1, 4 do
      ports[#ports + 1] = { box = b, kind = "pf", idx = i, num = i, ch = (b - 1) * 8 + i }
    end
    for i = 1, 4 do
      ports[#ports + 1] = { box = b, kind = "servo", idx = i, num = 4 + i, ch = (b - 1) * 8 + 4 + i }
    end
  end
end

local function portLabel(p)
  return (p.box == 1 and "Master" or "Slave") .. " " ..
    (p.kind == "pf" and "PF " or "Servo ") .. p.num
end

---------------------------------------------------------------------
-- Sources
---------------------------------------------------------------------
local function buildSources()
  local seen = {}
  local function add(list, field, label)
    local f = getFieldInfo(field)
    if f and f.id and not seen[f.id] then
      seen[f.id] = true
      local n = label or f.name or field
      list[#list + 1] = { id = f.id, name = n }
      srcName[f.id] = n
    end
  end

  local sticks, pots, sw, ls, chs, other = {}, {}, {}, {}, {}, {}
  for _, n in ipairs({ "ail", "ele", "thr", "rud" }) do add(sticks, n) end
  for _, n in ipairs({ "s1", "s2", "s3", "s4", "p1", "p2", "p3",
                       "ls", "rs", "ext1", "ext2", "ext3", "ext4" }) do
    add(pots, n)
  end
  for i = 0, 15 do add(sw, "s" .. string.char(97 + i)) end   -- sa .. sp
  for i = 1, 64 do
    local l = model.getLogicalSwitch(i - 1)
    if l and l.func and l.func ~= 0 then add(ls, "ls" .. i) end
  end
  for i = 1, 16 do add(chs, "ch" .. i) end
  add(other, "max", "MAX")
  for i = 1, 9 do add(other, "gvar" .. i) end

  local all = {
    { key = "catSticks", list = sticks, detect = true },
    { key = "catPots",   list = pots,   detect = true },
    { key = "catSw",     list = sw,     detect = true },
    { key = "catLs",     list = ls },
    { key = "catCh",     list = chs },
    { key = "catOther",  list = other },
  }
  CATS = {}
  for _, c in ipairs(all) do
    if #c.list > 0 then CATS[#CATS + 1] = c end
  end
end

local function srcLabel(id)
  if id == nil then return "-" end
  if srcName[id] then return srcName[id] end
  if getSourceName then
    local ok, s = pcall(getSourceName, id)
    if ok and s then return s end
  end
  return "#" .. tostring(id)
end

---------------------------------------------------------------------
-- Mixes
---------------------------------------------------------------------
local function removeNamed(ch0, nm)
  for i = model.getMixesCount(ch0) - 1, 0, -1 do
    local m = model.getMix(ch0, i)
    if m and m.name == nm then model.deleteMix(ch0, i) end
  end
end

local function cleanupTemp()
  for ch0 = 0, 31 do removeNamed(ch0, TEMP_MIX) end
end

local function setOffset(ch0, weight)
  removeNamed(ch0, TEMP_MIX)
  if weight ~= 0 then
    model.insertMix(ch0, model.getMixesCount(ch0), {
      name = TEMP_MIX, source = maxSrc, weight = weight, multiplex = 0,
    })
  end
end

local function refreshInfo(ch)
  local ch0 = ch - 1
  local first
  for i = 0, model.getMixesCount(ch0) - 1 do
    local m = model.getMix(ch0, i)
    if m and m.name ~= TEMP_MIX then first = m; break end
  end
  local o = model.getOutput(ch0)
  info[ch] = { mix = first, name = (o and o.name) or "" }
end

local function refreshAll()
  for ch = 1, 16 do refreshInfo(ch) end
end

---------------------------------------------------------------------
-- Wiggle test
---------------------------------------------------------------------
local function stopTest()
  if active then
    setOffset(active.ch0, 0)
    lastPort = active.port
    active = nil
  end
end

local function startTest(p)
  local was = active and active.port
  stopTest()
  if was == p then return end           -- tap again = stop
  active = { port = p, ch0 = ports[p].ch - 1, step = 0, nextT = 0 }
end

local function updateTest()
  if not active or getTime() < active.nextT then return end
  active.step = active.step + 1
  if active.step > CFG.cycles * 2 then
    stopTest()
  else
    local w = (active.step % 2 == 1) and CFG.amplitude or -CFG.amplitude
    setOffset(active.ch0, w)
    active.nextT = getTime() + CFG.halfPeriod
  end
end

---------------------------------------------------------------------
-- Builder logic
---------------------------------------------------------------------
local function openBuilder()
  stopTest()
  local p = ports[sel]
  local inf = info[p.ch] or {}
  local m = inf.mix

  B.src = m and m.source or nil
  local w = m and m.weight or 100
  B.inv = w < 0
  w = math.abs(w)
  if w > 100 then w = 100 end
  B.weight = w
  B.replace = true
  B.detect = nil
  B.confirmClear = false

  B.names = {}
  for i, n in ipairs(NAMES[lang]) do B.names[i] = n end
  B.nameIdx = 1
  local cur = inf.name or ""
  local found = false
  for i, n in ipairs(B.names) do
    if n == cur then B.nameIdx = i; found = true end
  end
  if not found and cur ~= "" then
    table.insert(B.names, 2, cur)
    B.nameIdx = 2
  end

  B.cat, B.page = 1, 1
  if B.src then
    for ci, c in ipairs(CATS) do
      for k, s in ipairs(c.list) do
        if s.id == B.src then
          B.cat = ci
          B.page = math.floor((k - 1) / PER_PAGE) + 1
        end
      end
    end
  end
  screen = "build"
end

local function applyAssign()
  if not B.src then toastMsg(T("needSrc")) return end
  stopTest()
  local p = ports[sel]
  local ch0 = p.ch - 1
  if B.replace then
    for i = model.getMixesCount(ch0) - 1, 0, -1 do model.deleteMix(ch0, i) end
  end
  local w = B.inv and -B.weight or B.weight
  model.insertMix(ch0, model.getMixesCount(ch0), {
    name = OWN_MIX, source = B.src, weight = w, multiplex = 0,
  })
  local o = model.getOutput(ch0)
  if o and o.name ~= B.names[B.nameIdx] then
    o.name = B.names[B.nameIdx]
    model.setOutput(ch0, o)
  end
  refreshInfo(p.ch)
  toastMsg("CH" .. p.ch .. " = " .. srcLabel(B.src) .. " " .. w .. "%")
  screen = "main"
end

local function clearChannel()
  if not B.confirmClear then
    B.confirmClear = true
    return
  end
  stopTest()
  local p = ports[sel]
  local ch0 = p.ch - 1
  for i = model.getMixesCount(ch0) - 1, 0, -1 do model.deleteMix(ch0, i) end
  refreshInfo(p.ch)
  B.src = nil
  B.confirmClear = false
  toastMsg(string.format(T("cleared"), p.ch))
end

local function startDetect()
  local base = {}
  for _, c in ipairs(CATS) do
    if c.detect then
      for _, s in ipairs(c.list) do base[s.id] = getValue(s.id) or 0 end
    end
  end
  B.detect = { base = base, untilT = getTime() + 1000 }
end

local function updateDetect()
  local d = B.detect
  if not d then return end
  if getTime() > d.untilT then
    B.detect = nil
    toastMsg(T("nothing"))
    return
  end
  local best, bestD = nil, 400
  for ci, c in ipairs(CATS) do
    if c.detect then
      for k, s in ipairs(c.list) do
        local dd = math.abs((getValue(s.id) or 0) - (d.base[s.id] or 0))
        if dd > bestD then best = { ci = ci, k = k, id = s.id }; bestD = dd end
      end
    end
  end
  if best then
    B.src = best.id
    B.cat = best.ci
    B.page = math.floor((best.k - 1) / PER_PAGE) + 1
    B.detect = nil
    toastMsg(T("detected") .. srcLabel(best.id))
  end
end

---------------------------------------------------------------------
-- Shared UI parts
---------------------------------------------------------------------
local function closeButton()
  local bw = 48
  local x = W - bw
  rect(x, 0, bw, 38, C.danger)
  local cx, cy, s = x + bw / 2, 19, 8
  for o = -1, 1 do
    lcd.drawLine(F(cx - s + o), F(cy - s), F(cx + s + o), F(cy + s), SOLID, C.white)
    lcd.drawLine(F(cx - s + o), F(cy + s), F(cx + s + o), F(cy - s), SOLID, C.white)
  end
  addBtn(x, 0, bw, 38, function() exitReq = true end)
end

local function titleBar(title, backFn)
  rect(0, 0, W, 38, C.bar)
  local tx = 12
  if backFn then
    button(0, 0, 44, 38, "<", backFn)
    tx = 54
  end
  if title then text(tx, 9, title, C.white) end
  closeButton()
end

local function drawToast(y)
  if toast and getTime() < toastUntil then
    rect(W / 2 - 180, y, 360, 26, C.toast)
    text(W / 2, y + 5, toast, CENTER + C.black)
  end
end

---------------------------------------------------------------------
-- RC Box Mini, top view
-- All geometry in pixels of the reference photo (box 20..1980 x 20..1600)
---------------------------------------------------------------------
-- Each layout describes one box. Only the RC Box Mini exists so far;
-- further boxes can be added here and selected via CFG.layout.
local LAYOUTS = {}

LAYOUTS.rcboxmini = {
  name = "RC Box Mini",
  x0 = 20, y0 = 20, w = 1960, h = 1580,
}

local PF_GEO = {
  [1] = { -- top left
    side = { 20, 195, 75, 610 }, outer = { 70, 115, 165, 720 }, inner = { 320, 140, 390, 705 },
    pins = { { 158, 320 }, { 158, 445 }, { 328, 385 }, { 328, 505 } },
    label = { 243, 420 }, hit = { 20, 100, 410, 730 } },
  [2] = { -- bottom left
    side = { 20, 1015, 75, 1415 }, outer = { 70, 905, 165, 1520 }, inner = { 325, 920, 395, 1505 },
    pins = { { 160, 1115 }, { 160, 1245 }, { 330, 1175 }, { 330, 1305 } },
    label = { 245, 1210 }, hit = { 20, 890, 410, 1530 } },
  [3] = { -- bottom right
    side = { 1895, 965, 1980, 1365 }, outer = { 1810, 860, 1900, 1475 }, inner = { 1600, 875, 1670, 1475 },
    pins = { { 1665, 1075 }, { 1665, 1195 }, { 1830, 1130 }, { 1830, 1255 } },
    label = { 1740, 1165 }, hit = { 1590, 850, 1980, 1490 } },
  [4] = { -- top right
    side = { 1885, 190, 1980, 610 }, outer = { 1795, 85, 1890, 680 }, inner = { 1580, 110, 1650, 685 },
    pins = { { 1645, 290 }, { 1645, 410 }, { 1805, 345 }, { 1805, 465 } },
    label = { 1722, 380 }, hit = { 1570, 75, 1980, 695 } },
}

local CROSSES = {
  { 590, 215 }, { 590, 600 }, { 600, 1000 }, { 605, 1395 },
  { 1385, 195 }, { 1390, 590 }, { 1405, 975 }, { 1410, 1385 },
}

local SERVO_ROWS = { 1055, 1185, 1310, 1440 }

LAYOUTS.rcboxmini.pf = PF_GEO
LAYOUTS.rcboxmini.crosses = CROSSES
LAYOUTS.rcboxmini.servoRows = SERVO_ROWS

local LAY = LAYOUTS[CFG.layout] or LAYOUTS.rcboxmini
local PH_X0, PH_Y0, PH_W, PH_H = LAY.x0, LAY.y0, LAY.w, LAY.h

local function drawBox(b, x0, y0, bw, title)
  local k = bw / PH_W
  local pulse = (math.floor(getTime() / 15) % 2 == 0)

  local function PX(px) return F(x0 + (px - PH_X0) * k) end
  local function PY(py) return F(y0 + (py - PH_Y0) * k) end
  local function R(x1, y1, x2, y2, c)
    local a, bb = PX(x1), PY(y1)
    lcd.drawFilledRectangle(a, bb, math.max(1, PX(x2) - a), math.max(1, PY(y2) - bb), c)
  end
  local function HL(x1, y1, x2, y2)
    lcd.drawLine(PX(x1), PY(y1), PX(x2), PY(y2), SOLID, C.hi)
  end
  local sh = 14
  local function raised(r)
    R(r[1] + sh, r[2] + sh, r[3] + sh, r[4] + sh, C.shadow)
    R(r[1], r[2], r[3], r[4], C.raised)
    HL(r[1], r[2], r[3], r[2])
    HL(r[1], r[2], r[1], r[4])
  end
  local function pin(px, py, s)
    s = s or 16
    local a, bb = PX(px - s), PY(py - s)
    local w = math.max(2, PX(px + s) - a)
    lcd.drawFilledRectangle(a, bb, w, w, C.pin)
  end
  local function circle(cx, cy, r, c)
    if lcd.drawFilledCircle then
      lcd.drawFilledCircle(PX(cx), PY(cy), math.max(2, F(r * k)), c)
    else
      R(cx - r, cy - r, cx + r, cy + r, c)
    end
  end
  local function chamfer(px, py, size, dir, c)
    -- fills a triangular corner; dir: 1 = top-left, 2 = top-right
    local n = math.max(1, F(size * k))
    local ax, ay = PX(px), PY(py)
    for i = 0, n - 1 do
      if dir == 1 then
        lcd.drawLine(ax, ay + i, ax + n - 1 - i, ay + i, SOLID, c)
      else
        lcd.drawLine(ax - n + 1 + i, ay + i, ax, ay + i, SOLID, c)
      end
    end
  end

  -- Title above the box
  text(x0 + bw / 2, y0 - 17, title, CENTER + SMLSIZE + C.text)

  -- Housing
  R(20, 20, 1980, 1600, C.case)
  lcd.drawRectangle(PX(20), PY(20), PX(1980) - PX(20), PY(1600) - PY(20), C.caseEdge, 1)

  -- Raised Technic crosses
  local a, t = 125, 40
  for _, c in ipairs(LAY.crosses) do
    local cx, cy = c[1], c[2]
    R(cx - a + sh, cy - t + sh, cx + a + sh, cy + t + sh, C.shadow)
    R(cx - t + sh, cy - a + sh, cx + t + sh, cy + a + sh, C.shadow)
  end
  for _, c in ipairs(LAY.crosses) do
    local cx, cy = c[1], c[2]
    R(cx - a, cy - t, cx + a, cy + t, C.raised)
    R(cx - t, cy - a, cx + t, cy + a, C.raised)
    HL(cx - t, cy - a, cx + t, cy - a)
    HL(cx - t, cy - a, cx - t, cy - t)
    HL(cx - a, cy - t, cx - t, cy - t)
    HL(cx + t, cy - t, cx + a, cy - t)
    HL(cx - a, cy - t, cx - a, cy + t)
    HL(cx - t, cy + t, cx - t, cy + a)
  end

  -- Small engraved cross below the XT30
  R(940, 709, 1070, 721, C.engrave)
  R(999, 650, 1011, 780, C.engrave)

  -- XT30 main power
  R(840, 90, 1140, 640, C.shadow)
  R(825, 75, 1125, 625, C.xt30)
  R(1105, 195, 1130, 610, C.xt30Side)
  chamfer(825, 75, 75, 1, C.case)
  chamfer(1125, 75, 75, 2, C.case)
  R(875, 115, 1080, 580, C.xt30In)
  chamfer(875, 115, 45, 1, C.xt30)
  chamfer(1080, 115, 45, 2, C.xt30)
  circle(980, 245, 58, C.gold)
  circle(980, 490, 58, C.gold)
  circle(970, 232, 22, C.goldHi)
  circle(970, 477, 22, C.goldHi)

  -- Servo header labels and window
  text(PX(870), PY(915) - 7, "SGN", CENTER + SMLSIZE + C.engraveTxt)
  text(PX(1135), PY(915) - 7, "GND", CENTER + SMLSIZE + C.engraveTxt)
  R(805, 955, 1215, 1600, C.window)

  -- Ports
  for pi, p in ipairs(ports) do
    if p.box == b then
      local isAct = active and active.port == pi
      local hit, lx, ly, lflag, ldy

      if p.kind == "pf" then
        local g = LAY.pf[p.idx]
        hit = g.hit
        if isAct then R(hit[1], hit[2], hit[3], hit[4], pulse and C.accent or C.accentDim) end
        raised(g.side)
        raised(g.outer)
        raised(g.inner)
        for _, pp in ipairs(g.pins) do pin(pp[1], pp[2], 13) end
        lx, ly, lflag, ldy = PX(g.label[1]), PY(g.label[2]), CENTER, 7
      else
        local cy = LAY.servoRows[p.idx]
        hit = { 805, cy - 62, 1360, cy + 62 }
        if isAct then R(hit[1], hit[2], hit[3], hit[4], pulse and C.accent or C.accentDim) end
        local hc = isAct and C.housingAct or C.housing
        R(835, cy - 55, 1065, cy + 55, hc)
        R(1078, cy - 55, 1192, cy + 55, hc)
        pin(885, cy)
        pin(1005, cy)
        pin(1125, cy)
        lx, ly, lflag, ldy = PX(1192) + 2, PY(cy), 0, 10
      end

      -- Channel number
      text(lx, ly - ldy, tostring(p.ch), lflag + SMLSIZE + (isAct and C.black or C.white))

      -- Selection / last tested
      local hx, hy = PX(hit[1]), PY(hit[2])
      local hw, hh = PX(hit[3]) - hx, PY(hit[4]) - hy
      if pi == sel then
        lcd.drawRectangle(hx, hy, hw, hh, C.white, 2)
      elseif pi == lastPort then
        lcd.drawRectangle(hx, hy, hw, hh, C.accentDim, 1)
      end

      local idx = pi
      addBtn(hx, hy, hw, hh, function()
        sel = idx
        startTest(idx)
      end)
    end
  end
end

---------------------------------------------------------------------
-- Screens
---------------------------------------------------------------------
local function drawWarning()
  lcd.clear(C.bg)
  rect(0, 0, W, 38, C.warn)
  text(W / 2, 7, T("warnTitle"), CENTER + MIDSIZE + C.black)
  closeButton()

  local y = Y(70)
  text(W / 2, y, T("warn1"), CENTER + MIDSIZE + C.white)
  text(W / 2, y + 45, string.format(T("warn2"), CFG.amplitude), CENTER + C.text)
  text(W / 2, y + 70, T("warn3"), CENTER + C.text)

  button(W / 2 - 120, H - Y(80), 240, 46, T("start"),
    function() screen = "main" end, "primary")
  text(W / 2, H - 22, APP_NAME .. "  " .. VERSION, CENTER + SMLSIZE + C.text)
end

local function drawTitleControls()
  -- language switch
  button(176, 6, 46, 26, string.upper(lang), function()
    lang = (lang == "de") and "en" or "de"
    saveCfg()
  end, nil, true)

  -- slave box switch
  local tw, th = 50, 24
  local tx = W - 48 - 12 - tw
  local ty = 7
  text(tx - 8, 10, "Slave Box", RIGHT + C.white)
  rect(tx, ty, tw, th, slave and C.on or C.btnOff)
  local kx = slave and (tx + tw - th + 3) or (tx + 3)
  rect(kx, ty + 3, th - 6, th - 6, C.white)
  addBtn(tx - 95, 0, tw + 100, 38, function()
    slave = not slave
    if not slave and sel and ports[sel].box == 2 then sel = nil end
    saveCfg()
  end)
end

local function drawBottomBar()
  local by = H - 54
  rect(0, by, W, 54, C.bar)
  if not sel then
    text(W / 2, by + 8, T("hint1"), CENTER + C.white)
    text(W / 2, by + 30, T("hint2"), CENTER + SMLSIZE + C.text)
    return
  end
  local p = ports[sel]
  local inf = info[p.ch] or {}
  local l1 = portLabel(p) .. "  ·  CH" .. p.ch
  if inf.name and inf.name ~= "" then l1 = l1 .. "  ·  " .. inf.name end
  text(10, by + 6, l1, C.white)
  local l2
  if inf.mix then
    l2 = T("source") .. srcLabel(inf.mix.source) .. "  " .. tostring(inf.mix.weight) .. "%"
  else
    l2 = T("unused")
  end
  text(10, by + 30, l2, SMLSIZE + C.text)

  local isAct = active and active.port == sel
  button(W - 222, by + 7, 100, 40, isAct and T("stop") or T("test"),
    function() startTest(sel) end)
  button(W - 114, by + 7, 106, 40, T("assign"), openBuilder, "primary")
end

local function drawMain()
  lcd.clear(C.bg)
  titleBar(nil)
  text(12, 2, APP_NAME, C.white)
  text(12, 21, VERSION .. "  ·  " .. LAY.name, SMLSIZE + C.text)
  drawTitleControls()

  local top, bottom = 38, H - 54
  local labelH = 20
  local availH = bottom - top - labelH - 4
  local ratio = PH_W / PH_H
  if slave then
    local bw = math.min((W - 30) / 2, availH * ratio)
    local bh = bw / ratio
    local gap = (W - 2 * bw) / 3
    local y0 = top + labelH + (availH - bh) / 2
    drawBox(1, gap, y0, bw, "MASTER  (CH1-8)")
    drawBox(2, gap * 2 + bw, y0, bw, "SLAVE  (CH9-16)")
  else
    local bw = math.min(W - 40, availH * ratio)
    local bh = bw / ratio
    local y0 = top + labelH + (availH - bh) / 2
    drawBox(1, (W - bw) / 2, y0, bw, "MASTER  (CH1-8)")
  end
  drawBottomBar()
  drawToast(H - 54 - 30)
end

local function drawBuild()
  lcd.clear(C.bg)
  local p = ports[sel]
  titleBar(string.format(T("buildTitle"), p.ch) .. "  ·  " .. portLabel(p),
    function() stopTest(); screen = "main" end)

  -- Categories
  local n = #CATS
  local tw = (W - 8) / n
  local ty, th = Y(44), Y(30)
  for ci, c in ipairs(CATS) do
    local idx = ci
    button(4 + (ci - 1) * tw + 1, ty, tw - 2, th, T(c.key),
      function() B.cat = idx; B.page = 1 end, (ci == B.cat) and "on" or nil, true)
  end

  -- Source grid
  local list = CATS[B.cat].list
  local pages = math.max(1, math.ceil(#list / PER_PAGE))
  if B.page > pages then B.page = pages end
  local gy, bh, gap = Y(80), Y(34), Y(4)
  local bw = (W - 12) / 4

  if B.detect then
    rect(6, gy, W - 12, 3 * bh + 2 * gap, C.bar)
    local left = math.max(0, math.ceil((B.detect.untilT - getTime()) / 100))
    text(W / 2, gy + 14, T("det1"), CENTER + C.white)
    text(W / 2, gy + 38, string.format(T("det2"), left), CENTER + C.white)
    button(W / 2 - 70, gy + 70, 140, 36, T("cancel"), function() B.detect = nil end)
  else
    for i = 1, PER_PAGE do
      local s = list[(B.page - 1) * PER_PAGE + i]
      if s then
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local x = 6 + col * bw + 1
        local y = gy + row * (bh + gap)
        local id = s.id
        button(x, y, bw - 2, bh, s.name, function() B.src = id end,
          (id == B.src) and "on" or nil, true)
        -- live value bar
        local v = getValue(id) or 0
        local half = (bw - 14) / 2
        local mid = x + (bw - 2) / 2
        local len = math.max(-half, math.min(half, v / 1024 * half))
        local barC = (id == B.src) and C.black or C.live
        if len >= 0 then
          rect(mid, y + bh - 5, math.max(1, len), 3, barC)
        else
          rect(mid + len, y + bh - 5, -len, 3, barC)
        end
      end
    end
  end

  -- Pages
  local py = Y(200)
  if pages > 1 and not B.detect then
    button(W / 2 - 110, py, 60, Y(26), "<",
      function() B.page = (B.page - 2) % pages + 1 end, nil, true)
    text(W / 2, py + Y(26) / 2 - 7, B.page .. " / " .. pages, CENTER + SMLSIZE + C.text)
    button(W / 2 + 50, py, 60, Y(26), ">",
      function() B.page = B.page % pages + 1 end, nil, true)
  end

  -- Options
  local oy, oh = Y(232), Y(36)
  local x = 6
  button(x, oy, 40, oh, "-", function() B.weight = math.max(0, B.weight - 10) end)
  x = x + 42
  rect(x, oy, 60, oh, C.bar)
  text(x + 30, oy + oh / 2 - 9, B.weight .. "%", CENTER + C.white)
  x = x + 62
  button(x, oy, 40, oh, "+", function() B.weight = math.min(100, B.weight + 10) end)
  x = x + 48
  local rest = W - x - 6
  local ow = (rest - 8) / 3
  button(x, oy, ow, oh, T("inverted"), function() B.inv = not B.inv end,
    B.inv and "on" or "off", true)
  x = x + ow + 4
  button(x, oy, ow, oh, B.replace and T("replace") or T("add"),
    function() B.replace = not B.replace end, nil, true)
  x = x + ow + 4
  local nm = B.names[B.nameIdx]
  button(x, oy, ow, oh, T("name") .. (nm == "" and "-" or nm),
    function() B.nameIdx = B.nameIdx % #B.names + 1 end, nil, true)

  -- Actions
  local ay, ah = H - Y(44), Y(38)
  local aw = (W - 12 - 18) / 4
  x = 6
  button(x, ay, aw, ah, T("detect"), startDetect, B.detect and "on" or nil)
  x = x + aw + 6
  local isAct = active and active.port == sel
  button(x, ay, aw, ah, isAct and T("stop") or T("test"), function() startTest(sel) end)
  x = x + aw + 6
  button(x, ay, aw, ah, B.confirmClear and T("sure") or T("clear"), clearChannel,
    B.confirmClear and "danger" or nil)
  x = x + aw + 6
  button(x, ay, aw, ah, T("apply"), applyAssign, "primary")

  drawToast(py)
end

---------------------------------------------------------------------
-- Tool functions
---------------------------------------------------------------------
local function init()
  W, H = LCD_W, LCD_H
  local f = getFieldInfo("max")
  maxSrc = f and f.id or 0

  -- UI
  C.bg         = lcd.RGB(22, 24, 28)
  C.bar        = lcd.RGB(40, 44, 52)
  C.btn        = lcd.RGB(62, 68, 80)
  C.btnOff     = lcd.RGB(48, 52, 60)
  C.text       = lcd.RGB(170, 176, 188)
  C.white      = lcd.RGB(255, 255, 255)
  C.black      = lcd.RGB(0, 0, 0)
  C.accent     = lcd.RGB(255, 196, 0)
  C.accentDim  = lcd.RGB(180, 135, 0)
  C.on         = lcd.RGB(120, 210, 255)
  C.danger     = lcd.RGB(200, 50, 50)
  C.warn       = lcd.RGB(255, 170, 0)
  C.toast      = lcd.RGB(255, 220, 120)
  C.live       = lcd.RGB(120, 210, 255)
  -- RC Box Mini
  C.case       = lcd.RGB(60, 62, 59)
  C.caseEdge   = lcd.RGB(88, 90, 86)
  C.raised     = lcd.RGB(70, 72, 68)
  C.shadow     = lcd.RGB(34, 35, 33)
  C.hi         = lcd.RGB(98, 100, 95)
  C.engrave    = lcd.RGB(38, 39, 37)
  C.engraveTxt = lcd.RGB(25, 26, 25)
  C.pin        = lcd.RGB(225, 195, 130)
  C.window     = lcd.RGB(16, 16, 16)
  C.housing    = lcd.RGB(44, 45, 44)
  C.housingAct = lcd.RGB(120, 90, 0)
  C.xt30       = lcd.RGB(245, 175, 30)
  C.xt30Side   = lcd.RGB(200, 135, 15)
  C.xt30In     = lcd.RGB(225, 150, 20)
  C.gold       = lcd.RGB(205, 145, 50)
  C.goldHi     = lcd.RGB(240, 200, 120)

  loadCfg()
  buildPorts()
  buildSources()
  cleanupTemp()
  refreshAll()
end

local function run(event, touchState)
  if event == EVT_VIRTUAL_EXIT then exitReq = true end

  if event == EVT_TOUCH_TAP and touchState then
    local tx, ty = touchState.x, touchState.y
    for i = #buttons, 1, -1 do
      local b = buttons[i]
      if tx >= b.x and tx <= b.x + b.w and ty >= b.y and ty <= b.y + b.h then
        if screen == "build" and b.fn ~= clearChannel then B.confirmClear = false end
        b.fn()
        break
      end
    end
  elseif event == EVT_VIRTUAL_ENTER and screen == "warn" then
    screen = "main"
  end

  if exitReq then
    stopTest()
    cleanupTemp()
    return 1
  end

  updateTest()
  if screen == "build" then updateDetect() end

  buttons = {}
  if screen == "warn" then
    drawWarning()
  elseif screen == "main" then
    drawMain()
  else
    drawBuild()
  end
  return 0
end

return { init = init, run = run }
