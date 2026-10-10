-- Runs under the Luau CLI (no Roblox needed). Prompt.parseReply takes the
-- JSON decoder as an argument so the reply-parsing logic can be checked here.

local Prompt = require("../src/Prompt")

local passed, failed = 0, 0

local function check(name, condition, detail)
	if condition then
		passed += 1
		print("ok   " .. name)
	else
		failed += 1
		print("FAIL " .. name .. (detail and ("  " .. detail) or ""))
	end
end

-- A decoder that records what it was handed and returns a canned result, or
-- errors the way HttpService:JSONDecode does on malformed input.
local function stub(result)
	local calls = {}
	local decode = function(raw)
		table.insert(calls, raw)
		if result == nil then
			error("invalid JSON")
		end
		return result
	end
	return decode, calls
end

-- systemPrompt advertises only the action types the game registered.
check("lists registered action types", string.find(Prompt.systemPrompt("You are Mara.", { "open_gate", "close_gate" }), "open_gate", 1, true) ~= nil)
check("lists every registered type", string.find(Prompt.systemPrompt("You are Mara.", { "open_gate", "close_gate" }), "close_gate", 1, true) ~= nil)
check("keeps the persona", string.find(Prompt.systemPrompt("You are Mara.", {}), "You are Mara.", 1, true) ~= nil)

local withoutActions = Prompt.systemPrompt("You are Borin.", {})
check("asks for null action when none registered", string.find(withoutActions, "Always set action to null.", 1, true) ~= nil)
check("omits an empty action list", string.find(withoutActions, "propose one of these", 1, true) == nil)

-- buildMessages puts the system prompt first, history in order, question last.
local messages = Prompt.buildMessages("persona", {}, {
	{ player = "hi", npc = "hello" },
	{ player = "where is the gate", npc = "north" },
}, "thanks")
check("system message first", messages[1].role == "system")
check("first turn kept", messages[2].content == "hi" and messages[3].content == "hello")
check("second turn kept", messages[4].content == "where is the gate" and messages[5].content == "north")
check("question is last", messages[#messages].role == "user" and messages[#messages].content == "thanks")
check("system prompt is built", messages[1].content == Prompt.systemPrompt("persona", {}))

-- parseReply strips fences and hands the bare object to the decoder.
local decode, calls = stub({ dialogue = "north", action = nil })
Prompt.parseReply('```json\n{"dialogue":"north","action":null}\n```', decode)
check("strips a code fence", calls[1] == '{"dialogue":"north","action":null}', tostring(calls[1]))

decode, calls = stub({ dialogue = "north", action = nil })
Prompt.parseReply('Sure! {"dialogue":"north","action":null}', decode)
check("extracts from surrounding prose", calls[1] == '{"dialogue":"north","action":null}', tostring(calls[1]))

local reply = Prompt.parseReply(
	'{"dialogue":"north","action":{"type":"open_gate"}}',
	stub({ dialogue = "north", action = { type = "open_gate" } }))

check("keeps a proposed action", reply.action ~= nil and reply.action.type == "open_gate")
check("keeps the dialogue", reply.dialogue == "north")

-- A non-table action is dropped, so nothing reaches the action registry.
reply = Prompt.parseReply('{"dialogue":"north","action":"open_gate"}', stub({ dialogue = "north", action = "open_gate" }))
check("drops a non-table action", reply.action == nil)
check("keeps dialogue when action is malformed", reply.dialogue == "north")

reply = Prompt.parseReply('{"dialogue":"north","action":{"type":1}}', stub({ dialogue = "north", action = { type = 1 } }))
check("drops an action with a non-string type", reply.action == nil)

-- Anything that is not decodable still reaches the player as plain speech.
decode, calls = stub(nil)
reply = Prompt.parseReply("The mill is past the bridge.", decode)
check("plain prose needs no JSON", #calls == 0)
check("plain prose becomes dialogue", reply.dialogue == "The mill is past the bridge.")
check("plain prose has no action", reply.action == nil)

decode, calls = stub(nil)
reply = Prompt.parseReply('{"dialogue": oops', decode)
check("broken JSON falls back to raw text", reply.dialogue == '{"dialogue": oops' and reply.action == nil)

reply = Prompt.parseReply('{"dialogue":"a","unknown":1}', stub({ dialogue = "a" }))
check("ignores unknown fields", reply.dialogue == "a")

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	error("logic tests failed")
end
