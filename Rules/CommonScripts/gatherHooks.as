#include "gatherMatch.as";

#define SERVER_ONLY

void startGathering(CRules@ this){
	gatherMatch@ gatherGame = getGatherObject(this);
	gatherGame.resetGameVars();
	gatherGame.isGameRunning=true;
	//this.set_bool("isGameRunning",true);

	getNet().server_SendMsg("a gather game is starting!! Players not in this match will be moved to spectator");
	putAllPlayersIntoTeams(this);
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

		this.set_bool(tagname, true);
	}

	if(gatherGame !is null){

		//code for detecting new player list/subs
		if(this.get_bool("teamsSet")){
			startGathering(this);
			this.set_bool("teamsSet", false);
		}
		if(this.get_bool("teamsUpdated")){
			checkSubInSpec(this);
			this.set_bool("teamsUpdated", false);
		}
		if(this.get_bool("updateScore")){
			this.set_bool("updateScore", false);
		}

		//dynamic number of players
		int newNumPlayers=this.get_s32("numPlayers");
		if(newNumPlayers!=gatherGame.defaultNumPlayers){
			gatherGame.numPlayers=newNumPlayers;
			this.set_s32("numPlayers",gatherGame.defaultNumPlayers);
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


void onPlayerLeave( CRules@ this, CPlayer@ player ){
	gatherMatch@ gatherGame=getGatherObject(this);
	if(gatherGame.setPlayerUnready(player.getUsername())==0)
		getNet().server_SendMsg(player.getUsername() + " is no longer ready (" +gatherGame.numPlayersReady+"/"+gatherGame.numPlayers+" left)");
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

if(text_in=="!pos"){
	Vec2f playerpos = player.getBlob().getPosition();
	print("player x: "+playerpos.x+" player y: "+playerpos.y);
	return true;
}

		gatherMatch@ gatherGame = getGatherObject(this);
		if(gatherGame !is null){
			int numSubVotesTemp=0;
			
			if(text_in=="!ready" || text_in=="!Ready" || text_in=="!READY" || text_in=="!r" || text_in=="!R"){
				
				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning ){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}

				if (player.getTeamNum()==this.getSpectatorTeamNum()){		//player cant be in spec for this command
					getNet().server_SendMsg("you must be in a team to ready");
					return true;
				}

				if(gatherGame.isLive){
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

				
			}else if(text_in=="!unready" || text_in=="!Unready" || text_in=="!UnReady" || text_in=="!UNREADY" || text_in=="!u" || text_in=="!U" || text_in=="!ur" || text_in=="!UR"){

				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}

				if(gatherGame.isLive){
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
			}else if(text_in=="!restart" || text_in=="!Restart"){

				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}

				if(!gatherGame.isLive){
					getNet().server_SendMsg("round is not live yet!");
					return true;
				}
				if(gatherGame.addRestartVote(player.getUsername())==0){
					getNet().server_SendMsg("restart vote counted for "+player.getUsername());
					if(gatherGame.numPlayersReqRestart>=gatherGame.restartVotesReq){
						getNet().server_SendMsg("Restarting Map...");
						gatherGame.resetRoundVars();
						gatherGame.restartMap();
						getNet().server_SendMsg("Players must ready again to resume the round");
					return true;
					}
				}else{
					getNet().server_SendMsg("you have already requested a restart "+player.getUsername());
					return true;
				}
			}else if(text_in=="!wr" || text_in=="!who_ready" || text_in=="!whoReady" || text_in=="!WR" || text_in=="!Who_Ready"){
				if(gatherGame.isLive){
					getNet().server_SendMsg("round is already live!");
					return true;
				}
				gatherGame.whoReady();
				return true;
			}else if(text_in=="!wnr" || text_in=="!who_not_ready" || text_in=="!whoNotReady" || text_in=="!WNR" || text_in=="!Who_Not_Ready" || text_in=="!whonotready" ){
				if(gatherGame.isLive){
					getNet().server_SendMsg("round is already live!");
					return true;
				}
				gatherGame.whoNotReady();
				return true;
			}else if(text_in=="!score" || text_in=="!Score" || text_in=="!SCORE"){
				gatherGame.sayScore();
				return true;
			}else if(text_in=="!teams" || text_in=="!Teams" || text_in=="!TEAMS"){
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
			}else if(text_in=="!team" || text_in=="!Team" || text_in=="!TEAM"){

				if(isInTeam(0, player.getUsername())) getNet().server_SendMsg("you are in the blue team "+player.getUsername());
				else if (isInTeam(1, player.getUsername())) getNet().server_SendMsg("you are in the red team "+player.getUsername());
				else getNet().server_SendMsg("you are not playing in this game "+player.getUsername());
				
				return true;
			}else if(text_in=="!veto" || text_in=="!Veto" || text_in=="!VETO"){

				if(!isInMatch(player.getUsername()) && gatherGame.isGameRunning){
					getNet().server_SendMsg("you cannot veto if you are not in the game "+player.getUsername());
					return true;
				}

				if(gatherGame.isLive){
					getNet().server_SendMsg("cannot veto, game has already started");
					return true;
				}
				if(gatherGame.addVetoVote(player.getUsername())==1){
					getNet().server_SendMsg("You have already requested to veto this map "+player.getUsername()+"!");
				}else{
					getNet().server_SendMsg(player.getUsername()+" has requested to veto this map! ("+gatherGame.numPlayersVeto+"/"+gatherGame.vetoVotesReq+")");
				}
				if(gatherGame.numPlayersVeto>=gatherGame.vetoVotesReq){
					gatherGame.resetRoundVars();
					gatherGame.nextMap();
				}
				return true;
			}else if(text_in.substr(0,5)=="!rsub" || text_in.substr(0,5)=="!Rsub" || text_in.substr(0,5)=="!RSub" || text_in.substr(0,5)=="!RSUB"){

				if(!isInMatch(player.getUsername()) || !gatherGame.isGameRunning){
					getNet().server_SendMsg("you cannot do that if you are not in the game "+player.getUsername());
					return true;
				}

				if(text_in=="!rsub" || text_in=="!Rsub" || text_in=="!RSub" || text_in=="!RSUB"){		//no player specified, sub self
					//getNet().server_SendMsg("requesting sub for "+player.getUsername());
					gatherGame.requestSub(player.getUsername());
					return true;
				}
				//numSubVotesTemp = 
				gatherGame.addSubVote(text_in.substr(6,text_in.size()),player.getUsername());
				/*if(numSubVotesTemp==-1){
					getNet().server_SendMsg("You have already voted to sub this player "+player.getUsername()+"!");
				}else{
					getNet().server_SendMsg("sub request vote added for "+text_in.substr(6,text_in.size())+" by "+player.getUsername()+" ("+numSubVotesTemp+"/"+gatherGame.subVotesReq+")");
				}
				if(numSubVotesTemp>=gatherGame.subVotesReq){
					getNet().server_SendMsg("requesting sub for "+text_in.substr(6,text_in.size()));
					gatherGame.requestSub(text_in.substr(6,text_in.size()));
				}*/
				return true;
			}else if(text_in.substr(0,4)=="!say" || text_in.substr(0,4)=="!Say" || text_in.substr(0,4)=="!SAY"){
				print("[Gather] SAY "+player.getUsername()+" "+ text_in.substr(5,text_in.size()));
				return true;
			}else if(text_in.substr(0,5)=="!link" || text_in.substr(0,5)=="!Link" || text_in.substr(0,5)=="!LINK"){
				print("[Gather] LINK " + text_in.substr(6,text_in.size()) + " " + player.getUsername());
			}else if(text_in.substr(0,11)=="!forceready" || text_in.substr(0,11)=="!FORCEREADY" || text_in.substr(0,11)=="!forceReady" || text_in.substr(0,11)=="!fr" || text_in.substr(0,11)=="!FR" || text_in.substr(0,11)=="!ForceReady"){
				if(player.isMod())
					gatherGame.startRound();
				else
					getNet().server_SendMsg("Only admins can do that " + player.getUsername());
				return true;
			}else if(text_in.substr(0,8)=="!givewin" || text_in.substr(0,8)=="!Givewin" || text_in.substr(0,8)=="!GiveWin" || text_in.substr(0,8)=="!giveWin" || text_in.substr(0,8)=="!GIVEWIN" ){
				/*if(!player.isMod()){
					getNet().server_SendMsg("Only admins can do that " + player.getUsername());
					return true;
				}*/

				if(!gatherGame.isLive){
					getNet().server_SendMsg("round isn't live!");
					return true;
				}

				int giveWinStatus;

				if(text_in.substr(9,text_in.size())=="blue"){
					if(player.isMod()){
						if(gatherGame.roundOver(0)!=-1) gatherGame.nextMap();
					}else{
						giveWinStatus = gatherGame.addGiveWinVote(player.getUsername(), 0);
						if(giveWinStatus==3)
							getNet().server_SendMsg("vote to givewin to blue counted ("+gatherGame.blueGiveWinVotes+"/"+gatherGame.giveWinVotesReq+")");
						else if(giveWinStatus==4)
							getNet().server_SendMsg("vote changed to blue");
					}

				}else if(text_in.substr(9,text_in.size())=="red"){
					if(player.isMod()){
						if(gatherGame.roundOver(1)!=-1) gatherGame.nextMap();
					}else{
						giveWinStatus = gatherGame.addGiveWinVote(player.getUsername(), 1);
						if(giveWinStatus==3)
							getNet().server_SendMsg("vote to givewin to red counted ("+gatherGame.redGiveWinVotes+"/"+gatherGame.giveWinVotesReq+")");
						else if(giveWinStatus==4)
							getNet().server_SendMsg("vote changed to red");
					}

				}else if(text_in.substr(9,text_in.size())=="draw"){
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
			}else if(text_in.substr(0,11)=="!resetScore" || text_in.substr(0,11)=="!resetscore" || text_in.substr(0,11)=="!RESETSCORE" || text_in.substr(0,11)=="!ResetScore"){
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


			}/*else if(text_in.substr(0,11)=="!setPlayers" || text_in.substr(0,11)=="!setplayers" || text_in.substr(0,11)=="!SETPLAYERS" ){
				if(!player.isMod())
					getNet().server_SendMsg("Only admins can do that " + player.getUsername());

				else if(text_in.substr(12,text_in.size())=="2")
					if(gatherGame.roundOver(0)!=-1) gatherGame.nextMap();

				else
					getNet().server_SendMsg("invalid use of !setPlayers <numPlayers>, numPlayers must be an even integer");
				
				return true;
			}*/			//dont need this if can just force start ready as admin
		}
	}

	CBlob@ blob = player.getBlob();			//moved from top
	if (blob is null) {
		return true;
	}

	//END GATHER COMMANDS
	return true;
}