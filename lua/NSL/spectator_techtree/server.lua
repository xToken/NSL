-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/spectator_techtree/server.lua
-- - Dragon

local hookedPlayers = { }

local function OnNetMsgRequestTeamTechTree(client, message)
    local player = client:GetControllingPlayer()
	local teamNum = message.teamNumber
	--Send stuff now, add them to table to receive updates for that team.
	--Safety third ladies
	if player and player:isa("Spectator") then
		if teamNum ~= 1 and teamNum ~= 2 then
			--Geeeeeeet outta here
			player.hookedTechTree = 0
			table.remove(hookedPlayers, player:GetId())
			Server.SendNetworkMessage(player, "ClearTechTree", {}, true)
		elseif player.hookedTechTree ~= teamNum then
			player.hookedTechTree = teamNum
			local team = GetGamerules():GetTeam(teamNum)
			if team then
				team.techTree:SendTechTreeBase(player)
			end
			table.insertunique(hookedPlayers, player:GetId())
		end
	end
end

Server.HookNetworkMessage("RequestTeamTechTree", OnNetMsgRequestTeamTechTree)

local function OnGameEndClearTechHooks()
	hookedPlayers = { }
end

table.insert(gGameEndFunctions, OnGameEndClearTechHooks)

local originalTeamGetPlayers
originalTeamGetPlayers = Class_ReplaceMethod("Team", "GetPlayers",
	function(self)
		--KEKEKEKEKEKEKE
		local players = originalTeamGetPlayers(self)
		if self.IsUpdatingTechTree and hookedPlayers then
			local HP = { }
			table.copy(hookedPlayers, HP)
			hookedPlayers = { }
			for index, pId in ipairs(HP) do
				if pId then
					local player = Shared.GetEntity(pId)
					--This creates a bit of a mess, but no good way to make sure EntIDs stay relevant without some kind of global OnEntityIDChanged thingie... it works :/
					if player and player:isa("Spectator") then
						--Always readd if still a spec and has a valid hook.
						if player.hookedTechTree == 1 or player.hookedTechTree == 2 then
							table.insert(hookedPlayers, player:GetId())
							if player.hookedTechTree == self:GetTeamNumber() then
								table.insert(players, player)
							end
						end
					end
				end
			end
			self.IsUpdatingTechTree = false
		end
		return players
	end
)

local originalPlayingTeamUpdateTechTree
originalPlayingTeamUpdateTechTree = Class_ReplaceMethod("PlayingTeam", "UpdateTechTree", 
	function(self)
		self.IsUpdatingTechTree = true
		originalPlayingTeamUpdateTechTree(self)
		self.IsUpdatingTechTree = false
	end
)