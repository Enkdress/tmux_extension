local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local telescope = require("telescope")
local tutils = require("telescope.utils")

local tmux_commands = {}
tmux_commands.list_sessions = function(opts)
	local cmd = { "tmux", "list-sessions" }
	if opts.format ~= nil then
		table.insert(cmd, "-F")
		table.insert(cmd, opts.format)
	end
	return tutils.get_os_command_output(cmd)
end
tmux_commands.session_id_fmt = "#{session_id}"
tmux_commands.session_name_fmt = "#S"

local function tmux_session_picker(opts)
	local session_ids = tmux_commands.list_sessions({ format = tmux_commands.session_id_fmt })
	local user_formatted_session_names = tmux_commands.list_sessions({ format = tmux_commands.session_name_fmt })
	local formatted_to_real_session_map = {}
	for i, v in ipairs(user_formatted_session_names) do
		formatted_to_real_session_map[v] = session_ids[i]
	end
	local current_session =
		tutils.get_os_command_output({ "tmux", "display-message", "-p", tmux_commands.session_id_fmt })[1]
	local current_client = tutils.get_os_command_output({ "tmux", "display-message", "-p", "#{client_tty}" })[1]

	pickers
		.new(opts, {
			prompt_title = "Tmux Sessions",
			finder = finders.new_table({
				results = user_formatted_session_names,
				entry_maker = function(result)
					return {
						value = result,
						display = result,
						ordinal = result,
						valid = formatted_to_real_session_map[result] ~= current_session,
					}
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					vim.cmd(string.format('silent !tmux switchc -t "%s" -c "%s"', selection.value, current_client))
					actions.close(prompt_bufnr)
				end)

				actions.close:enhance({
					post = function()
						if opts.quit_on_select then
							vim.cmd("q!")
						end
					end,
				})
				return true
			end,
		})
		:find()
end

return telescope.register_extension({
	exports = {
		sessions = tmux_session_picker,
	},
})
