--!nonstrict
-- Quick popup above the bar icon: one row per favourite, click to flip it.

local C = require("./common.luau")

-- Every node reports enter/leave; the widget waits a short grace period after
-- a leave, so moving between rows never closes the popup.
local function onHover(state)
  noctalia.state.set("popupHovered", state == "true")
end

local function openManager()
  -- Set before closing: our onClose clears popupHovered, which starts the
  -- widget's close timer, and the widget must already know the manager is up.
  noctalia.state.set("managerOpen", true)
  panel.close()
  noctalia.togglePanel(C.MANAGER)
end

local function render()
  local apps = noctalia.state.get("apps")
  local rows = {}

  table.insert(rows, ui.row({ gap = 8, align = "center", paddingH = 4, onHover = onHover }, {
    ui.glyph({ name = "arrows-split-2", size = 16, color = "primary" }),
    ui.label({ text = "Split tunnel", fontWeight = "semibold", flexGrow = 1 }),
  }))

  if apps == nil then
    table.insert(rows, ui.label({ text = "Loading…", color = "on_surface_variant" }))
  elseif #apps == 0 then
    table.insert(rows, ui.label({
      text = "No favourites yet.",
      color = "on_surface_variant",
    }))
  else
    for _, app in ipairs(apps) do
      table.insert(rows, ui.row({
        key = app.name,
        gap = 10,
        align = "center",
        padding = 8,
        radius = 8,
        fill = app.state == "excluded" and "primary/0.10" or "surface_container",
        tooltip = app.state == "stopped" and "Starts the app outside the VPN" or nil,
        onHover = onHover,
        onClick = function()
          C.toggle(app.name)
        end,
      }, C.appRow(app)))
    end
  end

  table.insert(rows, ui.row({ justify = "center", onHover = onHover }, {
    ui.button({
      glyph = (apps ~= nil and #apps == 0) and "plus" or "settings",
      text = (apps ~= nil and #apps == 0) and "Add favourites" or "Manage favourites",
      variant = (apps ~= nil and #apps == 0) and "primary" or "ghost",
      controlSize = "sm",
      -- The button takes the hover from the row around it, so report it too.
      onHover = onHover,
      onClick = openManager,
    }),
  }))

  panel.render(ui.column({ gap = 6, padding = 10, onHover = onHover }, rows))
end

noctalia.state.watch("apps", render)

function onOpen()
  noctalia.state.set("popupOpen", true)
  render()
  C.refresh()
end

function onClose()
  noctalia.state.set("popupOpen", false)
  noctalia.state.set("popupHovered", false)
end
