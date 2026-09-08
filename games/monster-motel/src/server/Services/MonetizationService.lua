--!strict
--[[
	MonetizationService

	Receipt handling for developer products, and prompt helpers for both products
	and gamepasses.

	Two things this file takes seriously:

	  * Receipts are granted exactly once. ProcessReceipt can fire more than once
	    for the same PurchaseId, and if the profile is not loaded yet we return
	    NotProcessedYet so Roblox retries rather than taking someone's Robux for
	    nothing.
	  * Cash drops are sized against the buyer's own rent and the exact figure is
	    on the button before the prompt opens. Nobody should have to guess what
	    they are getting, and nobody should find out their drop was worth four
	    minutes at the rate they now earn.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Format = require(Shared.Util.Format)
local Schema = require(Shared.Schema)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Remote = require(script.Parent.Remote)

type Profile = Schema.Profile

local MonetizationService = {}

local RECEIPT_HISTORY = 60

local function alreadyGranted(profile: Profile, purchaseId: string): boolean
	return table.find(profile.purchases, purchaseId) ~= nil
end

local function recordReceipt(profile: Profile, purchaseId: string)
	table.insert(profile.purchases, purchaseId)
	while #profile.purchases > RECEIPT_HISTORY do
		table.remove(profile.purchases, 1)
	end
end

--[[ What a cash drop is worth to this player right now. The store calls this
     through the state payload so the button and the grant always agree. ]]
function MonetizationService.cashAmount(player: Player, profile: Profile, product: Monetization.Product): number
	return EconomyService.secondsToCash(player, profile, product.seconds or 0, product.floor)
end

local function grant(player: Player, profile: Profile, product: Monetization.Product): boolean
	if product.kind == "cash" then
		local amount = MonetizationService.cashAmount(player, profile, product)
		EconomyService.addCash(player, profile, amount)
		Remote.notify(player, `${Format.comma(amount)} added to your wallet. Thank you.`, "good")
		return true
	elseif product.kind == "boost" then
		EconomyService.grantBoost(profile, product.multiplier or 2, product.duration or 0)
		EconomyService.markDirty(player)
		Remote.notify(
			player,
			`{Format.multiplier(product.multiplier or 2)} rent for {Format.duration(EconomyService.boostRemaining(profile))}.`,
			"good"
		)
		return true
	end
	return false
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		-- They left before we could grant. Roblox will call again next time they
		-- join; leaving it unprocessed is what keeps the purchase intact.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = DataService.get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(info.PurchaseId)
	if alreadyGranted(profile, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = Monetization.ProductByAsset[info.ProductId]
	if not product then
		warn(`[MonetizationService] receipt for unknown product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(grant, player, profile, product)
	if not ok or not granted then
		warn(`[MonetizationService] failed to grant {product.id} to {player.Name}: {granted}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	recordReceipt(profile, purchaseId)

	-- Write immediately. If the server dies between the grant and the next
	-- autosave, the player has paid and lost the goods.
	DataService.save(player)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.promptProduct(player: Player, productId: string): (boolean, string)
	local product = Monetization.ProductById[productId]
	if not product then
		return false, "No such item."
	end
	if not Monetization.isConfigured(product.assetId) then
		return false, "That item is not available yet."
	end
	MarketplaceService:PromptProductPurchase(player, product.assetId)
	return true, ""
end

function MonetizationService.promptGamepass(player: Player, passId: string): (boolean, string)
	local pass = Monetization.GamepassById[passId]
	if not pass then
		return false, "No such pass."
	end
	if not Monetization.isConfigured(pass.assetId) then
		return false, "That pass is not available yet."
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.assetId)
	return true, ""
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	local unconfigured = {}
	for _, pass in Monetization.Gamepasses do
		if not Monetization.isConfigured(pass.assetId) then
			table.insert(unconfigured, pass.id)
		end
	end
	for _, product in Monetization.Products do
		if not Monetization.isConfigured(product.assetId) then
			table.insert(unconfigured, product.id)
		end
	end
	if #unconfigured > 0 then
		warn(
			`[MonetizationService] no asset id set for: {table.concat(unconfigured, ", ")}. `
				.. `They are hidden from the store until you fill them in in Config/Monetization.lua.`
		)
	end
end

return MonetizationService
