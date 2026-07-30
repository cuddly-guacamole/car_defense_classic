local Event = require 'utils.event'
local GuiDispatcher = require 'utils.gui_dispatcher'
local Global = require 'utils.global'
local mod_gui = require('__core__/lualib/mod-gui')
local GuiRebuild = require 'utils.gui_rebuild'

local Public = {}

local TOGGLE_BUTTON_NAME = 'top_bar_toggle_button'

local BUTTON_HEIGHT = 36
local BUTTON_MAX_HEIGHT = 36
local BUTTON_STYLE = 'mod_gui_button'

local this = {
    toggle_button_enabled = true,
    collapsed = {}
}

Global.register(this, function(tbl)
    this = tbl
end)

function Public.get_toggle_button_name()
    return TOGGLE_BUTTON_NAME
end

function Public.is_collapsed(player_index)
    return this.collapsed[player_index] or false
end

function Public.set_toggle_button_enabled(state)
    this.toggle_button_enabled = state
end

function Public.get_button_flow(player)
    return mod_gui.get_button_flow(player)
end

local function create_toggle_button(player)
    if not this.toggle_button_enabled then
        return
    end

    local flow = mod_gui.get_button_flow(player)

    if flow[TOGGLE_BUTTON_NAME] then
        return
    end

    local collapsed = this.collapsed[player.index]

    local sprite = collapsed and 'utility/expand_dots' or 'utility/preset'
    local tooltip = collapsed and {'amap.top_bar_show'} or {'amap.top_bar_hide'}

    local b = flow.add({
        type = 'sprite-button',
        name = TOGGLE_BUTTON_NAME,
        sprite = sprite,
        tooltip = tooltip,
        style = BUTTON_STYLE
    })
    b.style.minimal_height = BUTTON_HEIGHT
    b.style.maximal_height = BUTTON_MAX_HEIGHT
    b.style.minimal_width = 18
    b.style.maximal_width = 18
    b.style.padding = -2
end

local LEGACY_TOP_NAMES = {
    'poll_button',
    'main_button',
    'wave_defense',
}

local function migrate_buttons_to_flow(player)
    local top = player.gui.top
    local flow = mod_gui.get_button_flow(player)

    local to_migrate = {}
    local to_destroy = {}
    for _, child in pairs(top.children) do
        if child and child.valid
            and child.name ~= 'mod_gui_top_frame'
            and child.name ~= 'mod_gui_button_flow' then
            if not flow[child.name] then
                table.insert(to_migrate, child)
            else
                table.insert(to_destroy, child)
            end
        end
    end

    for _, child in ipairs(to_migrate) do
        if child.valid then
            if tonumber(child.name) then
                child.destroy()
            else
                local is_legacy = false
                for _, legacy_name in ipairs(LEGACY_TOP_NAMES) do
                    if child.name == legacy_name then
                        is_legacy = true
                        break
                    end
                end
                if is_legacy then
                    child.destroy()
                else
                    child.parent = flow
                end
            end
        end
    end

    for _, child in ipairs(to_destroy) do
        if child.valid then
            child.destroy()
        end
    end
end

local function resize_buttons(player)
    local flow = mod_gui.get_button_flow(player)
    for _, child in pairs(flow.children) do
        if child and child.valid and child.name ~= TOGGLE_BUTTON_NAME then
            child.style = BUTTON_STYLE
            child.style.minimal_height = BUTTON_HEIGHT
            child.style.maximal_height = BUTTON_MAX_HEIGHT
        end
    end
end

local ALWAYS_VISIBLE_BUTTONS = {
    ['rpg_draw_main_frame'] = true,
    ['pet_draw_main_button'] = true,
    ['tianfu'] = true,
}

local function apply_collapse_state(player, collapsed)
    local flow = mod_gui.get_button_flow(player)

    for _, child in pairs(flow.children) do
        if child and child.valid and child.name ~= TOGGLE_BUTTON_NAME and not ALWAYS_VISIBLE_BUTTONS[child.name] then
            child.visible = not collapsed
        end
    end

    this.collapsed[player.index] = collapsed

    local button = flow[TOGGLE_BUTTON_NAME]
    if button and button.valid then
        if collapsed then
            button.sprite = 'utility/expand_dots'
            button.tooltip = {'amap.top_bar_show'}
        else
            button.sprite = 'utility/preset'
            button.tooltip = {'amap.top_bar_hide'}
        end
    end
end

GuiDispatcher.register_click(TOGGLE_BUTTON_NAME, function(event)
    local player = event.player
    if not player or not player.valid then
        return
    end

    local collapsed = this.collapsed[player.index]

    if collapsed then
        apply_collapse_state(player, false)
    else
        apply_collapse_state(player, true)
    end
end)

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    migrate_buttons_to_flow(player)
    create_toggle_button(player)
    resize_buttons(player)

    if this.collapsed[player.index] then
        apply_collapse_state(player, true)
    end
end

local function on_player_left_game(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    this.collapsed[player.index] = nil
end

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game, on_player_left_game)

function Public.add_button(player, definition)
    local flow = mod_gui.get_button_flow(player)

    if flow[definition.name] and flow[definition.name].valid then
        return flow[definition.name]
    end

    definition.style = BUTTON_STYLE
    local element = flow.add(definition)
    element.style.minimal_height = BUTTON_HEIGHT
    element.style.maximal_height = BUTTON_MAX_HEIGHT

    if this.collapsed[player.index] and not ALWAYS_VISIBLE_BUTTONS[definition.name] then
        element.visible = false
    end

    return element
end

Public.button_style = BUTTON_STYLE
Public.create_toggle_button = create_toggle_button
Public.apply_collapse_state = apply_collapse_state
Public.migrate_buttons_to_flow = migrate_buttons_to_flow
Public.resize_buttons = resize_buttons

-- 注册到统一重建入口：场景热更 / 服务器更新时统一迁移旧顶栏按钮并重建折叠开关
GuiRebuild.register('top_bar', function(player)
    migrate_buttons_to_flow(player)
    create_toggle_button(player)
    resize_buttons(player)
end)

return Public
