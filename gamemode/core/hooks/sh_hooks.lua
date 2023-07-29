
function GM:PlayerNoClip(client)
	return client:IsAdmin()
end

function GM:EntityEmitSound(data)
	if (data.Entity.ixIsMuted) then
		return false
	end
end

function GM:EntityRemoved(entity)
	if (SERVER) then
		entity:ClearNetVars()
	elseif (entity:IsWeapon()) then
		local owner = entity:GetOwner()

		-- GetActiveWeapon is the player's new weapon at this point so we'll assume
		-- that the player switched away from this weapon
		if (IsValid(owner) and owner:IsPlayer()) then
			hook.Run("PlayerWeaponChanged", owner, owner:GetActiveWeapon())
		end
	end
end

function GM:PlayerSwitchWeapon(client, oldWeapon, weapon)
	if (!IsFirstTimePredicted()) then
		return
	end

	-- the player switched weapon themself (i.e not through SelectWeapon), so we have to network it here
	if (SERVER) then
		net.Start("PlayerSelectWeapon")
			net.WriteEntity(client)
			net.WriteString(weapon:GetClass())
		net.Broadcast()
	end

	hook.Run("PlayerWeaponChanged", client, weapon)
end

do
	local KEY_BLACKLIST = IN_ATTACK + IN_ATTACK2

	function GM:StartCommand(client, command)
		if (!client:CanShootWeapon()) then
			command:RemoveKey(KEY_BLACKLIST)
		end
	end
end

function GM:CharacterVarChanged(char, varName, oldVar, newVar)
	if (ix.char.varHooks[varName]) then
		for _, v in pairs(ix.char.varHooks[varName]) do
			v(char, oldVar, newVar)
		end
	end
end

function GM:CanPlayerThrowPunch(client)
	return true
end

function GM:OnCharacterCreated(client, character)
	local faction = ix.faction.Get(character:GetFaction())

	if (faction and faction.OnCharacterCreated) then
		faction:OnCharacterCreated(client, character)
	end
end

function GM:GetDefaultCharacterName(client, faction)
	local info = ix.faction.indices[faction]

	if (info and info.GetDefaultName) then
		return info:GetDefaultName(client)
	end
end

function GM:CanPlayerUseCharacter(client, character)
	local banned = character:GetData("banned")

	if (banned) then
		if (isnumber(banned)) then
			if (banned < os.time()) then
				return
			end

			return false, "@charBannedTemp"
		end

		return false, "@charBanned"
	end

	local bHasWhitelist = client:HasWhitelist(character:GetFaction())

	if (!bHasWhitelist) then
		return false, "@noWhitelist"
	end
end

function GM:CanProperty(client, property, entity)
	if (client:IsAdmin()) then
		return true
	end

	if (CLIENT and (property == "remover" or property == "collision")) then
		return true
	end

	return false
end

function GM:PhysgunPickup(client, entity)
	local bPickup = self.BaseClass:PhysgunPickup(client, entity)

	if (!bPickup and entity:IsPlayer() and (client:IsSuperAdmin() or client:IsAdmin() and !entity:IsSuperAdmin())) then
		bPickup = true
	end

	if (bPickup) then
		if (entity:IsPlayer()) then
			entity:SetMoveType(MOVETYPE_NONE)
		elseif (!entity.ixCollisionGroup) then
			entity.ixCollisionGroup = entity:GetCollisionGroup()
			entity:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		end
	end

	return bPickup
end

function GM:PhysgunDrop(client, entity)
	if (entity:IsPlayer()) then
		entity:SetMoveType(MOVETYPE_WALK)
	elseif (entity.ixCollisionGroup) then
		entity:SetCollisionGroup(entity.ixCollisionGroup)
		entity.ixCollisionGroup = nil
	end
end

do
	local TOOL_DANGEROUS = {}
	TOOL_DANGEROUS["dynamite"] = true
	TOOL_DANGEROUS["duplicator"] = true

	function GM:CanTool(client, trace, tool)
		if (client:IsAdmin()) then
			return true
		end

		if (TOOL_DANGEROUS[tool]) then
			return false
		end

		return self.BaseClass:CanTool(client, trace, tool)
	end
end

function GM:Move(client, moveData)
	local char = client:GetCharacter()

	if (char) then
		if (client:GetNetVar("actEnterAngle")) then
			moveData:SetForwardSpeed(0)
			moveData:SetSideSpeed(0)
			moveData:SetVelocity(vector_origin)
		end

		if (client:GetMoveType() == MOVETYPE_WALK and moveData:KeyDown(IN_WALK)) then
			local mf, ms = 0, 0
			local speed = client:GetWalkSpeed()
			local ratio = ix.config.Get("walkRatio")

			if (moveData:KeyDown(IN_FORWARD)) then
				mf = ratio
			elseif (moveData:KeyDown(IN_BACK)) then
				mf = -ratio
			end

			if (moveData:KeyDown(IN_MOVELEFT)) then
				ms = -ratio
			elseif (moveData:KeyDown(IN_MOVERIGHT)) then
				ms = ratio
			end

			moveData:SetForwardSpeed(mf * speed)
			moveData:SetSideSpeed(ms * speed)
		end
	end
end

function GM:CanTransferItem(itemObject, curInv, inventory)
	if (SERVER) then
		local client = itemObject.GetOwner and itemObject:GetOwner() or nil

		if (IsValid(client) and curInv.GetReceivers) then
			local bAuthorized = false

			for _, v in ipairs(curInv:GetReceivers()) do
				if (client == v) then
					bAuthorized = true
					break
				end
			end

			if (!bAuthorized) then
				return false
			end
		end
	end

	-- we can transfer anything that isn't a bag
	if (!itemObject or !itemObject.isBag) then
		return
	end

	-- don't allow bags to be put inside bags
	if (inventory.id != 0 and curInv.id != inventory.id) then
		if (inventory.vars and inventory.vars.isBag) then
			local owner = itemObject:GetOwner()

			if (IsValid(owner)) then
				owner:NotifyLocalized("nestedBags")
			end

			return false
		end
	elseif (inventory.id != 0 and curInv.id == inventory.id) then
		-- we are simply moving items around if we're transferring to the same inventory
		return
	end

	inventory = ix.item.inventories[itemObject:GetData("id")]

	-- don't allow transferring items that are in use
	if (inventory) then
		for _, v in pairs(inventory:GetItems()) do
			if (v:GetData("equip") == true) then
				local owner = itemObject:GetOwner()

				if (owner and IsValid(owner)) then
					owner:NotifyLocalized("equippedBag")
				end

				return false
			end
		end
	end
end

function GM:CanPlayerEquipItem(client, item)
	return item.invID == client:GetCharacter():GetInventory():GetID()
end

function GM:CanPlayerUnequipItem(client, item)
	return item.invID == client:GetCharacter():GetInventory():GetID()
end

function GM:OnItemTransferred(item, curInv, inventory)
	local bagInventory = item.GetInventory and item:GetInventory()

	if (!bagInventory) then
		return
	end

	-- we need to retain the receiver if the owner changed while viewing as storage
	if (inventory.storageInfo and isfunction(curInv.GetOwner)) then
		bagInventory:AddReceiver(curInv:GetOwner())
	end
end

function GM:ShowHelp() end

function GM:PreGamemodeLoaded()
	hook.Remove("PostDrawEffects", "RenderWidgets")
	hook.Remove("PlayerTick", "TickWidgets")
	hook.Remove("RenderScene", "RenderStereoscopy")
end

function GM:PostGamemodeLoaded()
	baseclass.Set("ix_character", ix.meta.character)
	baseclass.Set("ix_inventory", ix.meta.inventory)
	baseclass.Set("ix_item", ix.meta.item)
end

if (SERVER) then
	util.AddNetworkString("PlayerVehicle")

	function GM:PlayerEnteredVehicle(client, vehicle, role)
		-- UpdateAnimationTable(client)

		net.Start("PlayerVehicle")
			net.WriteEntity(client)
			net.WriteEntity(vehicle)
			net.WriteBool(true)
		net.Broadcast()
	end

	function GM:PlayerLeaveVehicle(client, vehicle)
		-- UpdateAnimationTable(client)

		net.Start("PlayerVehicle")
			net.WriteEntity(client)
			net.WriteEntity(vehicle)
			net.WriteBool(false)
		net.Broadcast()
	end
else
	net.Receive("PlayerVehicle", function(length)
		local client = net.ReadEntity()
		local vehicle = net.ReadEntity()
		local bEntered = net.ReadBool()

		-- UpdateAnimationTable(client, bEntered and vehicle or false)
	end)
end
