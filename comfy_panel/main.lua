--[[
Comfy Panel

To add a tab, insert into the "main_gui_tabs" table.

Example: main_gui_tabs["mapscores"] = {gui = draw_map_scores, admin = false}
if admin = true, then tab is visible only for admins (usable for map-specific settings)

draw_map_scores would be a function with the player and the frame as arguments

]]
local Event = require 'utils.event'
local Server = require 'utils.server'
local SpamProtection = require 'utils.spam_protection'
local Token = require 'utils.token'
local GuiDispatcher = require 'utils.gui_dispatcher'
local TopBar = require 'utils.top_bar'

local Task = require 'utils.task'

local main_gui_tabs = {}
local Public = {}
local screen_elements = {}

local function fix_frame_style(event)
    local frame = event.frame
    if not frame or not frame.valid then
        return
    end
    frame.style.padding = 10
end

local fix_frame_style_token = Token.register(fix_frame_style)

local LEGACY_GUI_NAMES = {
    'tianfu_frame', 'tianfu_frame_table', 'tianfu_frame_button',
    'zhiye_select', 'choise1', 'choise2', 'choise3',
    '选择你的天赋', 'choise_zhiye_frame',
    'poll_button', 'poll_frame', 'close_poll_frame',
    'mini_camera', 'mini_cam_element',
    'player_list_panel_header_table', 'scroll_pane',
    'player_list_panel_table', 'score_scroll_pane',
    'groups_table', 'group_table', 'frame2',
    'new_group_name', 'new_group_description', 'create_new_group',
    'datalog', 'admin_player_select',
}

local function cleanup_legacy_uid_gui(player)
    local locations = {player.gui.top, player.gui.screen, player.gui.left, player.gui.center}
    for _, location in ipairs(locations) do
        for _, child in pairs(location.children) do
            if tonumber(child.name) then
                child.destroy()
            end
        end
    end
    for _, name in ipairs(LEGACY_GUI_NAMES) do
        for _, location in ipairs(locations) do
            if location[name] then
                location[name].destroy()
            end
        end
    end
end

--- This adds the given gui to the main gui.
---@param tbl
function Public.add_tab_to_gui(tbl)
    if not tbl then
        return
    end
    if not tbl.name then
        return
    end
    if not tbl.id then
        return
    end
    local admin = tbl.admin or false
    local only_server_sided = tbl.only_server_sided or false

    if not main_gui_tabs[tbl.name] then
        main_gui_tabs[tbl.name] = {id = tbl.id, admin = admin, only_server_sided = only_server_sided}
    else
        error('Given name: ' .. tbl.name .. ' already exists in table.')
    end
end

function Public.screen_to_bypass(elem)
    screen_elements[elem] = true
    return screen_elements
end

--- Fetches the main gui tabs. You are forbidden to write as this is local.
---@param key
function Public.get(key)
    if key then
        return main_gui_tabs[key]
    else
        return main_gui_tabs
    end
end

function Public.comfy_panel_clear_left_gui(player)
    for _, child in pairs(player.gui.left.children) do
        child.visible = false
    end
end

function Public.comfy_panel_restore_left_gui(player)
    for _, child in pairs(player.gui.left.children) do
        child.visible = true
    end
end

function Public.comfy_panel_clear_screen_gui(player)
    for _, child in pairs(player.gui.screen.children) do
        if not screen_elements[child.name] then
            child.visible = false
        end
    end
end

function Public.comfy_panel_restore_screen_gui(player)
    for _, child in pairs(player.gui.screen.children) do
        if not screen_elements[child.name] then
            child.visible = true
        end
    end
end

function Public.comfy_panel_get_active_frame(player)
    if not player.gui.left.comfy_panel then
        return false
    end
    if not player.gui.left.comfy_panel.tabbed_pane.selected_tab_index then
        return player.gui.left.comfy_panel.tabbed_pane.tabs[1].content
    end
    return player.gui.left.comfy_panel.tabbed_pane.tabs[player.gui.left.comfy_panel.tabbed_pane.selected_tab_index].content
end

function Public.comfy_panel_refresh_active_tab(player)
    local frame = Public.comfy_panel_get_active_frame(player)
    if not frame then
        return
    end

    local pane = player.gui.left.comfy_panel
    if pane then
        pane = pane.tabbed_pane
    end
    if pane then
        for _, t in pairs(pane.tabs) do
            if t.content and t.content.valid and t.content.name ~= frame.name then
                t.content.clear()
            end
        end
    end

    local tab = main_gui_tabs[frame.name]
    if not tab then
        return
    end
    local id = tab.id
    if not id then
        return
    end
    local func = Token.get(id)

    local data = {
        player = player,
        frame = frame
    }

    return func(data)
end

local function top_button(player)
    if TopBar.get_button_flow(player)['comfy_panel_top_button'] then
        return
    end
    local button = TopBar.add_button(player, {type = 'sprite-button', name = 'comfy_panel_top_button', sprite = 'item/raw-fish'})
    button.style.minimal_width = 40
    button.style.padding = -2
end

local function main_frame(player)
    local tabs = main_gui_tabs
    Public.comfy_panel_clear_left_gui(player)

    local frame = player.gui.left.comfy_panel
    if not frame or not frame.valid then
        frame = player.gui.left.add({type = 'frame', name = 'comfy_panel'})
    end

    frame.style.margin = 6

    local tabbed_pane = frame.add({type = 'tabbed-pane', name = 'tabbed_pane'})

    for name, func in pairs(tabs) do
        if func.only_server_sided then
            local secs = Server.get_current_time()
            if secs then
                local tab = tabbed_pane.add({type = 'tab', caption = name, name = 'tab_' .. name, style = 'slightly_smaller_tab'})
                local name_frame = tabbed_pane.add({type = 'frame', name = name, direction = 'vertical', style = 'deep_frame_in_shallow_frame'})
                tab.style.padding = 10
                Task.set_timeout_in_ticks(10, fix_frame_style_token, {frame = name_frame})
                tabbed_pane.add_tab(tab, name_frame)
            end
        elseif func.admin == true then
            if player.admin then
                local tab = tabbed_pane.add({type = 'tab', caption = name, name = 'tab_' .. name, style = 'slightly_smaller_tab'})
                local name_frame = tabbed_pane.add({type = 'frame', name = name, direction = 'vertical', style = 'deep_frame_in_shallow_frame'})
                tab.style.padding = 10
                Task.set_timeout_in_ticks(10, fix_frame_style_token, {frame = name_frame})
                tabbed_pane.add_tab(tab, name_frame)
            end
        else
            local tab = tabbed_pane.add({type = 'tab', caption = name, name = 'tab_' .. name, style = 'slightly_smaller_tab'})
            local name_frame = tabbed_pane.add({type = 'frame', name = name, direction = 'vertical', style = 'deep_frame_in_shallow_frame'})
            tab.style.padding = 10
            Task.set_timeout_in_ticks(10, fix_frame_style_token, {frame = name_frame})
            tabbed_pane.add_tab(tab, name_frame)
        end
    end

    local tab = tabbed_pane.add({type = 'tab', name = 'comfy_panel_close', caption = 'X'})
    tab.style.maximal_width = 32
    local t_frame = tabbed_pane.add({type = 'frame', direction = 'vertical'})
    tabbed_pane.add_tab(tab, t_frame)

    for _, child in pairs(tabbed_pane.children) do
        child.style.padding = 8
        child.style.left_padding = 2
        child.style.right_padding = 2
    end

    Public.comfy_panel_refresh_active_tab(player)
end

function Public.comfy_panel_call_tab(player, name)
    main_frame(player)
    local tabbed_pane = player.gui.left.comfy_panel.tabbed_pane
    for key, v in pairs(tabbed_pane.tabs) do
        if v.tab.caption == name then
            tabbed_pane.selected_tab_index = key
            Public.comfy_panel_refresh_active_tab(player)
        end
    end
end

local function on_player_joined_game(event)
    local player = game.players[event.player_index]
    cleanup_legacy_uid_gui(player)
    top_button(player)
end

GuiDispatcher.register_click('comfy_panel_top_button', function(event)
    local player = game.players[event.player_index]
    local is_spamming = SpamProtection.is_spamming(player, nil, 'Comfy Main GUI Click')
    if is_spamming then
        return
    end
    if player.gui.left.comfy_panel then
        player.gui.left.comfy_panel.destroy()
        Public.comfy_panel_restore_left_gui(player)
        Public.comfy_panel_restore_screen_gui(player)
        return
    else
        Public.comfy_panel_clear_screen_gui(player)
        main_frame(player)
        return
    end
end)

GuiDispatcher.register_click('comfy_panel_close', function(event)
    local element = event.element
    local player = game.players[event.player_index]
    if element.caption == 'X' then
        local is_spamming = SpamProtection.is_spamming(player, nil, 'Comfy Main Gui Close Button')
        if is_spamming then
            return
        end
        player.gui.left.comfy_panel.destroy()
        Public.comfy_panel_restore_left_gui(player)
        return
    end
end)

local function on_gui_click(event)
    local element = event.element
    if not element or not element.valid then
        return
    end

    if not element.caption then
        return
    end
    if element.type ~= 'tab' then
        return
    end

    local player = game.players[event.player_index]
    Public.comfy_panel_refresh_active_tab(player)
end

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_created, on_player_joined_game)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_selected_tab_changed, function(event)
    local element = event.element
    if not element or not element.valid then
        return
    end
    if element.name ~= 'tabbed_pane' then
        return
    end
    local player = game.players[event.player_index]
    Public.comfy_panel_refresh_active_tab(player)
end)

return Public
