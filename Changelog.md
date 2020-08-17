# Changelog

## 8-17-20 (Buld 139)
- Added logic to parse league bans and enforce them on associated servers.
	- Currently supports 'gather' level bans, which block users from PCW/GATHERS - and full bans which block users from all modes.
- Added sv_nslenforcegatherbans server command to toggle if 'gather' level bans are enforced.

## 6-12-20 (Buld 138)
- Fixed issue with asset error after 332 relating to scoreboard changes
- Corrected issue allowing for 1 frame of input even during pauses resulting from 332 input changes.

## 11-28-19 (Buld 137)
- Fixed incorrect team being awarded victory from auto-concede
- Added server admin command to disable automatic error reporting
- Locked marine models to male in officials

## 11-14-19 (Buld 136)
- Fixed assert from calling marine variant function that was removed with B331 BMAC
- Added fallback default name when using ForceLeagueNicks and an unregistered player joins

## 9-20-19 (Buld 135)
- Fixed new main menu not working when game was paused (Build 329)
- Added sv_nslleaguemapcycle, toggles using the mapcycle configured in the respective league config.  This is a server admin command only!
- Added note to sv_nslcfg command about seasons & server configs needed mapcycle to clear if mod is disabled.
- Changed sv_nslcaptainslimit to a server admin only command
- Cleaned up admin command validations a bit
- Added ServerAdminsAreRefs config flag to be used in future by default league config

## 9-13-19 (Buld 133)
- Fixed random alien spawn not respecting spawn rules for maps with spawn override entities

## 7-13-19 (Buld 132)
- Fixed issue with cross spawn vanilla logic not being cached, which caused issues when aliens selected certain spawn locations.

## 7-8-19 (Buld 131)
- Consolidated custom spawn toggles into single option.
- Supports UseFixedSpawnsWhenLoaded (overrides other options), CustomSpawns - allows spawns to be configured by dates and AliensChoose which allows aliens to choose their spawn.
- Added client side toggleopponentmute console command, toggles the display of opponents chat messages on or off.

## 6-23-19 (Buld 130)
- 'Ready' command will no longer work during pauses for game resets.
- During a pause, 'ready' will toggle your teams readiness for the game to unpause, just like resume/unpause.
- Fixed GUI workarounds to allow specific GUI scripts to update during pause so that it works with 328 changes.
- Fixed issue where you couldnt mark your team as not ready during a pause after you had marked them as ready.
- Added config setting to control server ranking status.
- Added config setting to control forcing league nicknames.
- Removed legacy first person spectating block code, was no longer functional and not currently in use by any leagues.
- Added game build to NSL error reporter.
- Fixed Default perf level not being selectable after changing to other perf levels

## 6-23-19 (Buld 128)
- Fixed server commands being server admin commands and not 'League' commands
- Added function to make command validations easier

## 6-21-19 (Buld 127)
- Fixed server commands being registered multiple times in some cases
- Added support for leagues without player databases
- Fixed player data cache not being cleared when league is changed
- Fully removed optimizations module now that entity throttling is live in 328
- Added additional league

## 6-8-19 (Buld 126)
- Fixed assert caused by players joining that didnt have badges

## 6-7-19 (Buld 125)
- Fixed badge icon granted being 1 rank off from actual players rank
- Updated to new badge icons
- Disabled heartbeat system
- Disabled optimizations

## 4-28-19 (Buld 123)
- Fixed assert caused by IP spawning model

## 4-28-19 (Buld 122)
- Fixed assert caused by NutrientMist

## 4-23-19 (Buld 121)
- Compatibility with B327

## 4-16-19 (Buld 120)
- Removed UpValue utility func, use built-in NS2 debug utility func
- Re-enabled sound FX optimizations with fixes for local looping sounds not playing correctly.
- Fixed script error for cyst wakeup calls if cysts had children that dont sleep

## 2-28-19 (Buld 118)
- Fixed cysts ticking too fast after they had slept for a considerable amount of time
- Fixed umbra effect sometimes lingering on entities forever
- Re-enabled optimizations module

## 2-14-19 (Buld 117)
- Removed client side model clear on ghost structure poofing, was causing asserts for spectators.

## 2-9-19 (Build 116)
- Fixed ARCs and MACs getting stuck in the Robo because it didnt open :<

## 2-8-19 (Build 115)
- Re-enabled optimizations module (beware!)

## 1-30-19 | 2-5-19 (Builds 113-114)
- A/B testing of optimizations module

## 1-28-19 (Build 112)
- Adjusted all console commands to use default admin commands hooks - Refs are still given access to 'league' based commands.  No change in overall functionality
- Added 'Optimizations' module which reconfigures sleep mixin to actually completely turn off entity updates - various mixin and other tweaks to support this
- Added 'Captains' mode to NSL mod, allows for picking captains and then those captains picking teams.  Currently uses chat/console commands only!
- Added small rate limit to resume to prevent multiple people from typing it at the same time (like the limiter on ready)
- Added checks on sv_nslsetteamspawns command to prevent asserts
- Added additional insight hooks to ensure team scores get updated if you join spectate after the sync
- Removed some debug prints from the team decal system

## 1-15-19 (Build 110)
- Added language system, based on clients locale
- All messages can be translated by the language system
- Restructured configs to have 1 config per league
- Fixed 're' during a pause leaving the game as paused after the reset.

## 1-7-19 (Build 108)
- Changed SpectatorTechMaps to hook vanilla techmap system, this should ensure compatibility with ProGMod tech trees

## 1-6-19 (Build 107)
- Added networked tournamentmode boolean from ProGMod

## 1-6-19 (Build 106)
- Fixed silly typo causing sv_nslswitchteams not to actually switch the team names

## 1-1-19 (Build 105)
- Updated decal system to only show team decals if valid decal exists for the team
- Added hints for spectator tech tree buttons

## 12-31-18 (Build 104)
- Added heartbeat system, clients need to send message every few seconds or they will be disconnected by the server after 20 seconds of no messages.
- Added command to set team IDs manually.
- Updated formatting of countdown messages, added alternate sound to last 5 seconds
- Updated help command structure and location of help messages in code.
- Other small changes as part of restructuring & code cleanup

## 12-28-18 (Build 103)
- Statesave no longer transfers spectators of the disconnected player to the temporary player that is disconnected.
- PlayerInfoEntity is now allowed to update during pauses
- Backdated scoreboard update times to allow disconnected clients to be deleted during a pause.

## 12-28-18 (Build 102)
- Restructured NSL mod files, will allow for better maintainability
- NSL Mod will now grant NSL team badges based on team ID (format for badge is ENSL#Team_ID).  This is the format used by the NSL Team Badges mod
- Decals now use individual textures, will load the team texture based on team ID.  Each team decal should be placed in a folder in materials\teamlogos\teamID\decal.material.
	- Each material file can reference the same shader, shader = "materials/teamlogos/teamlogos.surface_shader"
	- There should be 3 .dds textures created, albedoMap, emissiveMap and opacityMap.
- Fixed missing names on NSL badges
- Tons of other fixes I forgot :D

## 12-27-18 (Build 101)

- Fixed assert that could cause instability if disconnected 'saved' players were kicked, and then the original player re-joined after.
- Updated decal system to allow for individual decals for each team, with a <10 character name.

## 12-21-18 (Build 100)

- Added automatic error reporting on round end
- Added build number, starting at 100 cause i never had it before :D

## 2-14-18

- Fixed team join function hook not working for officials mainly.
- Updated server settings to prevent some exploits in officials mode.
- You cannot leave the alien or marine team during the countdown phase.
- Unstuck will now also prevent the actual unstuck from triggering during a pause, not just the initiation of one.
- Corrected many minor issues with perf configs and adjusted 'defaults' to be scanned shortly after game init.
- Improved spawn location options & config file settings. (values from keatsandyeats)
- Coin Flip. (keatsandyeats)

## 11-4-17

- Adjustments for Default Skins setting - Marines can change sex (using default skin).  Exos cannot change skins anymore, and shoulder pads are back.
- Pregame lerk damage fix (keatsandyeats)

## 9-16-17

- Allowed lifeform/weapon purchases during warmup - damage disabled (keatsandyeats)
- Made pregame command structure damage radius smaller (keatsandyeats)

## 8-8-17

- Added invalid sound for some NSL messages (pause/admin) (keatsandyeats)
- Added shine command access for NSL admins (if enabled) (keatsandyeats)
- Corrected automatic mapcycle on invalid mapchanges (keatsandyeats)

## 2-8-17

- Updated config system to have multiple individual configs so things are more clear.
- TeamBadgeNames is loaded by clients now, can be used to show team decals on endgame vis.
- State save defaults to on.
- NSL decal system added.
- League can select colors for messages.

## 3-10-16

- Updated decal system to use models and a ton of other BS to mitigate infestation overlay issues.
- Split out files for some slightly better organization (its still terrible, NSL mod has become a mess).

## 2-16-16

- Fixes for statesave not joining players to team as needed.
- Altchat mode now main chat mode.

## 2-14-16

- Fix for league admin access not working after NS2 patch.

## 1-24-16

- Updated state saving to account for NS2 not counting bot clients as players in the server browser, but counting them in the reserve-slot system.  This would cause anyone rejoining after a d/c on a full server to be kicked.
- State saving defaults to disabled now, can be toggled on with: sv_nslstatesave

## 1-6-16

- Updated with dev version of state saving for players that crash/disconnect.

## 1-4-16

- Updated local config to allow alien vision modifications.
- Was already updated in remote file.

## 1-3-16

- Fixed missing badge descriptions

## 1-1-16

- Added client side sync of NSL Plugin state.

## 12-24-15

- Update for BWLimit increases in Vanilla

## 12-4-15

- Reverted seasons change

## 12-4-15

- NSL Mod will disable seasonal content if enabled on map load.

## 11-1-15

- Quick fix for badges not always being sync'd to new clients.

## 10-31-15

- Added support for new user API on ENSL site.
- Added new badges for additional user ranks.
- Added sv_nslleagueadmins which defaults to disabled.  When enabled, refs, casters and admins are granted access to some server admin commands based on league configs.

## 10-25-15

- Fix for assert in handicap plugin.
- Updates for scoreboard changes to correctly set teamnames.
- Fix for formatting error with Insight end game messages.

## 9-30-15

- Added support for handicaps.
- sv_nslhandicap (0.1-1), 1 = 100% damage, 0.75 = 75% damage.
- Players with handicap have the (%) appended to their name.
- Also the percent is visible in sv_nslinfo

## 11-13-14

- Fixes for pause plugin and jetpacks

## 10-16-14

- Added NSL configurable spawns

## 10-7-14

- Fixed spectators being able to 're' games.
- Fixed PCW config blocking players from joining ongoing games larger than 6v6

## 9-1-14

- Fixed whips being able to attack during pauses.

## 8-30-14

- Corrected sendrate not being applied if tickrate was unchanged.

## 8-25-14

- Updated for greater rates configuration
- Added tech map to spectators

## 8-22-14

- Updated for B268
- Tweaked configs slightly for better clarity for me.

## 8-5-14

- Updated for B267.
- Added enforced NSL consistency checks.
- Added extra rates configurations.

## 7-12-14

- Another attempt at fixing chat in a way that works with more mods.

## 6-30-14

- Fixed chat not consuming bind key when game is paused.
- Fixed marine commander logging in when pause activates bugging out chair.
- Fixed default team names not transferring pause usage.

## 6-1-14

- Fixed issue with automatic Referee access for NSL not working as expected.
- Added 'levels' of ref badges

## 5-27-14

- Updates to add badges for 'Refs'
- Added pRes block to players joining after initial game start.

## 4-15-14

- Major changes to pause plugin and timesync to clients.  Should resolve many issues, including spectator view bugs, clients always running, time drift on clients and other issues.  Also fixed follow spectate not obeying selected player in insight, and added callbacks for mod state changes.

## 3-31-14

- Updated to hopefully fix some pause related issues.

## 3-21-14

- Updated default configs
- Added sanity check to SendClientMessage function

## 3-13-14

- Added sv_nslsetpauses command to set available pauses for a team
- Changed max pauses to be per map, not per round
- Fixed issue with NSL commands when mod was set to disabled.

## 3-4-14

- Final parts of 'League' update.

## 3-3-14

- Updated for changes in B263
- Fixed pause plugin issues with beacon and scoreboard changes.
- Made changes to make mod more of an 'League' mod - can support NSL and AusNS2 leagues now, could also have supported the WC.

## 2-14

- Updated to support B263

## 12-30 Changes

- Added support for nsl version of Eclipse