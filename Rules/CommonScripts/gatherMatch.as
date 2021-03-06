
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
	int restartVotesReq=numPlayers*0.6;
	int vetoVotesReq=numPlayers*0.6;

	int subVotesReq=numPlayers*0.4;

	int giveWinVotesReq=numPlayers*0.6;

	int scrambleVotesReq=numPlayers*0.8;

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
	int resetScoreVotesRequired=numPlayers*0.6;

	string[] playersReqPause(numPlayers);
	string[] playersReqUnpause(numPlayers);
	int numPlayersReqPause;
	int numPlayersReqUnpause;
	int pauseVotesReq = numPlayers*0.3;
	private bool gamePaused = false;

	string joinFullSeclevString = "joinFull";
	CSeclev@ joinFullSeclev=null;

	//constructor
	//crules is passed here because there was a bug that caused the default constructor to be called multiple times
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

		numPlayersReqPause=0;
		numPlayersReqUnpause=0;

		//full seclev is applied to players when the game starts or after they first join
		//they will need not be able to join full if they have not already joined since the game was created
		//this is not perfect, but is okay. Someone will just need to let them on if they want the game to start
		//they should be able to join no matter what if they disconnect mid game, which is the main goal of this feature
		@joinFullSeclev = getSecurity().getSeclev(joinFullSeclevString);
		if(joinFullSeclev is null) {
			print("WARNING: join full seclev not found, gather players will not be able to join a full server!");
		}

		rules.set_s32("numPlayers", this.defaultNumPlayers);
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
			//set the var to false first because an unchanged variable isnt synced --- bad impl imo >:(
			rules.set_bool("gatherStartSound", false);
			rules.Sync("gatherStartSound", true);
			rules.set_bool("gatherStartSound", true);
			rules.Sync("gatherStartSound", true);
		}
	}

	bool isLive()
	{
		return this.isGameLive;
	}

	void setNumPlayers(int count)
	{
		if(!this.isLive()) {
			this.numPlayers=count;
			this.numBluePlayers=this.numPlayers/2;
			this.numRedPlayers=this.numPlayers/2;

			this.restartVotesReq=this.numPlayers*0.6;
			this.vetoVotesReq=this.numPlayers*0.6;

			this.subVotesReq=this.numPlayers*0.4;

			this.giveWinVotesReq=this.numPlayers*0.6;

			this.scrambleVotesReq=this.numPlayers*0.8;
			this.resetScoreVotesRequired=this.numPlayers*0.6;
			this.pauseVotesReq = this.numPlayers*0.3;

			this.resetVotes();

			//check any sub votes now passing
			//this code is unused/untested because the bot manages sub requests, not the server mod
			for(int i=0;i<playersWithSub.length();i++){
				if(playersWithSub[i].numPlayersReqSub>subVotesReq)
				{
					this.requestSub(playersWithSub[i].username);
				}
			}
		}
	}

	bool isReady(string username){
		for(int i=0;i<numPlayersReady;i++){
			if(username.toLower()==playersReady[i].username.toLower()) return true;
		}
		return false;
	}

	bool hasReqRestart(string userName){
		for(int i=0;i<numPlayersReqRestart;i++){
			if(userName.toLower()==playersReqRestart[i].toLower()) return true;
		}
		return false;
	}

	bool hasVeto(string userName){
		for(int i=0;i<numPlayersVeto;i++){
			if(userName.toLower()==playersVeto[i].toLower()) return true;
		}
		return false;
	}

	bool hasReqScramble(string userName){
		for(int i=0;i<numPlayersReqScramble;i++){
			if(userName.toLower()==playersReqScramble[i].toLower()) return true;
		}
		return false;
	}

	bool hasReqPause(string username){
		for(int i=0;i<numPlayersReqPause;i++){
			if(username.toLower()==playersReqPause[i].toLower()) return true;
		}
		return false;
	}
	bool hasReqUnpause(string username){
		for(int i=0;i<numPlayersReqUnpause;i++){
			if(username.toLower()==playersReqUnpause[i].toLower()) return true;
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

	void resetVotes(){
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

		playersReqGiveWin.clear();
		blueGiveWinVotes=0;
		redGiveWinVotes=0;
		drawGiveWinVotes=0;

		playersReqScramble.clear();
		numPlayersReqScramble=0;

		playersReqPause.clear();
		playersReqUnpause.clear();
		numPlayersReqPause=0;
		numPlayersReqUnpause=0;
	}

	void setStartRoundVars(){
		setLive(true);
		playersReady.clear();
		numPlayersReady=0;
		playersVeto.clear();
		numPlayersVeto=0;
		redTeamReady.clear();
		blueTeamReady.clear();
		numRedPlayersReady=0;
		numBluePlayersReady=0;

		playersReqScramble.clear();
		numPlayersReqScramble=0;

		playersReqPause.clear();
		playersReqUnpause.clear();
		numPlayersReqPause=0;
		numPlayersReqUnpause=0;
		unpauseGame();
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

		playersReqPause.clear();
		playersReqUnpause.clear();
		numPlayersReqPause=0;
		numPlayersReqUnpause=0;
		unpauseGame();
	}

	void resetGameVars(){
		isGameRunning=false;
		//getRules().set_bool("isGameRunning",false);
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
		redWins=0;
		blueWins=0;
		roundsPlayed=0;
		playersWithSub.clear();
		numPlayersWithSub=0;

		playersReqPause.clear();
		playersReqUnpause.clear();
		numPlayersReqPause=0;
		numPlayersReqUnpause=0;
		unpauseGame();
	}

	void resetBuildTimeEndVars(){
		playersVeto.clear();
		numPlayersVeto=0;
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

		//if they are requesting to sub themselves then just add a sub
		if(playerToSub == playerReqSub)
		{
			requestSub(playerToSub);
		}
		else
		{
			tcpr("[Gather] SUBVOTE "+playerToSub +" "+ playerReqSub);
		}
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

		setStartRoundVars();
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
				tcpr("[Gather] GAMEOVER 1");
				//game will next map itself
			}else if(blueWins>redWins){
				getNet().server_SendMsg("Blue Team wins the game!!!");
				tcpr("[Gather] GAMEOVER 0");
			}else{
				getNet().server_SendMsg("Its a draw!..");
				tcpr("[Gather] GAMEOVER -1");
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

	int addPauseVote(string username){
		if(!this.hasReqPause(username)){
			playersReqPause.insertAt(numPlayersReqPause,username);
			numPlayersReqPause++;
			return 0;
		}
		return 1;	//player has already voted
	}
	int addUnpauseVote(string username){
		if(!this.hasReqUnpause(username)){
			playersReqUnpause.insertAt(numPlayersReqUnpause,username);
			numPlayersReqUnpause++;
			return 0;
		}
		return 1;	//player has already voted
	}

	bool isPaused(){
		return this.gamePaused;
	}

	void pauseGame(){
		this.gamePaused = true;
		this.freezePlayers();
		this.playersReqPause.clear();
		this.numPlayersReqPause=0;
		this.playersReqUnpause.clear();
		this.numPlayersReqUnpause=0;
	}

	void unpauseGame(){
		this.unfreezePlayers();
		this.gamePaused = false;
		this.playersReqUnpause.clear();
		this.numPlayersReqUnpause=0;
		this.playersReqPause.clear();
		this.numPlayersReqPause=0;
	}

	void freezePlayers(){
		u32 len = getPlayerCount();
		for (uint i = 0; i < len; i++)
		{
			getPlayer(i).freeze = true;
		}
	}

	void unfreezePlayers(){
		u32 len = getPlayerCount();
		for (uint i = 0; i < len; i++)
		{
			getPlayer(i).freeze = false;
		}
	}
};

//helper
gatherMatch@ getGatherObject(CRules@ this){

	gatherMatch@ gatherGame=null;
	if(this.get("gatherGame", @gatherGame)) return gatherGame;

	print("Error getting gather game object");
	return null;
}
