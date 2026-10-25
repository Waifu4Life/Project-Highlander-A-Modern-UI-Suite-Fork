-- Screen Ratio: makes the whole game run in a 16:9 area on screens with
-- another shape (Steam Deck 16:10, phones around 19.5:9, ultrawide monitors).
--
-- How it works:
--   * The game is told the window is the largest 16:9 rectangle that fits
--     the real screen (love.graphics.getDimensions and friends report that
--     size), so every widescreen and Dynamic UI layout lays itself out for
--     16:9 without any per-screen changes.
--   * Everything the game would draw to the screen is drawn into a canvas of
--     exactly that size instead. At the end of the frame the canvas is copied
--     1:1 (no stretching or blurring) into the middle of the real screen, with
--     black bars around it.
--   * Mouse and touch positions are shifted into the 16:9 area, so taps and
--     clicks still land where they look like they land.
--
-- It is a SCREEN RATIO row in the Custom Borders sub-menu and works whether
-- the Custom Borders border art is on or off. Portrait windows are left
-- alone (the game has its own portrait layouts). If anything goes wrong while
-- compositing, it switches itself off for the rest of the session and logs
-- why, rather than leaving a broken picture.
return function(mod)
  if type(love) ~= "table" or type(love.graphics) ~= "table" then return end
  local G = love.graphics
  if G.__phScreenRatio then return end
  G.__phScreenRatio = true

  local RATIOS = { ["16:9"] = 16 / 9 }
  local unpack = unpack or table.unpack
  local function pack(...) return { n = select("#", ...), ... } end

  local real = {
    getDimensions = G.getDimensions,
    getWidth = G.getWidth,
    getHeight = G.getHeight,
    getPixelDimensions = G.getPixelDimensions,
    getPixelWidth = G.getPixelWidth,
    getPixelHeight = G.getPixelHeight,
    setCanvas = G.setCanvas,
    getCanvas = G.getCanvas,
    present = G.present,
    reset = G.reset,
    origin = G.origin,
    clear = G.clear,
  }

  -- Live state. on = compositing this frame; x/y = where the 16:9 area sits
  -- on the real screen; w/h = its size (what the game is told).
  local S = { on = false, x = 0, y = 0, w = 0, h = 0, rw = 0, rh = 0,
    canvas = nil, target = nil, broken = false, poll = 0,
    -- active = drawing is aimed at the canvas right now (only ever between
    -- the start of a frame's drawing and its present). presentSeen = the game
    -- presents through love.graphics.present, so we get to composite and
    -- step off the canvas every frame. Without that, nothing switches on.
    active = false, presentSeen = false,
    -- route = how frames end for us: "present" (love.graphics.present, the
    -- desktop/Deck path) or "hook" (the game's own render.present mod hook,
    -- for builds such as the phone one that present through their own copy).
    -- frameOpen = the hook route may take the canvas this frame (set when
    -- the game's update runs, cleared when the frame ends at the hook).
    route = nil, frameOpen = false, hookCount = 0, updateCount = 0,
    pairedFrames = 0, reason = nil, started = nil }

  local function log(fmt, ...)
    pcall(mod.log.info, mod.log, "Screen Ratio: " .. fmt, ...)
  end

  local function wantedRatio()
    local ok, value = pcall(mod.options.get, mod.options, "screen_ratio")
    return ok and RATIOS[value] or nil
  end

  -- The 16:9 rectangle for the current real window, or nil for "leave it".
  local function targetRect()
    S.reason = nil
    if S.broken then S.reason = "error"; return nil end
    local ratio = wantedRatio()
    if not ratio then return nil end
    local rw, rh = real.getDimensions()
    if not (rw and rh) or rw <= 0 or rh <= 0 then return nil end
    if rw < rh then S.reason = "portrait"; return nil end
    local w, h
    if rw / rh > ratio then
      h = rh
      w = math.floor(rh * ratio + 0.5)
    else
      w = rw
      h = math.floor(rw / ratio + 0.5)
    end
    -- Already 16:9 (within a couple of pixels): nothing to do.
    if rw - w <= 2 and rh - h <= 2 then S.reason = "fits"; return nil end
    return math.floor((rw - w) / 2), math.floor((rh - h) / 2), w, h, rw, rh
  end

  -- Tell the game its window "changed size" so anything that lays itself
  -- out on resize does so again. Uses the game's own resize callback.
  local origResizeHandler
  local function announceResize()
    local w, h = G.getDimensions()
    if origResizeHandler then
      pcall(origResizeHandler, w, h)
    elseif type(love.resize) == "function" then
      pcall(love.resize, w, h)
    end
  end

  -- Re-check the option and window. Returns true when the game's view of the
  -- window size changed. Call only between frames.
  local function refresh()
    local x, y, w, h, rw, rh
    if S.route then x, y, w, h, rw, rh = targetRect() end
    if not x then
      if not S.on then return false end
      if S.active then real.setCanvas(); S.active = false end
      S.on, S.canvas, S.target = false, nil, nil
      log("off")
      return true
    end
    if S.on and w == S.w and h == S.h and x == S.x and y == S.y then
      return false
    end
    local sizeChanged = not S.on or w ~= S.w or h ~= S.h
    if sizeChanged then
      local ok, canvas = pcall(G.newCanvas, w, h)
      if not ok or not canvas then
        S.broken = true
        log("could not make a %dx%d canvas (%s); turned off", w, h, tostring(canvas))
        if S.active then real.setCanvas(); S.active = false end
        S.on, S.canvas, S.target = false, nil, nil
        return true
      end
      pcall(canvas.setFilter, canvas, "nearest", "nearest")
      S.canvas = canvas
      S.target = { canvas, stencil = true }
    end
    if S.active then real.setCanvas(); S.active = false end
    S.on, S.x, S.y, S.w, S.h, S.rw, S.rh = true, x, y, w, h, rw, rh
    log("%dx%d area at %d,%d on a %dx%d screen", w, h, x, y, rw, rh)
    return sizeChanged
  end

  ---------------------------------------------------------------------------
  -- What the game is told about the window
  ---------------------------------------------------------------------------
  G.getDimensions = function()
    if S.on then return S.w, S.h end
    return real.getDimensions()
  end
  G.getWidth = function()
    if S.on then return S.w end
    return real.getWidth()
  end
  G.getHeight = function()
    if S.on then return S.h end
    return real.getHeight()
  end

  local function pixelScale()
    local ok, dpi = pcall(G.getDPIScale)
    return (ok and type(dpi) == "number" and dpi > 0) and dpi or 1
  end
  if real.getPixelDimensions then
    G.getPixelDimensions = function()
      if S.on then
        local d = pixelScale()
        return math.floor(S.w * d + 0.5), math.floor(S.h * d + 0.5)
      end
      return real.getPixelDimensions()
    end
  end
  if real.getPixelWidth then
    G.getPixelWidth = function()
      if S.on then return math.floor(S.w * pixelScale() + 0.5) end
      return real.getPixelWidth()
    end
  end
  if real.getPixelHeight then
    G.getPixelHeight = function()
      if S.on then return math.floor(S.h * pixelScale() + 0.5) end
      return real.getPixelHeight()
    end
  end

  local W = love.window
  if type(W) == "table" then
    local realGetMode = W.getMode
    if type(realGetMode) == "function" then
      -- getMode can use window units rather than graphics units, so scale
      -- proportionally instead of returning S.w/S.h directly.
      W.getMode = function(...)
        local w, h, flags = realGetMode(...)
        if S.on and S.rw > 0 and S.rh > 0 and w and h then
          return math.floor(w * S.w / S.rw + 0.5), math.floor(h * S.h / S.rh + 0.5), flags
        end
        return w, h, flags
      end
    end
    local realSafeArea = W.getSafeArea
    if type(realSafeArea) == "function" then
      -- The notch-free part of the screen, clipped to the 16:9 area and
      -- given relative to it.
      W.getSafeArea = function(...)
        local x, y, w, h = realSafeArea(...)
        if not (S.on and x and y and w and h) then return x, y, w, h end
        local x0 = math.max(x, S.x)
        local y0 = math.max(y, S.y)
        local x1 = math.min(x + w, S.x + S.w)
        local y1 = math.min(y + h, S.y + S.h)
        return x0 - S.x, y0 - S.y, math.max(0, x1 - x0), math.max(0, y1 - y0)
      end
    end
  end

  ---------------------------------------------------------------------------
  -- Drawing: "the screen" means the 16:9 canvas while this is on
  ---------------------------------------------------------------------------
  -- Aim drawing at the 16:9 canvas. Happens on the frame's first draw to
  -- "the screen" (love.run's origin/clear, or the game switching back from
  -- its own canvas) and lasts until present, so the canvas is never active
  -- while the game reads input between frames.
  local function activate()
    if S.route == "hook" and not S.frameOpen then return end
    if S.on and not S.active and S.target then
      real.setCanvas(S.target)
      S.active = true
    end
  end

  G.setCanvas = function(...)
    if S.on and (select("#", ...) == 0 or (...) == nil) then
      activate()
      if S.active then return real.setCanvas(S.target) end
    end
    return real.setCanvas(...)
  end

  G.getCanvas = function(...)
    local first = real.getCanvas(...)
    if S.active and first ~= nil and first == S.canvas then return nil end
    return real.getCanvas(...)
  end

  G.origin = function(...)
    if S.on and not S.active and real.getCanvas() == nil then activate() end
    return real.origin(...)
  end

  G.clear = function(...)
    if S.on and not S.active and real.getCanvas() == nil then activate() end
    return real.clear(...)
  end

  if type(real.reset) == "function" then
    G.reset = function(...)
      local a, b, c, d = real.reset(...)
      if S.active then real.setCanvas(S.target) end
      return a, b, c, d
    end
  end

  local function composite()
    real.setCanvas()
    S.active = false
    G.push("all")
    real.origin()
    G.setScissor()
    G.setShader()
    real.clear(0, 0, 0, 1)
    G.setBlendMode("alpha", "premultiplied")
    G.setColor(1, 1, 1, 1)
    G.draw(S.canvas, S.x, S.y)
    G.pop()
  end

  -- End of a frame, from whichever route this game uses: copy the 16:9
  -- canvas to the real screen, step off the canvas, and every few frames
  -- pick up option and window changes.
  local function endFrame()
    if S.active and S.canvas then
      local ok, err = pcall(composite)
      if not ok then
        S.broken = true
        S.on, S.canvas, S.target = false, nil, nil
        log("compositing failed (%s); turned off", tostring(err))
      end
    end
    -- Whatever happened above, the canvas is never left active past here.
    if S.active then pcall(real.setCanvas); S.active = false end
    S.frameOpen = false
    S.poll = S.poll - 1
    if S.poll <= 0 then
      S.poll = 10
      if refresh() then announceResize() end
    end
  end

  G.present = function(...)
    if not S.presentSeen then
      S.presentSeen = true
      if S.route ~= "present" then
        if S.active then pcall(real.setCanvas); S.active = false end
        S.route = "present"
        log("frames end at love.graphics.present")
      end
    end
    if S.route == "present" then
      -- Composite before the real present; refresh after it (below).
      if S.active and S.canvas then
        local ok, err = pcall(composite)
        if not ok then
          S.broken = true
          S.on, S.canvas, S.target = false, nil, nil
          log("compositing failed (%s); turned off", tostring(err))
        end
      end
      if S.active then pcall(real.setCanvas); S.active = false end
    end
    local a, b, c, d = real.present(...)
    if S.route == "present" then
      S.poll = S.poll - 1
      if S.poll <= 0 then
        S.poll = 10
        if refresh() then announceResize() end
      end
    end
    return a, b, c, d
  end

  ---------------------------------------------------------------------------
  -- Second route: the game's own mod hooks. Used only when the game never
  -- calls love.graphics.present through the table (phone builds). These are
  -- installed on the suite's own hook table, so they run even while the
  -- Custom Borders art is switched off.
  ---------------------------------------------------------------------------
  local parent = getmetatable(mod) and getmetatable(mod).__index
  local parentHooks = type(parent) == "table" and parent.hooks or nil
  local NEEDED_FRAMES = 60    -- update + render.present pairs before trusting it

  if parentHooks and type(parentHooks.wrap) == "function" then
    pcall(function()
      parentHooks:wrap("core.update", function(nextFn, ...)
        S.updateCount = S.updateCount + 1
        if not S.presentSeen then
          if S.frameOpen and S.route ~= "hook" then
            -- Last frame never reached render.present: not steady yet.
            S.pairedFrames = 0
          end
          S.frameOpen = true
        end
        return nextFn(...)
      end, 100000)
    end)
    pcall(function()
      parentHooks:wrap("render.present", function(nextFn, ...)
        local results = pack(pcall(nextFn, ...))
        S.hookCount = S.hookCount + 1
        if not S.presentSeen then
          if S.route ~= "hook" then
            if S.frameOpen then S.pairedFrames = S.pairedFrames + 1 end
            S.frameOpen = false
            if S.pairedFrames >= NEEDED_FRAMES then
              S.route = "hook"
              log("frames end at the game's render.present hook")
              S.poll = 0
              if refresh() then announceResize() end
            end
          else
            endFrame()
          end
        end
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2, results.n)
      end, 100000)
    end)
  end

  ---------------------------------------------------------------------------
  -- LOVE refuses a few calls while any canvas is active (event pumping and
  -- window mode changes). The canvas is already off between frames; this
  -- covers those calls if a game makes them in the middle of drawing.
  ---------------------------------------------------------------------------
  local function offCanvas(orig)
    return function(...)
      if not S.active then return orig(...) end
      real.setCanvas()
      local results = pack(pcall(orig, ...))
      if S.active and S.target then real.setCanvas(S.target) end
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2, results.n)
    end
  end
  local E = love.event
  if type(E) == "table" then
    if type(E.pump) == "function" then E.pump = offCanvas(E.pump) end
    if type(E.wait) == "function" then E.wait = offCanvas(E.wait) end
  end
  if type(W) == "table" then
    for _, name in ipairs({ "setMode", "updateMode", "setFullscreen", "close" }) do
      if type(W[name]) == "function" then W[name] = offCanvas(W[name]) end
    end
  end

  ---------------------------------------------------------------------------
  -- Input: shift mouse and touch positions into the 16:9 area
  ---------------------------------------------------------------------------
  local H = love.handlers
  if type(H) == "table" then
    local function wrapXY(name, xIndex)
      local orig = H[name]
      if type(orig) ~= "function" then return end
      H[name] = function(...)
        if not S.on then return orig(...) end
        local args = { n = select("#", ...), ... }
        if type(args[xIndex]) == "number" then args[xIndex] = args[xIndex] - S.x end
        if type(args[xIndex + 1]) == "number" then args[xIndex + 1] = args[xIndex + 1] - S.y end
        return orig(unpack(args, 1, args.n))
      end
    end
    wrapXY("mousepressed", 1)
    wrapXY("mousereleased", 1)
    wrapXY("mousemoved", 1)       -- dx, dy are relative: left as-is
    wrapXY("touchpressed", 2)     -- (id, x, y, dx, dy, pressure)
    wrapXY("touchreleased", 2)
    wrapXY("touchmoved", 2)

    origResizeHandler = H.resize
    if type(origResizeHandler) == "function" then
      H.resize = function(w, h, ...)
        refresh()
        if S.on then return origResizeHandler(S.w, S.h, ...) end
        return origResizeHandler(w, h, ...)
      end
    end
  end

  local M = love.mouse
  if type(M) == "table" then
    local getPosition, getX, getY, setPosition = M.getPosition, M.getX, M.getY, M.setPosition
    if type(getPosition) == "function" then
      M.getPosition = function()
        local x, y = getPosition()
        if S.on then return x - S.x, y - S.y end
        return x, y
      end
    end
    if type(getX) == "function" then
      M.getX = function()
        local x = getX()
        if S.on then return x - S.x end
        return x
      end
    end
    if type(getY) == "function" then
      M.getY = function()
        local y = getY()
        if S.on then return y - S.y end
        return y
      end
    end
    if type(setPosition) == "function" then
      M.setPosition = function(x, y)
        if S.on and type(x) == "number" and type(y) == "number" then
          return setPosition(x + S.x, y + S.y)
        end
        return setPosition(x, y)
      end
    end
  end

  local T = love.touch
  if type(T) == "table" and type(T.getPosition) == "function" then
    local getTouch = T.getPosition
    T.getPosition = function(id)
      local x, y = getTouch(id)
      if S.on and x and y then return x - S.x, y - S.y end
      return x, y
    end
  end

  -- Nothing switches on here: the first present picks up the option and
  -- announces the new size; the frame after that is the first one drawn
  -- into the canvas.
  -- What the SCREEN RATIO row shows, so a phone (where the log can't be
  -- read) still says why it isn't working. Kept to 13 characters or fewer.
  S.started = (love.timer and love.timer.getTime) and love.timer.getTime() or 0
  mod.exports.screenRatioLabel = function()
    if not wantedRatio() then return "OFF" end
    if S.broken then return "16:9 ERROR" end
    if S.on then return "16:9" end
    if not S.route then
      local now = (love.timer and love.timer.getTime) and love.timer.getTime() or 0
      if now - (S.started or 0) < 5 then return "16:9 WAITING" end
      return "16:9 NO FRAME"
    end
    if S.reason == "portrait" then return "16:9 PORTRAIT" end
    if S.reason == "fits" then return "16:9 FITS" end
    return "16:9 WAITING"
  end

  mod.exports.screenRatioRect = function()
    if not S.on then return nil end
    return { x = S.x, y = S.y, w = S.w, h = S.h }
  end
  log("ready")
end
