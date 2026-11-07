--!nonstrict
-- Bar icon. Right click opens the quick popup above it; left click opens the
-- manager.

local C = require("./common.luau")

-- Clicking the icon while a panel is open also counts as an outside click,
-- which may close it just before our click handler runs. Don't reopen it then.
local REOPEN_GUARD_MS = 250
local POLL_MS = 5000

local lastPoll = 0

local function render()
  barWidget.setGlyph("arrows-split-2")
  -- Highlight the icon while any app is bypassing the VPN.
  barWidget.setGlyphColor(C.anyExcluded(noctalia.state.get("apps")) and "primary" or "on_surface")
end

local function justClosed(key)
  return noctalia.nowMs() - (noctalia.state.get(key) or 0) < REOPEN_GUARD_MS
end

noctalia.state.watch("apps", render)

function update()
  local now = noctalia.nowMs()
  if now - lastPoll >= POLL_MS then
    lastPoll = now
    C.refresh()
  end
  noctalia.setUpdateInterval(POLL_MS)
  render()
end

function onRightClick()
  if noctalia.state.get("popupOpen") == true or not justClosed("popupClosedAt") then
    noctalia.togglePanel(C.POPUP)
  end
end

function onClick()
  if noctalia.state.get("popupOpen") == true then
    noctalia.togglePanel(C.POPUP)
  end
  if noctalia.state.get("managerOpen") == true or not justClosed("managerClosedAt") then
    noctalia.togglePanel(C.MANAGER)
  end
end
