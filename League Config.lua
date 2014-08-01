{
	"Version": 1.1,
	"Configs": [
		{
		"LeagueName": 							"NSL",
		"PlayerDataURL": 						"http://www.ensl.org/plugin/user/",
		"PlayerDataFormat":						"ENSL",
		"PlayerRefLevel": 						1,
		"AutomaticMapCycleDelay":				10800,
		"PauseEndDelay": 						5,
		"PauseStartDelay": 						5,
		"PauseMaxPauses": 						3,
		"PausedReadyNotificationDelay": 		30,
		"PauseEnabled": 						true,
		"Interp": 								70,
		"MoveRate": 							50,
		"ClientRate": 							20,
		"TickRate":								30,
		"MaxDataRate": 							25600,
		"FriendlyFireDamagePercentage": 		0.33,
		"FriendlyFireEnabled":			 		true,
		"TournamentModeAlertDelay": 			30,
		"TournamentModeGameStartDelay": 		15,
		"RefereeBadge":				 			{
													"ensl_staff":							1,
													"ensl_admin":							2
												},
		"PCW": 									{
													"PausedMaxDuration": 					300,
													"TournamentModeForfeitClock":			0,
													"TournamentModeRestartDuration": 		90,
													"Limit6PlayerPerTeam": 					false,
													"MercsRequireApproval": 				false
												},
		"OFFICIAL":								{
													"PausedMaxDuration": 					300,
													"TournamentModeForfeitClock":			900,
													"TournamentModeRestartDuration": 		30,
													"Limit6PlayerPerTeam": 					true,
													"MercsRequireApproval": 				true
												},
		"REFS":									[ 37983254, 2582259, 4204158, 3834993, 9821488, 1009560, 850663, 870339, 3834993, 220612, 
													33962486, 26400815, 4048968, 4288812, 44665807, 28798044, 40509515, 39359741, 64272164, 
													56472390, 42416427, 7862563, 1080730, 221386, 42984531, 37996245, 49465,
													44778147, 10498798, 24256940, 22793, 80887771, 512557, 4288812, 12482757, 54867496, 
													711854, 6851233, 13901505, 19744894, 206793, 1561398, 8973, 50582634, 73397263, 
													15901849,  38540300, 136317, 1592683, 7494, 20682781, 90227495, 42608442, 3023411, 81519, 
													3814554, 70496041, 41851898, 35329790, 1207116, 69364649, 3490104, 115723837, 
													15097215, 100657023, 95816540, 599694, 131547597, 24995964, 7246681
												],
		"PLAYERDATA":							{
												"999999999999": { 
																"NSL_Team": "ThisIsAnExample",
																"NICK": "TestUser",
																"S_ID": "0:1:12345678910"
																}
												}
		},
		{
		"LeagueName": 							"AusNS2",
		"PlayerDataURL": 						"http://ausns2.org/league-api.php?lookup=player&steamid=",
		"PlayerDataFormat":						"AUSNS",
		"PlayerRefLevel": 						1,
		"AutomaticMapCycleDelay":				10800,
		"PauseEndDelay": 						5,
		"PauseStartDelay": 						1,
		"PauseMaxPauses": 						3,
		"PausedReadyNotificationDelay": 		30,
		"PauseEnabled": 						true,
		"Interp": 								70,
		"MoveRate": 							50,
		"ClientRate": 							20,
		"TickRate":								30,
		"MaxDataRate": 							25600,
		"FriendlyFireDamagePercentage": 		0.33,
		"FriendlyFireEnabled":			 		true,
		"TournamentModeAlertDelay": 			30,
		"TournamentModeGameStartDelay": 		15,
		"PCW": 									{
													"PausedMaxDuration": 					120,
													"TournamentModeForfeitClock":			0,
													"TournamentModeRestartDuration": 		90,
													"Limit6PlayerPerTeam": 					false,
													"MercsRequireApproval": 				false
												},
		"OFFICIAL":								{
													"PausedMaxDuration": 					90,
													"TournamentModeForfeitClock":			1200,
													"TournamentModeRestartDuration": 		30,
													"Limit6PlayerPerTeam": 					true,
													"MercsRequireApproval": 				true
												},
		"REFS":									[ ],
		"PLAYERDATA":							{
												"999999999999": { 
																"NSL_Team": "ThisIsAnExample", 
																"NICK": "TestUser", 
																"S_ID": "0:1:12345678910" 
																}
												}
		}
	],
	"EndOfTable": true
}