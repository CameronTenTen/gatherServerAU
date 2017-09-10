
#include "gatherPlayer.as";
#include "gatherManageTeams.as";

#define SERVER_ONLY

shared class giveWinVoteObj
{
	string userName;
	int teamvotedFor;
	giveWinVoteObj(string setUserName, int setVote){
		userName=setUserName;
		teamvotedFor=setVote;
	}
};

shared class gatherMatch
{
	
	int defaultNumPlayers = 10;

	int numPlayers=defaultNumPlayers;

	int numBluePlayers=numPlayers/2;
	int numRedPlayers=numPlayers/2;

	int numRounds=1;	//best of
	int restartVotesReq=6;
	int vetoVotesReq=6;
	
	int subVotesReq=4;

	int giveWinVotesReq=6;
	
	int scrambleVotesReq=8;
	
	bool isGameRunning;
	private bool isGameLive;
	//string[] playersInMatch(numPlayers);

	gatherPlayer[] playersReady(numPlayers);
	string[] playersReqRestart(numPlayers);
	string[] playersVeto(numPlayers);
	string[] redTeamReady(numPlayers/2);
	string[] blueTeamReady(numPlayers/2);
	int numPlayersReady;
	int redWins;
	int blueWins;
	int numPlayersReqRestart;
	int roundsPlayed;
	int numPlayersVeto;
	int numRedPlayersReady;
	int numBluePlayersReady;
	
	int numPlayersReqScramble;
	string[] playersReqScramble(numPlayers);

	giveWinVoteObj[] playersReqGiveWin;
	int blueGiveWinVotes;
	int redGiveWinVotes;
	int drawGiveWinVotes;
	
	gatherPlayer[] playersWithSub(numPlayers);
	int numPlayersWithSub;

	string[] resetScoreVotes;
	int resetScoreVotesRequired=6;
	
	//constructor
	gatherMatch(CRules@ rules){
		print("GATHER SERVER STARTED");
		isGameRunning=false;
		setLive(false);
		numPlayersReady=0;
		redWins=0;
		blueWins=0;
		numPlayersReqRestart=0;
		roundsPlayed=0;
		numPlayersVeto=0;
		numRedPlayersReady=0;
		numBluePlayersReady=0;
		numPlayersReqScramble=0;

		blueGiveWinVotes=0;
		redGiveWinVotes=0;
		drawGiveWinVotes=0;
		
		numPlayersWithSub=0;
		
		//get players from seclevs
		
	}
	
	void setLive(bool val)
	{
		this.isGameLive=val;
		
		//so the client can show the game status onRender()
		CRules@ rules = getRules();
		rules.set_bool("isLive", val);
		rules.Sync("isLive", true);
		
		if(true==val)
		{
			rules.set_bool("gatherStartSound", true);
			rules.Sync("gatherStartSound", true);
		}
	}
	
	bool isLive()
	{
		return this.isGameLive;
	}
	
	bool isReady(string username){
		for(int i=0;i<numPlayersReady;i++){
			if(username==playersReady[i].username) return true;
		}
		return false;
	}
	
	bool hasReqRestart(string userName){
		for(int i=0;i<numPlayersReqRestart;i++){
			if(userName==playersReqRestart[i]) return true;
		}
		return false;
	}
	
	bool hasVeto(string userName){
		for(int i=0;i<numPlayersVeto;i++){
			if(userName==playersVeto[i]) return true;
		}
		return false;
	}
	
	bool hasReqScramble(string userName){
		for(int i=0;i<numPlayersReqScramble;i++){
			if(userName==playersReqScramble[i]) return true;
		}
		return false;
	}
	
	int setPlayerReady(string username,int teamNum){
		if(!isReady(username)){
			gatherPlayer tempPlayer;
			tempPlayer.username=username;
			tempPlayer.teamNum=teamNum;
			playersReady.insertAt(numPlayersReady,tempPlayer);
			if(teamNum==0){
				blueTeamReady.insertAt(numBluePlayersReady,username);
				numBluePlayersReady++;
			}else if(teamNum==1){
				redTeamReady.insertAt(numRedPlayersReady,username);
				numRedPlayersReady++;
			}
			numPlayersReady++;
			return 0;
		}
		return 1;	//player is already ready
	}
	
	int setPlayerUnready(string username){
		for(int i=0; i< numPlayersReady; i++){
			if(playersReady[i].username==username){
				playersReady.removeAt(i);
				numPlayersReady--;
				for(int j=0;j<numBluePlayersReady;j++){
					if(blueTeamReady[j]==username){
						blueTeamReady.removeAt(j	);
						numBluePlayersReady--;
					}
				}
				for(int j=0;j<numRedPlayersReady;j++){
					if(redTeamReady[j]==username){
						redTeamReady.removeAt(j);
						numRedPlayersReady--;
					}
					//find player in team list
				}
				return 0;
			}
		}
		return 1;	//player not found in playersReady (they arent ready)
	}
	
	void whoReady(){		//prints the names of all players who are ready
	string temp="";
		for(int i=0; i< numPlayersReady; i++){
			temp=temp+playersReady[i].username;
			if(i<numPlayersReady-1) temp=temp+", ";
		}
		getNet().server_SendMsg("("+ numPlayersReady +"/"+ numPlayers + ") players ready: " + temp);
	}
	
	void whoNotReady(){

		//if no bot controlled game running, just check who is on a team and not ready
		if(!this.isGameRunning)
		{
			string notReadyString="";
			u32 len = getPlayerCount();
			int spectatorTeamNum = getRules().getSpectatorTeamNum();
			for (uint i = 0; i < len; i++)
			{
				CPlayer@ p = getPlayer(i);
				if (p.getTeamNum() != spectatorTeamNum && !isReady(p.getUsername()))
				{
					notReadyString = notReadyString+" "+p.getUsername();
				}
			}
			if(notReadyString == "")
			{
				getNet().server_SendMsg("All players on a team are ready");
			}
			else
			{
				getNet().server_SendMsg("Players not readied: " + notReadyString);
			}
		}
		else
		{
			string[]@ bluePlayers;
			string[]@ redPlayers;
			string blueNotReadyString="";
			string redNotReadyString="";
			
			if(!getRules().get("blueTeam", @bluePlayers) || bluePlayers is null){
	        		error("failed to get blue team players (command who not ready)");
	        		return;
			}
			if(!getRules().get("redTeam", @redPlayers) || redPlayers is null){
	        		error("failed to get red team players (command who not ready)");
	        		return;
			}
			for(int i=0;i<bluePlayers.length;i++){
				if(!isReady(bluePlayers[i]))
					blueNotReadyString=blueNotReadyString+" "+bluePlayers[i];
			}
			for(int i=0;i<redPlayers.length;i++){
				if(!isReady(redPlayers[i]))
					redNotReadyString=redNotReadyString+" "+redPlayers[i];
			}
			getNet().server_SendMsg("Players not readied: " + blueNotReadyString+redNotReadyString);
		}

	}
	
	void whoIsReqRestart(){		//prints the names of all players who have requested a restart
	string temp="";
		for(int i=0; i< numPlayersReqRestart; i++){
			temp=temp+playersReqRestart[i];
			if(i<numPlayersReqRestart-1) temp=temp+", ";
		}
		getNet().server_SendMsg("Players that have requested restart: " + temp);
	}
	
	int addRestartVote(string userName){
		if(!hasReqRestart(userName)){
			playersReqRestart.insertAt(numPlayersReqRestart,userName);
			numPlayersReqRestart++;
			return 0;
		}
		return 1;	//player has already requested restart
	}
	
	int addScrambleVote(string userName){
		if(!hasReqScramble(userName)){
			playersReqScramble.insertAt(numPlayersReqScramble,userName);
			numPlayersReqScramble++;
			return 0;
		}
		return 1;	//player has already requested scramble
	}
	
	void resetRoundVars(){
		setLive(false);
		playersReady.clear();
		playersReqRestart.clear();
		numPlayersReady=0;
		numPlayersReqRestart=0;
		playersVeto.clear();
		numPlayersVeto=0;
		redTeamReady.clear();
		blueTeamReady.clear();
		numRedPlayersReady=0;
		numBluePlayersReady=0;
		
		playersReqScramble.clear();
		numPlayersReqScramble=0;

		playersReqGiveWin.clear();
		blueGiveWinVotes=0;
		redGiveWinVotes=0;
		drawGiveWinVotes=0;
	}
	
	void resetGameVars(){
		isGameRunning=false;
		//getRules().set_bool("isGameRunning",false);
		setLive(false);
		numPlayers=defaultNumPlayers;
		playersReady.clear();
		playersReqRestart.clear();
		numPlayersReady=0;
		numPlayersReqRestart=0;
		playersVeto.clear();
		numPlayersVeto=0;
		redTeamReady.clear();
		blueTeamReady.clear();
		numRedPlayersReady=0;
		numBluePlayersReady=0;
		playersReqScramble.clear();
		numPlayersReqScramble=0;
		playersReqGiveWin.clear();
		blueGiveWinVotes=0;
		redGiveWinVotes=0;
		drawGiveWinVotes=0;
		redWins=0;
		blueWins=0;
		roundsPlayed=0;
		playersWithSub.clear();
		numPlayersWithSub=0;
	}
	
	void restartMap(){
		LoadMap(getMap().getMapName());
	}

	void nextMap(){
		LoadNextMap();
	}
	
	void sayScore(){
		getNet().server_SendMsg("Blue Team: "+blueWins+" Red Team: "+redWins);
	}

	void setScore(int setBlueWins, int setRedWins, int setRoundsPlayed){
		this.blueWins=setBlueWins;
		this.redWins=setRedWins;
		this.roundsPlayed=setRoundsPlayed;
	}

	int addResetScoreVote(string username){
		for(int i=0;i<resetScoreVotes.length;i++){

			if(resetScoreVotes[i]==username)
				return 1;
		}
		resetScoreVotes.push_back(username);
		return 0;
	}

	void resetScoreboard(){
 		CPlayer@ player;
	        for(uint i=0; i<getPlayerCount(); i++ ){
	                getPlayer(i).setScore(0);
	                getPlayer(i).setKills(0);
	                getPlayer(i).setDeaths(0);
        	}
	}
	
	int addVetoVote(string userName){
		if(!hasVeto(userName)){
			playersVeto.insertAt(numPlayersVeto,userName);
			numPlayersVeto++;
			return 0;
		}
		return 1;	//player has already requested to veto
	}
	
	void addSubVote(string playerToSub, string playerReqSub){

		tcpr("[gather] SUBVOTE "+playerToSub +" "+ playerReqSub);
		/*for(int i=0;i<numPlayersWithSub;i++){
			if(playersWithSub[i].username==playerToSub){
				return playersWithSub[i].addSubVote(playerReqSub);
			}
		}
		gatherPlayer tempPlayer;
		tempPlayer.username=playerToSub;
		tempPlayer.addSubVote(playerReqSub);
		playersWithSub.insertAt(numPlayersWithSub,tempPlayer);
		numPlayersWithSub++;
		return 1;		//now one player is requesting the sub (returns num players requesting sub for this player)*/
		return;
	}
	
	void removePlayersSubVotes(string username){
		for(int i=0;i<numPlayersWithSub;i++){
			if (playersWithSub[i].username==username){
				playersWithSub.removeAt(i);
			}
		}
	}
	
	void requestSub(string username){
		if(!this.isLive()) setPlayerUnready(username);
		//removePlayersSubVotes(username);
		tcpr("[Gather] RSUB "+username);
		return;
	}
	
	void startRound(){
		restartMap();			//send message to restart map
		getNet().server_SendMsg("ROUND IS NOW LIVE!!!");
		
		/*string tempRed="red:";
		string tempBlue="blue:";
		for(int i=0;i<numPlayersReady;i++){
			if(playersReady[i].teamNum==0){
				print("in team num if");
				tempBlue=tempBlue+playersReady[i].username;
				tempBlue=tempBlue+",";
			}else if(playersReady[i].teamNum==1){
				tempRed=tempRed+playersReady[i].username;
				tempRed=tempRed+",";
			}
		}*/
		
		u32 len = getPlayerCount();
		int spectatorTeamNum = getRules().getSpectatorTeamNum();
		string tempRed="red:";
		string tempBlue="blue:";
		for (uint i = 0; i < len; i++)
		{
			CPlayer@ p = getPlayer(i);
			if (p !is null && p.getTeamNum() != spectatorTeamNum)
			{
				if(p.getTeamNum() == 0)
				{
					tempBlue = tempBlue+" "+p.getUsername();
				}
				else
				{
					tempRed = tempRed+" "+p.getUsername();
				}
			}
		}
		
		tcpr("[Gather] ROUNDSTARTED: "+tempBlue+" "+tempRed);

		resetScoreboard();
		getNet().server_SendMsg("The scoreboard has been reset");

		resetRoundVars();
		setLive(true);
	}
	
	int roundOver(int winningTeam){
		if(!this.isLive())return -1;			//game isnt live yet

		resetRoundVars();
		roundsPlayed++;
		if(winningTeam==0){
			blueWins++;
			if(blueWins<((numRounds/2)+1)) tcpr("[Gather] Blue round won");		//check there is a real game running and the game hasnt ended (if game has ended only want game over print not round one)
			getNet().server_SendMsg("Round is over! Blue Team has won!");
		}else if(winningTeam==1){
			redWins++;
			if(redWins<((numRounds/2)+1)) tcpr("[Gather] Red round won");
			getNet().server_SendMsg("Round is over! Red Team has won!");
		
		}else if(winningTeam==-1){
			tcpr("[Gather] round drawn");
			getNet().server_SendMsg("Round is over! its a draw!");
		
		}	//if winning team == -1 its a draw

		//TODO: this only works if there is an odd number of rounds?
		if(blueWins>=((numRounds/2)+1) || redWins>=((numRounds/2)+1)){
			if(numRounds>1) getNet().server_SendMsg("Final score is Blue: "+blueWins+" Red: "+redWins);
			if(redWins>blueWins){
				getNet().server_SendMsg("Red Team wins the game!!!");
				tcpr("[Gather] Red won");
				//game will next map itself
			}else if(blueWins>redWins){
				getNet().server_SendMsg("Blue Team wins the game!!!");
				tcpr("[Gather] Blue won");
			}else{
				getNet().server_SendMsg("Its a draw!..");
				tcpr("[Gather] Draw");
			}
			resetGameVars();
			return 1;		//game has ended
		}else{
			sayScore();
			getNet().server_SendMsg("players must !ready to start the next round");
		}
		return 0;		//game not ended yet
	}

	int hasReqGiveWin(string userName){
		for(int i=0; i<playersReqGiveWin.length;i++){
			if(playersReqGiveWin[i].userName==userName) return i;
		}
		return -1;
	}

	int addGiveWinVote(string userName, int vote){
		int requested=hasReqGiveWin(userName);
		if(requested==-1){
			playersReqGiveWin.push_back(giveWinVoteObj(userName, vote));
			if(vote==0)blueGiveWinVotes++;
			else if(vote==1)redGiveWinVotes++;
			else if(vote==-1)drawGiveWinVotes++;
			if(blueGiveWinVotes>=giveWinVotesReq){
				this.roundOver(0);
				return 0;
			}else if(redGiveWinVotes>=giveWinVotesReq){
				this.roundOver(1);
				return 1;
			}else if(drawGiveWinVotes>=giveWinVotesReq){
				this.roundOver(-1);
				return 2;
			}
			return 3;
		}else{
			if(playersReqGiveWin[requested].teamvotedFor!=vote){
				playersReqGiveWin[requested].teamvotedFor=vote;
				return 4;
			}
		}
		return -1;	//player has already voted to givewin for that team
	}
};

//helper
gatherMatch@ getGatherObject(CRules@ this){

	gatherMatch@ gatherGame=null;
	if(this.get("gatherGame", @gatherGame)) return gatherGame;

	print("Error getting gather game object");
	return null;
}

