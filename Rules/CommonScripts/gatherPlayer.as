#define SERVER_ONLY

shared class gatherPlayer
{
	
	string username;
	int teamNum;
	
	string[] playersReqSub;
	int numPlayersReqSub;
	
	gatherPlayer(){
		username="";
		teamNum=-1;
		playersReqSub.clear();
		numPlayersReqSub=0;
	}
	
	bool subReqBy(string username){
		for(int i=0;i<numPlayersReqSub;i++){
			if(username==playersReqSub[i]) return true;
		}
		return false;
	}
	
	int addSubVote(string userRequestingSub){
		if(!subReqBy(userRequestingSub)){
			playersReqSub.insertAt(numPlayersReqSub,userRequestingSub);
			numPlayersReqSub++;
			return numPlayersReqSub;
		}
		return -1;	//player has already requested to sub this person

	}
	
};
