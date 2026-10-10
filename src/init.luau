local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Actions = require(script.Actions)
local Config = require(script.Config)
local Http = require(script.Http)
local Prompt = require(script.Prompt)

local PollinationsNpc = {}

local function readApiKey()
	local ok, secret = pcall(function()
		return HttpService:GetSecret(Config.SECRET_NAME)
	end)
	if ok and type(secret) == "string" and secret ~= "" then
		return secret
	end

	-- Studio-only fallback so the example place runs before a secret exists.
	local attribute = Workspace:GetAttribute(Config.API_KEY_ATTRIBUTE)
	if type(attribute) == "string" and attribute ~= "" then
		return attribute
	end

	return nil
end

-- Gives one character a conversation. Returns an object with :ask(player, message).
--
-- options.actions maps an action type to a handler(action) that returns true
-- only when it really performed the action. The model can propose a type from
-- that table; the handler decides.
function PollinationsNpc.start(options)
	local npc = {
		name = options.name or "NPC",
		persona = options.persona or "You are a friendly villager.",
		model = options.model or Config.DEFAULT_MODEL,
		maxHistoryTurns = options.maxHistoryTurns or Config.DEFAULT_HISTORY_TURNS,
		cooldownSeconds = options.cooldownSeconds or Config.DEFAULT_COOLDOWN,
		actions = options.actions or {},
		onReply = options.onReply,
	}

	local apiKey = readApiKey()
	local history = {}
	local lastAsked = {}
	local actionTypes = Actions.types(npc.actions)

	local function turnsFor(player)
		local turns = history[player.UserId]
		if not turns then
			turns = {}
			history[player.UserId] = turns
		end
		return turns
	end

	function npc.hasApiKey()
		return apiKey ~= nil
	end

	-- Returns { dialogue, action, actionPerformed }, or nil when the request
	-- was skipped (cooldown, no key) or the API failed.
	function npc.ask(player, message)
		if apiKey == nil or type(message) ~= "string" or message == "" then
			return nil
		end

		local now = os.clock()
		if lastAsked[player.UserId] and now - lastAsked[player.UserId] < npc.cooldownSeconds then
			return nil
		end
		lastAsked[player.UserId] = now

		local turns = turnsFor(player)
		local messages = Prompt.buildMessages(npc.persona, actionTypes, turns, message)
		local ok, result = Http.chat(npc.model, apiKey, messages)
		if not ok then
			return nil
		end

		local reply = Prompt.parseReply(result.reply)
		local performed = Actions.dispatch(npc.actions, reply.action, {
			player = player,
			npcName = npc.name,
		})

		table.insert(turns, { player = message, npc = reply.dialogue })
		while #turns > npc.maxHistoryTurns * 2 do
			table.remove(turns, 1)
		end

		if npc.onReply then
			npc.onReply(player, reply, performed)
		end

		return {
			dialogue = reply.dialogue,
			action = reply.action,
			actionPerformed = performed,
		}
	end

	Players.PlayerRemoving:Connect(function(player)
		history[player.UserId] = nil
		lastAsked[player.UserId] = nil
	end)

	return npc
end

return PollinationsNpc
