#include "gatherMatch.as";

#define SERVER_ONLY

void startGathering(CRules@ this){
	gatherMatch@ gatherGame = getGatherObject(this);
	gatherGame.setNumPlayers(this.get_s32("numPlayers"));
	gatherGame.resetGameVars();
	gatherGame.isGameRunning=true;

	//assign player to a seclev that allows them to join when the server is full
	assignPlayersJoinFullSeclev(gatherGame);

	getNet().server_SendMsg("a gather game is starting!! Players not in this match will be moved to spectator");
	putAllPlayersIntoTeams(this);
}

void clearGame(CRules@ this){
	gatherMatch@ gatherGame = getGatherObject(this);
	if(!gatherGame.isGameRunning) return;
	gatherGame.resetGameVars();
	removePlayersJoinFullSeclev(gatherGame);
	getNet().server_SendMsg("the currently running gather game has been ended with no scores given");
}

void assignPlayersJoinFullSeclev(gatherMatch@ gatherGame) {
	u32 len = getPlayerCount();

	CSecurity@ security = getSecurity();

	for (uint i = 0; i < len; i++)
	{
		CPlayer@ player = getPlayer(i);
		if(isInMatch(player.getUsername()) && !security.checkAccess_Feature(player, "join_full")){
			gatherGame.joinFullSeclev.addUser(player.getUsername());
		}
	}
}

void removePlayersJoinFullSeclev(gatherMatch@ gatherGame) {
	u32 len = getPlayerCount();

	for (uint i = 0; i < len; i++)
	{
		gatherGame.joinFullSeclev.removeUser(getPlayer(i).getUsername());
	}
}

void scrambleTeams(CRules@ this, bool includeSpectators)
{
	RulesCore@ core;
	this.get("core", @core);
	if (core is null)
	{
		warn("gatherHooks: CORE NOT FOUND ");
		return;
	}
	PlayerInfo@[] playerInfos = core.players;
	u32 len = playerInfos.length;
	string [] players;

	//make an array of usernames
	for (u32 i = 0; i < len; i++)
	{
		players.push_back(playerInfos[i].username);
	}

	//change the order of the player list
	for (u32 i = 0; i < len; i++)
	{
		uint index = XORRandom(len);
		string p = players[index];

		players[index] = players[i];
		players[i] = p;
	}

	getNet().server_SendMsg("Scrambling the teams!");

	int numTeams = this.getTeamsCount();
	int team = XORRandom(128) % numTeams;
	//now just go through the player list and alternate between each team
	for (u32 i = 0; i < len; i++)
	{
		CPlayer@ p = getPlayerByUsername(players[i]);

		if (includeSpectators || p.getTeamNum() != this.getSpectatorTeamNum())
		{
			int tempteam = team++ % numTeams;
			core.ChangePlayerTeam(p, tempteam);
		}
	}
}

int pauseDelay = 10;
void initiatePause(CRules@ this)
{
	this.set_s8("pauseTimer", pauseDelay);
	this.Sync("pauseTimer", true);
}

void initiateUnpause(CRules@ this)
{
	this.set_s8("unpauseTimer", pauseDelay);
	this.Sync("unpauseTimer", true);
}

//end of round code

const string tagname = "gather round over processed";

void onRestart(CRules@ this)
{
	this.set_bool(tagname, false);		//also done in onInit()
}

void onTick(CRules@ this){

	gatherMatch@ gatherGame = getGatherObject(this);

	if (this.isGameOver() && !this.get_bool(tagname)){
		if(gatherGame !is null){
			if(gatherGame.roundOver(this.getTeamWon())==-1) {
				print("round over -1");
			}
		}
		removePlayersJoinFullSeclev(gatherGame);
		this.set_bool(tagname, true);
	}

	if(gatherGame !is null){

		//dynamic number of players
		//dont want to use this most of the time, the player count should be set before setting teams, so that it is loaded when the game starts
		//this is only here for flexibility in case is useful in future
		if(this.get_bool("playerCountUpdated")){
			//only does somethign if the game is not currently live
			gatherGame.setNumPlayers(this.get_s32("numPlayers"));
			//if the game is currently live this message is ignored
			this.set_bool("playerCountUpdated", false);
		}

		//code for detecting new player list/subs
		if(this.get_bool("teamsSet")){
			startGathering(this);
			this.set_bool("teamsSet", false);
		}
		if(this.get_bool("teamsUpdated")){
			if(gatherGame.isGameRunning==false)
			{
				startGathering(this);
			}
			else
			{
				checkSubInSpec(this);
			}
			this.set_bool("teamsUpdated", false);
		}
		if(this.get_bool("teamsScrambled")){
			if(gatherGame.isGameRunning==false)
			{
				startGathering(this);
			}
			else
			{
				putAllPlayersIntoTeams(this);
			}
			this.set_bool("teamsScrambled", false);
		}
		if(this.get_bool("updateScore")){
			this.set_bool("updateScore", false);
		}

		if(this.get_bool("clearGame")){
			clearGame(this);
			this.set_bool("clearGame", false);
		}
	}

	if(gatherGame !is null){
		s8 timer = this.get_s8("pauseTimer");
		if(timer>0 && getGameTime()%getTicksASecond()==0){
			this.set_s8("pauseTimer", timer-1);
			this.Sync("pauseTimer", true);
			if(timer<=1) gatherGame.pauseGame();
		}

		timer = this.get_s8("unpauseTimer");
		if(timer>0 && getGameTime()%getTicksASecond()==0){
			this.set_s8("unpauseTimer", timer-1);
			this.Sync("unpauseTimer", true);
			if(timer<=1) gatherGame.unpauseGame();
		}
	}

}

void onInit(CRules@ this){
	gatherMatch gatherGame(this);
	this.set("gatherGame", gatherGame);
	//this.set_bool("isGameRunning",false);			//set in gatherGame constructor

	this.set_s32("numPlayers",gatherGame.defaultNumPlayers);
	this.set_bool(tagname, false);

	this.set_bool("updateScore", false);
}

void onStateChange( CRules@ this, const u8 oldState )
{
	gatherMatch@ gatherGame = getGatherObject(this);
	if(gatherGame is null) return;
	if(oldState==WARMUP && this.getCurrentState()==GAME && gatherGame.isLive()) tcpr("[Gather] BUILDINGTIMEENDED");
	if(gatherGame !is null && gatherGame.isLive()) gatherGame.resetBuildTimeEndVars();
}

void onPlayerLeave( CRules@ this, CPlayer@ player ){
	gatherMatch@ gatherGame=getGatherObject(this);
	if(gatherGame.setPlayerUnready(player.getUsername())==0)
		getNet().server_SendMsg(player.getUsername() + " is no longer ready (" +gatherGame.numPlayersReady+"/"+gatherGame.numPlayers+" left)");
}

void onNewPlayerJoin(CRules@ this, CPlayer@ player)
{
	gatherMatch@ gatherGame=getGatherObject(this);
	if(gatherGame.isPaused()){
		player.freeze = true;
	}
	if(gatherGame.isGameRunning){
		if(isInMatch(player.getUsername()) && !getSecurity().checkAccess_Feature(player, "join_full")){
			gatherGame.joinFullSeclev.addUser(player.getUsername());
		}
	} else if (gatherGame.joinFullSeclev !is null) {
		gatherGame.joinFullSeclev.removeUser(player.getUsername());
	}
}

void onPlayerChangedTeam( CRules@ this, CPlayer@ player, u8 oldteam, u8 newteam ){

	if(newteam==this.getSpectatorTeamNum()){
		gatherMatch@ gatherGame=getGatherObject(this);
		if(gatherGame.setPlayerUnready(player.getUsername())==0)
			getNet().server_SendMsg(player.getUsername() + " is no longer ready (" +gatherGame.numPlayersReady+"/"+gatherGame.numPlayers+" left)");
	}
}


bool onServerProcessChat( CRules@ this, const string& in text_in, string& out text_out, CPlayer@ player )
{
	if (player is null)
		return true;

	//GATHER COMMANDS
	if(text_in.substr(0,1) == "!"){

		string inputtext = text_in.toLower();

		gatherMatch@ gatherGame = getGatherObject(this);
		if(gatherGame !is null){
			int numSubVotesTemp=0;

			if(inputtext=="!ready" || inputtext=="!r"){

				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning ){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}

				if (player.getTeamNum()==this.getSpectatorTeamNum()){		//player cant be in spec for this command
					getNet().server_SendMsg("you must be in a team to ready");
					return true;
				}

				if(gatherGame.isLive()){
					getNet().server_SendMsg("round is already live!");
					return true;
				}
				if(gatherGame.setPlayerReady(player.getUsername(),player.getTeamNum())==1){
					getNet().server_SendMsg("you are already ready " + player.getUsername() +"! (" +gatherGame.numPlayersReady+"/"+gatherGame.numPlayers+")");
					return true;
				}else{
					if(player.getTeamNum()==0){
						getNet().server_SendMsg(player.getUsername() + " is now ready for Blue Team (" +gatherGame.numPlayersReady+"/"+gatherGame.numPlayers+")");
					}else{
						getNet().server_SendMsg(player.getUsername() + " is now ready for Red Team (" +gatherGame.numPlayersReady+"/"+gatherGame.numPlayers+")");
					}
					if(gatherGame.numPlayersReady>=gatherGame.numPlayers){
						gatherGame.startRound();
					}
					return true;
				}


			}else if(inputtext=="!unready" || inputtext=="!u" || inputtext=="!ur"){

				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}

				if(gatherGame.isLive()){
					getNet().server_SendMsg("round is already live!");
					return true;
				}
				if(gatherGame.setPlayerUnready(player.getUsername())==1){
					getNet().server_SendMsg("you are not ready " + player.getUsername() +"!");
					return true;
				}else{
					getNet().server_SendMsg(player.getUsername() + " is no longer ready (" +gatherGame.numPlayersReady+"/"+gatherGame.numPlayers+" left)");
					return true;
				}
			}else if(inputtext=="!restart"){

				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}

				if(!gatherGame.isLive()){
					getNet().server_SendMsg("round is not live yet!");
					return true;
				}
				if(gatherGame.addRestartVote(player.getUsername())==0){
					getNet().server_SendMsg("restart vote counted for "+player.getUsername()+"! (" +gatherGame.numPlayersReqRestart+"/"+gatherGame.restartVotesReq+")");
					if(gatherGame.numPlayersReqRestart>=gatherGame.restartVotesReq){
						getNet().server_SendMsg("Restarting Map...");
						gatherGame.restartMap();
						gatherGame.resetRoundVars();
						getNet().server_SendMsg("Players must ready again to resume the round");
					return true;
					}
				}else{
					getNet().server_SendMsg("you have already requested a restart "+player.getUsername()+"! (" +gatherGame.numPlayersReqRestart+"/"+gatherGame.restartVotesReq+")");
					return true;
				}
			}else if(inputtext=="!wr" || inputtext=="!who_ready" || inputtext=="!whoready"){
				if(gatherGame.isLive()){
					getNet().server_SendMsg("round is already live!");
					return true;
				}
				gatherGame.whoReady();
				return true;
			}else if(inputtext=="!wnr" || inputtext=="!who_not_ready" || inputtext=="!whonotready" ){
				if(gatherGame.isLive()){
					getNet().server_SendMsg("round is already live!");
					return true;
				}
				gatherGame.whoNotReady();
				return true;
			}else if(inputtext=="!score"){
				gatherGame.sayScore();
				return true;
			}else if(inputtext=="!teams"){
				string[]@ bluePlayers;
				string[]@ redPlayers;
				if(!getRules().get("blueTeam", @bluePlayers) || bluePlayers is null){
			        	error("failed to get blue team players");
			        	return true;
				}
				if(!getRules().get("redTeam", @redPlayers) || redPlayers is null){
			        	error("failed to get red team players");
			        	return true;
				}

				string blueString="";
				string redString="";
				for(int i=0;i<bluePlayers.length;i++){
					blueString=blueString+bluePlayers[i]+" ";
				}
				for(int i=0;i<redPlayers.length;i++){
					redString=redString+redPlayers[i]+" ";
				}

				getNet().server_SendMsg("blue: "+blueString+"red: "+redString);

				return true;
			}else if(inputtext=="!team"){

				if(isInTeam(0, player.getUsername())) getNet().server_SendMsg("you are in the blue team "+player.getUsername());
				else if (isInTeam(1, player.getUsername())) getNet().server_SendMsg("you are in the red team "+player.getUsername());
				else getNet().server_SendMsg("you are not playing in this game "+player.getUsername());

				return true;
			}else if(inputtext=="!veto"){

				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning){
					getNet().server_SendMsg("you cannot veto if you are not in the game "+player.getUsername());
					return true;
				}
				//want to allow veto when we get a bad map
				/*if(gatherGame.isLive()){
					getNet().server_SendMsg("cannot veto, game has already started");
					return true;
				}*/
				if(gatherGame.addVetoVote(player.getUsername())==1){
					getNet().server_SendMsg("You have already requested to veto this map "+player.getUsername()+"!");
				}else{
					getNet().server_SendMsg(player.getUsername()+" has requested to veto this map! ("+gatherGame.numPlayersVeto+"/"+gatherGame.vetoVotesReq+")");
				}
				if(gatherGame.numPlayersVeto>=gatherGame.vetoVotesReq){
					if(!gatherGame.isLive()) gatherGame.resetRoundVars();
					else gatherGame.setStartRoundVars();
					gatherGame.nextMap();
				}
				return true;
			}else if(inputtext.substr(0,5)=="!rsub"){

				if(!isInMatch(player.getUsername()) || !gatherGame.isGameRunning){
					getNet().server_SendMsg("you cannot do that if you are not in a game "+player.getUsername());
					return true;
				}

				if(inputtext=="!rsub"){		//no player specified, sub self
					//getNet().server_SendMsg("requesting sub for "+player.getUsername());
					gatherGame.requestSub(player.getUsername());
					return true;
				}
				//numSubVotesTemp =
				gatherGame.addSubVote(inputtext.substr(6,inputtext.size()),player.getUsername());
				/*if(numSubVotesTemp==-1){
					getNet().server_SendMsg("You have already voted to sub this player "+player.getUsername()+"!");
				}else{
					getNet().server_SendMsg("sub request vote added for "+inputtext.substr(6,inputtext.size())+" by "+player.getUsername()+" ("+numSubVotesTemp+"/"+gatherGame.subVotesReq+")");
				}
				if(numSubVotesTemp>=gatherGame.subVotesReq){
					getNet().server_SendMsg("requesting sub for "+inputtext.substr(6,inputtext.size()));
					gatherGame.requestSub(inputtext.substr(6,inputtext.size()));
				}*/
				return true;
			}else if(inputtext.substr(0,4)=="!say"){
				tcpr("[Gather] SAY "+player.getUsername()+" "+ text_in.substr(5,text_in.size()));
				return true;
			}else if(inputtext.substr(0,5)=="!link"){
				tcpr("[Gather] LINK " + text_in.substr(6,text_in.size()) + " " + player.getUsername());
			}else if(inputtext=="!forceready" || inputtext=="!fr"){
				if(player.isMod())
					gatherGame.startRound();
				else
					getNet().server_SendMsg("Only admins can do that " + player.getUsername());
				return true;
			}else if(inputtext.substr(0,8)=="!givewin"){
				/*if(!player.isMod()){
					getNet().server_SendMsg("Only admins can do that " + player.getUsername());
					return true;
				}*/

				if(!gatherGame.isLive()){
					getNet().server_SendMsg("round isn't live!");
					return true;
				}

				int giveWinStatus;

				if(inputtext.substr(9,inputtext.size())=="blue"){
					if(player.isMod()){
						if(gatherGame.roundOver(0)!=-1) gatherGame.nextMap();
					}else{
						giveWinStatus = gatherGame.addGiveWinVote(player.getUsername(), 0);
						if(giveWinStatus==3)
							getNet().server_SendMsg("vote to givewin to blue counted ("+gatherGame.blueGiveWinVotes+"/"+gatherGame.giveWinVotesReq+")");
						else if(giveWinStatus==4)
							getNet().server_SendMsg("vote changed to blue");
					}

				}else if(inputtext.substr(9,inputtext.size())=="red"){
					if(player.isMod()){
						if(gatherGame.roundOver(1)!=-1) gatherGame.nextMap();
					}else{
						giveWinStatus = gatherGame.addGiveWinVote(player.getUsername(), 1);
						if(giveWinStatus==3)
							getNet().server_SendMsg("vote to givewin to red counted ("+gatherGame.redGiveWinVotes+"/"+gatherGame.giveWinVotesReq+")");
						else if(giveWinStatus==4)
							getNet().server_SendMsg("vote changed to red");
					}

				}else if(inputtext.substr(9,inputtext.size())=="draw"){
					if(player.isMod()){
						if(gatherGame.roundOver(-1)!=-1) gatherGame.nextMap();
					}else{
						giveWinStatus = gatherGame.addGiveWinVote(player.getUsername(), -1);
						if(giveWinStatus==3)
							getNet().server_SendMsg("vote to give draw counted ("+gatherGame.drawGiveWinVotes+"/"+gatherGame.giveWinVotesReq+")");
						else if(giveWinStatus==4)
							getNet().server_SendMsg("vote changed to draw");
					}

				}else{
					getNet().server_SendMsg("invalid team used for !givewin command ");
				}

				if(giveWinStatus==-1){
					getNet().server_SendMsg("you have already voted to givewin to that team");
				}

				return true;
			}else if(inputtext=="!resetscore"){
				if(getSecurity().checkAccess_Feature(player, "admin_color")){

					//do admin stuff
					gatherGame.setScore(0, 0, 0);
					gatherGame.sayScore();

				}else{

					//add a vote
					if(gatherGame.addResetScoreVote(player.getUsername())==1){
						getNet().server_SendMsg("you have already voted to reset the score");
					}else{

						if(gatherGame.resetScoreVotes.length < gatherGame.resetScoreVotesRequired){

							getNet().server_SendMsg("vote to reset score vote counted ("+gatherGame.resetScoreVotes.length+"/"+gatherGame.resetScoreVotesRequired+")");

						}else{

							gatherGame.setScore(0,0,0);
							gatherGame.sayScore();

						}
					}
				}
			}
			else if(inputtext=="!scrambleteams" || inputtext=="!scramble")
			{
				if(getSecurity().checkAccess_Feature(player, "admin_color"))
				{
					scrambleTeams(this, true);
				}
				else
				{
					if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning ){
						getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
						return true;
					}
					if(gatherGame.isGameRunning){
						getNet().server_SendMsg("cannot scramble while a game is running!");
						return true;
					}
					//add a vote
					if(gatherGame.addScrambleVote(player.getUsername())==1){
						getNet().server_SendMsg("you have already voted to scramble the teams "+player.getUsername() + " ("+gatherGame.numPlayersReqScramble+"/"+gatherGame.scrambleVotesReq+")");
					}else{
						getNet().server_SendMsg("vote to scramble teams counted ("+gatherGame.numPlayersReqScramble+"/"+gatherGame.scrambleVotesReq+")");
						if(gatherGame.numPlayersReqScramble >= gatherGame.scrambleVotesReq)
						{
							scrambleTeams(this, true);
						}
					}
				}
			}
			else if(inputtext=="!scramblenotspec")
			{
				if(gatherGame.isGameRunning){
					getNet().server_SendMsg("cannot scramble while a game is running!");
					return true;
				}
				if(gatherGame.isLive()){
					getNet().server_SendMsg("cannot scramble, game has already started!");
					return true;
				}
				if(getSecurity().checkAccess_Feature(player, "admin_color"))
				{
					scrambleTeams(this, false);
				}
				else
				{
					getNet().server_SendMsg("Only admins can do that " + player.getUsername());
				}
			}
			else if (inputtext=="!allspec")
			{
				if(gatherGame.isLive()){
					getNet().server_SendMsg("cannot send players to spectator, game has already started");
					return true;
				}
				if(getSecurity().checkAccess_Feature(player, "admin_color"))
				{
					RulesCore@ core;
					this.get("core", @core);
					if (core is null)
					{
						warn("gatherHooks: CORE NOT FOUND ");
						return true;
					}
					getNet().server_SendMsg("Sending all players to spectator!");
					PlayerInfo@[] players = core.players;
					u32 len = players.length;
					for (u32 i = 0; i < len; i++)
					{
						core.ChangePlayerTeam(getPlayerByUsername(players[i].username), this.getSpectatorTeamNum());
					}
				}
				else
				{
					getNet().server_SendMsg("Only admins can do that " + player.getUsername());
				}
			}
			else if(inputtext=="!freeze" || inputtext=="!pause" || inputtext=="!stop" || inputtext=="!wait")
			{
				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning ){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}
				if(gatherGame.isPaused()){
					getNet().server_SendMsg("the game is already paused "+player.getUsername() + "!");
				}else if(gatherGame.numPlayersReqPause >= gatherGame.pauseVotesReq){
					getNet().server_SendMsg("the game is already being paused "+player.getUsername() + "!");
					return true;		//it is possible for players to request a pause while the countdown is happening, this prevents a second countdown
				}else if(gatherGame.addPauseVote(player.getUsername())==1){
					getNet().server_SendMsg("you have already voted to paused the game "+player.getUsername() + " ("+gatherGame.numPlayersReqPause+"/"+gatherGame.pauseVotesReq+")");
				}else{
					getNet().server_SendMsg("vote to paused game counted ("+gatherGame.numPlayersReqPause+"/"+gatherGame.pauseVotesReq+")");
				}

				if(gatherGame.numPlayersReqPause >= gatherGame.pauseVotesReq)
				{
					initiatePause(this);
				}
			}
			else if(inputtext=="!unfreeze"|| inputtext=="!unpause"  || inputtext=="!continue" || inputtext=="!go" || inputtext=="!resume")
			{
				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning ){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}
				if(!gatherGame.isPaused()){
					getNet().server_SendMsg("the game is already unpaused "+player.getUsername() + "!");
				}else if(gatherGame.numPlayersReqUnpause >= gatherGame.pauseVotesReq){
					getNet().server_SendMsg("the game is already being unpaused "+player.getUsername() + "!");
					return true;		//it is possible for players to request an unpause while the countdown is happening, this prevents a second countdown
				}else if(gatherGame.addUnpauseVote(player.getUsername())==1){
					getNet().server_SendMsg("you have already voted to unpause the game "+player.getUsername() + " ("+gatherGame.numPlayersReqUnpause+"/"+gatherGame.pauseVotesReq+")");
				}else{
					getNet().server_SendMsg("vote to unpause game counted ("+gatherGame.numPlayersReqUnpause+"/"+gatherGame.pauseVotesReq+")");
				}

				if(gatherGame.numPlayersReqUnpause >= gatherGame.pauseVotesReq)
				{
					initiateUnpause(this);
				}
			}
				/*else if(inputtext.substr(0,11)=="!setPlayers" || inputtext.substr(0,11)=="!setplayers" || inputtext.substr(0,11)=="!SETPLAYERS" ){
				if(!player.isMod())
					getNet().server_SendMsg("Only admins can do that " + player.getUsername());

				else if(inputtext.substr(12,inputtext.size())=="2")
					if(gatherGame.roundOver(0)!=-1) gatherGame.nextMap();

				else
					getNet().server_SendMsg("invalid use of !setPlayers <numPlayers>, numPlayers must be an even integer");

				return true;
			}*/			//dont need this if can just force start ready as admin

			else if(inputtext=="!pos")
			{	//for debugging
				Vec2f playerpos = player.getBlob().getPosition();
				print("player x: "+playerpos.x+" player y: "+playerpos.y);
				return true;
			}
		}
	}

	CBlob@ blob = player.getBlob();			//moved from top
	if (blob is null) {
		return true;
	}

	//END GATHER COMMANDS
	return true;
}
