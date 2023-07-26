
ITEM.name = "Attachment Base"
ITEM.model = "models/Items/BoxSRounds.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.attachment = "md_rugersup"
ITEM.weapons = {}
ITEM.isAttachment = true
ITEM.description = "A box that contains a weapon attachment."
ITEM.category = "Attachments"
ITEM.useSound = "items/ammo_pickup.wav"

-- On player uneqipped the item, Removes a weapon from the player and keep the ammo in the item.
-- ITEM.functions.use = {
-- 	name = "Attach",
-- 	tip = "useTip",
-- 	icon = "icon16/add.png",
-- 	OnRun = function(item)
--         CustomizableWeaponry:giveAttachment( item.player, item.attachment )

-- 		return true
-- 	end,
-- }