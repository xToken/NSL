### NSL Mod Commands Overview:

#### 'Ref' Commands - Players who are marked as referres or admins for the configured league (ENSL, AUSNS2 etc).

##### Merc Commands:
- **sv_nslclearmercs**: <team> - Clears approval of opposing teams mercs, '1' clearing any alien mercs.
- **sv_nslapprovemercs**: <team, opt. player> - Forces approval of teams mercs, '1' approving for marines which allows alien mercs.

##### Team Management:
- **sv_nslsetteamids**: <t1id, t2id> Will set the team ids manually.
- **sv_nslsetteamscores**: <t1score, t2score> Will set the team scores manually.
- **sv_nslswitchteams** Will switch team names (best used if setting team names manually).
- **sv_nslsetteamnames**: <team1name, team2name> Will set the team names manually, also will prevent automatic team name updates.
- **sv_nsltsay**: <team, message> - Will send a message to all players on the team provided that displays in yellow.
- **sv_nslsetteamspawns**: marinespawnname, alienspawnname, Spawns teams at specified locations. Locations must be exact

##### Player Management:
- **sv_nsllistcachedplayers**: Will list currently cached players names and steamIDs, for sv_nslreplaceplayer cmd.
- **sv_nslreplaceplayer**: <newPlayer, oldPlayer> Will force different player to take crashed/disconnect players place.
- **sv_nslpsay**: <player, message> - Will send a message to the provided player that displays in yellow.
- **sv_nslinfo**: <team> - marines,aliens,specs,other,all - Will return the player details from the corresponding league site.

##### General:
- **sv_nslsay**: <message> - Will send a message to all connected players that displays in yellow.
- **sv_nslpassword**: <password> - Sets the current password on the server.
- **sv_nslperfconfig**: <config> - Changes the performance config used by the NSL plugin.
- **sv_nslcfg**: <state> - disabled,gather,pcw,official - Changes the configuration mode of the NSL plugin.
- **sv_nslcancelstart**: Will cancel a game start countdown currently in progress.
- **sv_nslforcestart**: <seconds> - Will force the game start countdown to start in the provided amount of seconds, or 15 if blank.
- **sv_nslpausedisconnect**: Enables automatic pausing on client disconnect.

##### Pause:
- **sv_nslsetpauses**: <team, pauses> - Sets the number of pauses remaining for a team.
- **sv_nslpause**: Will pause/unpause game using standard delays.  Does not consume teams allowed pauses.

***

#### Player Commands - Anyone playing on a server running the NSL Mod

##### General Commands:
- **sv_nslhelp**: Returns various NSL commands and their helper messages.
- **sv_nslhandicap**: <0.1 - 1> Lowers your damage to the specified percentage.
- **coinflip**: Simulates a coinflip and returns heads or tails.
	
	- Chat Variants:
		- **coinflip**
		- **!coinflip**
		- **!flip**

- **stuck**: Will automatically attempt to unstuck you after a few seconds.
	
	- Chat Variants:
		- **stuck**
		- **/stuck**
		- **\\stuck**
		- **unstuck**

- **unstuck**: Same as stuck command
- **toggleopponentmute**: This will hide the opposing teams chat messages if enabled.
- **tom**: Same as toggleopponentmute command.
- **notready**: Marks your team as not ready to begin the game.
	
	- Chat Variants:
		- **notready**
		- **!notready**
		- **!notrdy**

- **ready**: Marks your team as ready to begin the game.
	
	- Chat Variants:
		- **ready**
		- **!ready**
		- **!rdy**

- **unpause**: Readies your team to resume the game.
	
	- Chat Variants:
		- **unpause**
		- **!unpause**
		- **resume**
		- **!resume**

- **gpause**: Pauses the game.
	
	- Chat Variants:
		- **pause**
		- **!pause**

##### Merc Commands:
- **sv_nslmerchelp**: Displays specific help information pertaining to approving and clearing mercs.
- **approvemercs**: Chat command, will approve opposing teams merc(s).
- **mercsok**: Chat or console command, will approve opposing teams merc(s).
- **clearmercs**: Chat or console command, will also clear any merc approvals for your team.
    
    - Chat Variants:
		- **rejectmercs**
		- **clearmercs**

***

##### Captains Mode Commands:
- **selectmap**: <map> - Will vote for the specified map.
- **selectplayer**: <player> - (Captains Only!) Will select the specified player to join your team.
- **votecaptain**: <player> - Will vote for the specified player to be a captain.  2 votes allowed per player.
- **leavegame**: Will remove you from the upcoming captains game.
    
    - Chat Variants:
		- **leavegame**
		- **!leave**

- **joingame**: Will register you for the upcoming captains game.
	
	- Chat Variants:
		- **joingame**
		- **!join**

***

#### Server Admin Commands - Players who are admins on the server

- **sv_nslallowperfconfigs**: Toggles league staff having access set performance configs.
- **sv_nslleagueadmins**: Toggles league staff having access to administrative commands on server.
- **sv_nslleaguemapcycle**: Toggles league map cycle being applied to server.  This will not overwrite server mapcycle!
- **sv_nslconfig**: <league> - Changes the league settings used by the NSL plugin (ENSL, AUSNS2, NOSTALGIA, DEFAULT.
- **sv_nslcaptainslimit**: <limit> Changes the player limit for each team in Captains mode.