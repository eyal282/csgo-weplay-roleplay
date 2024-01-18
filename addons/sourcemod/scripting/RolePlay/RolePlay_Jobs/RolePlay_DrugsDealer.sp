#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <emitsoundany>
#include <Eyal-RP>
#include <fuckzones>

#define GRAMS_PER_PLANT 300

// Minimum amount of players needed to allow cocaine to be planted or bought
new MIN_PLAYERS_COCAINE = 32;

new EngineVersion:g_Game;

enum struct enDrugs
{
	char name[32];
	char shortName[8];
	int price;
	int karmaOnPlant;
	int karmaOnHarvest;
	int maxKarma;
	int expOnHarvest;
	float worthPerGram;
	int minLevel;
	bool bSpecial;
}

/* Per 5 minutes:
	Ritalin: $900
	Cannabis: $3,000
	Marijuana: $6,000
	Nice Guy Seeds: $10,500
	Cocaine: $75,000
	
*/
enDrugs Drugs[16];/* =
{ 
    { "Ritalin Seeds", "RITS", 150, 0, 0, 0, 3, 1.0, 0, false },
    { "Cannabis Seeds", "CANNA", 500, 50, 100, 1000, 5, 3.333333334, 1, false },
    { "Marijuana Seeds", "MARS", 1500, 100, 200, 1399, 6, 8.3333333334, 2, false },
    { "Nice Guy", "NICG", 2000, 150, 150, 1399, 7, 12.5, 3, false },
    { "Cocaine", "COCS", 100000, 99999, 99999, 3500, 50, 583.333333, 0, true },
    { "Xoxoaine", "XOXOA", -1, 0, 99999, 3500, 75, 166.666666, 0, true }
}
*/
public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

new g_iSeedItem[16];
new g_iSeedSellerNPC;
new g_iWeedBuyerNPC;
new g_iDrugDealerJob;
new g_iSeedCount[2048];
new g_iSeedExtend[2048];
new g_iSpawnTime[2048];
new g_iWeedOwner[2048];
new g_iGrams[MAXPLAYERS+1][16];
new Float:NextCocaine = 0.0;

new g_iSackGrams[2048];
new Float:g_iLastWeedTouch[MAXPLAYERS+1];
new ArrayList:g_aClientPlants[MAXPLAYERS+1];

new String:g_szDrugDealer_Names[11][16];

new g_iDrugDealer_PlantSeed[11];

new Handle:Trie_DrugDealerEco;

public RP_OnEcoLoaded()
{
	
	Trie_DrugDealerEco = RP_GetEcoTrie("Drugs Dealer");
	
	if(Trie_DrugDealerEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Drugs Dealer");
		
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "PLANT_SEED_LVL_#%i", i);
		
		if(!GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat)))
			break;
			
		g_iDrugDealer_PlantSeed[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "JOB_NAME_LVL_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		FormatEx(g_szDrugDealer_Names[i], sizeof(g_szDrugDealer_Names[]), TempFormat);
		
		i++;
	}
	i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "PLANT_NAME_#%i", i);
		
		new String:PlantName[32], String:PlantShortName[8],
		PlantPrice, PlantKarmaOnPlant, PlantKarmaOnHarvest, PlantMaxKarma, PlantExpOnHarvest,
		Float:PlantWorthPerGram, PlantMinLevel, bool:bPlantSpecial;
		
		if(!GetTrieString(Trie_DrugDealerEco, Key, PlantName, sizeof(PlantName)))
			break;
		
		FormatEx(Key, sizeof(Key), "PLANT_SHORTNAME_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, PlantShortName, sizeof(PlantShortName));
		
		FormatEx(Key, sizeof(Key), "PLANT_PRICE_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		PlantPrice = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "PLANT_KARMA_ON_PLANT_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		PlantKarmaOnPlant = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "PLANT_KARMA_ON_HARVEST_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		PlantKarmaOnHarvest = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "PLANT_MAX_KARMA_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		PlantMaxKarma = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "PLANT_EXP_ON_HARVEST_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		PlantExpOnHarvest = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "PLANT_WORTH_PER_GRAM_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		PlantWorthPerGram = StringToFloat(TempFormat);
		
		FormatEx(Key, sizeof(Key), "PLANT_MIN_LEVEL_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		PlantMinLevel = StringToInt(TempFormat);		
		
		FormatEx(Key, sizeof(Key), "PLANT_IS_SPECIAL_#%i", i);
		GetTrieString(Trie_DrugDealerEco, Key, TempFormat, sizeof(TempFormat));
		
		bPlantSpecial = view_as<bool>(StringToInt(TempFormat));				
		
		Drugs[i].name = PlantName;
		Drugs[i].shortName = PlantShortName;
		Drugs[i].price = PlantPrice;
		Drugs[i].karmaOnPlant = PlantKarmaOnPlant;
		Drugs[i].karmaOnHarvest = PlantKarmaOnHarvest;
		Drugs[i].maxKarma = PlantMaxKarma;
		Drugs[i].expOnHarvest = PlantExpOnHarvest;
		Drugs[i].worthPerGram = PlantWorthPerGram;
		Drugs[i].minLevel = PlantMinLevel;
		Drugs[i].bSpecial = bPlantSpecial;
		
		i++;
	}
	
	GetTrieString(Trie_DrugDealerEco, "MIN_PLAYERS_COCAINE", TempFormat, sizeof(TempFormat));
	MIN_PLAYERS_COCAINE = StringToInt(TempFormat);
	
	new cat = RP_AddCategory("Drug Seeds");
	
	for(i=0;i < sizeof(Drugs);i++)
	{
		if(Drugs[i].name[0] == EOS)
			break;
			
		g_iSeedItem[i] = RP_CreateItem(Drugs[i].name, Drugs[i].shortName);
		RP_SetItemCategory(g_iSeedItem[i], cat);
	}
}
public OnPluginStart()
{	
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	for(new i=1;i <= MaxClients;i++)
	{
		g_aClientPlants[i] = CreateArray(1);
	}
	
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
	
	RegAdminCmd("sm_xoxoaine", Command_Xoxoaine, ADMFLAG_ROOT);
	RegAdminCmd("sm_reloaddrud", Command_ReloadDrud, ADMFLAG_ROOT);
	RegAdminCmd("sm_supergrow", Command_SuperGrow, ADMFLAG_ROOT);
	
	if(RP_GetEcoTrie("Drugs Dealer") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public Action:Command_ReloadDrud(client, args)
{
	new count = GetEntityCount();
	
	for(new i=0;i < count;i++)
	{
		if(!IsValidEdict(i))
			continue;
			
		new String:Classname[64];
		
		GetEdictClassname(i, Classname, sizeof(Classname));
		
		if(strncmp(Classname, "drug_", 5) == 0)
		{
			RP_PrintToChat(client, "Could not reload Drug Dealer plugin, found plant");
			return Plugin_Handled;
		}
	}
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(GetClientTotalGrams(i) > 0)
		{
			RP_PrintToChat(client, "Could not reload Drug Dealer plugin, found grams");
			return Plugin_Handled;
		}
	}
	
	
	CreateTimer(0.5, Timer_ReloadPlugin, _, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Handled;
}

public Action:Command_SuperGrow(client, args)
{
	for(new i=0;i < GetEntityCount();i++)
	{
		g_iSpawnTime[i] = 0;
	}
}

public Action:Timer_ReloadPlugin(Handle:hTimer)
{
	ReloadPlugin();
}
public Action:Command_Xoxoaine(client, args)
{
	if(!IsHighManagement(client))
		return Plugin_Handled;
		
	for(new i=0;i < sizeof(Drugs);i++)
	{
		if(StrEqual(Drugs[i].shortName, "XOXOA"))
		{
			RP_GiveItem(client, g_iSeedItem[i]);
			
			break;
		}
	}
	
	return Plugin_Handled;
}
public Action:Event_OnPlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid", 0));

	if(RP_IsUserInArena(victim) || RP_IsUserInDuel(victim))
		return;
		
	for(new i=0;i < sizeof(Drugs);i++)
	{
		if(!g_iGrams[victim][i])
			continue;
		
		new Float:origin[3] = 0.0;
		GetClientAbsOrigin(victim, origin);
		CreateDrugsSack(g_iGrams[victim][i], origin, i);
		g_iGrams[victim][i]= 0;
	}
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_DrugsDealer");
	CreateNative("RP_GetTotalGrams", _RP_GetTotalGrams);
	CreateNative("RP_ResetGrams", _RP_ResetGrams);
}

public _RP_GetTotalGrams(Handle:plugin, numParams)
{
	return GetClientTotalGrams(GetNativeCell(1));
}

public _RP_ResetGrams(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);

	new worth = GetClientDrugsWorth(client);
	
	for(new i=0;i < sizeof(Drugs);i++)
	{
		g_iGrams[client][i] = 0;
	}
	
	return worth;
}

public OnMapStart()
{
	NextCocaine = GetGameTime();
	
	LoadDirOfModels("materials/models/player/voikanaa/re4/leon");
	LoadDirOfModels("models/player/custom_player/voikanaa/re4");
	PrecacheModel("models/player/custom_player/voikanaa/re4/leon.mdl", true);
	LoadDirOfModels("models/player/custom_player/voikanaa/gtaiv");
	LoadDirOfModels("models/player/custom_player/hekut/marcusreed");
	LoadDirOfModels("materials/models/player/custom_player/hekut/marcusreed");
	PrecacheModel("models/player/custom_player/hekut/marcusreed/marcusreed.mdl", true);
	
	LoadDirOfModels("materials/models/custom_prop/marijuana");
	LoadDirOfModels("models/custom_prop/marijuana");
	PrecacheModel("models/custom_prop/marijuana/marijuana_1.mdl", true);
	LoadDirOfModels("models/xflane/sack");
	LoadDirOfModels("materials/xflane/sack");
	PrecacheModel("models/xflane/sack/weed_sack.mdl", true);
	AddFileToDownloadsTable("sound/roleplay/weed_cut_.mp3");
	PrecacheSoundAny("roleplay/weed_cut_.mp3", true);
}


public Action:RolePlay_OnKarmaChanged(client, &karma, String:Reason[], &any:data)
{
	if(!StrEqual(Reason, KARMA_KILL_REASON))
	{
		return Plugin_Continue;
	}	
	new victim = data;
	
	if(!IsPlayer(victim))
		return Plugin_Continue;
	
	new level = RP_GetClientLevel(client, g_iDrugDealerJob);
	
	// No check if client is Drugs Dealer, karma is reduced regardless of current job.
	if(level >= 8)
	{
		karma -= 100;
		return Plugin_Changed;
	}
	else if(level >= 5)
	{
		karma -= 50;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
public bool:UpdateJobStats(client, job)
{
	if(job == -1)
		return false;
		
	if (job == g_iDrugDealerJob)
	{
		if (GetClientTeam(client) != CS_TEAM_T)
		{
			CS_SwitchTeam(client, CS_TEAM_T);
			CS_RespawnPlayer(client);
			
			return false; // Return because UpdateJobStats is called upon respawning.
		}
		
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iDrugDealerJob, model, sizeof(model));

		if(model[0] != EOS)
			SetEntityModel(client, model);

		CS_SetClientClanTag(client, "Drugs Dealer");
		RP_SetClientJobName(client, g_szDrugDealer_Names[RP_GetClientLevel(client, g_iDrugDealerJob)]);
		
		new level = RP_GetClientLevel(client, g_iDrugDealerJob);
		
		new bool:result = false;
		
		switch (level)
		{
			case 1, 2:
			{
				RP_GivePlayerItem(client, "weapon_glock");
			}
			case 3, 4, 5:
			{
				RP_GivePlayerItem(client, "weapon_deagle");
			}
			case 6, 7, 8:
			{
				RP_GivePlayerItem(client, "weapon_mp5sd");
				RP_GivePlayerItem(client, "weapon_deagle");
			}
			case 9, 10:
			{
				RP_GivePlayerItem(client, "weapon_ak47");
				RP_GivePlayerItem(client, "weapon_deagle");
				RP_GivePlayerItem(client, "weapon_tagrenade");
			}
		}
		
		if(level >= 4)
			SetClientArmor(client, 100);
			
		if(level >= 6)
			SetClientHelmet(client, true);
			
		return result;
	}
	
	return false;
}

public Frame_GiveLessAmmoGlock(client)
{
	if(!IsClientInGame(client)) // In a single frame a client can only get invalidated, not replaced.
		return;
		
	Client_GiveWeaponAndAmmo(client, "weapon_glock", false, 0, -1, 10, -1);
}
public OnUseNPC(client, id, entity)
{
	if (g_iSeedSellerNPC == id)
	{
		ShowSeedSellerMenu(client, entity);
	}
	else
	{
		if(g_iWeedBuyerNPC == id)
		{
			ShowWeedBuyerMenu(client, entity);
		}
	}
}

public Thief_OnItemsSteal(client, target, &Handle:items)
{
	for(new i=0;i < sizeof(Drugs);i++)
	{
		new item = g_iSeedItem[i];
		
		if(Drugs[i].bSpecial)
		{
			new pos;
			
			while((pos = FindValueInArray(items, item)) != -1)
			{
				RemoveFromArray(items, pos);
			}
		}
	}
	
	if(g_iDrugDealer_PlantSeed[RP_GetClientLevel(client, g_iDrugDealerJob)] > GetClientTotalSeeds(client, true))
		return;
		
	for(new i=0;i < sizeof(Drugs);i++)
	{
		new pos = -1;
		
		while((pos = FindValueInArray(items, g_iSeedItem[i])) != -1)
			RemoveFromArray(items, pos);
	}
}

public Action:OnItemSent(client, player, item)
{
	for(new i=0;i < sizeof(Drugs);i++)
	{
		if (g_iSeedItem[i] == item)
		{
			if (g_iDrugDealer_PlantSeed[RP_GetClientLevel(player, g_iDrugDealerJob)] <= GetClientTotalSeeds(player, true))
			{
				RP_PrintToChat(client, "%N cant hold any more seeds!", player);
						
				return Plugin_Handled;
			}
			
			else if(Drugs[i].minLevel > RP_GetClientLevel(player, g_iDrugDealerJob))
			{
				RP_PrintToChat(client, "%N's level is too low for this seed.", player);
						
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}
public Action:OnItemUsed(client, item)
{
	for(new i=0;i < sizeof(Drugs);i++)
	{
		if(Drugs[i].name[0] == EOS)
			return Plugin_Continue;
			
		if (g_iSeedItem[i] == item)
		{
			if(StrEqual(Drugs[i].shortName, "COCS") && GetPlayerCount() < MIN_PLAYERS_COCAINE)
			{
				RP_PrintToChat(client, "Cocaine cannot be bought or planted with less than %i players online.", MIN_PLAYERS_COCAINE);
				
				return Plugin_Stop;
			}
			else if (RP_GetClientJob(client) != g_iDrugDealerJob && !StrEqual(Drugs[i].shortName, "XOXOA"))
			{
				RP_PrintToChat(client, "You have to be \x02drug dealer\x01 to use this seeds!");
				return Plugin_Stop;
			}
			
			VerifyPlantedWeeds(client);
			
			if (g_iDrugDealer_PlantSeed[RP_GetClientLevel(client, g_iDrugDealerJob)] <= GetArraySize(g_aClientPlants[client]))
			{
				RP_PrintToChat(client, "You cant plant more seeds!");
				return Plugin_Stop;
			}
			
			else if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				RP_PrintToChat(client, "Drugs can't fly, they only make you fly.");
				return Plugin_Stop;
			}
			else if(RP_IsClientInJail(client))
			{
				RP_PrintToChat(client, "it's too dangerous to do something so stupid.");
				return Plugin_Stop;
			}
			else if(IsClientNoKillZone(client))
			{
				RP_PrintToChat(client, "You cannot plant inside a no-kill zone!");
				
				return Plugin_Stop;	
			}
			else if(Zone_IsClientInZone(client, "BhopPlace", false))
			{
				RP_PrintToChat(client, "You cannot plant on roofs that you can only reach with bunnyhopping!");
				
				return Plugin_Stop;
			}
			else if(StrEqual(Drugs[i].shortName, "COCS") && CocaineExists())
			{
				RP_PrintToChat(client, "Cocaine cannot be planted if another cocaine plant exists.");
				
				return Plugin_Stop;
			}
			PlantWeed(client, i);
		}
	}
	return Plugin_Continue;
}

ShowWeedBuyerMenu(client, entity)
{
	if (GetClientTeam(client) == 2)
	{
		new String:szEntityId[8];
		new String:szFormat[32];
		IntToString(entity, szEntityId, 5);
		new Menu:menu = CreateMenu(WeedBuyer_Handler, MenuAction:28);
		RP_SetMenuTitle(menu, "Weed Buyer Menu\n● Grams on you: %i\n ", GetClientTotalGrams(client));
		
		new worth = GetClientDrugsWorth(client);
	
		FormatEx(szFormat, 32, "Sell grams - $%i", worth);
		AddMenuItem(menu, szEntityId, szFormat, worth > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

		DisplayMenu(menu, client, 0);
	}
	else
	{
		RP_PrintToChat(client, "Who are you? I dont know you...");
	}
}

public WeedBuyer_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId, 10);
		if(CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
		}
		else
		{
			new worth = GetClientDrugsWorth(client);
			
			new BruteWorth = worth;
			new NetWorth = BruteWorth - GetClientRelativeDrugsCost(client);
			//new TaxedNet = RoundToFloor(float(NetWorth) * (float(Get_User_Gang_Tax(client)) / 100.0));
			
			new Float:TaxPercent = (float(NetWorth) / float(BruteWorth)) * 100.0;
			
			
			if(Get_User_Gang(client) == -1)
				TaxPercent = 100.0;
				
			if(TaxPercent < 0.0)
				TaxPercent = 0.0;
				
			worth = GiveClientCash(client, POCKET_CASH, BruteWorth, TaxPercent);
			
			RP_PrintToChat(client, "You have sold \x02%i\x01 grams for \x04$%i!", GetClientTotalGrams(client), worth);
			
			for(new i=0;i < sizeof(Drugs);i++)
			{
				g_iGrams[client][i] = 0;
			}
		}
	}
	else
	{
		if (action == MenuAction_End)
		{
			CloseHandle(menu);
			menu = null;
		}
	}
}

ShowSeedSellerMenu(client, entity)
{
	if (GetTime({0,0}) - g_iSeedExtend[entity] > 60)
	{
		g_iSeedCount[entity] = GetRandomInt(5, 20);
	}
	new String:szEntityId[8];
	new String:szFormat[32];
	IntToString(entity, szEntityId, 5);
	new Menu:menu = CreateMenu(SeedSeller_Handler, MenuAction:28);
	
	new bool:bBank = RP_GetClientLevel(client, g_iDrugDealerJob) >= 7;
	
	RP_SetMenuTitle(menu, "Seed Seller Menu\n● %s cash: $%i\n ", bBank ? "Bank" : "Pocket", bBank ? GetClientCash(client, BANK_CASH) : GetClientCash(client, POCKET_CASH));
	
	if (g_iSeedCount[entity])
	{
		for(new i=0;i < sizeof(Drugs);i++)
		{
			if(Drugs[i].price <= 0)
				continue;
			
			else if(Drugs[i].name[0] == EOS)
				break;
				
			if(StrEqual(Drugs[i].shortName, "COCS"))
			{
				if(NextCocaine <= GetGameTime())
				{
					FormatEx(szFormat, 32, "Buy %s - $%i", Drugs[i].name, Drugs[i].price);
					AddMenuItem(menu, szEntityId, szFormat, ITEMDRAW_DEFAULT);
				}
				else
				{
					FormatEx(szFormat, 32, "Buy %s - $%i [%.1fm]", Drugs[i].name, Drugs[i].price, (NextCocaine - GetGameTime()) / 60.0);
					AddMenuItem(menu, szEntityId, szFormat, ITEMDRAW_DISABLED);
				}
			}
			else
			{
				FormatEx(szFormat, 32, "Buy %s - $%i", Drugs[i].name, Drugs[i].price);
				AddMenuItem(menu, szEntityId, szFormat, ITEMDRAW_DEFAULT);
			}
		}
	}
	else
	{
		AddMenuItem(menu, szEntityId, "No seeds left", ITEMDRAW_DISABLED);
	}
	DisplayMenu(menu, client, 0);
}

public SeedSeller_Handler(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new bool:bBank = RP_GetClientLevel(client, g_iDrugDealerJob) >= 7;
		
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId);
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
		}
		else
		{
			if(StrEqual(Drugs[key].shortName, "COCS") && GetPlayerCount() < MIN_PLAYERS_COCAINE)
			{
				RP_PrintToChat(client, "Cocaine cannot be bought or planted with less than %i players online.", MIN_PLAYERS_COCAINE);
			}
			else if(Drugs[key].minLevel > RP_GetClientLevel(client, g_iDrugDealerJob))
			{
				RP_PrintToChat(client, "You need to be level %i to buy this!", Drugs[key].minLevel);
			}
			else if (!Drugs[key].bSpecial && g_iDrugDealer_PlantSeed[RP_GetClientLevel(client, g_iDrugDealerJob)] <= GetClientTotalSeeds(client, true))
			{
				RP_PrintToChat(client, "You cant buy any more seeds!");
			}
			else if (!bBank && GetClientCash(client, POCKET_CASH) < Drugs[key].price)
			{
				RP_PrintToChat(client, "You dont have enough pocket cash to buy these seeds!");
			}
			else if (bBank && GetClientCash(client, BANK_CASH) < Drugs[key].price)
			{
				RP_PrintToChat(client, "You dont have enough bank cash to buy these seeds!");
			}
			else
			{
				if(!StrEqual(Drugs[key].shortName, "COCS"))
				{
					RP_PrintToChat(client, "\x04You \x01just bought \x07%s", Drugs[key].name);

					if(bBank)
						GiveClientCash(client, BANK_CASH, -1 * Drugs[key].price);
					
					else
						GiveClientCash(client, POCKET_CASH, -1 * Drugs[key].price);

					RP_GiveItem(client, g_iSeedItem[key]);

					g_iSeedCount[entity]--;

					if (!g_iSeedCount[entity])
					{
						g_iSeedExtend[entity] = GetTime({0,0});
					}
						
				}
				else if(NextCocaine <= GetGameTime())
				{
					NextCocaine = GetGameTime() + 3600.0;
					
					RP_PrintToChat(client, "\x04You \x01just bought \x07%s", Drugs[key].name);

					if(bBank)
						GiveClientCash(client, BANK_CASH, -1 * Drugs[key].price);
					
					else
						GiveClientCash(client, POCKET_CASH, -1 * Drugs[key].price);

					RP_GiveItem(client, g_iSeedItem[key]);

					g_iSeedCount[entity]--;

					if (!g_iSeedCount[entity])
					{
						g_iSeedExtend[entity] = GetTime({0,0});
					}
				}
			}
		}
	}
}

public OnClientPostAdminCheck(client)
{
	ClearArray(g_aClientPlants[client]);
	

	AttachPlantedWeedsBySteamId(client);
}

public OnClientDisconnect(client)
{
	DeattachPlantedWeedsFromClientIndex(client);
}

public Action:Thief_RequestIdentity(client, const String:JobShortName[], &FakeLevel, String:LevelName[32], String:Model[PLATFORM_MAX_PATH])
{
	if(StrEqual(JobShortName, "DRUD", false))
	{
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iDrugDealerJob, model, sizeof(model));

		if(model[0] != EOS)
			FormatEx(Model, sizeof(Model), model);

		FormatEx(LevelName, sizeof(LevelName), "Drugs Dealer");
		
		FakeLevel = RP_GetClientLevel(client, g_iDrugDealerJob)
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_NPC", true))
	{
		g_iSeedSellerNPC = RP_CreateNPC("models/player/custom_player/hekut/marcusreed/marcusreed.mdl", "SEEDSELLER");
		g_iWeedBuyerNPC = RP_CreateNPC("models/player/custom_player/voikanaa/re4/leon.mdl", "WEEDBUYER");
	}
	if (StrEqual(name, "RolePlay_Jobs", true))
	{
		g_iDrugDealerJob = RP_CreateJob("Drugs Dealer", "DRUD", 11);
	}
}

PlantWeed(client, type)
{
	new Float:origin[3] = 0.0;
	GetClientAbsOrigin(client, origin);
	RP_PrintToChat(client, "Planting weeds...");
	new iEnt = CreateEntityByName("prop_dynamic_override", -1);
	DispatchKeyValue(iEnt, "disableshadows", "1");
	DispatchKeyValue(iEnt, "solid", "6");
	DispatchKeyValue(iEnt, "model", "models/custom_prop/marijuana/marijuana_1.mdl");
	SetEntityMoveType(iEnt, MoveType:8);
	DispatchSpawn(iEnt);
	TeleportEntity(iEnt, origin, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(iEnt, "TouchType", "4");
	SetEntProp(iEnt, PropType:0, "m_usSolidFlags", any:12, 4, 0);
	SetEntProp(iEnt, PropType:1, "m_nSolidType", any:6, 4, 0);
	SetEntProp(iEnt, PropType:0, "m_CollisionGroup", any:1, 4, 0);
	SetEntityMoveType(iEnt, MoveType:0);
	SetEntProp(iEnt, PropType:1, "m_MoveCollide", any:0, 4, 0);
	SetEntityModel(iEnt, "models/custom_prop/marijuana/marijuana_1.mdl");
	
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	new String:Classname[64];
	FormatEx(Classname, sizeof(Classname), "drug_%s", AuthId);
	DispatchKeyValue(iEnt, "classname", Classname);
	
	if(StrEqual(Drugs[type].shortName, "XOXOA"))
		g_iSpawnTime[iEnt] = 0;
	
	else
		g_iSpawnTime[iEnt] = GetTime({0,0});
		
	PushArrayCell(g_aClientPlants[client], iEnt);
	g_iWeedOwner[iEnt] = client;
	
	CreateTimer(300.0, Timer_ReadyDrugs, EntIndexToEntRef(iEnt));
	
	CreateTimer(600.0, Timer_ExpireDrugs, EntIndexToEntRef(iEnt));
	AcceptEntityInput(iEnt, "FireUser1", -1, -1, 0);
	SDKHookEx(iEnt, SDKHook_Touch, WeedTouch);
	
	new String:sType[5];
	IntToString(type, sType, sizeof(sType));
		
	SetEntPropString(iEnt, Prop_Data, "m_iName", sType);
	
	new karmaToGive = Drugs[type].karmaOnPlant;
	
	if(RP_GetClientLevel(client, g_iDrugDealerJob) >= 10)
		karmaToGive /= 2;
		
	new totalKarma = RP_GetKarma(client) + Drugs[type].karmaOnPlant;
	
	if(totalKarma > Drugs[type].maxKarma)
		totalKarma = Drugs[type].maxKarma;
	
	if(totalKarma > RP_GetKarma(client))
		RP_SetKarma(client, totalKarma, true);
}

public Action:Timer_ReadyDrugs(Handle:hTimer, Ref)
{
	new ent = EntRefToEntIndex(Ref);
	
	if(ent == -1)
		return;
		
	new owner = g_iWeedOwner[ent];
	
	if(owner == 0 || !IsClientInGame(owner))
		return;
		
	else if(!CheckCommandAccess(owner, "sm_vip", ADMFLAG_CUSTOM2))
		return;
	
	RP_PrintToChat(owner, "One of your\x03 drug plants\x01 is ready for\x04 harvest!");
}

public Action:Timer_ExpireDrugs(Handle:hTimer, Ref)
{
	new ent = EntRefToEntIndex(Ref);
	
	if(ent == -1)
		return;
		
	new owner = g_iWeedOwner[ent];
	
	AcceptEntityInput(ent, "Kill");
	
	if(owner == 0 || !IsClientInGame(owner))
		return;
	
	RP_PrintToChat(owner, "One of your drug plants has wilted");
}

public Action:WeedTouch(entity, client)
{
	if (!client || client > MaxClients)
	{
		return;
	}
	if (GetEngineTime() - g_iLastWeedTouch[client] > 1.0)
	{
		new String:sType[5];
		
		GetEntPropString(entity, Prop_Data, "m_iName", sType, sizeof(sType));
		
		new type = StringToInt(sType);
		
		new buttons = GetClientButtons(client);
		if (buttons & IN_USE)
		{	
			new grams = GetGrowthForTime(g_iSpawnTime[entity]);
			
			if (GetClientTeam(client) == CS_TEAM_CT)
			{
				new worth = RoundToFloor(Drugs[type].worthPerGram * float(grams));
				
				worth = RoundFloat(float(worth) / 1.5);
				
				worth = GiveClientCash(client, POCKET_CASH, worth);
			
				RP_PrintToChat(client, "You have seized \x02%i\x01 grams for \x04$%i!", grams, worth);
				GiveClientCash(client, BANK_CASH, worth);
				
				new Float:Origin[3];
				
				GetEntPropVector(entity, Prop_Data, "m_vecOrigin", Origin);
				
				EmitSoundByDistanceAny(512.0, "roleplay/weed_cut_.mp3", -2, 0, 75, 0, 1.0, 100, -1, Origin, NULL_VECTOR, true, 0.0);
			
				new exp = RoundToFloor(float(Drugs[type].expOnHarvest) * (float(grams) / float(GRAMS_PER_PLANT)));
				
				RP_AddClientEXP(client, RP_GetClientJob(client), exp);
				
				AcceptEntityInput(entity, "Kill");
			}
			else
			{
				g_iGrams[client][type] += grams;

				RP_PrintToChat(client, "You now have \x02%i\x01 grams on you.", GetClientTotalGrams(client));
				
				new Float:Origin[3];
				
				GetEntPropVector(entity, Prop_Data, "m_vecOrigin", Origin);
				
				EmitSoundByDistanceAny(512.0, "roleplay/weed_cut_.mp3", -2, 0, 75, 0, 1.0, 100, -1, Origin, NULL_VECTOR, true, 0.0);
				
				new exp = RoundToFloor(float(Drugs[type].expOnHarvest) * (float(grams) / float(GRAMS_PER_PLANT)));
				
				RP_AddClientEXP(client, g_iDrugDealerJob, exp);
				
				new karmaToGive = Drugs[type].karmaOnHarvest;
				
				if(RP_GetClientLevel(client, g_iDrugDealerJob) >= 10)
					karmaToGive /= 2;
					
				new totalKarma = RP_GetKarma(client) + RoundToFloor(float(karmaToGive) * (float(grams) / float(GRAMS_PER_PLANT)));
	
				if(totalKarma > Drugs[type].maxKarma)
					totalKarma = Drugs[type].maxKarma;
					
				if(totalKarma > RP_GetKarma(client))
					RP_SetKarma(client, totalKarma, true);
				
				AcceptEntityInput(entity, "Kill");
			}
		}
		PrintHintText(client, "</font><font color=\"#87CEFA\">%N</font>'s<font color=\"#7ABA71\"> %s\n</font>Growth: %i grams.\n<font color=\"#87CEFA\">Hold E to cut your plant.</font>", g_iWeedOwner[entity], Drugs[type].name, GetGrowthForTime(g_iSpawnTime[entity]));
		g_iLastWeedTouch[client] = GetEngineTime();
	}
}

GetGrowthForTime(time)
{
	new seconds = GetTime() - time;

	if (seconds > GRAMS_PER_PLANT)
	{
		seconds = GRAMS_PER_PLANT;
	}
	return seconds;
}

VerifyPlantedWeeds(client)
{
	new entity = -1;
	new String:szEntityClassName[64];


	for(new i=0;i < GetArraySize(g_aClientPlants[client]);i++)
	{
		entity = GetArrayCell(g_aClientPlants[client], i);

		if (IsValidEdict(entity) && g_iWeedOwner[entity] == client)
		{
			GetEdictClassname(entity, szEntityClassName, sizeof(szEntityClassName));
			if(strncmp(szEntityClassName, "drug", 4) != 0)
			{
				RemoveFromArray(g_aClientPlants[client], i);
				i--;
			}
		}
		else
		{
			RemoveFromArray(g_aClientPlants[client], i);
			i--;
		}
	}
}


AttachPlantedWeedsBySteamId(client)
{
	new String:szEntityClassName[64];
	
	new count = GetEntityCount();
	
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	new String:TargetClassname[64];
	FormatEx(TargetClassname, sizeof(TargetClassname), "drug_%s", AuthId);
	
	for(new i=MaxClients+1;i < count;i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i))
		{	
			GetEdictClassname(i, szEntityClassName, sizeof(szEntityClassName));
			

			if(StrEqual(szEntityClassName, TargetClassname))
			{

				PushArrayCell(g_aClientPlants[client], i);
				g_iWeedOwner[i] = client;
			}
		}
	}
}

DeattachPlantedWeedsFromClientIndex(client)
{
	if (!GetArraySize(g_aClientPlants[client]))
	{
		return;
	}
	new entity = -1;
	new String:szEntityClassName[64];

	for(new i=0;i < GetArraySize(g_aClientPlants[client]);i++)
	{
		entity = GetArrayCell(g_aClientPlants[client], i, 0, false);

		if (IsValidEdict(entity) && client == g_iWeedOwner[entity])
		{
			GetEdictClassname(entity, szEntityClassName, sizeof(szEntityClassName));
			
			if(strncmp(szEntityClassName, "drug", 4) == 0)
			{
				g_iWeedOwner[entity] = 0;
			}
		}
	}
	
	ClearArray(g_aClientPlants[client]);
}
/*
DeletePlantedWeeds(client)
{
	if (!GetArraySize(g_aClientPlants[client]))
	{
		return;
	}
	new entity = -1;
	new String:szEntityClassName[64];

	for(new i=0;i < GetArraySize(g_aClientPlants[client]);i++)
	{
		entity = GetArrayCell(g_aClientPlants[client], i, 0, false);

		if (IsValidEdict(entity) && client == g_iWeedOwner[entity])
		{
			GetEdictClassname(entity, szEntityClassName, sizeof(szEntityClassName));
			if(strncmp(szEntityClassName, "drug", 4) == 0)
			{
				AcceptEntityInput(entity, "Kill", -1, -1, 0);
			}
		}
	}
	
	ClearArray(g_aClientPlants[client]);
}
*/
CreateDrugsSack(grams, Float:origin[3], type)
{
	new sack = CreateEntityByName("prop_physics_override", -1);
	if (IsValidEntity(sack))
	{
		DispatchKeyValue(sack, "model", "models/xflane/sack/weed_sack.mdl");
		DispatchKeyValue(sack, "disableshadows", "1");
		DispatchKeyValue(sack, "disablereceiveshadows", "1");
		DispatchKeyValue(sack, "solid", "1");
		DispatchKeyValue(sack, "PerformanceMode", "1");
		
		DispatchSpawn(sack);
		
		SetEntProp(sack, Prop_Data, "m_nSolidType", SOLID_BBOX);
		SetEntProp(sack, Prop_Data, "m_usSolidFlags", FSOLID_TRIGGER);
		SetEntProp(sack, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
		SetEntProp(sack, Prop_Send, "m_nSolidType", SOLID_BBOX);
		SetEntProp(sack, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER);
		SetEntProp(sack, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
		
		TeleportEntity(sack, origin, NULL_VECTOR, NULL_VECTOR);
		g_iSackGrams[sack] = grams;
		SDKHookEx(sack, SDKHook_Touch, MoneySackTouch);
		
		
		SDKHook(sack, SDKHook_OnTakeDamage, SDKEvent_NeverTakeDamage);

		DispatchKeyValue(sack, "OnUser1", "!self,Kill,,60.0,-1");
		AcceptEntityInput(sack, "FireUser1", -1, -1, 0);
		
		new String:sType[5];
		IntToString(type, sType, sizeof(sType));
		
		SetEntPropString(sack, Prop_Data, "m_iName", sType);
	}
}

public Action:SDKEvent_NeverTakeDamage(victimEntity)
{
	return Plugin_Handled;
}	

public Action:MoneySackTouch(entity, client)
{
	if (!client || client >= MaxClients)
	{
		return;
	}
	
	new String:sType[5];
	
	GetEntPropString(entity, Prop_Data, "m_iName", sType, sizeof(sType));
	
	new type = StringToInt(sType);
	
	new grams = g_iSackGrams[entity];
	
	if(GetClientTeam(client) == CS_TEAM_CT)
	{
		new worth = RoundToFloor(Drugs[type].worthPerGram * float(grams));
		
		worth = GiveClientCash(client, BANK_CASH, worth);
		RP_PrintToChat(client, "You have found and seized \x02%i\x01 grams \x02(%i cash.)!", grams, worth);
	}
	else
	{
		RP_PrintToChat(client, "You have found \x04%i\x01 grams of %s!", grams, Drugs[type].name);

		g_iGrams[client][type] += grams;
	
		new karmaToGive = Drugs[type].karmaOnHarvest;
		
		if(RP_GetClientLevel(client, g_iDrugDealerJob) >= 10)
			karmaToGive /= 2;
			
		new totalKarma = RP_GetKarma(client) + RoundToFloor(float(karmaToGive) * (float(grams) / float(GRAMS_PER_PLANT)));

		if(totalKarma > Drugs[type].maxKarma)
			totalKarma = Drugs[type].maxKarma;
			
		if(totalKarma > RP_GetKarma(client))
			RP_SetKarma(client, totalKarma, true);

		RP_PrintToChat(client, "You now have \x04%i\x01 grams!", GetClientTotalGrams(client));
	}
	AcceptEntityInput(entity, "Kill", -1, -1, 0);
	return;
}

stock GetClientTotalGrams(client)
{
	new count;
	
	for(new i=0;i < sizeof(Drugs);i++)
	{
		if(Drugs[i].name[0] == EOS)
			break;
			
		count += g_iGrams[client][i];
	}
	
	return count;
}

// Relative to if they got 300 grams per plant.
stock GetClientRelativeDrugsCost(client)
{
	new cost;
	
	for(new i=0;i < sizeof(Drugs);i++)
	{
		if(Drugs[i].name[0] == EOS)
			break;
			
		cost += RoundToFloor((float(g_iGrams[client][i]) / 300.0) * Drugs[i].price);
	}
	
	return cost;
}
stock GetClientDrugsWorth(client)
{
	new worth;
	
	for(new i=0;i < sizeof(Drugs);i++)
	{
		if(Drugs[i].name[0] == EOS)
			break;
			
		worth += RoundToFloor(float(g_iGrams[client][i]) * Drugs[i].worthPerGram);
	}
	
	return worth;
}

stock GetClientTotalSeeds(client, bool:excludeSpecial)
{
	new count;
	
	for(new i=0;i < sizeof(Drugs);i++)
	{
		if(Drugs[i].bSpecial)
			continue;
		
		else if(Drugs[i].name[0] == EOS)
			break;
			
		count += RP_CountPlayerItems(client, g_iSeedItem[i]);
	}
	
	return count;
}


stock EmitSoundByDistanceAny(Float:distance, const String:sample[], 
                 entity = SOUND_FROM_PLAYER, 
                 channel = SNDCHAN_AUTO, 
                 level = SNDLEVEL_NORMAL, 
                 flags = SND_NOFLAGS, 
                 Float:volume = SNDVOL_NORMAL, 
                 pitch = SNDPITCH_NORMAL, 
                 speakerentity = -1, 
                 const Float:origin[3], 
                 const Float:dir[3] = NULL_VECTOR, 
                 bool:updatePos = true, 
                 Float:soundtime = 0.0)
{
	if(IsNullVector(origin))
	{
		ThrowError("Origin must not be null!");
	}
	
	new clients[MAXPLAYERS+1], count;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		new Float:iOrigin[3];
		GetEntPropVector(i, Prop_Data, "m_vecOrigin", iOrigin);
		
		if(GetVectorDistance(origin, iOrigin, false) < distance)
			clients[count++] = i;
	}
	
	EmitSoundAny(clients, count, sample, entity, channel, level, flags, volume, pitch, speakerentity, origin, dir, updatePos, soundtime);
}

stock bool:CocaineExists()
{
	for (new i = MaxClients; i < GetEntityCount();i++)
	{
		if(!IsValidEdict(i))
			continue;
			
		new String:Classname[8];
		
		GetEdictClassname(i, Classname, sizeof(Classname));
		
		if(strncmp(Classname, "drug_", 5) != 0)
			continue;
			
		new String:iName[11];
		
		GetEntPropString(i, Prop_Data, "m_iName", iName, sizeof(iName));
		
		if(!StrEqual(Drugs[StringToInt(iName)].shortName, "COCS"))
			continue;
			
		return true;
	}
	
	return false;
}