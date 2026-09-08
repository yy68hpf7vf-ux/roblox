--!strict
--[[
	ChatTagService

	The VIP chat tag the store promises.

	Small, but it was a real gap: the store copy sold "a chat tag" and nothing in
	the game delivered one, which is exactly the kind of thing that earns a refund
	request. If the description says it, the code has to do it.

	Uses TextChatService, which is the current chat system. On a place still using
	the legacy chat this quietly does nothing rather than erroring -- the tag is
	cosmetic and not worth taking a server down for.
]]

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local PassService = require(script.Parent.PassService)

local ChatTagService = {}

local TAGS = {
	{ pass = "vip", text = "VIP", color = "#FFC85C" },
}

function ChatTagService.start()
	local ok, err = pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage)
			local properties = Instance.new("TextChatMessageProperties")

			local source = message.TextSource
			if not source then
				return properties
			end

			local player = Players:GetPlayerByUserId(source.UserId)
			if not player then
				return properties
			end

			local prefixes = {}
			for _, tag in TAGS do
				if PassService.owns(player, tag.pass) then
					table.insert(prefixes, `<font color="{tag.color}">[{tag.text}]</font> `)
				end
			end

			if #prefixes > 0 then
				properties.PrefixText = table.concat(prefixes) .. message.PrefixText
			end

			return properties
		end
	end)

	if not ok then
		warn(`[ChatTagService] could not attach chat tags: {err}`)
	end
end

return ChatTagService
