// generates from a KAGGen config
// fileName is "" on client!

#include "LoaderUtilities.as";

bool loadMap(CMap@ _map, const string& in filename)
{
	CMap@ map = _map;
	
	if (!getNet().isServer() || filename == "")
	{
		SetupMap(map, 0, 0);
		SetupBackgrounds(map);
		return true;
	}
	
	Random@ map_random = Random(map.getMapSeed());
	print("Map Seed: "+map.getMapSeed());
	Noise@ map_noise = Noise(map_random.Next());
	
	Noise@ material_noise = Noise(map_random.Next());
	
	//read in our config stuff -----------------------------
	
	ConfigFile cfg = ConfigFile(filename);
	
	//boring vars
	s32 width = cfg.read_s32("m_width", m_width);
	s32 height = cfg.read_s32("m_height", m_height);
	
	s32 baseline = cfg.read_s32("baseline", 50);
	s32 baseline_tiles = height * (1.0f - (baseline / 100.0f));
	
	s32 deviation = cfg.read_s32("deviation", 20);
	
	//margin for teams
	s32 map_margin = cfg.read_s32("map_margin", 30);
	bool allowTreesInMargin = cfg.read_bool("allowTreesInMargin",false);
	s32 lerp_distance = cfg.read_s32("lerp_distance", 30);
	
	//erosion
	s32 erode_cycles = cfg.read_s32("erode_cycles", 10);
	
	//purturbation vars
	f32 purturb = cfg.read_f32("purturb", 5.0f);
	f32 purt_scale = cfg.read_f32("purt_scale", 0.0075);
	f32 purt_width = cfg.read_f32("purt_width", deviation);
	if (purt_width <= 0)
		purt_width = deviation;
	
	//cave vars
	Random@ cave_random = Random(map.getMapSeed() ^ 0xff00);
	Noise@ cave_noise = Noise(cave_random.Next());
	
	f32 cave_amount = cfg.read_f32("cave_amount", 0.2f);
	f32 cave_amount_var = cfg.read_f32("cave_amount_var", 0.1f);
	if (cave_amount > 0)
		cave_amount = Maths::Min(1.0f, Maths::Max(0.0f, cave_amount + cave_amount_var * (cave_random.NextFloat() - 0.5f)));
	
	f32 cave_scale = cfg.read_f32("cave_scale", 5.0f);
	cave_scale = 1.0f / Maths::Max(cave_scale, 0.001);
		
	f32 cave_detail_amp = cfg.read_f32("cave_detail_amp", 0.5f);
	f32 cave_distort = cfg.read_f32("cave_distort", 2.0f);
	f32 cave_width = cfg.read_f32("cave_width", 0.5f);
	f32 cave_lerp = cfg.read_f32("cave_lerp", 10.0f);
	if (cave_width <= 0)
		cave_width = 0;
	
	f32 cave_depth = cfg.read_f32("cave_depth", 20.0f);
	f32 cave_depth_var = cfg.read_f32("cave_depth_var", 10.0f);
	cave_depth += cave_depth_var * (cave_random.NextFloat() - 0.5f);
	
	cave_width *= width; //convert from ratio to tiles
	
	//ruins vars
	
	Random@ ruins_random = Random(map.getMapSeed() ^ 0x8ff000);
	
	s32 ruins_count = cfg.read_f32("ruins_count", 3);
	s32 ruins_count_var = cfg.read_f32("ruins_count_var", 2);
	s32 ruins_size = cfg.read_f32("ruins_size", 10);
	f32 ruins_width = cfg.read_f32("ruins_width", 0.5f);

	//gold under tent
	u32 goldUnderTent = cfg.read_u32("goldUnderTent",0);
	u32 goldStartX = cfg.read_u32("goldStartX",12);
	u32 goldStartY = cfg.read_u32("goldStartY",20);
	//gold in middle
	u32 midGoldStartDepth = cfg.read_u32("midGoldStartDepth",5);
	s32 midGoldStartPosFromMid = cfg.read_s32("midGoldStartPosFromMid",0);			//starts at a pos, 
	u32 midGoldDepth = cfg.read_u32("midGoldDepth",7);
	//hole in middle
	s32 holeWidth = cfg.read_s32("holeWidth",0);

	//mirrored map
	bool mirror = cfg.read_bool("mirror",false);			//mirrors everything regardless of other mirror bools
	bool mirrorTerrain = cfg.read_bool("mirrorTerrain",false);
	bool mirrorVegetation = cfg.read_bool("mirrorVegetation",false);
	bool mirrorRuins = cfg.read_bool("mirrorRuins",false);		//not hooked up
	//bool mirrorGold = cfg.read_bool("mirrorGold", false);		//gold is mirrored anyway
	


	s32 realWidth=width;
	s32 mirrorWidth=width;					//uses mirrorWidth where the value desired is dependent on whether mirroring or not
	if(mirror||mirrorTerrain)mirrorWidth=width/2;		



	if (ruins_count > 0)
	{
		// do variation
		ruins_count += ruins_random.NextRanged(ruins_count_var + 1) - ruins_count_var / 2;
		//convert from ratio to tiles
		ruins_width *= width;
	}
	
	//done with vars! --------------------------------
	
	SetupMap(map, width, height);

	//gen heightmap
	array<int> heightmap(width);
	for (int x = 0; x < width; ++x)			//generate whole width of heightmap even if mirrored (to avoid edge effects from erosion)
	{
		heightmap[x] = baseline_tiles - deviation / 2 +
			       (map_noise.Fractal((x + 100) * 0.05, 0) * deviation);
	}

	//erode gradient
	
	for (int erode_cycle = 0; erode_cycle < erode_cycles; ++erode_cycle) //cycles
	{
		for (int x = 1; x < width-1; x++)			//erode whole width of the heightmap even when mirrored to avoid any possible edge effects
		{
			s32 diffleft = heightmap[x] - heightmap[x - 1];
			s32 diffright = heightmap[x] - heightmap[x + 1];
			
			if (diffleft > 0 && x > map_margin && diffleft > diffright)
			{
				heightmap[x] -= (diffleft + 1) / 2;
				heightmap[x - 1] += diffleft / 2;
			}
			else if (diffright > 0 && width - x > map_margin && diffright > diffleft)
			{
				heightmap[x] -= (diffright + 1) / 2;
				heightmap[x + 1] += diffright / 2;
			}
			else if (diffleft == diffright && diffleft > 0)
			{
				heightmap[x] -= (diffright + 1) / 2;
				heightmap[x - 1] += (diffleft + 3) / 4;
				heightmap[x + 1] += (diffleft + 3) / 4;
			}
		}
	}
	
	
	//map margin
	
	for (int x = 0; x < map_margin + lerp_distance; ++x)
	{
		if (x < map_margin)
		{
			heightmap[x] = baseline_tiles;
			if(!mirror && !mirrorTerrain) heightmap[width-1-x] = baseline_tiles;
		}
		else
		{
			f32 lerp = Maths::Min(1.0f, (x - map_margin) / f32(lerp_distance));
			heightmap[x] = baseline_tiles * (1.0f - lerp) + heightmap[x] * lerp;
			if(!mirror && !mirrorTerrain) heightmap[width-1-x] = baseline_tiles * (1.0f-lerp) + heightmap[width-1-x] * lerp;
			
		}
	}

	/*if(mirror||mirrorTerrain){					//mirror the heightmap
		for(int x=0;x<width;x++){
			heightmap[width-x]=heightmap[x];
		}
	}*/
	
	//gen terrain
	s32 bush_skip = 0;
	s32 tree_skip = 0;
	const s32 tree_limit = 2;
	const s32 bush_limit = 3;
	
	array<int> naturemap(width);
	for (int x = 0; x < width; ++x)
	{
		naturemap[x] = -1; //no nature
	}
	
	for(int x = 0; x < mirrorWidth; ++x)
	{
		f32 overhang = 0;
		for (int y = 0; y < height; y++)
		{
			u32 offset = x + y * width;
			
			f32 midline_dist = y - heightmap[x];
			
			f32 midline_frac = (midline_dist + deviation / 2) / (deviation + 0.01f);
			
			f32 edge_dist = Maths::Max(Maths::Min(x - map_margin, width - x - map_margin), 0);
			f32 lerp = Maths::Min(1.0f, edge_dist / f32(lerp_distance));
			
			f32 amp = Maths::Max(0.0f, purturb * Maths::Min(1.0f, 1.0f - Maths::Abs(midline_dist) / (purt_width / 2 + 0.01f)) * lerp);
			f32 _n = map_noise.Fractal(x * purt_scale, y * purt_scale);
			
			f32 n = midline_frac * (1.0f + (_n - 0.5f) * amp);
			
			if (n > 0.5f)
			{
				bool add_dirt = true;
				
				const f32 bedrock_thresh = 1.5f;
				
				const f32 material_frac = (material_noise.Fractal(x * 0.1f, y * 0.1f) - 0.5f) * 2.0f;
				
				const f32 n_plus = n + (material_frac * 0.4f);
				
				f32 cave_n = 0.0f;
				if (cave_amount > 0.0f) //any chance of caves
				{
					const f32 cave_dist = Maths::Max(Maths::Abs(x - width * 0.5f) - cave_width * 0.5f + cave_lerp, 0.0f);
					const f32 cave_mul = 1.0f - (cave_dist / cave_lerp);
					
					if (cave_mul > 0.0f) //don't bother sampling if theres no cave
					{
						
						f32 target = heightmap[x] + (cave_depth * cave_mul);
						
						f32 mul = 1.0f - (Maths::Abs(y - target) / 10.0f) +
									(cave_noise.Sample(x * 0.1f + 31.0f, y * 0.1f + 10.0f) - 0.5f) * cave_distort * cave_mul;
						
						cave_n = (cave_noise.Fractal(x * cave_scale + 132.0f, y * cave_scale * 0.1f + 993.0f) * cave_amount - 
								  (cave_noise.Fractal(x * 0.1f + 31.0f, y * 0.1f + 10.0f) - 0.5f) * cave_detail_amp * 2.0f
								  + mul
								 ) * 0.5f;
					}
				}
				
				if (cave_n > 1.0f - cave_amount)
				{
					map.SetTile(offset, CMap::tile_ground_back);
					add_dirt = false;
					
					overhang -= _n * 2.0f + 0.5f;
					continue;
				}
				else if ((/*n > 0.55f &&*/ n_plus < bedrock_thresh - 0.2f) || n > bedrock_thresh)
				{
					add_dirt = false;
					
					f32 centerMaterialFrac = material_frac*(((width/2-Maths::Abs(x-(width/2)))*1.0f)/(width*1.0f));
					if (material_frac < 0.7f && n > bedrock_thresh)
					{
						map.SetTile(offset, CMap::tile_bedrock);
					}
					else if (lerp > 0.5f &&
							material_frac > -0.5f && material_frac < -0.49f &&
							n_plus < 0.8f)
					{
						map.SetTile(offset, CMap::tile_gold);
					}
					else if(material_frac > 0.9f /*&& n > 0.9f*/)			//commented out condition made stone not spawn at the surface
					{
						map.SetTile(offset, CMap::tile_thickstone);
					}
					else if(material_frac > 0.06f && centerMaterialFrac>0.05f /*&& n_plus > 0.8f*/)		//commented out condition made stone not spawn at the surface
					{
						map.SetTile(offset, CMap::tile_stone);
					}
					else
					{
						add_dirt = true;
					}
				}
				
				if (add_dirt)
				{
					map.SetTile(offset, CMap::tile_ground);
					if (overhang == 0 && y > 1)
					{
						naturemap[x] = y;
					}
				}
				
				overhang = 10.0f;
			}
			else if (overhang > 0.3f)
			{
				overhang -= _n * 2.0f + 0.5f;
				map.SetTile(offset, CMap::tile_ground_back);
			}
		}
	}
	
	for (int i = 0; i < ruins_count; i++)
	{
		int type = ruins_random.NextRanged(3);
		
		s32 x = (width * 0.5f) + (ruins_random.NextFloat() - 0.5f) * ruins_width;
		
		s32 _size = ruins_size + ruins_random.NextRanged(ruins_size / 2) - ruins_size / 4;
		
		x -= _size / 2;
		//first pass -get minimum alt
		s32 floor_height = 0;
		for (int x_step = 0; x_step < _size; ++x_step)
		{
			s32 _x = Maths::Min(width - 1, Maths::Max(0, x + x_step));
			floor_height = Maths::Max(heightmap[_x] + 1, floor_height);
		}
		
		
		const int _roofheight = 3 + ruins_random.NextRanged(2);
		
		for (int x_step = 0; x_step < _size; ++x_step)
		{
			bool is_edge = (x_step == 0 || x_step == _size - 1);
			
			s32 _x = Maths::Min(width - 1, Maths::Max(0, x + x_step));
			u32 offset = _x + floor_height * width;
			
			naturemap[_x] = -1;
			
			if (ruins_random.NextRanged(10) > 3)
				map.SetTile(offset, CMap::tile_castle);
			
			int _upheight = (ruins_random.NextRanged(_roofheight + 1) +
							 ruins_random.NextRanged(_roofheight + 1) +
							 ruins_random.NextRanged(_roofheight + 1) + 4) / 3;
			int _upoffset = offset - width;
			for (int _upstep = 1;
				//upwards stepping		or underground
				(_upstep < _upheight || floor_height - _upstep + 1 > heightmap[_x])
				&& _upoffset > 0;
				
				++_upstep)
			{
				
				TileType solidtile, backtile;
				
				switch (type)
				{
						//wooden
					case 1:
						solidtile = CMap::tile_wood;
						backtile = CMap::tile_wood_back;
						break;
						
						//random each time
					case 2:
						if (ruins_random.NextRanged(2) == 0)
						{
							solidtile = CMap::tile_castle;
							backtile = CMap::tile_castle_back;
						}
						else
						{
							solidtile = CMap::tile_wood;
						backtile = CMap::tile_wood_back;
						}
						break;
						
						//stone
					case 0:
					default:
						solidtile = CMap::tile_castle;
						backtile = CMap::tile_castle_back;
						break;
				}
				
				if (_upstep == _roofheight)
				{
					map.SetTile(_upoffset, solidtile);
					break;
				}
				else if (is_edge)
				{
					map.SetTile(_upoffset, solidtile);
				}
				else if (_upstep < _upheight)
				{
					map.SetTile(_upoffset, backtile);
				}
				else
				{
					map.SetTile(_upoffset, CMap::tile_ground_back);
				}
				_upoffset -= width;
			}
		}
	}
	

	//tent gold
	if(goldUnderTent>0){
		int gold_x=goldStartX;
		int gold_y=height-goldStartY;
		for(int i=0;i<goldUnderTent;i++){
			map.SetTile(gold_x + (gold_y+i)*width, CMap::tile_gold );
			map.SetTile(width-gold_x-1 + (gold_y+i)*width, CMap::tile_gold );
		}
	}

	//middle gold
	u32 midGoldStartX = (width/2)+midGoldStartPosFromMid;
	u32 midGoldStartY = ((height*(100-baseline))/100)+midGoldStartDepth;
	s32 midGoldWidth=midGoldStartPosFromMid*2;
	if(midGoldWidth<0) midGoldWidth=midGoldWidth*-1;
	if((width%2)!=0) midGoldWidth++;

	if(midGoldStartPosFromMid!=0){
		for(int i=0;i<midGoldDepth;i++){
			for(int j=0;j<midGoldWidth;j++){
				map.SetTile(midGoldStartX+j+(midGoldStartY+i)*width, CMap::tile_gold);
			}
		}
	}

	//middle hole
	u32 holeStartX= width/2-holeWidth/2;
	if(holeWidth>0){
		for(int i= 0 ; i<height;i++){
			for(int j=0;j<holeWidth;j++){
				map.SetTile( holeStartX+j+(i*width), CMap::tile_empty);
			}
		}
		for(int x=0;x<holeWidth;x++) naturemap[holeStartX+x]=-1;		//stop plants growing in the hole
	}


	for (int x = 0; x < mirrorWidth; ++x)
	{
		if (naturemap[x] == -1)
			continue;
		
		int y = naturemap[x];
		
		f32 edge_dist = Maths::Max(Maths::Min(x - map_margin, width - x - map_margin), 0);
		f32 lerp = Maths::Min(1.0f, edge_dist / f32(lerp_distance));
		
		u32 offset = x + y * width;
		
		s32 map_margin_tree=map_margin;
		if(allowTreesInMargin)map_margin_tree=0;

		bool force_tree = (x == map_margin - 2 || width - x == map_margin - 2);
						
		f32 grass_frac = material_noise.Fractal(x * 0.02f, y * 0.02f) + ((1.0f - lerp) * 0.5f);
		if (force_tree || grass_frac > 0.5f)
		{
			map.SetTile(offset - width, CMap::tile_grass + map_random.NextRanged(4));  //todo grass random
			
			//generate vegetation
			if (force_tree ||
				( x > map_margin_tree && width-x > map_margin_tree) && (x % 7 == 0 || x % 23 == 3) )
			{
				f32 _g = map_random.NextFloat();
				
				Vec2f pos = (Vec2f(x, y - 1) * map.tilesize) +
							Vec2f(4.0f, 4.0f);
				
				if (tree_skip < tree_limit &&
					(!force_tree && _g > 0.5f || bush_skip > bush_limit))  //bush
				{
					bush_skip = 0;
					server_CreateBlob("bush", -1, pos);
					if(mirror||mirrorVegetation) server_CreateBlob( "bush", -1, (Vec2f(width-x-1,y-1)*map.tilesize ) + Vec2f(4.0f, 4.0f) );
					tree_skip++;
				}
				else if (tree_skip >= tree_limit || force_tree || _g > 0.25f)  //tree
				{
					tree_skip = 0;
					CBlob@ tree = server_CreateBlobNoInit(y < baseline_tiles ? "tree_pine" : "tree_bushy");
					if (tree !is null)
					{
						tree.Tag("startbig");
						tree.setPosition(pos);
						tree.Init();
						if(mirror || mirrorVegetation){
							CBlob@ mirroredTree = server_CreateBlobNoInit( y < baseline_tiles ? "tree_pine" : "tree_bushy" );
							mirroredTree.Tag("startbig");
							mirroredTree.setPosition( (Vec2f(width-x-1,y-1)*map.tilesize ) + Vec2f(4.0f, 4.0f) );
							mirroredTree.Init();
						}
						
						if (map.getTile(offset).type == CMap::tile_empty)
							map.SetTile(offset, CMap::tile_grass + map_random.NextRanged(3));
					}
					bush_skip++;
				}
			}
		}
	}

	
	if(mirror){			//create the mirrored tiles
		for(uint i=0;i<height;i++){
			for(uint j=0;j<width/2;j++){
				map.SetTile((width-j)+(i*width)-1,map.getTile(j+i*width).type);

			}
		}
	}
	
	SetupBackgrounds(map);
	return true;
}


void SetupMap(CMap@ map, int width, int height)
{
	map.CreateTileMap(width, height, 8.0f, "Sprites/world.png");
}

void SetupBackgrounds(CMap@ map)
{
	// sky

	map.CreateSky(color_black, Vec2f(1.0f, 1.0f), 200, "Sprites/Back/cloud", 0);
	map.CreateSkyGradient("Sprites/skygradient.png");   // override sky color with gradient

	// plains

	map.AddBackground("Sprites/Back/BackgroundPlains.png", Vec2f(0.0f, 0.0f), Vec2f(0.3f, 0.3f), color_white); 
	map.AddBackground("Sprites/Back/BackgroundTrees.png", Vec2f(0.0f,  19.0f), Vec2f(0.4f, 0.4f), color_white); 
	//map.AddBackground( "Sprites/Back/BackgroundIsland.png", Vec2f(0.0f, 50.0f), Vec2f(0.5f, 0.5f), color_white ); 
	map.AddBackground("Sprites/Back/BackgroundCastle.png", Vec2f(0.0f, 50.0f), Vec2f(0.6f, 0.6f), color_white); 

	// fade in 				   
	SetScreenFlash(255, 0, 0, 0);

	SetupBlocks(map);
}

void SetupBlocks(CMap@ map)
{
	
}

bool LoadMap(CMap@ map, const string& in fileName)
{
    print("GENERATING KAGGen MAP " + fileName);
    
    return loadMap(map, fileName);
}
