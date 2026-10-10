local Prompt = {}

local function defaultDecode(raw)
	return game:GetService("HttpService"):JSONDecode(raw)
end

-- The model is only asked to propose an action from a whitelist the game
-- supplied, and it is told the game may refuse. It never decides what
-- happens: Actions.dispatch runs the handler the game registered.
function Prompt.systemPrompt(persona, actionTypes)
	local prompt = persona
		.. "\n\nReply with a single JSON object and nothing else, no code fences: "
		.. '{"dialogue": string, "action": null | {"type": string, "value": string}}. '
		.. '"dialogue" is what the character says out loud, one short in-character sentence.'

	if #actionTypes > 0 then
		prompt = prompt
			.. " You may propose one of these action types only when the player clearly asks for it: "
			.. table.concat(actionTypes, ", ")
			.. ". Otherwise set action to null. Proposing an action does not make it happen; the game decides."
	else
		prompt = prompt .. " Always set action to null."
	end

	return prompt
end

function Prompt.buildMessages(persona, actionTypes, turns, message)
	local messages = {
		{ role = "system", content = Prompt.systemPrompt(persona, actionTypes) },
	}
	for _, turn in ipairs(turns) do
		table.insert(messages, { role = "user", content = turn.player })
		table.insert(messages, { role = "assistant", content = turn.npc })
	end
	table.insert(messages, { role = "user", content = message })
	return messages
end

-- Models wrap JSON in prose or code fences. Pull out the first object and
-- decode it; anything that does not decode is treated as plain dialogue so a
-- malformed reply still reaches the player. `decode` exists so the parsing
-- can be exercised outside Roblox.
function Prompt.parseReply(reply, decode)
	decode = decode or defaultDecode

	local text = string.gsub(reply, "^%s*```[%w%-]*%s*", "")
	text = string.gsub(text, "%s*```%s*$", "")

	local first = string.find(text, "{")
	local last = string.find(text, "}")
	if first and last and last > first then
		local ok, decoded = pcall(decode, string.sub(text, first, last))
		if ok and type(decoded) == "table" and type(decoded.dialogue) == "string" then
			local action = nil
			if type(decoded.action) == "table" and type(decoded.action.type) == "string" then
				action = decoded.action
			end
			return { dialogue = decoded.dialogue, action = action }
		end
	end

	return { dialogue = text, action = nil }
end

return Prompt
