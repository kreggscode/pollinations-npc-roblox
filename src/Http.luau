local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)

local Http = {}

local function retryable(status)
	return status == 429 or status >= 500
end

-- One chat turn against the Pollinations API. Returns
-- (true, { reply = string }) or (false, { error = string }).
function Http.chat(model, apiKey, messages)
	local body = HttpService:JSONEncode({
		model = model,
		messages = messages,
		max_tokens = Config.DEFAULT_MAX_TOKENS,
		temperature = Config.DEFAULT_TEMPERATURE,
	})

	local lastError = "unknown"

	for attempt = 1, Config.MAX_ATTEMPTS do
		local ok, response = pcall(function()
			return HttpService:RequestAsync({
				Url = Config.BASE_URL .. "/v1/chat/completions",
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
					["Authorization"] = "Bearer " .. apiKey,
				},
				Body = body,
			})
		end)

		if not ok then
			lastError = tostring(response)
			task.wait(attempt)
		elseif response.Success then
			local decoded = HttpService:JSONDecode(response.Body)
			local choice = decoded.choices and decoded.choices[1]
			local content = choice and choice.message and choice.message.content
			if type(content) == "string" and content ~= "" then
				return true, { reply = content }
			end
			lastError = "empty_completion"
		else
			lastError = "http_" .. tostring(response.StatusCode)
			if not retryable(response.StatusCode) then
				return false, { error = lastError }
			end
		end
	end

	return false, { error = lastError }
end

return Http
