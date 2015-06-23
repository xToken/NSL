// Natural Selection League Plugin
// Source located at - https://github.com/xToken/NSL
// lua\nsl_unstuck_server.lua
// - Dragon

//NS2 Unstuck Plugin

local UnstuckOriginTracker = { }  	//Tracks origin of clients in unstuck Queue.
local LastUnstuckTracker = { }		//Tracks time of clients last successful unstuck.
local UnstuckRetryTracker = { }		//Tracks retries of unstuck up to kMaxUnstuckAttemps.
local kUnstuckRate = 30
local kMinUnstuckTime = 2.5
local kMaxUnstuckTime = 5
local kMaxUnstuckAttemps = 50
local kUnstuckOffset = 2

local function UnstuckCallback(self)
	
	local client = Server.GetOwner(self)
	if not client then
		return false
	end
	local ns2id = client:GetUserId()
	local origin = Vector(UnstuckOriginTracker[ns2id])
	if not self:GetIsAlive() or (HasMixin(self, "Stun") and self:GetIsStunned()) or (origin - self:GetOrigin()):GetLength() > 0.1 or self:isa("Embryo") then
		SendClientMessage(client, GetNSLMessage("UnstuckCancelled"))
		UnstuckRetryTracker[ns2id] = 0
		return false
	end
	origin.x = origin.x + (math.random(-1,1) * kUnstuckOffset)
	origin.z = origin.z + (math.random(-1,1) * kUnstuckOffset)
	local techId = kTechId.Skulk
	techId = self:GetTechId()
	local extents = HasMixin(self, "Extents") and self:GetExtents() or LookupTechData(techId, kTechDataMaxExtents)
    local capsuleHeight, capsuleRadius = GetTraceCapsuleFromExtents(extents)
    local spawnPoint = GetRandomSpawnForCapsule(capsuleHeight, capsuleRadius, origin, 3, 10, EntityFilterOne(self))
	if spawnPoint then
		SpawnPlayerAtPoint(self, spawnPoint)
		LastUnstuckTracker[ns2id] = Shared.GetTime()
		UnstuckOriginTracker[ns2id] = nil
		UnstuckRetryTracker[ns2id] = 0
		SendClientMessage(client, GetNSLMessage("Unstuck"))
		return false
	else
		if UnstuckRetryTracker[ns2id] < kMaxUnstuckAttemps then
			UnstuckRetryTracker[ns2id] = UnstuckRetryTracker[ns2id] + 1
			LastUnstuckTracker[ns2id] = Shared.GetTime()
			//Keep that donkey moving.
			return true
		else
			UnstuckOriginTracker[ns2id] = nil
			LastUnstuckTracker[ns2id] = 0
			SendClientMessage(client, string.format(GetNSLMessage("UnstuckFailed"), UnstuckRetryTracker[ns2id]))
			UnstuckRetryTracker[ns2id] = 0
			return false
		end
	end
	return false
end

local function UnstuckIntialCallback(self)
	self:AddTimedCallback(UnstuckCallback, 0.02)
	return false
end

local function RegisterClientStuck(client)
	if client ~= nil then
		local ns2id = client:GetUserId()
		if LastUnstuckTracker[ns2id] == nil or LastUnstuckTracker[ns2id] + kUnstuckRate < Shared.GetTime() then
			local player = client:GetControllingPlayer()
			local unstucktime = math.random(kMinUnstuckTime, kMaxUnstuckTime)
			UnstuckOriginTracker[ns2id] = player:GetOrigin()
			LastUnstuckTracker[ns2id] = Shared.GetTime()
			UnstuckRetryTracker[ns2id] = 0
			player:AddTimedCallback(UnstuckIntialCallback, unstucktime)
			SendClientMessage(client, string.format(GetNSLMessage("UnstuckIn"), unstucktime))
		else
			SendClientMessage(client, string.format(GetNSLMessage("UnstuckRecently"), (LastUnstuckTracker[ns2id] + kUnstuckRate) - Shared.GetTime()))
		end
	end
end

gChatCommands["stuck"] = RegisterClientStuck
gChatCommands["/stuck"] = RegisterClientStuck
gChatCommands["\\stuck"] = RegisterClientStuck
gChatCommands["unstuck"] = RegisterClientStuck

Event.Hook("Console_stuck",               RegisterClientStuck)
Event.Hook("Console_unstuck",               RegisterClientStuck)