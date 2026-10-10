local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local PollinationsNpc = require(game.ServerScriptService.PollinationsNpc)

local GATE_OPEN_HEIGHT = 6
local TALK_RANGE = 40

local function attachBubble(npcModel, displayName)
	local body = npcModel:FindFirstChild("Body")
	if not body then
		return nil
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SpeechBubble"
	billboard.Size = UDim2.fromScale(8, 2.2)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 48
	billboard.Enabled = false

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.Size = UDim2.fromScale(1, 0.3)
	name.BackgroundTransparency = 1
	name.Text = displayName
	name.TextColor3 = Color3.fromRGB(255, 220, 140)
	name.TextStrokeTransparency = 0.2
	name.TextScaled = true
	name.Parent = billboard

	local dialogue = Instance.new("TextLabel")
	dialogue.Name = "Label"
	dialogue.Size = UDim2.fromScale(1, 0.65)
	dialogue.Position = UDim2.fromScale(0, 0.35)
	dialogue.BackgroundTransparency = 1
	dialogue.TextColor3 = Color3.new(1, 1, 1)
	dialogue.TextStrokeTransparency = 0.2
	dialogue.TextScaled = true
	dialogue.TextWrapped = true
	dialogue.Parent = billboard

	billboard.Parent = body
	return billboard
end

local function showBubble(bubble, dialogue)
	if not bubble or type(dialogue) ~= "string" or dialogue == "" then
		return
	end
	bubble.Label.Text = dialogue
	bubble.Enabled = true
	task.delay(8, function()
		bubble.Enabled = false
	end)
end

local function position(npcModel)
	local body = npcModel:FindFirstChild("Body")
	return body and body.Position or Vector3.zero
end

local function playerDistance(player, target)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return math.huge
	end
	return (root.Position - target).Magnitude
end

local gate = Workspace:FindFirstChild("Gate")

local mara = PollinationsNpc.start({
	name = "Gatekeeper Mara",
	persona = "You are Gatekeeper Mara of a small village. You are polite but wary of strangers. "
		.. "You speak in one short sentence at a time. You guard the north gate.",
	actions = {
		-- The model only ever *proposes* this type. Deciding is ours: the gate
		-- opens when it is shut and the player is close enough to matter.
		open_gate = function(_action, context)
			if not gate or gate.Position.Y > GATE_OPEN_HEIGHT then
				return false
			end
			if playerDistance(context.player, gate.Position) > TALK_RANGE then
				return false
			end
			gate.Position = gate.Position + Vector3.new(0, 14, 0)
			return true
		end,
	},
})

local borin = PollinationsNpc.start({
	name = "Borin",
	persona = "You are Borin, the tavern keeper. You are grumpy but you like most people. "
		.. "You mention your stew often. You speak in one short sentence at a time.",
})

local characters = {
	{ npc = mara, model = Workspace:WaitForChild("Mara") },
	{ npc = borin, model = Workspace:WaitForChild("Borin") },
}

for _, entry in ipairs(characters) do
	entry.bubble = attachBubble(entry.model, entry.npc.name)
	local body = entry.model:FindFirstChild("Body")
	local prompt = body and body:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			local reply = entry.npc.ask(player, "Hello. Who are you?")
			if reply then
				showBubble(entry.bubble, reply.dialogue)
			end
		end)
	end
end

local function nearestCharacter(player)
	local best, bestDistance
	for _, entry in ipairs(characters) do
		local distance = playerDistance(player, position(entry.model))
		if distance <= TALK_RANGE and (not bestDistance or distance < bestDistance) then
			best, bestDistance = entry, distance
		end
	end
	return best
end

local function handle(player, text)
	local lower = string.lower(text)
	local chosen
	for _, entry in ipairs(characters) do
		if string.find(lower, string.lower(entry.npc.name), 1, true) then
			chosen = entry
			break
		end
	end
	if not chosen then
		chosen = nearestCharacter(player)
	end
	if not chosen then
		return
	end

	local reply = chosen.npc.ask(player, text)
	if reply then
		showBubble(chosen.bubble, reply.dialogue)
	end
end

TextChatService.OnIncomingMessage = function(textChatMessage)
	local source = textChatMessage.TextSource
	if source then
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			task.spawn(handle, player, textChatMessage.Text)
		end
	end
	return Instance.new("TextChatMessageProperties")
end

if not mara.hasApiKey() then
	warn(
		"[PollinationsNpc] No API key found. Add the POLLINATIONS_API_KEY secret "
			.. "in Game Settings > Security, or set the PollinationsApiKey attribute "
			.. "on Workspace for a local test."
	)
end
