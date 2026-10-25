-- PortFinder v2.0 for EdgeTX
-- by MisterCreators Custom MOCs (mistercreator.de)
--
-- Shows your RC box on the touchscreen. Tap a port and its channel wiggles,
-- then assign a stick, pot, switch or other source to it right away.
--
-- Install:
--   /SCRIPTS/TOOLS/PortFinder.lua            this tool
--   /SCRIPTS/PortFinder/layouts/*.lua        one file per box (layout)
-- Settings are saved in /SCRIPTS/PortFinder/PortFinder.cfg
--
-- Adding your own box: copy a layout file, change it, put it in the layouts
-- folder. See README.md for the layout format.
local toolName = "TNS|PortFinder|TNE"

local APP_NAME = "PortFinder"
local VERSION  = "v2.0"
local CREDIT   = "by MisterCreators"

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
local CFG = {
  amplitude  = 30,    -- test wiggle in % (added to the current position)
  cycles     = 3,     -- number of back-and-forth moves
  halfPeriod = 25,    -- time per direction in 10 ms
  dir        = "/SCRIPTS/PortFinder",
  -- used when the radio can't list folders
  knownLayouts = { "rcboxmini", "mk60", "mk40" },
}
local CFG_FILE = CFG.dir .. "/PortFinder.cfg"
local LAYOUT_DIR = CFG.dir .. "/layouts"

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
    setupTitle = "Box für dieses Modell", ports = "Ports",
    by = "von ", noLayouts = "Keine Layouts gefunden in",
    saved = "Setup gespeichert für ",
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
    setupTitle = "Box for this model", ports = "ports",
    by = "by ", noLayouts = "No layouts found in",
    saved = "Setup saved for ",
  },
}

local TEMP_MIX = "PFnd"     -- temporary test mix
local OWN_MIX  = "PF"       -- mixes created by the builder
local PER_PAGE = 12         -- source buttons per page (4 x 3)
local SETUP_ROWS = 5        -- setups per page in the setup list

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local W, H
local C = {}
local maxSrc
local lang = "en"
local screen = "warn"       -- "warn" | "main" | "build" | "setup"
local layouts = {}          -- id -> layout table
local setups = {}           -- sorted list of valid setups
local setup                 -- active setup
local modelName = ""
local modelSetups = {}      -- model name -> setup id
local ports = {}
local devs = {}             -- devices of the active setup
local info = {}             -- channel -> { mix, name }
local sel                   -- selected port (index into ports)
local active                -- running wiggle test
local lastPort
local buttons = {}
local exitReq = false
local toast, toastUntil = nil, 0
local setupPage = 1

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
-- Config: language and the setup of each model
---------------------------------------------------------------------
local function loadCfg()
  local hasLang = false
  local f = io.open(CFG_FILE, "r")
  if f then
    local s = io.read(f, 8192) or ""
    io.close(f)
    for line in string.gmatch(s, "[^\r\n]+") do
      local l = string.match(line, "^lang=(%a+)")
      if l == "de" or l == "en" then lang = l; hasLang = true end
      local m, id = string.match(line, "^m:(.-)=([%w_|]+)$")
      if m then modelSetups[m] = id end
    end
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
  local f = io.open(CFG_FILE, "w")
  if f then
    io.write(f, "lang=" .. lang .. "\n")
    for m, id in pairs(modelSetups) do
      io.write(f, "m:" .. m .. "=" .. id .. "\n")
    end
    io.close(f)
  end
end

---------------------------------------------------------------------
-- Layouts and setups
---------------------------------------------------------------------
local function loadLayout(file)
  local chunk = loadScript(LAYOUT_DIR .. "/" .. file)
  if not chunk then return end
  local ok, L = pcall(chunk)
  if ok and type(L) == "table" and L.id and L.ports and L.draw then
    L.channels = L.channels or #L.ports
    L.short = L.short or L.name
    layouts[L.id] = L
  end
end

local function loadLayouts()
  local files = {}
  if dir then
    pcall(function()
      for n in dir(LAYOUT_DIR) do
        if string.match(string.lower(n), "%.lua$") then files[#files + 1] = n end
      end
    end)
  end
  if #files == 0 then
    for _, n in ipairs(CFG.knownLayouts) do files[#files + 1] = n .. ".lua" end
  end
  table.sort(files)
  for _, n in ipairs(files) do loadLayout(n) end

  -- boxes for the setup list; extra boxes only if their layout is installed
  setups = {}
  for _, L in pairs(layouts) do
    if L.selectable ~= false then
      local ex = {}
      for _, e in ipairs(L.extras or {}) do
        if layouts[e.device] then ex[#ex + 1] = e end
      end
      L.extras = ex
      setups[#setups + 1] = L
    end
  end
  table.sort(setups, function(a, b)
    if (a.order or 999) ~= (b.order or 999) then return (a.order or 999) < (b.order or 999) end
    return a.name < b.name
  end)
end

-- the setup is the chosen box plus the extra boxes switched on in the title bar
local extraN = {}

local function setupKey()
  local parts = { setup.id }
  for i = 1, #(setup.extras or {}) do parts[#parts + 1] = tostring(extraN[i] or 0) end
  return table.concat(parts, "|")
end

local function applySetup(L, counts)
  setup = L
  ports, devs, sel, lastPort = {}, {}, nil, nil
  if not L then return end
  extraN = {}
  local list = { L.id }
  for i, e in ipairs(L.extras) do
    local n = math.max(0, math.min(e.max or 1, (counts and counts[i]) or 0))
    extraN[i] = n
    for _ = 1, n do
      if #list < 4 then list[#list + 1] = e.device end
    end
  end
  local count, same = {}, true
  for _, d in ipairs(list) do
    count[d] = (count[d] or 0) + 1
    if d ~= L.id then same = false end
  end
  local start, seen = 1, {}
  for di, id in ipairs(list) do
    local D = layouts[id]
    seen[id] = (seen[id] or 0) + 1
    local title = (same and #list > 1 and L.titles and L.titles[di]) or
      (D.short .. ((count[id] > 1) and (" #" .. seen[id]) or ""))
    devs[di] = { L = D, start = start, title = title }
    for _, p in ipairs(D.ports) do
      ports[#ports + 1] = { dev = di, lp = p, ch = start + p.ch - 1 }
    end
    start = start + D.channels
  end
end

local function saveSetup()
  modelSetups[modelName] = setupKey()
  saveCfg()
end

local function portLabel(p)
  return devs[p.dev].title .. " · " .. p.lp.name
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
-- Drawing helpers handed to the layouts (all coordinates in layout units)
---------------------------------------------------------------------
local function makeG(L, x0, y0, bw)
  local k = bw / L.w
  local g = { k = k, C = C }
  local ox, oy = L.x0 or 0, L.y0 or 0
  function g.PX(px) return F(x0 + (px - ox) * k) end
  function g.PY(py) return F(y0 + (py - oy) * k) end
  local PX, PY = g.PX, g.PY
  function g.R(x1, y1, x2, y2, c)
    local a, b = PX(x1), PY(y1)
    lcd.drawFilledRectangle(a, b, math.max(1, PX(x2) - a), math.max(1, PY(y2) - b), c)
  end
  function g.frame(x1, y1, x2, y2, c, t)
    local a, b = PX(x1), PY(y1)
    lcd.drawRectangle(a, b, math.max(1, PX(x2) - a), math.max(1, PY(y2) - b), c, t or 1)
  end
  function g.line(x1, y1, x2, y2, c)
    lcd.drawLine(PX(x1), PY(y1), PX(x2), PY(y2), SOLID, c)
  end
  -- raised part: shadow, body, highlight on top and left
  function g.raised(r, body, shadow, hi, sh)
    sh = sh or 14
    g.R(r[1] + sh, r[2] + sh, r[3] + sh, r[4] + sh, shadow)
    g.R(r[1], r[2], r[3], r[4], body)
    if hi then
      g.line(r[1], r[2], r[3], r[2], hi)
      g.line(r[1], r[2], r[1], r[4], hi)
    end
  end
  -- square pin, at least 2 pixels
  function g.pin(px, py, s, c)
    local a, b = PX(px - s), PY(py - s)
    local w = math.max(2, PX(px + s) - a)
    lcd.drawFilledRectangle(a, b, w, w, c)
  end
  function g.circle(cx, cy, r, c)
    if lcd.drawFilledCircle then
      lcd.drawFilledCircle(PX(cx), PY(cy), math.max(2, F(r * k)), c)
    else
      g.R(cx - r, cy - r, cx + r, cy + r, c)
    end
  end
  function g.ring(cx, cy, r, c)
    if lcd.drawCircle then
      lcd.drawCircle(PX(cx), PY(cy), math.max(2, F(r * k)), c)
    else
      g.frame(cx - r, cy - r, cx + r, cy + r, c)
    end
  end
  -- triangle corner, dir 1 = top left, 2 = top right
  function g.chamfer(px, py, size, dir, c)
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
  function g.text(px, py, s, flags)
    lcd.drawText(PX(px), PY(py), s, flags or 0)
  end
  return g
end

---------------------------------------------------------------------
-- Devices of the setup
---------------------------------------------------------------------
local function drawDevice(di, x0, y0, bw)
  local d = devs[di]
  local L = d.L
  local g = makeG(L, x0, y0, bw)
  local pulse = (math.floor(getTime() / 15) % 2 == 0)
  local last = d.start + L.channels - 1

  text(x0 + bw / 2, y0 - 16, string.upper(d.title) .. "  (CH" .. d.start .. "-" .. last .. ")",
    CENTER + SMLSIZE + C.text)
  L.draw(g)

  for pi, p in ipairs(ports) do
    if p.dev == di then
      local lp = p.lp
      local isAct = active and active.port == pi
      local h = lp.hit
      if isAct then g.R(h[1], h[2], h[3], h[4], pulse and C.accent or C.accentDim) end
      if L.drawPort then L.drawPort(g, lp, isAct) end

      -- port number: channel or the label printed on the box
      if lp.num then
        local s = (L.numbers == "label") and lp.label or tostring(p.ch)
        local flags = (lp.align == "left") and 0 or CENTER
        local col = isAct and C.black or (L.numColor or C.white)
        text(g.PX(lp.num[1]) + (lp.dx or 0), g.PY(lp.num[2]) - (lp.dy or 7), s, flags + SMLSIZE + col)
      end

      local hx, hy = g.PX(h[1]), g.PY(h[2])
      local hw, hh = g.PX(h[3]) - hx, g.PY(h[4]) - hy
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

-- 1 device big, 2 side by side, 3-4 in a 2 x 2 grid
local function drawDevices(top, bottom)
  local n = #devs
  if n == 0 then
    text(W / 2, top + 40, T("noLayouts"), CENTER + C.white)
    text(W / 2, top + 64, LAYOUT_DIR, CENTER + C.text)
    return
  end
  local cols = (n == 1) and 1 or 2
  local rows = (n <= 2) and 1 or 2
  local labelH = 18
  local gap = 10
  local cellW = (W - gap * (cols + 1)) / cols
  local cellH = (bottom - top - 4) / rows
  for di = 1, n do
    local L = devs[di].L
    local c = (di - 1) % cols
    local r = math.floor((di - 1) / cols)
    local availH = cellH - labelH - 4
    local ratio = L.w / L.h
    local bw = math.min(cellW, availH * ratio)
    local bh = bw / ratio
    local cx = gap + c * (cellW + gap)
    -- a single device in the last row is centered
    if rows == 2 and r == 1 and n == 3 then cx = (W - cellW) / 2 end
    local x0 = cx + (cellW - bw) / 2
    local y0 = top + r * cellH + labelH + (availH - bh) / 2
    drawDevice(di, x0, y0, bw)
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
  text(W / 2, H - 22, APP_NAME .. " " .. VERSION .. "  ·  by MisterCreators Custom MOCs",
    CENTER + SMLSIZE + C.text)
end

local function drawTitleControls()
  button(150, 6, 40, 26, string.upper(lang), function()
    lang = (lang == "de") and "en" or "de"
    saveCfg()
  end, nil, true)

  -- box button: opens the box list
  local x, w = 198, 126
  rect(x, 6, w, 26, C.btn)
  local name = setup and setup.name or "-"
  text(x + 8, 11, name, SMLSIZE + C.white)
  local ax, ay = x + w - 14, 16
  for i = 0, 4 do
    lcd.drawLine(ax - 4 + i, ay + i, ax + 4 - i, ay + i, SOLID, C.white)
  end
  addBtn(x, 0, w, 38, function()
    stopTest()
    setupPage = 1
    for i, s in ipairs(setups) do
      if s == setup then setupPage = math.floor((i - 1) / SETUP_ROWS) + 1 end
    end
    screen = "setup"
  end)

  -- extra boxes: a switch per extra, or a counter when the same box can be added several times
  if not setup then return end
  local ex = setup.extras
  local ex0, exW = x + w + 6, W - 48 - 6 - (x + w + 6)
  local function change(i, n)
    stopTest()
    local counts = {}
    for k = 1, #ex do counts[k] = extraN[k] or 0 end
    counts[i] = n
    applySetup(setup, counts)
    saveSetup()
  end
  if #ex == 1 and (ex[1].max or 1) > 1 then
    local n, max = extraN[1] or 0, ex[1].max
    button(ex0, 6, 28, 26, "-", function() change(1, math.max(0, n - 1)) end, n > 0 and nil or "off")
    rect(ex0 + 30, 6, exW - 60, 26, C.bar)
    text(ex0 + exW / 2, 11, (n + 1) .. "x", CENTER + SMLSIZE + C.white)
    button(ex0 + exW - 28, 6, 28, 26, "+", function() change(1, math.min(max, n + 1)) end,
      n < max and nil or "off")
  elseif #ex > 0 then
    local bw = (exW - 4 * (#ex - 1)) / #ex
    for i, e in ipairs(ex) do
      local on = (extraN[i] or 0) > 0
      button(ex0 + (i - 1) * (bw + 4), 6, bw, 26, e.label, function()
        change(i, on and 0 or 1)
      end, on and "on" or "off", true)
    end
  end
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
  text(12, 21, VERSION .. "  ·  " .. CREDIT, SMLSIZE + C.text)
  drawTitleControls()
  drawDevices(38, H - 54)
  drawBottomBar()
  drawToast(H - 54 - 30)
end

local function drawSetup()
  lcd.clear(C.bg)
  titleBar(T("setupTitle"), function() screen = "main" end)
  local top, rh = 44, 44
  local pages = math.max(1, math.ceil(#setups / SETUP_ROWS))
  if setupPage > pages then setupPage = pages end
  for i = 1, SETUP_ROWS do
    local idx = (setupPage - 1) * SETUP_ROWS + i
    local s = setups[idx]
    if s then
      local y = top + (i - 1) * rh
      local on = (s == setup)
      rect(6, y, W - 12, rh - 4, on and C.on or C.btn)
      local fg = on and C.black or C.white
      text(16, y + 3, s.name, fg)
      text(16, y + 22, T("by") .. (s.author or "?"), SMLSIZE + (on and C.black or C.text))
      text(W - 18, y + 12, s.channels .. " " .. T("ports"), RIGHT + SMLSIZE + fg)
      addBtn(6, y, W - 12, rh - 4, function()
        if s ~= setup then applySetup(s, {}) end
        saveSetup()
        toastMsg(T("saved") .. (modelName ~= "" and modelName or "?"))
        screen = "main"
      end)
    end
  end
  local by = H - 44
  rect(0, by, W, 44, C.bar)
  if pages > 1 then
    text(10, by + 12, setupPage .. " / " .. pages, C.text)
    button(W - 140, by, 65, 44, "<", function() setupPage = (setupPage - 2) % pages + 1 end)
    button(W - 70, by, 70, 44, ">", function() setupPage = setupPage % pages + 1 end)
  end
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

  loadCfg()
  loadLayouts()
  local mi = model.getInfo and model.getInfo()
  modelName = (mi and mi.name) or ""
  -- saved as "box|extra1|extra2", e.g. "mk60|1|0"
  local want = modelSetups[modelName] or ""
  local id = string.match(want, "^([%w_]+)")
  local counts = {}
  for n in string.gmatch(string.sub(want, #(id or "") + 1), "|(%d+)") do counts[#counts + 1] = tonumber(n) end
  local chosen = setups[1]
  for _, s in ipairs(setups) do
    if s.id == id then chosen = s end
  end
  applySetup(chosen, counts)
  buildSources()
  cleanupTemp()
  refreshAll()
end

local function run(event, touchState)
  if event == EVT_VIRTUAL_EXIT then
    if screen == "build" or screen == "setup" then
      stopTest()
      screen = "main"
      event = 0
    else
      exitReq = true
    end
  end

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
  elseif screen == "setup" then
    drawSetup()
  else
    drawBuild()
  end
  return 0
end

return { init = init, run = run }
