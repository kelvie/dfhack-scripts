
--@module = true
local args = { ... }
local max_send = 10

local gui = require "gui"
local guidm = require "gui.dwarfmode"
local widgets = require "gui.widgets"
local overlay = require "plugins.overlay"

-- TODO: maybe make this a hotspot instead. you'd hover over a message to pop up
-- a dialog to manage the dogs in there
DogWash = defclass(DogWash, overlay.OverlayWidget)
DogWash.ATTRS {
    viewscreens = 'dwarfmode/Zone/Some/Pen',
    default_enabled = true,
    default_pos = { x = 3, y = -3 },
    frame = { w = 60, h = 40 },
    frame_style = gui.WINDOW_FRAME,
    frame_background=gui.CLEAR_PEN,
}

function DogWash:init()
    self:addviews {
        widgets.Window {
            subviews = {
                -- TODO: why doesn't this label show up
                widgets.WrappedLabel {
                    view_id = "text",
                    frame = { t=0},
                    text_to_wrap = 'Please select a Pen/Pasture (using z)',
                    auto_height = true,
                },
                widgets.List {
                    view_id = "dogs",
                    frame = { t = 0 },
                    on_select = function(_, choice)
                        self:gotoDog(choice.unitId)
                    end,
                }
            }
        }
    }
    -- TODO: DEBUG
    printall(self)
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

-- TODO: get mouse events on an overlay
function DogWash:onInput(keys)
    return DogWash.super.onInput(self, keys)

    -- if keys._MOUSE_L_DOWN then
    --     print("handled 1")
    --     return true
    -- end
    -- print("handled 2")
    -- return false
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
    local pen = dfhack.screen.readTile(tilepos.x, tilepos.y, true)
    dfhack.screen.paintTile(COLOR_GREEN, tilepos.x, tilepos.y, 'x', CURSOR_TILE, true)
end

function DogWash:onRenderBody()
    printall(self.subviews.screen)
    local doglist = self.subviews.dogs
    local text = self.subviews.text
    local showmsg = function(msg)
        print("Setting text to ", msg)
        text.text_to_wrap = msg
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
        return
    end

    if self.pen == nil then
        return
    end

    -- No need to do anything else if selection hasn't changed
    if #doglist:getChoices() > 0 and (zone == nil or self.pen == zone) then
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

    if #animals > 0 then
        showmsg(string.format("%d animals have spatters on them", #animals))
        doglist:setChoices(animals)
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

OVERLAY_WIDGETS = {overlay=DogWash}

if dfhack_flags.module then
    return
end

-- View = View and View:raise() or DogWash{}:show()
