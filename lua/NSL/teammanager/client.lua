-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/teammanager/client.lua
-- - Dragon

local kTeamWinScreensEnabled = false

function ScoreboardUI_GetBlueTeamName()
	local gameInfo = GetGameInfoEntity()
    return gameInfo and gameInfo:GetTeam1Name() or kTeam1Name
end

function ScoreboardUI_GetRedTeamName()
	local gameInfo = GetGameInfoEntity()
    return gameInfo and gameInfo:GetTeam2Name() or kTeam2Name
end

function InsightUI_GetTeam1Name()
	local gameInfo = GetGameInfoEntity()
    return gameInfo and gameInfo:GetTeam1Name() or kTeam1Name
end

function InsightUI_GetTeam2Name()
	local gameInfo = GetGameInfoEntity()
    return gameInfo and gameInfo:GetTeam2Name() or kTeam2Name
end

local function UpdateGUIScoreboardTeamCache(gameInfo)
	local script = ClientUI.GetScript("GUIScoreboard")
    if script then
		if not script.cachedTeamNames then
			script.cachedTeamNames = { }
		end
        script.cachedTeamNames[1] = gameInfo.team1name
		script.cachedTeamNames[2] = gameInfo.team2name
    end
	local topBar = GetGUIManager():GetGUIScriptSingle("GUIInsight_TopBar")
    if topBar then
        topBar:SetTeams(gameInfo.team1name, gameInfo.team2name)
		topBar:SetScore(gameInfo.team1score, gameInfo.team2score)
    end
end

table.insert(gTeamNamesUpdatedFunctions, UpdateGUIScoreboardTeamCache)

local function GUITeamNameModifications(scriptName, script)

	if scriptName == "GUIScoreboard" then
		
		local oldGUIScoreboardUpdateTeam = GUIScoreboard.UpdateTeam
		function GUIScoreboard:UpdateTeam(updateTeam)
			oldGUIScoreboardUpdateTeam(self, updateTeam)
			if not self.cachedTeamNames then
				local gameInfo = GetGameInfoEntity()
				self.cachedTeamNames = { }
				self.cachedTeamNames[1] = gameInfo and gameInfo:GetTeam1Name() or kTeam1Name
				self.cachedTeamNames[2] = gameInfo and gameInfo:GetTeam2Name() or kTeam2Name
			end
			local teamNameGUIItem = updateTeam["GUIs"]["TeamName"]
			local teamNum = updateTeam["TeamNumber"]
			local teamScores = updateTeam["GetScores"]()
			local numPlayers = table.count(teamScores)
			local playersOnTeamText = string.format("%d %s", numPlayers, numPlayers == 1 and Locale.ResolveString("SB_PLAYER") or Locale.ResolveString("SB_PLAYERS") )
			if teamNum == 1 then
				teamNameGUIItem:SetText( string.format("%s (%s)", self.cachedTeamNames[1], playersOnTeamText) )
			elseif teamNum == 2 then
				teamNameGUIItem:SetText( string.format("%s (%s)", self.cachedTeamNames[2], playersOnTeamText) )
			end
			
		end
		
	end
	
	if scriptName == "GUIGameEnd" then
		--LAZY
		local kEndStates = enum({ 'AlienPlayerWin', 'MarinePlayerWin', 'AlienPlayerLose', 'MarinePlayerLose', 'AlienPlayerDraw', 'MarinePlayerDraw' })
		local kMessageText = { [kEndStates.AlienPlayerWin] = "ALIEN_VICTORY",
							   [kEndStates.MarinePlayerWin] = "MARINE_VICTORY",
							   [kEndStates.AlienPlayerLose] = "ALIEN_DEFEAT",
							   [kEndStates.MarinePlayerLose] = "MARINE_DEFEAT",
							   [kEndStates.AlienPlayerDraw] = "DRAW_GAME",
							   [kEndStates.MarinePlayerDraw] = "DRAW_GAME" }
		
		local oldGUIGameEndSetGameEnded = GUIGameEnd.SetGameEnded
		function GUIGameEnd:SetGameEnded(playerWon, playerDraw, playerTeamType)
			oldGUIGameEndSetGameEnded(self, playerWon, playerDraw, playerTeamType)
			if kTeamWinScreensEnabled then
				local playerIsMarine = playerTeamType == kMarineTeamType
				local endState
				if playerWon then
					endState = playerIsMarine and kEndStates.MarinePlayerWin or kEndStates.AlienPlayerWin
				elseif playerDraw then
					endState = playerIsMarine and kEndStates.MarinePlayerDraw or kEndStates.AlienPlayerDraw
				else
					endState = playerIsMarine and kEndStates.MarinePlayerLose or kEndStates.AlienPlayerLose
				end
				local messageString = Locale.ResolveString(kMessageText[endState])
				local winningTeamName = nil
				if endState == kEndStates.MarinePlayerWin then
					winningTeamName = InsightUI_GetTeam1Name()
				elseif endState == kEndStates.AlienPlayerWin then
					winningTeamName = InsightUI_GetTeam2Name()     
				end
				if winningTeamName then
					messageString = string.format("%s Wins!", winningTeamName)
				end
				local decalLocation = GetNSLTeamDecalLocation(GetNSLTeamName(winningTeamName))
				if decalLocation then
					local xOffset = ((decalLocation - 1) % kNSLTeamDecalColumns) * kNSLTeamDecalSize
					local yOffset = math.floor((decalLocation - 1) / kNSLTeamDecalColumns) * kNSLTeamDecalSize
					self.endIcon:SetTexture(teamDDS)
					self.endIcon:SetTexturePixelCoordinates(xOffset, yOffset, xOffset + kNSLTeamDecalSize, yOffset + kNSLTeamDecalSize)
					self.messageText:SetPosition(Vector(0, 0, 0) * GUIScale(1))
					self.messageText:SetText(messageString)
				end
			end
		end
	end
	
end

ClientUI.AddScriptCreationEventListener(GUITeamNameModifications)