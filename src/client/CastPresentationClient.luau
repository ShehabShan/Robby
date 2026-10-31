--!strict
-- Prepared exclusive owner. NOT started by live init until atomic legacy cutover.
-- Starts are synchronous/non-yielding; consumers borrow the producer's inboxes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Owner = require(ReplicatedStorage.Shared.CastOwner)
local Map = require(ReplicatedStorage.Shared.CastCommandMap)
local Receipts = require(script.Parent.CastReceiptClient)
local Delivery = require(script.Parent.CastDeliveryClient)
local Contact = require(script.Parent.CastContactClient)
local Client = {}
local catalog: Map.Catalog = {}
local controller = Owner.new({
	Receipts.start,
	function()
		return Delivery.start(catalog)
	end,
	function()
		return Contact.start(catalog)
	end,
}, warn)
function Client.start(value: Map.Catalog): () -> ()
	-- Running consumers retain their original catalog on duplicate start. A new
	-- lifetime takes the catalog supplied by that call; no stale first-start capture.
	catalog = value
	return controller.start()
end
return Client
