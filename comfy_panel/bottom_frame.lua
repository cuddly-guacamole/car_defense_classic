local Misc = require 'commands.misc'
local Event = require 'utils.event'
local Global = require 'utils.global'
local ComfyGui = require 'comfy_panel.main'
local GuiDispatcher = require 'utils.gui_dispatcher'
local TopBar = require 'utils.top_bar'
local this = {
    players = {},
    activate_custom_buttons = false,
    bottom_quickbar_button = {}
}

Global.register(
    this,
    function(t)
        this = t
    end
)

local Public = {}

local bottom_guis_frame = 'cp_bf_bottom_guis_frame'
local clear_corpse_button_name = 'cp_bf_clear_corpse_button'
local bottom_quickbar_button_name = 'cp_bf_bottom_quickbar_button'

local function create_top_clear_corpse_button(player)
    local flow = TopBar.get_button_flow(player)
    if flow[clear_corpse_button_name] then
        return
    end
    TopBar.add_button(player, {
        type = 'sprite-button',
        sprite = 'entity/behemoth-biter',
        name = clear_corpse_button_name,
        tooltip = {'commands.clear_corpse'}
    })
end

function Public.get_player_data(player, remove_user_data)
    if remove_user_data then
        if this.players[player.index] then
            this.players[player.index] = nil
        end
        return
    end
    if not this.players[player.index] then
        this.players[player.index] = {}
    end
    return this.players[player.index]
end

function Public.get(key)
    if key then
        return this[key]
    else
        return this
    end
end

function Public.set(key, value)
    if key and (value or value == false) then
        this[key] = value
        return this[key]
    elseif key then
        return this[key]
    else
        return this
    end
end

function Public.clear_data(player)
    this.players[player.index] = nil
    this.bottom_quickbar_button[player.index] = nil
end

function Public.reset()
    local players = game.players
    for i = 1, #players do
        local player = players[i]
        if player and player.valid then
            if not player.connected then
                this.players[player.index] = nil
                this.bottom_quickbar_button[player.index] = nil
            end
        end
    end
end

----! Gui Functions ! ----

local function destroy_frame(player)
    local gui = player.gui
    local frame = gui.screen[bottom_guis_frame]
    if frame and frame.valid then
        frame.destroy()
    end
end

local function create_frame(player, alignment, location, portable)
    destroy_frame(player)
    this.bottom_quickbar_button[player.index] = {name = bottom_quickbar_button_name}
end

local function set_location(player, state)
    local data = Public.get_player_data(player)
    local alignment = 'vertical'

    local location
    local resolution = player.display_resolution
    local scale = player.display_scale

    if state == 'bottom_left' then
        if data.above then
            location = {
                x = (resolution.width / 2) - ((259) * scale),
                y = (resolution.height - (150 * scale))
            }
            alignment = 'horizontal'
        else
            location = {
                x = (resolution.width / 2) - ((54 + 444) * scale),
                y = (resolution.height - (96 * scale))
            }
        end
        data.bottom_state = 'bottom_left'
    elseif state == 'bottom_right' then
        if data.above then
            location = {
                x = (resolution.width / 2) - ((-376) * scale),
                y = (resolution.height - (150 * scale))
            }
            alignment = 'horizontal'
        else
            location = {
                x = (resolution.width / 2) - ((54 + -528) * scale),
                y = (resolution.height - (96 * scale))
            }
        end
        data.bottom_state = 'bottom_right'
    else
        Public.get_player_data(player, true)
        location = {
            x = (resolution.width / 2) - ((54 + -528) * scale),
            y = (resolution.height - (96 * scale))
        }
    end

    create_frame(player, alignment, location, data.portable)
end

--- Activates the custom buttons
---@param boolean
function Public.activate_custom_buttons(value)
    if value then
        this.activate_custom_buttons = value
    else
        this.activate_custom_buttons = false
    end
end

--- Fetches if the custom buttons are activated
function Public.is_custom_buttons_enabled()
    return this.activate_custom_buttons
end

GuiDispatcher.register_click(clear_corpse_button_name, function(event)
    Misc.clear_corpses(event)
end)

Event.add(
    defines.events.on_player_joined_game,
    function(event)
        local player = game.players[event.player_index]
        create_top_clear_corpse_button(player)
        if this.activate_custom_buttons then
            set_location(player)
        end
    end
)

Event.add(
    defines.events.on_player_display_resolution_changed,
    function(event)
        local player = game.get_player(event.player_index)
        if this.activate_custom_buttons then
            set_location(player)
        end
    end
)

Event.add(
    defines.events.on_player_respawned,
    function(event)
        local player = game.get_player(event.player_index)
        if this.activate_custom_buttons then
            set_location(player)
        end
    end
)

Event.add(
    defines.events.on_player_display_scale_changed,
    function(event)
        local player = game.get_player(event.player_index)
        if this.activate_custom_buttons then
            set_location(player)
        end
    end
)

Event.add(
    defines.events.on_pre_player_left_game,
    function(event)
        local player = game.get_player(event.player_index)
        destroy_frame(player)
        Public.clear_data(player)
    end
)

Public.bottom_guis_frame = bottom_guis_frame
Public.set_location = set_location
ComfyGui.screen_to_bypass(bottom_guis_frame)

return Public
