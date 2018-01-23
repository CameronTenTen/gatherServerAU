
void onRender(CRules@ this){
	bool live = this.get_bool("isLive");
	
	if(live)
	{
		GUI::DrawText( "LIVE", Vec2f(610,getScreenHeight()-90), SColor(0xffff00ff) );
	}
	else
	{
		GUI::DrawText( "Warmup", Vec2f(600,getScreenHeight()-90), SColor(0xff00ff00) );
	}
	
	s8 timer = this.get_s8("pauseTimer");
	if(timer>0) {
		GUI::DrawText( "Pausing game in "+timer, Vec2f(getScreenWidth()/2-70,getScreenHeight()/2-50), SColor(0xffff00ff) );
	}
	timer = this.get_s8("unpauseTimer");
	if(timer>0) {
		GUI::DrawText( "Unpausing game in "+timer, Vec2f(getScreenWidth()/2-70,getScreenHeight()/2-50), SColor(0xffff00ff) );
	}
}

void onTick(CRules@ this)
{
	if(this.get_bool("gatherStartSound"))
	{
		Sound::Play("/party_join.ogg");
		this.set_bool("gatherStartSound", false);
	}
	
	s8 timer = this.get_s8("pauseTimer");
	if(timer>0 && getGameTime()%getTicksASecond()==0){
		Sound::Play("/GUI/buttonclick.ogg");
	}
	
	timer = this.get_s8("unpauseTimer");
	if(timer>0 && getGameTime()%getTicksASecond()==0){
		Sound::Play("/GUI/buttonclick.ogg");
	}
}