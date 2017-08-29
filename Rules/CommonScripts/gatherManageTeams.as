#define SERVER_ONLY

#include "rulesCore.as";

string[]@ bluePlayers;
string[]@ redPlayers;

void setTeams(){	//I dont think this works - not used anymore (the set teams dont seem to remain in scope for the other functions)

	if(!getRules().get("blueTeam", @bluePlayers) || bluePlayers is null){
        	error("failed to get blue team players");
        	return;
	}
	if(!getRules().get("redTeam", @redPlayers) || redPlayers is null){
        	error("failed to get red team players");
        	return;
	}
}

void updateTeams(){
	setTeams();
}

bool isInTeam(int team, string username){			//check if the player should be in the team
	getRules().get("blueTeam", @bluePlayers);
	getRules().get("redTeam", @redPlayers);
	if(bluePlayers is null || redPlayers is null) return false;

	if(team==0){
		if(bluePlayers is null) return false;
		if(bluePlayers.find(username)>=0) return true;
	}else if(team==1){
		if(redPlayers is null) return false;
		if(redPlayers.find(username)>=0) return true;
	}
	return false;
}

int getTeam(string username){			//get the team the player is supposed to be in, returns spectator team number if not in a team
						//can probably use isInTeam() whenever this might be useful
	if(isInTeam(0,username))return 0;
	else if(isInTeam(1,username)) return 1;
	else return getRules().getSpectatorTeamNum();
	
	return -1;
}

bool isInMatch(string username){			//check if there is actually a game running maybe?
	if(isInTeam(0,username)||isInTeam(1,username)) return true;
	else return false;
}

void putAllPlayersIntoTeams(CRules@ this){
	//move players to spec if they arent playing this game
	u32 len = getPlayerCount();

	RulesCore@ core;
	this.get("core", @core);
	if (core is null) return;

	for (uint i = 0; i < len; i++)
	{
		CPlayer@ p = getPlayer(i);
		u8 gatherTeam=getTeam(p.getUsername());
		if(p.getTeamNum()!=gatherTeam) core.ChangePlayerTeam(p,gatherTeam);
	}
}

void checkSubInSpec(CRules@ this) {		//called when player list is updated
	u32 len = getPlayerCount();
	u8 specTeam = this.getSpectatorTeamNum();

	RulesCore@ core;
	this.get("core", @core);
	if (core is null) return;

	for (uint i = 0; i < len; i++)
	{
		CPlayer@ p = getPlayer(i);
		u8 gatherTeam=getTeam(p.getUsername());

		if(p.getTeamNum()==specTeam){
			if (gatherTeam!=specTeam){
				//core.ChangePlayerTeam(p,gatherTeam);		//dont need this, putAllPlayersIntoTeams() should do this
				putAllPlayersIntoTeams(this);		//should just move the player that was subbed out to spectator if they are still ingame
			}
		}
	}
}
