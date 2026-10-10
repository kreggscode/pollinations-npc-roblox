local Actions = {}

-- Runs the handler the game registered for action.type. The handler owns the
-- policy: it returns true only if it actually performed the action, and it is
-- free to refuse anything the model proposed. Returns whether an action ran.
function Actions.dispatch(registry, action, context)
	if type(action) ~= "table" or type(action.type) ~= "string" then
		return false
	end

	local handler = registry[action.type]
	if type(handler) ~= "function" then
		return false
	end

	local ok, performed = pcall(handler, action, context or {})
	return ok and performed == true
end

function Actions.types(registry)
	local names = {}
	for name in pairs(registry) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return Actions
