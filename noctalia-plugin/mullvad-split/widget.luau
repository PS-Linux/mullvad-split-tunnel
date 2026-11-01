--!nonstrict
-- Bar icon. Hover opens the quick popup above it; click opens the manager.
-- The popup reports its own hover state ("popupHovered"), and the popup closes
-- once neither the icon nor the popup has been hovered for CLOSE_GRACE_MS.

local C = require("./common.luau")

local CLOSE_GRACE_MS = 350
local POLL_MS = 5000

local hoverIcon, hoverPopup, popupOpen, managerOpen = false, false, false, false
local closeAt = nil
local suppressUntilLeave = false
local lastPoll = 0

local function render()
  barWidget.setGlyph("arrows-split-2")
  -- Highlight the icon while any app is bypassing the VPN.
  barWidget.setGlyphColor(C.anyExcluded(noctalia.state.get("apps")) and "primary" or "on_surface")
end

local function openPopup()
  if not popupOpen then
    popupOpen = true
    noctalia.togglePanel(C.POPUP)
  end
end

local function closePopup()
  if popupOpen then
    popupOpen = false
    noctalia.togglePanel(C.POPUP)
  end
end

local function scheduleClose()
  closeAt = noctalia.nowMs() + CLOSE_GRACE_MS
  noctalia.setUpdateInterval(50)
end

noctalia.state.watch("apps", render)
noctalia.state.watch("popupOpen", function(open)
  popupOpen = open == true
end)
-- Opening the manager makes the pointer leave and re-enter the icon; without
-- this the hover popup would reopen and replace the manager straight away.
noctalia.state.watch("managerOpen", function(open)
  managerOpen = open == true
end)
noctalia.state.watch("popupHovered", function(hovered)
  hoverPopup = hovered == true
  if hoverPopup then
    closeAt = nil
  else
    scheduleClose()
  end
end)

function update()
  local now = noctalia.nowMs()
  if closeAt and now >= closeAt then
    closeAt = nil
    if not hoverIcon and not hoverPopup then
      closePopup()
    end
  end
  if now - lastPoll >= POLL_MS then
    lastPoll = now
    C.refresh()
  end
  noctalia.setUpdateInterval(closeAt and 50 or POLL_MS)
  render()
end

function onHover(entered)
  hoverIcon = entered
  if entered then
    closeAt = nil
    if not suppressUntilLeave and not managerOpen then
      openPopup()
    end
  else
    suppressUntilLeave = false
    scheduleClose()
  end
end

function onClick()
  suppressUntilLeave = true
  closeAt = nil
  closePopup()
  managerOpen = not managerOpen
  noctalia.togglePanel(C.MANAGER)
end
