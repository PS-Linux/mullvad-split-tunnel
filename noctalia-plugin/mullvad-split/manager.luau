--!nonstrict
-- Full manager: switch favourites, remove them, add open apps as favourites.

local C = require("./common.luau")

local windows = nil

local function loadWindows()
  C.run({ "windows" }, function(result)
    windows = noctalia.json.decode(result.stdout or "") or {}
    render()
  end)
end

local function isFavourite(class, apps)
  local short = string.match(class, "([^%.]+)$") or class
  for _, app in ipairs(apps or {}) do
    if app.name == short then
      return true
    end
  end
  return false
end

local function sectionTitle(text)
  return ui.label({ text = text, fontWeight = "semibold", color = "on_surface_variant", fontSize = 12 })
end

function render()
  local apps = noctalia.state.get("apps")
  local body = {}

  table.insert(body, sectionTitle("FAVOURITES"))
  if apps == nil then
    table.insert(body, ui.label({ text = "Loading…", color = "on_surface_variant" }))
  elseif #apps == 0 then
    table.insert(body, ui.label({ text = "None yet. Add an open app below.", color = "on_surface_variant" }))
  else
    for _, app in ipairs(apps) do
      table.insert(body, ui.row({
        key = "fav-" .. app.name,
        gap = 10,
        align = "center",
        padding = 8,
        radius = 8,
        fill = app.state == "excluded" and "primary/0.10" or "surface_container",
        onClick = function()
          C.toggle(app.name)
        end,
      }, C.appRow(app, ui.button({
        glyph = "trash",
        variant = "ghost",
        controlSize = "sm",
        tooltip = "Remove from favourites",
        onClick = function()
          C.run({ "remove", app.name }, function()
            C.refresh()
          end)
        end,
      }))))
    end
  end

  table.insert(body, ui.separator({ spacing = 6 }))
  table.insert(body, sectionTitle("ADD FROM OPEN WINDOWS"))
  local offered = 0
  for _, win in ipairs(windows or {}) do
    if not isFavourite(win.class, apps) then
      offered += 1
      local icon = noctalia.appIconPath(win.class, 32)
      table.insert(body, ui.row({ key = "win-" .. win.class, gap = 10, align = "center", paddingH = 8, paddingV = 4 }, {
        icon and ui.image({ path = icon, width = 22, height = 22, fit = "contain" })
          or ui.glyph({ name = "app-window", size = 20, color = "on_surface_variant" }),
        ui.column({ gap = 1, flexGrow = 1 }, {
          ui.label({ text = string.match(win.class, "([^%.]+)$") or win.class, fontWeight = "medium" }),
          ui.label({ text = win.title or "", fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
        }),
        ui.button({
          glyph = "plus",
          text = "Add",
          variant = "outline",
          controlSize = "sm",
          onClick = function()
            C.run({ "add", tostring(win.pid), win.class }, function()
              C.refresh()
            end)
          end,
        }),
      }))
    end
  end
  if windows == nil then
    table.insert(body, ui.label({ text = "Loading…", color = "on_surface_variant" }))
  elseif offered == 0 then
    table.insert(body, ui.label({ text = "Every open app is already a favourite.", color = "on_surface_variant" }))
  end

  panel.render(ui.column({ gap = 10, padding = 16 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "arrows-split-2", size = 20, color = "primary" }),
      ui.label({ text = "Mullvad split tunnel", fontWeight = "bold", fontSize = 16, flexGrow = 1 }),
      ui.button({ glyph = "refresh", variant = "ghost", controlSize = "sm", tooltip = "Refresh", onClick = function()
        C.refresh()
        loadWindows()
      end }),
      ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = function()
        panel.close()
      end }),
    }),
    ui.label({
      text = "Apps switched on bypass the VPN. Connections already open move over once the app reconnects.",
      fontSize = 11,
      color = "on_surface_variant",
      maxLines = 3,
    }),
    ui.scroll({ height = 370, gap = 6 }, body),
    ui.row({ justify = "end" }, {
      ui.button({
        text = "Stop excluding everything",
        variant = "destructive",
        controlSize = "sm",
        enabled = C.anyExcluded(apps),
        onClick = function()
          C.run({ "clear" }, function()
            C.refresh()
          end)
        end,
      }),
    }),
  }))
end

noctalia.state.watch("apps", function()
  render()
end)

-- The widget reads this so the hover popup doesn't open over (and replace) us.
function onClose()
  noctalia.state.set("managerOpen", false)
end

function onOpen()
  noctalia.state.set("managerOpen", true)
  render()
  C.refresh()
  loadWindows()
end
