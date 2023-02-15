
--@module = true
local args = { ... }
local max_send = 10

local gui = require "gui"
local guidm = require "gui.dwarfmode"
local widgets = require "gui.widgets"
local overlay = require "plugins.overlay"

DogWashOverlay = defclass(DogWashOverlay, overlay.OverlayWidget)
DogWashOverlay.ATTRS {
    viewscreens = {
        'dwarfmode/Zone/Some/Pen',
        -- TODO: for some reason this still gets dismissed when the other popup is selected
        'dfhack/lua/dogwash',
    } ,
    default_enabled = true,
    default_pos = { x = 7, y = 13 },
    frame = { w = 34, h = 5 },
}

function DogWashOverlay:init()
    self:addviews {
        -- TODO: apparently a HotKeyLabel is the play here to have a clickable label
        widgets.WrappedLabel {
            view_id = "text",
            text_to_wrap = 'Please select a Pen/Pasture (using z)',
            auto_height = true,
            on_click = function()
                -- TODO: pass in seleted pen (or somehow don't lose selection)
                if View then
                    View:setPen(self.pen)
                    View:raise()
                else
                    View = DogWash{}
                    View:setPen(self.pen)
                    View:show()
                end
            end,
        },
    }
    self.first_updated = false
end

-- -- TODO: get mouse events on an overlay
-- function DogWashOverlay:onInput(keys)
--     return DogWash.super.onInput(self, keys)

--     -- if keys._MOUSE_L_DOWN then
--     --     print("handled 1")
--     --     return true
--     -- end
--     -- print("handled 2")
--     -- return false
-- end

function DogWashOverlay:onRenderBody()
    self:updateLayout()
    local text = self.subviews.text
    local showmsg = function(msg)
        text.text_to_wrap = msg
        self:updateLayout()
    end

    -- So this doesn't return anything if the dialog is selected
    -- TODO: There are probably some focus issues that need to be dealt with, or
    --       this function shouldn't even look at focus at all (since you can
    --       have a zone selected but not focussed on it).
    local zone = dfhack.gui.getSelectedCivZone(true);

    if zone ~= nil then
        if self.pen ~= zone then
            self.pen = zone
            self.first_updated = false
        end
    else
        if self.pen == nil then
            -- Don't overwrite the messsage if one is already
            showmsg("Please select a Pen/Pasture to send dogs to the wash!")
            return
        end
    end

    local animals = {}

    local zonetype = df.civzone_type[self.pen.type]

    if zonetype ~= "Pen" then
        showmsg(string.format("Selected zone is not a Pen: %s", zonetype))
        return
    end

    if self.pen == nil then
        return
    end

    if zone == nil then
        return
    end

    -- No need to do anything else if selection hasn't changed, unless we
    -- haven't gotten our first update yet
    if self.first_updated and self.pen == zone then
        return
    end

    for _, unitId in pairs(self.pen.assigned_units) do
        local unit = df.unit.find(unitId)
        if unit == nil then
            showmsg("Unit not found: ", unitId)
            goto continue
        end

        local spatters = #unit.body.spatters
        local name = dfhack.TranslateName(unit.name)
        if not name or name == "" then
            name = "stray dog"
        end

        -- for console printing
        -- name = dfhack.df2utf(name)
        if spatters == 0 then
            goto continue
        end
        table.insert(animals, {
            text = string.format("Pastured animal %d (%s) has %d spatter(s)",
                unitId, name, spatters),
            unitId = unitId,
        })

        -- Use a persist table, make this a module so that it can be enabled and
        -- run in the background
        -- https://docs.dfhack.org/en/latest/docs/dev/Lua%20API.html#enabling-and-disabling-scripts
        --
        -- See fix/protect-nicks.lua
        -- TODO: assign them to a new pasture
        -- TODO: send them back to the original pen somehow? needs persistence
        ::continue::
    end

    self.first_updated = true
    if #animals > 0 then
        showmsg{
            string.format("%d animals have spatters.\n", #animals),
            "Click here to send them to the wash!",
        }
    else
        showmsg("")
    end
end

-- View = View and View:raise() or DogWash{}:show()

DogWash = defclass(DogWash, gui.ZScreen)
DogWash.ATTRS {
    focus_path = "dwarfmode/Zone/Some/Pen/dogwash"
}

-- TODO: make this an overlay on dwarfmode/Zone/Some/Pen
function DogWash:init()
    local window = widgets.Window {
            view_id = "main",
            -- Show at bottom left to avoid details pane
            frame = { b = 3, l = 3, w = 40, h = 32 },
            frame_title="DogWash",
            drag_anchors={title=true, frame=true, body=true},
        }
    local label_width = 18;
    window:addviews {
        widgets.Label {
            frame = { l = 0, t = 0 },
            text = "Current pasture:",
            auto_width = true,
        },
        widgets.Label {
            frame = { t = 0, l = label_width + 1 },
            text = "Unset",
        },

        widgets.Label {
            frame = { l = 0, t = 1 },
            text = "Wash pasture:",
        },

        widgets.Label {
            frame = { t = 1, l = label_width + 1 },
            text = "Unset",
        },

        widgets.WrappedLabel {
            view_id = "text",
            frame = { t = 3 },
            text_to_wrap = 'Please select a Pen/Pasture (using z)',
            auto_height = true,
        },
        widgets.Panel {
            subviews = {
                widgets.List {
                    view_id = "dogs",
                    frame = { t = 5, h = 20 },
                    on_select = function(_, choice)
                        if choice then
                            self:gotoDog(choice.unitId)
                        end
                    end,
                },
            }
        },

        widgets.HotkeyLabel {
            text_pen = gui.COLOR_GREEN,
            frame = { b = 0 , l = 0, h = 1},
            label = "Select Cleaning Pasture",
            auto_width = true,
            on_activate = function()
            end,
        },
        widgets.HotkeyLabel {
            text_pen = gui.COLOR_RED,
            frame = { b = 0,  r = 0, h = 1 },
            label = "Close",
            auto_width = true,
            -- not using on-activate because it doesn't activate hover
            on_activate = function()
                self:dismiss()
            end,
        },
    }
    self:addviews { window }
end

function DogWash:setPen(pen)
    self.pen = pen
end

function DogWash:gotoDog(id)
    local unit = df.unit.find(id)
    if unit == nil then
        return
    end

    -- Already selected, nothing needs to be doen
    if self.selected == unit.pos then
        return
    end

    -- Let's show where the selected dog is
    dfhack.gui.revealInDwarfmodeMap(unit.pos, true)

    -- This signals a highlight if necessary
    self.selected = unit.pos
    -- -- highlight the tile
    -- -- local block = dfhack.maps.getTileBlock(unit.pos)
    -- local x, y = dfhack.screen.getWindowSize()
    -- -- todo: find real coords, and move this to onRenderBody
    -- dfhack.screen.paintTile(BOX_PEN, x/2, y/2)
    --

end

local CURSOR_TILE = dfhack.screen.findGraphicsTile('CURSORS', 0, 0)
function DogWash:onRenderFrame(painter, frame_rect)
    if self.selected == nil then
        return
    end
    local vp = guidm.Viewport.get()

    if not vp:isVisible(self.selected) then
        return
    end

    local tilepos = vp:tileToScreen(self.selected)
    dfhack.screen.paintTile(COLOR_GREEN, tilepos.x, tilepos.y, 'x', CURSOR_TILE, true)
end

function DogWash:onRenderBody()
    local text = self.subviews.text
    local showmsg = function(msg)
        text.text_to_wrap = msg
        self:updateLayout()
    end

    -- So this doesn't return anything if the dialog is selected
    local zone = dfhack.gui.getSelectedCivZone(true);

    if zone ~= nil then
        self.pen = zone
    else
        if self.pen == nil then
            -- Don't overwrite the messsage if one is already
            showmsg("Please select a Pen/Pasture to send dogs to the wash!")
            return
        end
    end


    local animals = {}

    local zonetype = df.civzone_type[self.pen.type]

    if zonetype ~= "Pen" then
        showmsg(string.format("Selected zone is not a Pen: %s", zonetype))
        self.subviews.dogs:setChoices({})
        return
    end

    if self.pen == nil then
        return
    end

    -- No need to do anything else if selection hasn't changed
    if #self.subviews.dogs:getChoices() > 0 and zone == nil then
        return
    end

    for _, unitId in pairs(self.pen.assigned_units) do
        local unit = df.unit.find(unitId)
        if unit == nil then
            showmsg("Unit not found: ", unitId)
            goto continue
        end

        local spatters = #unit.body.spatters
        local name = dfhack.TranslateName(unit.name)
        -- TODO: determine animal type
        if not name or name == "" then
            name = "stray dog"
        end

        -- for console printing
        -- name = dfhack.df2utf(name)
        if spatters == 0 then
            goto continue
        end
        table.insert(animals, {
            text = string.format("%s has %d spatter(s)", name, spatters),
            unitId = unitId,
        })

        -- Use a persist table, make this a module so that it can be enabled and
        -- run in the background
        -- https://docs.dfhack.org/en/latest/docs/dev/Lua%20API.html#enabling-and-disabling-scripts
        --
        -- See fix/protect-nicks.lua
        -- TODO: assign them to a new pasture
        -- TODO: send them back to the original pen somehow? needs persistence
        ::continue::
    end

    if #animals > 0 then
        showmsg(string.format("%d animals have spatters", #animals))
        self.subviews.dogs:setChoices(animals)
    else
        showmsg("All animals in this pasture are clean!")
        self.subviews.dogs:setChoices({})
    end
end

function DogWash:onDismiss()
    View = nil
end

if not dfhack.isMapLoaded then
    gerror("Map is not loaded yet")
    return
end

-- max number of dogs to send to the wash at once
if #args > 0 then
    max_send = args[1]
end

OVERLAY_WIDGETS = {overlay=DogWashOverlay}

if dfhack_flags.module then
    return
end

View = View and View:raise() or DogWash{}:show()
