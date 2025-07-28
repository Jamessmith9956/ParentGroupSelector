PART_NAME_ATTRIBUTE = 3

---@param val any static value to pass into the equality function
---@param eq_func? fun(tbl_val, val): boolean is vals matching
---@return string|nil tbl_key of the first matching value found in tbl, or nil
function match(tbl, val, eq_func)
	if not tbl then error("table expected, got nil", 2) end
	eq_func = eq_func or function (v, val) return v == val end
	for k, v in pairs(tbl) do
		if eq_func(v, val) then return k end
	end
	return nil
end

---@see selector function takes a table "selection" of the currently selected parts.
---@see edit this table to define waht parts should be selected by this function.
function select_parent_groups(selection)
    local parent_groups = {}
    local i, group = next(selection)
    while group do
        local parent_group = pytha.get_element_parent_group(group)
        if not match(parent_groups, parent_group) then
            table.insert(parent_groups, parent_group)
        end
        table.remove(selection, i)
        i, group = next(selection)
    end
    while #selection > 0 do
        table.remove(selection)
    end
    while #parent_groups > 0 do
        local group = table.remove(parent_groups)
        if group then
            table.insert(selection, group)
        end
    end
end

local front_group_names = {}
local default_front_group_name = {name=""}

function main()
    front_group_names = pyio.load_values("front_group_names") or front_group_names
    default_front_group_name = pyio.load_values("default_front_group_name") or default_front_group_name
    local is_new_name = false
    local result = pyui.run_modal_subdialog(front_settings_dialog, is_new_name)
    if result == "ok" then
        if is_new_name then
            table.insert(front_group_names, default_front_group_name.name)
        end
        pyio.save_values("front_group_names", front_group_names)
        pyio.save_values("default_front_group_name", default_front_group_name)
    end
end


function front_settings_dialog(dialog_handle, is_new_name)
    dialog_handle:set_window_title(pyloc "Part Selection - Front Group Settings")
    dialog_handle:create_label(1, pyloc "default selection name: ")
    local combo = dialog_handle:create_combo_box(2, front_group_names[1] or "")
    local add_btn = dialog_handle:create_button({1,2}, pyloc "Add New Name")
    dialog_handle:create_ok_button(1)
    dialog_handle:create_cancel_button(2)

    for i, name in ipairs(front_group_names) do
        combo:insert_control_item(name)
    end
    local i = match(front_group_names, default_front_group_name.name)
    if i then
        combo:set_control_selection(i)
    end

    combo:set_on_change_handler(function (text, new_index)
        default_front_group_name.name = text
        if new_index==nil then
            is_new_name = true
        else
            is_new_name = false
        end
    end)
    add_btn:set_on_click_handler(function ()
        local input
        local result = pyui.run_modal_subdialog(
            function (sub_dialog)
                sub_dialog:set_window_title(pyloc "Add New Front Group Name")
                sub_dialog:create_label(1, pyloc "Enter new front group name:")
                txt = sub_dialog:create_text_box(2, "")
                sub_dialog:create_ok_button(1)
                sub_dialog:create_cancel_button(2)

                txt:set_on_change_handler(function (text, new_index)
                    input = text
                end)
            end
        )
        if result == "ok" then
            if not match(front_group_names, input) then
                table.insert(front_group_names, input)
                combo:insert_control_item(input)
                combo:set_control_selection(#front_group_names)
            end
        end
    end)
end

---@see opens a dialog to select a name to be selected
function select_front_groups(selection)
    front_group_names = pyio.load_values("front_group_names") or front_group_names
    local default_front_group_name = pyio.load_values("default_front_group_name") or {name=""}
    local key = default_front_group_name.name
    local is_get_parent = false

    local function highlight_selection()
        pyux.clear_highlights()
        if #selection > 0 then
            for i, part in ipairs(selection) do
                pyux.highlight_element(part)
            end
        end
    end

    ---@param name string the name to match
    ---@see replace selection elements with matching groups
    local function select_matching_groups(name)
        while #selection > 0 do
            table.remove(selection)
        end
        if not name or name == "" then
            return
        end
        for part in pytha.enumerate_parts() do
            local part_name = pytha.get_element_attribute(part, PART_NAME_ATTRIBUTE)
            local i,j = part_name:find(name)
            if i or j then
                if not is_get_parent then
                    table.insert(selection, part)
                else
                    local parent = pytha.get_element_parent_group(part)
                    if parent then
                        table.insert(selection, parent)
                    end
                end
            end
        end
    end

    if key and key ~= "" then
        select_matching_groups(key)
    end

    local result = pyui.run_modal_subdialog(
        function (dialog_handle)
            dialog_handle:set_window_title(pyloc "Select Fronts by Name")
            local combo_box = dialog_handle:create_combo_box({1,2}, key)
            for i, name in ipairs(front_group_names) do
                combo_box:insert_control_item(name)
            end
            combo_box:set_control_selection(1)

            local get_parent_checkbox = dialog_handle:create_check_box({1,2}, pyloc "Select Group")

            local select_part_name_btn = dialog_handle:create_button({1,2}, pyloc "Get name from Part")

            dialog_handle:create_ok_button(1)
            dialog_handle:create_cancel_button(2)

            combo_box:set_on_change_handler(function (text, new_index)
                key = text
                select_matching_groups(key)
                highlight_selection()
            end)

            get_parent_checkbox:set_on_click_handler(function (checked)
                is_get_parent = checked
                select_matching_groups(key)
                highlight_selection()
            end)

            select_part_name_btn:set_on_click_handler(function ()
                local element_tbl = pyux.select_part(false, pyloc "Select a part to get its name")
                if not element_tbl or #element_tbl == 0 then
                    return
                end
                local part_name = pytha.get_element_attribute(element_tbl[1], PART_NAME_ATTRIBUTE)
                if not part_name or part_name == "" then
                    pyui.show_message(pyloc "Selected part has no name set.")
                    return
                end
                key = part_name
                combo_box:set_control_text(part_name)
                select_matching_groups(key)
                highlight_selection()
            end)
        end
    )
    if result == "ok" then
        -- check if final selection key is in the front group names, else add it to the list
        if key and key ~= "" and not match(front_group_names, key) then
            table.insert(front_group_names, key)
            pyio.save_values("front_group_names", front_group_names)
            local default_front_group_name = pyio.load_values("default_front_group_name")
            if not default_front_group_name or default_front_group_name.name == "" then
                default_front_group_name = {name=key}
                pyio.save_values("default_front_group_name", default_front_group_name)
            end
        end
    end

end