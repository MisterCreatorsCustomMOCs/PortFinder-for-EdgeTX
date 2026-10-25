-- PortFinder v2 für EdgeTX (Flysky Paladin PL18)
-- RC Box Mini: Ports antippen -> Kanal wackelt kurz; danach direkt
-- eine Quelle (Stick, Poti, Schalter, Log. Schalter, Kanal, GV) zuweisen.
--
-- Master-Box: PF 1-4 = CH1-4, Servo 1-4 = CH5-8
-- Slave-Box:  PF 1-4 = CH9-12, Servo 1-4 = CH13-16
--
-- Ablage: /SCRIPTS/TOOLS/PortFinder.lua
local toolName = "TNS|PortFinder|TNE"

---------------------------------------------------------------------
-- Einstellungen
---------------------------------------------------------------------
local CFG = {
  amplitude  = 30,    -- Test-Ausschlag in % (addiert zur aktuellen Position)
  cycles     = 3,     -- Anzahl Hin-und-her-Bewegungen
  halfPeriod = 25,    -- Dauer je Richtung in 10 ms
  cfgFile    = "/SCRIPTS/TOOLS/PortFinder.cfg",
  -- Kanalnamen zum Durchtippen (max. 6 Zeichen)
  names = { "", "Fahrt", "Lenkg", "Licht", "Kran", "Arm", "Winde",
            "Kippe", "Gang", "Turm", "Schild", "Motor", "Pumpe", "Hupe" },
}

local TEMP_MIX = "PFnd"     -- temporärer Test-Mixer
local OWN_MIX  = "PF"       -- vom Builder angelegte Mixer
local PER_PAGE = 12         -- Quellen-Buttons pro Seite (4 x 3)

---------------------------------------------------------------------
-- Zustand
---------------------------------------------------------------------
local W, H
local C = {}
local maxSrc
local screen = "warn"       -- "warn" | "main" | "build"
local slave = false
local ports = {}
local info = {}             -- Kanal (1-basiert) -> { mix, name }
local sel                   -- gewählter Port (Index in ports)
local active                -- laufender Wackel-Test
local lastPort
local buttons = {}
local exitReq = false
local toast, toastUntil = nil, 0

local CATS = {}             -- Quellen-Kategorien
local srcName = {}          -- Quellen-ID -> Anzeigename

local B = {}                -- Builder-Zustand

---------------------------------------------------------------------
-- Hilfsfunktionen
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
  local bg = C.btn
  local fg = C.white
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
-- Konfiguration (Slave-Schalter merken)
---------------------------------------------------------------------
local function loadCfg()
  local f = io.open(CFG.cfgFile, "r")
  if f then
    local s = io.read(f, 32) or ""
    io.close(f)
    slave = (string.find(s, "slave=1", 1, true) ~= nil)
  end
end

local function saveCfg()
  local f = io.open(CFG.cfgFile, "w")
  if f then
    io.write(f, slave and "slave=1" or "slave=0")
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
      ports[#ports + 1] = { box = b, kind = "pf", idx = i, ch = (b - 1) * 8 + i }
    end
    for i = 1, 4 do
      ports[#ports + 1] = { box = b, kind = "servo", idx = i, ch = (b - 1) * 8 + 4 + i }
    end
  end
end

local function portLabel(p)
  return (p.box == 1 and "Master" or "Slave") .. " " ..
    (p.kind == "pf" and "PF " or "Servo ") .. p.idx
end

---------------------------------------------------------------------
-- Quellen
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

  add(other, "max", "MAX (voll)")
  for i = 1, 9 do add(other, "gvar" .. i) end

  local all = {
    { title = "Sticks",   list = sticks, detect = true },
    { title = "Potis",    list = pots,   detect = true },
    { title = "Schalter", list = sw,     detect = true },
    { title = "Log.Sch",  list = ls },
    { title = "Kanäle",   list = chs },
    { title = "Andere",   list = other },
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
-- Mixer
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
-- Wackel-Test
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
  if was == p then return end           -- erneutes Tippen = Stopp
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
-- Builder-Logik
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
  for i, n in ipairs(CFG.names) do B.names[i] = n end
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
  if not B.src then toastMsg("Erst eine Quelle wählen") return end
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
  toastMsg("Alle Mixer auf CH" .. p.ch .. " entfernt")
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
    toastMsg("Nichts erkannt")
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
    toastMsg("Erkannt: " .. srcLabel(best.id))
  end
end

---------------------------------------------------------------------
-- Gemeinsame UI-Teile
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
  text(tx, 9, title, C.white)
  closeButton()
end

local function drawToast(y)
  if toast and getTime() < toastUntil then
    rect(W / 2 - 180, y, 360, 26, C.toast)
    text(W / 2, y + 5, toast, CENTER + C.black)
  end
end

---------------------------------------------------------------------
-- RC Box Mini (Draufsicht)
---------------------------------------------------------------------
local function cross(cx, cy, s, c)
  local t = math.max(2, s * 0.32)
  rect(cx - s / 2, cy - t / 2, s, t, c)
  rect(cx - t / 2, cy - s / 2, t, s, c)
end

local function highlight(pi, r, pulse)
  if active and active.port == pi then
    rect(r.x, r.y, r.w, r.h, pulse and C.accent or C.accentDim)
  end
end

local function marks(pi, r)
  if pi == sel then
    frame(r.x, r.y, r.w, r.h, C.white, 2)
  elseif pi == lastPort then
    frame(r.x, r.y, r.w, r.h, C.accentDim, 1)
  end
end

local function drawBox(b, x, y, S, title)
  local pulse = (math.floor(getTime() / 15) % 2 == 0)
  text(x + S / 2, y - 18, title, CENTER + SMLSIZE + C.text)

  -- Gehäuse
  rect(x, y, S, S, C.case)
  frame(x, y, S, S, C.caseEdge, 2)

  -- Technic-Kreuzlöcher
  for _, fx in ipairs({ 0.27, 0.73 }) do
    for _, fy in ipairs({ 0.2, 0.4, 0.6, 0.8 }) do
      cross(x + S * fx, y + S * fy, S * 0.075, C.hole)
    end
  end

  -- XT30
  rect(x + S * 0.42, y + S * 0.06, S * 0.16, S * 0.13, C.xt30)
  rect(x + S * 0.45, y + S * 0.09, S * 0.10, S * 0.07, C.xt30Dark)

  for pi, p in ipairs(ports) do
    if p.box == b then
      local inf = info[p.ch]
      local used = inf and inf.mix ~= nil
      local isAct = active and active.port == pi
      local r

      if p.kind == "pf" then
        -- PF 1/2 links, PF 3/4 rechts (jeweils oben/unten)
        local left = p.idx <= 2
        local top = (p.idx % 2 == 1)
        local sxp = left and (x + S * 0.04) or (x + S * 0.86)
        local syp = top and (y + S * 0.10) or (y + S * 0.60)
        local sw, sh = S * 0.10, S * 0.30
        r = { x = left and x + 2 or x + S * 0.80, y = syp - S * 0.04,
              w = S * 0.18, h = sh + S * 0.08 }
        highlight(pi, r, pulse)
        rect(sxp, syp, sw, sh, C.slot)
        for k = 0, 3 do
          rect(sxp + sw * 0.3, syp + sh * (0.12 + k * 0.22), sw * 0.4, sh * 0.1, C.metal)
        end
        local lx = left and (x + S * 0.17) or (x + S * 0.83)
        text(lx, syp + sh / 2 - 7, tostring(p.ch),
          (left and 0 or RIGHT) + SMLSIZE + (isAct and C.black or C.white))
        if used then
          rect(left and lx or lx - 6, syp + sh / 2 + 9, 6, 6, C.used)
        end
      else
        -- Servo-Stiftleisten in der Mitte (Signal / + / -)
        local hx, hw = x + S * 0.38, S * 0.24
        local rh = S * 0.15
        local ry = y + S * 0.23 + (p.idx - 1) * rh
        r = { x = hx - S * 0.02, y = ry, w = hw + S * 0.28, h = rh }
        highlight(pi, r, pulse)
        local hh = rh * 0.72
        rect(hx, ry + (rh - hh) / 2, hw, hh, C.black)
        local pin = hh * 0.6
        local pinCols = { C.sig, C.plus, C.minus }
        for k = 1, 3 do
          rect(hx + hw * (k - 0.5) / 3 - pin / 2, ry + (rh - pin) / 2, pin, pin, pinCols[k])
        end
        text(hx + hw + S * 0.02, ry + rh / 2 - 7, tostring(p.ch),
          SMLSIZE + (isAct and C.black or C.white))
        if used then
          rect(hx + hw + S * 0.02 + 16, ry + rh / 2 - 3, 6, 6, C.used)
        end
      end

      marks(pi, r)
      local idx = pi
      addBtn(r.x, r.y, r.w, r.h, function()
        sel = idx
        startTest(idx)
      end)
    end
  end

  text(x + S / 2, y + S * 0.92 - 6, "RC Box Mini", CENTER + SMLSIZE + C.caseText)
end

---------------------------------------------------------------------
-- Bildschirme
---------------------------------------------------------------------
local function drawWarning()
  lcd.clear(C.bg)
  rect(0, 0, W, 38, C.warn)
  text(W / 2, 7, "ACHTUNG", CENTER + MIDSIZE + C.black)
  closeButton()

  local y = Y(70)
  text(W / 2, y, "Propeller ab, Räder frei, Motoren sichern!", CENTER + MIDSIZE + C.white)
  text(W / 2, y + 45, "Getestete Kanäle werden um +/-" .. CFG.amplitude ..
    "% bewegt, auch Regler.", CENTER + C.text)
  text(W / 2, y + 70, "Der Builder ändert Mixer im aktuellen Modell.", CENTER + C.text)

  button(W / 2 - 120, H - Y(80), 240, 46, "Verstanden - Start",
    function() screen = "main" end, "primary")
end

local function drawSlaveToggle()
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
    text(W / 2, by + 8, "Tippe auf einen Port: er bewegt sich kurz hin und her.",
      CENTER + C.white)
    text(W / 2, by + 30, "Danach kannst du ihm hier eine Funktion zuweisen.",
      CENTER + SMLSIZE + C.text)
    return
  end
  local p = ports[sel]
  local inf = info[p.ch] or {}
  local l1 = portLabel(p) .. "  ·  CH" .. p.ch
  if inf.name and inf.name ~= "" then l1 = l1 .. "  ·  " .. inf.name end
  text(10, by + 6, l1, C.white)
  local l2
  if inf.mix then
    l2 = "Quelle: " .. srcLabel(inf.mix.source) .. "  " .. tostring(inf.mix.weight) .. "%"
  else
    l2 = "nicht belegt"
  end
  text(10, by + 30, l2, SMLSIZE + C.text)

  local isAct = active and active.port == sel
  button(W - 222, by + 7, 100, 40, isAct and "Stopp" or "Testen",
    function() startTest(sel) end)
  button(W - 114, by + 7, 106, 40, "Belegen", openBuilder, "primary")
end

local function drawMain()
  lcd.clear(C.bg)
  titleBar("PortFinder")
  drawSlaveToggle()

  local top, bottom = 38, H - 54
  local bodyH = bottom - top
  if slave then
    local S = math.min(bodyH - 26, (W - 36) / 2)
    local gap = (W - 2 * S) / 3
    drawBox(1, gap, top + 22, S, "MASTER  (CH1-8)")
    drawBox(2, gap * 2 + S, top + 22, S, "SLAVE  (CH9-16)")
  else
    local S = math.min(bodyH - 26, W - 40)
    drawBox(1, (W - S) / 2, top + 22, S, "MASTER  (CH1-8)")
  end
  drawBottomBar()
  drawToast(H - 54 - 30)
end

local function drawBuild()
  lcd.clear(C.bg)
  local p = ports[sel]
  titleBar("CH" .. p.ch .. " belegen  ·  " .. portLabel(p),
    function() stopTest(); screen = "main" end)

  -- Kategorien
  local n = #CATS
  local tw = (W - 8) / n
  local ty, th = Y(44), Y(30)
  for ci, c in ipairs(CATS) do
    local idx = ci
    button(4 + (ci - 1) * tw + 1, ty, tw - 2, th, c.title,
      function() B.cat = idx; B.page = 1 end, (ci == B.cat) and "on" or nil, true)
  end

  -- Quellen-Raster
  local list = CATS[B.cat].list
  local pages = math.max(1, math.ceil(#list / PER_PAGE))
  if B.page > pages then B.page = pages end
  local gy, bh, gap = Y(80), Y(34), Y(4)
  local bw = (W - 12) / 4

  if B.detect then
    rect(6, gy, W - 12, 3 * bh + 2 * gap, C.bar)
    local left = math.max(0, math.ceil((B.detect.untilT - getTime()) / 100))
    text(W / 2, gy + 14, "Bewege jetzt einen Stick, ein Poti", CENTER + C.white)
    text(W / 2, gy + 38, "oder einen Schalter ...  (" .. left .. " s)", CENTER + C.white)
    button(W / 2 - 70, gy + 70, 140, 36, "Abbrechen", function() B.detect = nil end)
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
        -- Live-Anzeige des Werts
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

  -- Seiten
  local py = Y(200)
  if pages > 1 and not B.detect then
    button(W / 2 - 110, py, 60, Y(26), "<",
      function() B.page = (B.page - 2) % pages + 1 end, nil, true)
    text(W / 2, py + Y(26) / 2 - 7, B.page .. " / " .. pages, CENTER + SMLSIZE + C.text)
    button(W / 2 + 50, py, 60, Y(26), ">",
      function() B.page = B.page % pages + 1 end, nil, true)
  end

  -- Optionen
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
  button(x, oy, ow, oh, "Invertiert", function() B.inv = not B.inv end,
    B.inv and "on" or "off", true)
  x = x + ow + 4
  button(x, oy, ow, oh, B.replace and "Ersetzen" or "Hinzufügen",
    function() B.replace = not B.replace end, nil, true)
  x = x + ow + 4
  local nm = B.names[B.nameIdx]
  button(x, oy, ow, oh, "Name: " .. (nm == "" and "-" or nm),
    function() B.nameIdx = B.nameIdx % #B.names + 1 end, nil, true)

  -- Aktionen
  local ay, ah = H - Y(44), Y(38)
  local aw = (W - 12 - 18) / 4
  x = 6
  button(x, ay, aw, ah, "Erkennen", startDetect, B.detect and "on" or nil)
  x = x + aw + 6
  local isAct = active and active.port == sel
  button(x, ay, aw, ah, isAct and "Stopp" or "Testen", function() startTest(sel) end)
  x = x + aw + 6
  button(x, ay, aw, ah, B.confirmClear and "Wirklich?" or "Leeren", clearChannel,
    B.confirmClear and "danger" or nil)
  x = x + aw + 6
  button(x, ay, aw, ah, "Übernehmen", applyAssign, "primary")

  drawToast(py)
end

---------------------------------------------------------------------
-- Tool-Funktionen
---------------------------------------------------------------------
local function init()
  W, H = LCD_W, LCD_H
  local f = getFieldInfo("max")
  maxSrc = f and f.id or 0

  C.bg        = lcd.RGB(22, 24, 28)
  C.bar       = lcd.RGB(40, 44, 52)
  C.btn       = lcd.RGB(62, 68, 80)
  C.btnOff    = lcd.RGB(48, 52, 60)
  C.text      = lcd.RGB(170, 176, 188)
  C.white     = lcd.RGB(255, 255, 255)
  C.black     = lcd.RGB(0, 0, 0)
  C.accent    = lcd.RGB(255, 196, 0)
  C.accentDim = lcd.RGB(180, 135, 0)
  C.on        = lcd.RGB(120, 210, 255)
  C.danger    = lcd.RGB(200, 50, 50)
  C.warn      = lcd.RGB(255, 170, 0)
  C.toast     = lcd.RGB(255, 220, 120)
  C.live      = lcd.RGB(120, 210, 255)
  C.used      = lcd.RGB(80, 220, 110)
  C.case      = lcd.RGB(70, 72, 76)
  C.caseEdge  = lcd.RGB(100, 103, 108)
  C.caseText  = lcd.RGB(120, 123, 128)
  C.hole      = lcd.RGB(38, 40, 43)
  C.slot      = lcd.RGB(45, 47, 50)
  C.metal     = lcd.RGB(200, 200, 205)
  C.xt30      = lcd.RGB(240, 180, 30)
  C.xt30Dark  = lcd.RGB(170, 120, 10)
  C.sig       = lcd.RGB(255, 140, 0)
  C.plus      = lcd.RGB(220, 40, 40)
  C.minus     = lcd.RGB(110, 70, 40)

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
