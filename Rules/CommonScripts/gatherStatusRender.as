
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
}

void onTick(CRules@ this)
{
	if(this.get_bool("gatherStartSound"))
	{
		Sound::Play("/party_join.ogg");
		this.set_bool("gatherStartSound", false);
	}
}