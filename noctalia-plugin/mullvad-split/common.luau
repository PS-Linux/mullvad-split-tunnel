--!nonstrict
-- Shared helpers: talks to the mullvad-split-menu script and keeps the app
-- list in plugin state ("apps") so the widget and both panels stay in sync.

local M = {}

M.SCRIPT = noctalia.expandPath("~/.local/bin/mullvad-split-menu")
M.POPUP = "ps/mullvad-split:popup"
M.MANAGER = "ps/mullvad-split:manager"

function M.run(args, onDone)
  local argv = { M.SCRIPT }
  for _, a in ipairs(args) do
    table.insert(argv, a)
  end
  noctalia.runAsync(argv, function(result)
    if result.exitCode ~= 0 and result.stderr ~= "" then
      noctalia.notifyError("Mullvad split tunnel", result.stderr)
    end
    if onDone then
      onDone(result)
    end
  end, 15000)
end

function M.refresh()
  M.run({ "status" }, function(result)
    local apps = noctalia.json.decode(result.stdout or "")
    if type(apps) == "table" then
      noctalia.state.set("apps", apps)
    end
  end)
end

-- Flip one app; shows it as "pending" until the script reports back.
function M.toggle(name)
  local apps = noctalia.state.get("apps") or {}
  for _, app in ipairs(apps) do
    if app.name == name then
      app.state = "pending"
    end
  end
  noctalia.state.set("apps", apps)
  M.run({ "toggle", name }, function()
    M.refresh()
  end)
end

function M.anyExcluded(apps)
  for _, app in ipairs(apps or {}) do
    if app.state == "excluded" then
      return true
    end
  end
  return false
end

M.STATUS_TEXT = {
  excluded = "Bypassing VPN",
  running = "Through VPN",
  stopped = "Not running · starts outside VPN",
  pending = "Switching…",
}

function M.icon(app)
  return noctalia.appIconPath(app.name, 32)
    or noctalia.appIconPath(string.lower(app.name), 32)
    or noctalia.appIconPath(app.proc or "", 32)
end

-- A small on/off switch drawn from boxes, so the whole row stays one click
-- and hover target (a real ui.toggle would swallow both).
function M.switch(on, pending)
  return ui.row({
    width = 34,
    height = 20,
    radius = 10,
    padding = 2,
    fill = on and "primary" or "outline_variant",
    opacity = pending and 0.5 or 1,
    justify = on and "end" or "start",
    align = "center",
  }, {
    ui.box({ width = 16, height = 16, radius = 8, fill = on and "on_primary" or "surface" }),
  })
end

-- One favourite: icon, name, status line, switch.
function M.appRow(app, extra)
  local icon = M.icon(app)
  local children = {
    icon and ui.image({ path = icon, width = 22, height = 22, fit = "contain" })
      or ui.glyph({ name = "app-window", size = 20, color = "on_surface_variant" }),
    ui.column({ gap = 1, flexGrow = 1 }, {
      ui.label({ text = app.name, fontWeight = "medium" }),
      ui.label({
        text = M.STATUS_TEXT[app.state] or app.state,
        fontSize = 11,
        color = app.state == "excluded" and "primary" or "on_surface_variant",
        maxLines = 1,
      }),
    }),
    M.switch(app.state == "excluded", app.state == "pending"),
  }
  if extra then
    table.insert(children, extra)
  end
  return children
end

return M
