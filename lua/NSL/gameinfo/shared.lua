-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/gameinfo/shared.lua
-- - Dragon

local kMaxTeamNameLength = 50
local kMaxLeagueNameLength = 20

local networkVars = 
{
	nslconfig = "enum kNSLPluginConfigs",
	league = string.format("string (%d)", kMaxLeagueNameLength),
    team1name = string.format("string (%d)", kMaxTeamNameLength + 1),
	team2name = string.format("string (%d)", kMaxTeamNameLength + 1),
	team1score = "integer (0 to 10)",
	team2score = "integer (0 to 10)",
	teamupdates = "integer (0 to 9)",
	heartbeat = "boolean",
	tournamentMode = "boolean",
	captainsstate = "enum kNSLCaptainsStates"
}

local function ApplyClientCFGInitialUpdate(self)
	self:ApplyClientCFGUpdate()
	return false
end

local originalGameInfoOnCreate
originalGameInfoOnCreate = Class_ReplaceMethod("GameInfo", "OnCreate", 
	function(self)
		originalGameInfoOnCreate(self)
		
		if Server then
			self.nslconfig = GetNSLMode()
			self.league = string.sub(GetActiveLeague(), 1, kMaxLeagueNameLength) 
			self.team1name = kTeam1Name
			self.team2name = kTeam2Name
			self.team1score = 0
			self.team2score = 0
			self.teamupdates = 0
			self.heartbeat = false
			self.tournamentMode = GetNSLModEnabled()
			self.captainsstate = 1 -- GetNSLCaptainsState()
		end
		
		if Client then
		
			self.nslconfig = kNSLPluginConfigs.DISABLED
			self:AddFieldWatcher("teamupdates", GameInfo.ApplyClientTeamUpdates)
			self:AddFieldWatcher("nslconfig", GameInfo.ApplyClientCFGUpdate)
			self:AddTimedCallback(ApplyClientCFGInitialUpdate, 1)
		end
		
	end
)

function GameInfo:ApplyClientTeamUpdates()
	for i = 1, #gTeamNamesUpdatedFunctions do
		gTeamNamesUpdatedFunctions[i](self)
	end
	return true
end

function GameInfo:ApplyClientCFGUpdate()
	for i = 1, #gNSLConfigUpdateFunctions do
		gNSLConfigUpdateFunctions[i](self)
	end
	return true
end

function GameInfo:GetNSLConfig()
	return self.nslconfig
end

function GameInfo:GetLeagueName()
	return self.league
end

function GameInfo:GetTeam1Name()
	return self.team1name
end

function GameInfo:GetTeam2Name()
	return self.team2name
end

function GameInfo:GetTeam1Score()
	return self.team1score
end

function GameInfo:GetTeam2Score()
	return self.team2score
end

function GameInfo:GetHeartbeatRequired()
	return self.heartbeat
end

function GameInfo:GetTournamentMode()
    return self.tournamentMode
end

function GameInfo:GetNSLCaptainsState()
	return self.captainsstate
end

if Server then

	function GameInfo:SetNSLConfig(cfg)
		self.nslconfig = cfg
	end
	
	function GameInfo:SetLeagueName(newLeagueName)
		self.league = newLeagueName
	end
	
	function GameInfo:SetTeamsUpdated()
		self.teamupdates = (self.teamupdates + 1) % 10
	end
	
	function GameInfo:SetTeam1Name(t1n)
		self.team1name = string.sub(t1n, 1, kMaxTeamNameLength)
	end
	
	function GameInfo:SetTeam2Name(t2n)
		self.team2name = string.sub(t2n, 1, kMaxTeamNameLength)
	end
	
	function GameInfo:SetTeam1Score(t1s)
		self.team1score = Clamp(t1s, 0, 10)
	end
	
	function GameInfo:SetTeam2Score(t2s)
		self.team2score = Clamp(t2s, 0, 10)
	end
	
	function GameInfo:SetHeartbeatRequired(hb)
		self.heartbeat = hb
	end
	
	function GameInfo:SetTournamentMode(tM)
        self.tournamentMode = tM
    end

    function GameInfo:SetNSLCaptainsState(newState)
		self.captainsstate = newState
	end

end

Class_Reload("GameInfo", networkVars)