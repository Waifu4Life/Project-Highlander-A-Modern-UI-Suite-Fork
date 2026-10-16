-- Window focus on launch.
--
-- When the game is started from outside the Recomp launcher (our frontend,
-- Playnite, a shortcut with -red / -blue ...), Windows often refuses to hand
-- the new game window the keyboard focus: the window appears, but key
-- presses and gamepad input keep going to whatever had focus before until
-- the player clicks the window.
--
-- 3.52.0 trusted LÖVE's own "has focus" flag, which can say yes while
-- Windows still has another program in the foreground, and it looked the
-- window up by its title. This version finds the game window through the
-- game's own process, checks the real Windows foreground window, and uses
-- the stronger "attach to the foreground thread" method. Every step is
-- written to the log as "Window focus: ...".
--
-- It only acts during the first seconds after start-up, so alt-tabbing away
-- later is never undone.
return function(mod)
  if not (love and love.window) then return end

  local ATTEMPTS = { 0.3, 1.0, 2.0, 3.5, 5.5 } -- seconds after first update
  local GIVE_UP = 9.0
  local clock, nextAttempt, finished, reported = 0, 1, false, false

  local function log(fmt, ...)
    local logger = mod.log
    if not logger then return end
    local fn = logger.warn or logger.info
    if fn then pcall(fn, logger, "Window focus: " .. fmt, ...) end
  end

  local okFfi, ffi = pcall(require, "ffi")
  if not okFfi or type(ffi) ~= "table" then ffi = nil end

  local isWindows = love.system and love.system.getOS
    and love.system.getOS() == "Windows"

  local user32, kernel32, hwnd
  if ffi and isWindows then
    pcall(ffi.cdef, [[
      typedef void *HWND;
      typedef int (__stdcall *HL_ENUMPROC)(HWND, intptr_t);
      int EnumThreadWindows(uint32_t thread, HL_ENUMPROC fn, intptr_t lp);
      uint32_t GetCurrentThreadId(void);
      HWND GetForegroundWindow(void);
      uint32_t GetWindowThreadProcessId(HWND hwnd, uint32_t *pid);
      int AttachThreadInput(uint32_t from, uint32_t to, int attach);
      int IsWindowVisible(HWND hwnd);
      int IsIconic(HWND hwnd);
      int ShowWindow(HWND hwnd, int cmd);
      int SetForegroundWindow(HWND hwnd);
      int BringWindowToTop(HWND hwnd);
      HWND SetFocus(HWND hwnd);
      HWND SetActiveWindow(HWND hwnd);
      int SetWindowPos(HWND hwnd, HWND after, int x, int y, int cx, int cy,
        unsigned int flags);
      void keybd_event(uint8_t vk, uint8_t scan, uint32_t flags, uintptr_t extra);
    ]])
    local ok1, u = pcall(ffi.load, "user32")
    local ok2, k = pcall(ffi.load, "kernel32")
    if ok1 and ok2 then user32, kernel32 = u, k end
  end

  -- The LÖVE window is created on this (the main) thread, so the visible
  -- window owned by this thread is the game window.
  local function findWindow()
    if hwnd ~= nil or not user32 then return hwnd end
    pcall(function()
      local found
      local cb = ffi.cast("HL_ENUMPROC", function(h)
        if user32.IsWindowVisible(h) ~= 0 then found = h return 0 end
        return 1
      end)
      user32.EnumThreadWindows(kernel32.GetCurrentThreadId(), cb, 0)
      cb:free()
      hwnd = found
    end)
    return hwnd
  end

  local function windowsHasFocus()
    local h = findWindow()
    if not h then return nil end
    return user32.GetForegroundWindow() == h
  end

  local function hasFocus()
    if user32 then
      local fg = windowsHasFocus()
      if fg ~= nil then return fg end
    end
    return love.window.hasFocus and love.window.hasFocus() or false
  end

  local function forceForeground()
    local h = findWindow()
    if not h then return false end
    local ok = pcall(function()
      local SW_RESTORE, SW_SHOW = 9, 5
      local HWND_TOPMOST = ffi.cast("HWND", -1)
      local HWND_NOTOPMOST = ffi.cast("HWND", -2)
      local SWP_NOMOVE, SWP_NOSIZE = 0x0002, 0x0001
      if user32.IsIconic(h) ~= 0 then user32.ShowWindow(h, SW_RESTORE) end
      local fg = user32.GetForegroundWindow()
      local mine = kernel32.GetCurrentThreadId()
      local theirs = fg ~= nil and user32.GetWindowThreadProcessId(fg, nil) or 0
      local attached = theirs ~= 0 and theirs ~= mine
        and user32.AttachThreadInput(mine, theirs, 1) ~= 0
      -- A tapped ALT counts as user input and lifts the foreground lock.
      user32.keybd_event(0x12, 0, 0, 0)
      user32.keybd_event(0x12, 0, 0x0002, 0)
      user32.SetWindowPos(h, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE + SWP_NOSIZE)
      user32.SetWindowPos(h, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE + SWP_NOSIZE)
      user32.ShowWindow(h, SW_SHOW)
      user32.BringWindowToTop(h)
      user32.SetForegroundWindow(h)
      user32.SetActiveWindow(h)
      user32.SetFocus(h)
      if attached then user32.AttachThreadInput(mine, theirs, 0) end
    end)
    return ok
  end

  -- Used when the Windows calls aren't available: Windows activates a
  -- window its own program restores from the taskbar.
  local function minimizeRestore()
    if not (love.window.minimize and love.window.restore) then return end
    pcall(love.window.minimize)
    pcall(love.window.restore)
  end

  local function attempt(n)
    if user32 then
      forceForeground()
    else
      minimizeRestore()
    end
    return hasFocus()
  end

  mod.hooks:wrap("core.update", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    if finished then return result end
    if not reported then
      reported = true
      log("start (ffi %s, Windows calls %s, window %s, has focus %s)",
        ffi and "yes" or "no", user32 and "yes" or "no",
        findWindow() and "found" or "not found", tostring(hasFocus()))
    end
    clock = clock + (tonumber(dt) or 0)
    if hasFocus() then
      if nextAttempt > 1 then
        log("focus taken after %d tries", nextAttempt - 1)
      end
      finished = true
      return result
    end
    if clock >= GIVE_UP or nextAttempt > #ATTEMPTS then
      finished = true
      log("could not take focus after %d tries", nextAttempt - 1)
      return result
    end
    if clock >= ATTEMPTS[nextAttempt] then
      attempt(nextAttempt)
      nextAttempt = nextAttempt + 1
    end
    return result
  end)
end
