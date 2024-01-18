#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <Eyal-RP>
#include <fuckzones>

#define MENUINFO_ASSISTBOUNTY "Thief - Rob - Assist Bounty"

// %1 indicates the sum of all levels in all jobs of the player.
#define MAX_WEAPONS_TO_HOLD_FORMULA(%1) 1 + %1

new g_iLastNPC[MAXPLAYERS+1];
new bool:g_bLastRifle[MAXPLAYERS+1];

new COOLDOWN_BETWEEN_CRAFTS = 180;

new TIME_TO_BUILD_WEAPON = 60;

new Float:WEAPON_SELL_MULTIPLIER = 0.6;

new WEP_STORE_ROB_TIME = 60;
new WEP_STORE_ROB_KARMA = 1600;
new WEP_STORE_MAX_KARMA = 1800;

new MIN_PLAYERS_ROB = 6;

new Float:ROB_COOLDOWN = 1500.0;
new Float:ROB_FAIL_COOLDOWN = 300.0;

enum struct enMaterialInfo
{
	char MaterialName[32];
	char MaterialShortName[16];
	int MaterialPrice;
}

enMaterialInfo g_MaterialItems[3];

enum struct enItemInfo
{
    char WeaponName[32];
    char WeaponShortName[16];
    char WeaponClassname[32];
    int WeaponPrice;
    int WoodCost;
    int MetalCost;
    int IronCost;
    int CraftProfit;
	bool isRifle;
    int StockAmount;
	
	int maxCost()
	{
		int max = this.WoodCost;
		
		if(this.WoodCost < this.MetalCost)
			max = this.MetalCost;
			
		if(this.MetalCost < this.IronCost)
			max = this.IronCost;
			
		return max;
	}
}

enItemInfo g_ShopItems[64];/* =
{
	{ "AK-47", "AK47", "weapon_ak47", 25000, 11, 12, 13, 6000, true, 0 },
	{ "SG-553", "SG553", "weapon_sg556", 30000, 8, 10, 12, 5000, true, 0 },
	{ "AUG", "AUG", "weapon_aug", 30000, 12, 8, 10, 5000, true, 0 },
	{ "SSG-08", "SSG08", "weapon_ssg08", 17500, 10, 12, 6, 5000, true, 0 },
	{ "Galil-AR", "GALILAR", "weapon_galilar", 15000, 8, 5, 11, 4000, true, 0 },
	{ "PP-Bizon", "PPBIZON", "weapon_bizon", 10000, 9, 8, 11, 4000, true, 0 },
	{ "CZ75-Auto", "CZ75AUTO", "weapon_cz75a", 8500, 6, 5, 6, 3000, false, 0 },
	{ "Deagle", "DEAGLE", "weapon_deagle", 6000, 7, 7, 8, 3000, false, 0 },
	{ "Glock-18", "GLOCK18", "weapon_glock", 500, 5, 5, 5, 3000, false, 0 },
	{ "USP-S", "USPS", "weapon_usp_silencer", 2000, 6, 5, 5, 3000, false, 0 },
	{ "Mac-10", "MAC10", "weapon_mac10", 10000, 9, 11, 8, 4000, true, 0 },
	{ "MAG-7", "MAG7", "weapon_mag7", 20000, 6, 11, 9, 4000, true, 0 },
	{ "Negev", "NEGEV", "weapon_negev", 50000, 14, 14, 10, 7000, true, 0 },
	{ "Nova", "NOVA", "weapon_nova", 20000, 10, 11, 5, 4000, true, 0 },
	{ "P250", "P250", "weapon_p250", 500, 4, 5, 5, 3000, false, 0 },
	{ "P90", "P90", "weapon_p90", 12500, 10, 11, 12, 5000, true, 0 },
	{ "Sawed-off", "SAWEDOFF", "weapon_sawedoff", 20000, 10, 11, 9, 4000, true, 0 },
	{ "Tec-9", "TEC9", "weapon_tec9", 2500, 6, 5, 6, 3000, false, 0 },
	{ "R8 Revolver", "R8REVOLVER", "weapon_revolver", 5000, 8, 7, 7, 3000, false, 0 },
	{ "Kevlar", "KEVLAR", "item_kevlar", 2000, 11, 0, 0, 4000, true, 0 },
	{ "Kevlar + Helmet", "KEVLARHELMET", "item_assaultsuit", 15000, 15, 15, 15, 10000, true, 0 },
	{ "AWP", "AWP", "weapon_awp", -1, 99999, 99999, 99999, 0, true, 0 }
}
*/
public Plugin:myinfo =
{
	name = "RolePlay - Weapons Shop",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = "https://steamcommunity.com/id/xflane/"
};

new String:g_szLevels[11][16];

new g_iCrafter_MaxMaterials[11];

// Amount of items robbed from the weapon store.
new g_iThief_RobItems[11];

// Amount of materials a weapon can be worth before it can be robbed.
new g_iThief_RobMaxMaterials[11];

new g_iThief_RobRifleChance[11];

new g_iThief_MinRobReward[11];
new g_iThief_MaxRobReward[11];

new Handle:Array_ItemIds;
new Handle:Array_MaterialItemIds;
new Handle:Trie_Cooldown;

new Handle:hTimer_CraftWeapon[MAXPLAYERS+1];
new Handle:hTimer_RobShop[MAXPLAYERS+1];

new g_iShopNPC;
new g_iMaterialNPC;
new g_iWeaponCategory;
new g_iMaterialCategory;
new g_iCrafterJob = -1;

new g_iThiefJob = -1;
new Float:g_fNPCNextRob[4096];
new Float:g_fNextBountyMessage[MAXPLAYERS+1]
new bool:g_bNPCBeingRobbed[4096];


new Handle:Trie_WeaponsShopEco;

public RP_OnEcoLoaded()
{
	
	Trie_WeaponsShopEco = RP_GetEcoTrie("Weapons Shop");
	
	if(Trie_WeaponsShopEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Weapons Shop");
		
	new String:TempFormat[64];

	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "CRAFTER_MAX_MATERIALS_LVL_#%i", i);
		
		if(!GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat)))
			break;
			
		g_iCrafter_MaxMaterials[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "JOB_NAME_LVL_#%i", i);
		
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		FormatEx(g_szLevels[i], sizeof(g_szLevels[]), TempFormat);
		
		FormatEx(Key, sizeof(Key), "THIEF_ROB_ITEMS_LVL_#%i", i);
		
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iThief_RobItems[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "THIEF_ROB_MAX_MATERIALS_LVL_#%i", i);
		
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iThief_RobMaxMaterials[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "THIEF_ROB_RIFLE_CHANCE_LVL_#%i", i);
		
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iThief_RobRifleChance[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "THIEF_ROB_MIN_REWARD_LVL_#%i", i);
		
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iThief_MinRobReward[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "THIEF_ROB_MAX_REWARD_LVL_#%i", i);
		
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iThief_MaxRobReward[i] = StringToInt(TempFormat);
		
		i++;
	}
	
	i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "MATERIAL_NAME_#%i", i);
		
		new String:MaterialName[32], String:MaterialShortName[8], MaterialPrice;
		
		if(!GetTrieString(Trie_WeaponsShopEco, Key, MaterialName, sizeof(MaterialName)))
			break;
		
		FormatEx(Key, sizeof(Key), "MATERIAL_SHORTNAME_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, MaterialShortName, sizeof(MaterialShortName));
		
		FormatEx(Key, sizeof(Key), "MATERIAL_PRICE_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		MaterialPrice = StringToInt(TempFormat);	
		
		g_MaterialItems[i].MaterialName = MaterialName;
		g_MaterialItems[i].MaterialShortName = MaterialShortName;
		g_MaterialItems[i].MaterialPrice = MaterialPrice;
		
		i++;
	}
	
	i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "WEAPON_NAME_#%i", i);
		
		new String:WeaponName[32], String:WeaponShortName[8], String:WeaponClassname[32], WeaponPrice,
		WoodCost, MetalCost, IronCost, CraftProfit, bool:isRifle;
		
		if(!GetTrieString(Trie_WeaponsShopEco, Key, WeaponName, sizeof(WeaponName)))
			break;
		
		FormatEx(Key, sizeof(Key), "WEAPON_SHORTNAME_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, WeaponShortName, sizeof(WeaponShortName));

		FormatEx(Key, sizeof(Key), "WEAPON_CLASSNAME_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, WeaponClassname, sizeof(WeaponClassname));
		
		FormatEx(Key, sizeof(Key), "WEAPON_PRICE_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		WeaponPrice = StringToInt(TempFormat);	
		
		FormatEx(Key, sizeof(Key), "WEAPON_WOOD_COST_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		WoodCost = StringToInt(TempFormat);	
		
		FormatEx(Key, sizeof(Key), "WEAPON_METAL_COST_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		MetalCost = StringToInt(TempFormat);	
		
		FormatEx(Key, sizeof(Key), "WEAPON_IRON_COST_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		IronCost = StringToInt(TempFormat);	
		
		FormatEx(Key, sizeof(Key), "WEAPON_CRAFT_PROFIT_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		CraftProfit = StringToInt(TempFormat);	
		
		FormatEx(Key, sizeof(Key), "WEAPON_IS_RIFLE_#%i", i);
		GetTrieString(Trie_WeaponsShopEco, Key, TempFormat, sizeof(TempFormat));
		
		isRifle = view_as<bool>(StringToInt(TempFormat));	
		
		g_ShopItems[i].WeaponName = WeaponName;
		g_ShopItems[i].WeaponShortName = WeaponShortName;
		g_ShopItems[i].WeaponClassname = WeaponClassname;
		g_ShopItems[i].WeaponPrice = WeaponPrice;
		g_ShopItems[i].WoodCost = WoodCost;
		g_ShopItems[i].MetalCost = MetalCost;
		g_ShopItems[i].IronCost = IronCost;
		g_ShopItems[i].CraftProfit = CraftProfit;
		g_ShopItems[i].isRifle = isRifle;
		g_ShopItems[i].StockAmount = 3;
		
		i++;
	}

	GetTrieString(Trie_WeaponsShopEco, "COOLDOWN_BETWEEN_CRAFTS", TempFormat, sizeof(TempFormat));
	
	COOLDOWN_BETWEEN_CRAFTS = StringToInt(TempFormat);	
	
	GetTrieString(Trie_WeaponsShopEco, "TIME_TO_BUILD_WEAPON", TempFormat, sizeof(TempFormat));
	
	TIME_TO_BUILD_WEAPON = StringToInt(TempFormat);

	GetTrieString(Trie_WeaponsShopEco, "WEAPON_SELL_MULTIPLIER", TempFormat, sizeof(TempFormat));
	
	WEAPON_SELL_MULTIPLIER = StringToFloat(TempFormat);	
	
	GetTrieString(Trie_WeaponsShopEco, "WEP_STORE_ROB_TIME", TempFormat, sizeof(TempFormat));
	
	WEP_STORE_ROB_TIME = StringToInt(TempFormat);	
	
	GetTrieString(Trie_WeaponsShopEco, "WEP_STORE_ROB_KARMA", TempFormat, sizeof(TempFormat));
	
	WEP_STORE_ROB_KARMA = StringToInt(TempFormat);	
	
	GetTrieString(Trie_WeaponsShopEco, "WEP_STORE_MAX_KARMA", TempFormat, sizeof(TempFormat));
	
	WEP_STORE_MAX_KARMA = StringToInt(TempFormat);	
	
	GetTrieString(Trie_WeaponsShopEco, "MIN_PLAYERS_ROB", TempFormat, sizeof(TempFormat));
	
	MIN_PLAYERS_ROB = StringToInt(TempFormat);	
	
	GetTrieString(Trie_WeaponsShopEco, "ROB_COOLDOWN", TempFormat, sizeof(TempFormat));
	
	ROB_COOLDOWN = StringToFloat(TempFormat);	
	
	GetTrieString(Trie_WeaponsShopEco, "ROB_FAIL_COOLDOWN", TempFormat, sizeof(TempFormat));
	
	ROB_FAIL_COOLDOWN = StringToFloat(TempFormat);	

	g_iWeaponCategory = RP_AddCategory("Weapons");
	
	for(i=0;i < sizeof(g_ShopItems);i++)
	{
		if(g_ShopItems[i].WeaponName[0] == EOS)
			break;
			
		new item = RP_CreateItem(g_ShopItems[i].WeaponName, g_ShopItems[i].WeaponShortName);
		RP_SetItemCategory(item, g_iWeaponCategory);
		PushArrayCell(Array_ItemIds, item);
	}
	
	g_iMaterialCategory = RP_AddCategory("Materials");
	
	for(i=0;i < sizeof(g_MaterialItems);i++)
	{
		if(g_MaterialItems[i].MaterialName[0] == EOS)
			break;
			
		new item = RP_CreateItem(g_MaterialItems[i].MaterialName, g_MaterialItems[i].MaterialShortName);
		RP_SetItemCategory(item, g_iMaterialCategory);
		PushArrayCell(Array_MaterialItemIds, item);
	}
}

public OnMapStart()
{
	for(new i=0;i < sizeof(g_fNextBountyMessage);i++)
		g_fNextBountyMessage[i] = 0.0;
		
	for(new i=0;i < sizeof(g_fNPCNextRob);i++)
		g_fNPCNextRob[i] = 0.0;
		
	for(new i=0;i < sizeof(g_bNPCBeingRobbed);i++)
		g_bNPCBeingRobbed[i] = false;
	
	for(new i=0;i < sizeof(hTimer_CraftWeapon);i++)
		hTimer_CraftWeapon[i] = INVALID_HANDLE;

	for(new i=0;i < sizeof(hTimer_RobShop);i++)
		hTimer_RobShop[i] = INVALID_HANDLE;
		
	LoadDirOfModels("models/player/custom_player/kuristaja/l4d2/ellis");
	LoadDirOfModels("materials/models/player/kuristaja/l4d2/ellis");
	PrecacheModel("models/player/custom_player/kuristaja/l4d2/ellis/ellisv2.mdl", true);
	
	LoadDirOfModels("materials/models/player/voikanaa/gtaiv/niko");
	PrecacheModel("models/player/custom_player/voikanaa/gtaiv/niko.mdl", true);
}
public OnPluginStart()
{
	Array_ItemIds = CreateArray(1);
	Array_MaterialItemIds = CreateArray(1);
	
	Trie_Cooldown = CreateTrie();
	
	if(RP_GetEcoTrie("Weapons Shop") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public void fuckZones_OnStartTouchZone_Post(int client, int entity, const char[] zoneName, int type)
{
	if(StrContains(zoneName, "FailRob", false) != -1)
	{
		if(hTimer_RobShop[client] != INVALID_HANDLE)
			TriggerTimer(hTimer_RobShop[client]);
	}
}

public OnClientDisconnect(client)
{
	if(hTimer_CraftWeapon[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_CraftWeapon[client]);
		hTimer_CraftWeapon[client] = INVALID_HANDLE;
	}
	if(hTimer_RobShop[client] != INVALID_HANDLE)
	{
		TriggerTimer(hTimer_RobShop[client], true);
		
		hTimer_RobShop[client] = INVALID_HANDLE;
	}
	
	g_fNextBountyMessage[client] = 0.0;
}

public OnClientPutInServer(client)
{
	g_fNextBountyMessage[client] = 0.0;
}
public OnClientPostAdminCheck(client)
{
	new String:AuthId[35], dummy_value;
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	if(!GetTrieValue(Trie_Cooldown, AuthId, dummy_value))
		SetTrieValue(Trie_Cooldown, AuthId, 0);
}


public OnUseNPC(client, id, entity)
{
	if(g_iThiefJob == -1)
		g_iThiefJob = RP_FindJobByShortName("TH");
			
	if (g_iShopNPC == id)
	{
		ShowShopCategoriesMenu(client, entity);
	}
	else if(g_iMaterialNPC == id)
	{
		ShowMaterialMenu(client, entity);
	}
}

public bool:UpdateJobStats(client, job)
{
	if(job == -1)
		return false;
		
	new level = RP_GetClientLevel(client, g_iCrafterJob);
	
	if (job == g_iCrafterJob)
	{
		if (GetClientTeam(client) != CS_TEAM_T)
		{
			CS_SwitchTeam(client, CS_TEAM_T);
			CS_RespawnPlayer(client);
			
			return false; // Return because UpdateJobStats is called upon respawning.
		}
		
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iCrafterJob, model, sizeof(model));

		if(model[0] != EOS)
			SetEntityModel(client, model);
		
		CS_SetClientClanTag(client, "Weapon Crafter");
		RP_SetClientJobName(client, g_szLevels[RP_GetClientLevel(client, g_iCrafterJob)]);
			
		switch (level)
		{
			case 0:
			{
			}
			case 1:
			{
				RP_GivePlayerItem(client, "weapon_glock");
			}

			case 2, 3:
			{
				RP_GivePlayerItem(client, "weapon_deagle");
			}
			case 4, 5:
			{
			
				RP_GivePlayerItem(client, "weapon_deagle");
				
				RP_GivePlayerItem(client, "weapon_mp9");
			}
			case 6:
			{
				RP_GivePlayerItem(client, "weapon_deagle");

					
				RP_GivePlayerItem(client, "weapon_ump45");
			
			}
			case 7, 8:
			{
				RP_GivePlayerItem(client, "weapon_deagle");
			
				RP_GivePlayerItem(client, "weapon_p90");
			}
			case 9, 10:
			{
				RP_GivePlayerItem(client, "weapon_deagle");
			
				RP_GivePlayerItem(client, "weapon_ak47");
				
				RP_GivePlayerItem(client, "weapon_tagrenade");
			}
		}
		
		if(level >= 4)
			SetClientArmor(client, 100);
			
		if(level >= 6)
			SetClientHelmet(client, true);
	}
	
	if(level >= 8 && GetRandomInt(1, 100) <= 10)
	{
		new weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
		
		if(weapon != -1)
			RemovePlayerItem(client, weapon);
			
		RP_GivePlayerItem(client, "weapon_awp");
	}	
	if(level >= 5 && GetRandomInt(1, 100) <= 5)
	{
		new weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);
		
		if(weapon != -1)
			RemovePlayerItem(client, weapon);
			
		RP_GivePlayerItem(client, "weapon_awp");
	}
	return false;
}

public Frame_GiveLessAmmoGlock(client)
{
	if(!IsClientInGame(client)) // In a single frame a client can only get invalidated, not replaced.
		return;
		
	Client_GiveWeaponAndAmmo(client, "weapon_glock", false, 0, -1, 10, -1);
}

ShowShopCategoriesMenu(client, entity)
{
	new String:szEntityId[8];
	IntToString(entity, szEntityId, 5);
	
	new Handle:menu = CreateMenu(MenuHandler_ShopCategoriesMenu);
	RP_SetMenuTitle(menu, "Weapon Shop Menu\n● Bank cash: $%i\n ", GetClientCash(client, BANK_CASH));
	
	AddMenuItem(menu, szEntityId, "Rifles");
	AddMenuItem(menu, szEntityId, "Pistols");
	
	new level = RP_GetClientLevel(client, g_iThiefJob);
	
	if(GetPlayerCount() >= MIN_PLAYERS_ROB)
	{
		if(RP_GetClientJob(client) == g_iThiefJob)
		{
			new count = g_iThief_RobItems[level];
			new minLevel = MAX_INTEGER;
			
			if(count == 0)
			{
				for(new i=level+1;i < sizeof(g_iThief_RobItems);i++)
				{
					count = g_iThief_RobItems[i];
					
					if(count > 0)
					{
						minLevel = i;
						break;
					}
				}
				
				new String:TempFormat[64];
				FormatEx(TempFormat, sizeof(TempFormat), "ROB THE STORE [ Level %i ]", minLevel);
				
				AddMenuItem(menu, szEntityId, TempFormat, ITEMDRAW_DISABLED);
			}
			else
			{
				if(g_fNPCNextRob[entity] <= GetGameTime())
					AddMenuItem(menu, szEntityId, "ROB THE STORE");
					
				else
				{
					new String:TempFormat[64];
					FormatEx(TempFormat, sizeof(TempFormat), "ROB THE STORE [%.1fm]", (g_fNPCNextRob[entity] - GetGameTime()) / 60.0);
					
					AddMenuItem(menu, szEntityId, TempFormat, ITEMDRAW_DISABLED);
				}
			}
		}
		else
			AddMenuItem(menu, szEntityId, "ROB THE STORE [Thief]", ITEMDRAW_DISABLED);
	}
	else
	{
		new String:TempFormat[64];
		
		FormatEx(TempFormat, sizeof(TempFormat), "ROB THE STORE [Min. %i Players]", MIN_PLAYERS_ROB);
		AddMenuItem(menu, szEntityId, TempFormat, ITEMDRAW_DISABLED);
	}	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public MenuHandler_ShopCategoriesMenu(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId, 10);
		
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
		}
		else
		{
			if(key == 2)
			{
				if(RP_GetClientJob(client) == g_iThiefJob)
				{
					if(g_bNPCBeingRobbed[entity])
						RP_PrintToChat(client, "Someone else is robbing this shop. Shoot him to replace him");
						
					else
						RobWeaponShop(client, entity);
				}
			}
			else
				ShowShopMenu(client, !key, entity);
		}
	}
}

RobWeaponShop(client, entity)
{
	if(GetPlayerCount() < MIN_PLAYERS_ROB)
		return;
		
	new totalKarma = RP_GetKarma(client) + WEP_STORE_ROB_KARMA;
	
	if(totalKarma > WEP_STORE_MAX_KARMA)
		totalKarma = WEP_STORE_MAX_KARMA;
	
	if(totalKarma > RP_GetKarma(client))
		RP_SetKarma(client, totalKarma, true);
		
	if(hTimer_RobShop[client] != INVALID_HANDLE)
	{
		RP_PrintToChat(client, "You are already robbing a store");
		return;
	}
	
	g_bNPCBeingRobbed[entity] = true;
	
	new Handle:DP;
	hTimer_RobShop[client] = CreateDataTimer(1.0, Timer_RobWeaponStore, DP, TIMER_FLAG_NO_MAPCHANGE);
	
	WritePackCell(DP, GetClientUserId(client));
	WritePackCell(DP, entity);
	WritePackCell(DP, WEP_STORE_ROB_TIME);
}

public Action:Timer_RobWeaponStore(Handle:hTimer, Handle:DP)
{
	ResetPack(DP);
	
	new client = GetClientOfUserId(ReadPackCell(DP));
	new entity = ReadPackCell(DP);
	new TimeLeft = ReadPackCell(DP);
	
	TimeLeft--;
	
	if(client == 0)
	{
		g_bNPCBeingRobbed[entity] = false;
		return;
	}
	hTimer_RobShop[client] = INVALID_HANDLE;
	
	if (CheckDistance(client, entity) > 512.0)
	{
		RP_PrintToChat(client, "You are too far away from this NPC!");
		
		g_bNPCBeingRobbed[entity] = false;
		
		return;
	}
	
	else if(Zone_IsClientInZone(client, "FailRob", false))
	{
		RP_PrintToChat(client, "You cannot rob while being here!");
		
		g_bNPCBeingRobbed[entity] = false;
		
		return;
	}
	
	else if(!IsPlayerAlive(client))
	{
		RP_PrintToChat(client, "Store robbery stopped because you died!");
		
		g_fNPCNextRob[entity] = GetGameTime() + ROB_FAIL_COOLDOWN;
		
		g_bNPCBeingRobbed[entity] = false;
		
		if(RP_GetClientLevel(client, g_iThiefJob) >= 10)
		{
			RP_SetKarma(client, 0, true);
			RP_UnJailClient(client);
		}
		
		return;
	}
	
	else if(g_fNPCNextRob[entity] > GetGameTime())
	{
		RP_PrintToChat(client, "Store robbery stopped someone else robbed it!");
		
		g_bNPCBeingRobbed[entity] = false;
		
		return;
	}
	
	else if(TimeLeft > 0)
	{
		new Handle:MimicDP;
		hTimer_RobShop[client] = CreateDataTimer(1.0, Timer_RobWeaponStore, MimicDP, TIMER_FLAG_NO_MAPCHANGE);
		
		WritePackCell(MimicDP, GetClientUserId(client));
		WritePackCell(MimicDP, entity);
		WritePackCell(MimicDP, TimeLeft);
		
		PrintHintText(client, "You are bounty!!!\nRobbing Weapon Store! Will complete in %i seconds.\nDo not go away from the NPC or it will fail!", TimeLeft);
		
		return;
	}
	
	new level = RP_GetClientLevel(client, g_iThiefJob);
	
	new award = GetRandomInt(g_iThief_MinRobReward[level], g_iThief_MaxRobReward[level]);
	
	award = GiveClientCash(client, POCKET_CASH, award);
	
	RP_PrintToChat(client, "You have successfully robbed the store! Robbed $%i!", award);
	
	Handle GoodList = CreateArray(1);
	
	int[] RifleList = new int[sizeof(g_ShopItems)];
	int[] PistolList = new int[sizeof(g_ShopItems)];
	
	int rifleSize;
	int pistolSize;
	
	for(new i=0;i < sizeof(g_ShopItems);i++)
	{
		if(g_ShopItems[i].WeaponName[0] == EOS)
			break;
			
		if(g_ShopItems[i].maxCost() > g_iThief_RobMaxMaterials[level])
			continue;
			
		if(g_ShopItems[i].isRifle)
			RifleList[rifleSize++] = i;

		else
			PistolList[pistolSize++] = i;
	}
	
	for(new i=0;i < g_iThief_RobItems[level];i++)
	{
		new bool:isRifle = false;

		new TotalChance = g_iThief_RobRifleChance[level];
						
		TotalChance += Get_User_Luck_Bonus(client);
						
		if(TotalChance >= GetRandomInt(1, 100))
			isRifle = true;
			
		if(isRifle)
		{	
			PushArrayCell(GoodList, RifleList[GetRandomInt(0, rifleSize-1)]);
		}
		else
		{
			PushArrayCell(GoodList, PistolList[GetRandomInt(0, pistolSize-1)]);
		}
	}
	
	new String:FormatGoods[512];
	
	FormatEx(FormatGoods, sizeof(FormatGoods), "Robbery successful! Looted items:\n");
	
	new Handle:GoodListCopy = CloneArray(GoodList);
	
	new bool:nLine = false;
	

	for(new i=0;i < GetArraySize(GoodListCopy);i++)
	{
		new key = GetArrayCell(GoodListCopy, i);
		
		new count = 0;
		
		for(new a=0;a < GetArraySize(GoodListCopy);a++)
		{
			if(GetArrayCell(GoodListCopy, a) == key)
			{
				RemoveFromArray(GoodListCopy, a);
				a--;
				count++;
			}
		}
		
		Format(FormatGoods, sizeof(FormatGoods), "%s%ix %s%s", FormatGoods, count, g_ShopItems[key].WeaponName, nLine ? "\n" : ", ");
		
		nLine = !nLine;
		
		i--;
	}
	
	for(new i=0;i < GetArraySize(GoodList);i++)
	{
		RP_GiveItem(client, GetArrayCell(Array_ItemIds, GetArrayCell(GoodList, i)));
	}
	
	PrintHintText(client, FormatGoods);
	
	RP_AddClientEXP(client, g_iThiefJob, 20);

	g_fNPCNextRob[entity] = GetGameTime() + ROB_COOLDOWN;
	
	g_fNextBountyMessage[client] = GetGameTime() + 7.5;
	
	CloseHandle(GoodList);
	CloseHandle(GoodListCopy);
	
	g_bNPCBeingRobbed[entity] = false;
}

public Action:RolePlay_ShouldSeeBountyMessage(client)
{
	if(hTimer_RobShop[client] != INVALID_HANDLE)
	{
		//PrintToConsoleEyal("%N failed see bounty for rob weapons", client);
		return Plugin_Handled;
	}	
	else if(hTimer_CraftWeapon[client] != INVALID_HANDLE)
	{
		//PrintToConsoleEyal("%N failed see bounty for craft weapons", client);
		return Plugin_Handled;
	}
	else if(g_fNextBountyMessage[client] > GetGameTime())
	{
		//PrintToConsoleEyal("%N failed see bounty for next bounty weapons", client);
		return Plugin_Handled;
	}	
	return Plugin_Continue;
}


public RP_OnPlayerMenu(client, target, &Menu:menu, priority)
{
	if(priority != PRIORITY_ASSISTBOUNTY)
		return;
		
	if (RP_GetClientJob(target) == g_iThiefJob)
	{
		if(hTimer_RobShop[target] != INVALID_HANDLE && RP_GetKarma(target) >= BOUNTY_KARMA && Are_Users_Same_Gang(client, target))
		{
			new String:szFormatex[64];
			FormatEx(szFormatex, 64, "Assist Bounty");
			AddMenuItem(menu, MENUINFO_ASSISTBOUNTY, szFormatex);
		}
	}
}

public RP_OnMenuPressed(client, target, const String:info[])
{
	if(StrEqual(info, MENUINFO_ASSISTBOUNTY))
	{

		if(g_iThiefJob == RP_GetClientJob(target))
		{
			if (CheckDistance(client, target) > 150.0)
			{
				RP_PrintToChat(client, "You are too far away!");
			}
			
			else if(hTimer_RobShop[target] == INVALID_HANDLE)
			{
				RP_PrintToChat(client, "Bounty is no longer robbing the shop.");
			}
			else if(!IsPlayerAlive(client))
			{
				RP_PrintToChat(client, "You cannot assist a bounty if you are dead.");
			}
			
			else if(RP_GetKarma(target) <= BOUNTY_KARMA)
			{
				RP_PrintToChat(client, "You cannot assist a non-bounty.");
			}
			else
			{
				RP_SetKarma(client, RP_GetKarma(target), true);
				
				if(GetClientTeam(client) == CS_TEAM_CT)
				{
					RP_DismissAsCop(client);
				}
			}
		}
		else
			RP_PrintToChat(client, "Bounty is not a thief.");
	}
}

ShowShopMenu(client, bool:Rifles, entity)
{
	g_iLastNPC[client] = entity;
	
	new String:szMenuItem[64];
	new String:Info[32];
	new Handle:menu = CreateMenu(MenuHandler_ShopMenu);
	RP_SetMenuTitle(menu, "Weapon Shop Menu\n● Bank Cash: $%i\n ", GetClientCash(client, BANK_CASH));
	
	for(new i=0;i < sizeof(g_ShopItems);i++)
	{
		if(g_ShopItems[i].WeaponName[0] == EOS)
			break;
			
		else if(g_ShopItems[i].WeaponPrice <= 0)
			continue;
			
		else if(g_ShopItems[i].isRifle != Rifles)
			continue;
		
		FormatEx(Info, sizeof(Info), "%i,%i", entity, i);
		
		FormatEx(szMenuItem, 64, "%s [Stock: %i][∑%i]", g_ShopItems[i].WeaponName, g_ShopItems[i].StockAmount, RP_CountPlayerItems(client, GetArrayCell(Array_ItemIds, i)));
		AddMenuItem(menu, Info, szMenuItem);
	}
	
	SetMenuExitBackButton(menu, true);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public MenuHandler_ShopMenu(Menu:menu, MenuAction:action, client, item)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if(action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		ShowShopCategoriesMenu(client, g_iLastNPC[client]);
	}
	else if (action == MenuAction_Select)
	{
		new String:Info[32];
		new String:params[2][32];
		GetMenuItem(menu, item, Info, sizeof(Info));
		
		ExplodeString(Info, ",", params, 2, 16, false);
		
		new key = StringToInt(params[1]);
		
		
		new entity = StringToInt(params[0], 10);
		
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
		}
		else
		{
			ShowWeaponInfoMenu(client, key, entity);
		}
	}
}

ShowWeaponInfoMenu(client, key, entity)
{
	g_bLastRifle[client] = g_ShopItems[key].isRifle;
	g_iLastNPC[client] = entity;
	
	new String:szMenuItem[64];
	new String:Info[11];
	new String:szEntityId[8];
	IntToString(entity, szEntityId, 5);
	IntToString(key, Info, sizeof(Info));
	
	new WoodItem = GetArrayCell(Array_MaterialItemIds, 0);
	new MetalItem = GetArrayCell(Array_MaterialItemIds, 1);
	new IronItem = GetArrayCell(Array_MaterialItemIds, 2);
	
	new Handle:menu = CreateMenu(MenuHandler_WeaponInfoMenu);
	RP_SetMenuTitle(menu, "Weapon Shop Menu\n● Bank Cash: $%i\nCraft %s:\nWood: %i/%i\nMetal: %i/%i\nIron: %i/%i", GetClientCash(client, BANK_CASH), g_ShopItems[key].WeaponName, RP_CountPlayerItems(client, WoodItem), g_ShopItems[key].WoodCost, RP_CountPlayerItems(client, MetalItem), g_ShopItems[key].MetalCost, RP_CountPlayerItems(client, IronItem), g_ShopItems[key].IronCost);
	
	new item = GetArrayCell(Array_ItemIds, key);
			
	FormatEx(szMenuItem, sizeof(szMenuItem), "Buy for $%i [In Stock: %i]", g_ShopItems[key].WeaponPrice, g_ShopItems[key].StockAmount);
	AddMenuItem(menu, szEntityId, szMenuItem, g_ShopItems[key].StockAmount > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	FormatEx(szMenuItem, sizeof(szMenuItem), "Sell for $%i [Σ%i]", RoundToFloor(float(g_ShopItems[key].WeaponPrice) * WEAPON_SELL_MULTIPLIER), RP_CountPlayerItems(client, item));
	AddMenuItem(menu, Info, szMenuItem, RP_CountPlayerItems(client, item) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	if(RP_GetClientJob(client) == g_iCrafterJob)
	{
		new String:AuthId[35], NextCraft;
		
		if(GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId)))
		{
		
			new bool:result = GetTrieValue(Trie_Cooldown, AuthId, NextCraft);
				
			if(!result || NextCraft <= GetTime())
			{
				FormatEx(szMenuItem, sizeof(szMenuItem), "Craft for $%i", g_ShopItems[key].CraftProfit);
				AddMenuItem(menu, "", szMenuItem, CanCraftWeapon(client, key) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			}
			else
			{
				FormatEx(szMenuItem, sizeof(szMenuItem), "Craft for $%i [ COOLDOWN: %i ]", g_ShopItems[key].CraftProfit, NextCraft - GetTime());
				AddMenuItem(menu, "", szMenuItem, ITEMDRAW_DISABLED);
			}
		}
	}
	else
	{
		FormatEx(szMenuItem, sizeof(szMenuItem), "Craft [Weapon Crafter]");
		AddMenuItem(menu, "", szMenuItem, ITEMDRAW_DISABLED);
	}
	
	SetMenuExitBackButton(menu, true);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}
public MenuHandler_WeaponInfoMenu(Menu:menu, MenuAction:action, client, item)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}

	else if(action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		ShowShopMenu(client, g_bLastRifle[client], g_iLastNPC[client]);
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8], String:szKey[11];
		GetMenuItem(menu, 0, szEntityId, 5);
		GetMenuItem(menu, 1, szKey, sizeof(szKey));
		
		new entity = StringToInt(szEntityId);
		new key = StringToInt(szKey);
		
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this NPC!");
			
			return;
		}
		
		switch(item)
		{
			case 0:
			{
				if (GetClientCash(client, BANK_CASH) < g_ShopItems[key].WeaponPrice)
				{
					RP_PrintToChat(client, "You are missing \x02%i\x01 bank cash to buy the \x04%s!", g_ShopItems[key].WeaponPrice - GetClientCash(client, BANK_CASH), g_ShopItems[key].WeaponName);
					
					return;
				}
				
				else if(RP_CountPlayerItems(client, GetArrayCell(Array_ItemIds, key)) >= MAX_WEAPONS_TO_HOLD_FORMULA(RP_GetClientTotalLevels(client)))
				{
					RP_PrintToChat(client, "Maximum amount of a weapon you can hold is %i! Level up in jobs to increase it.", MAX_WEAPONS_TO_HOLD_FORMULA(RP_GetClientTotalLevels(client)));
					
					return;
				}
				
				else if(g_ShopItems[key].StockAmount <= 0)
				{
					RP_PrintToChat(client, "This weapon is out of stock!");
					
					return;
				}
				
				RP_PrintToChat(client, "You have successfully bought \x02%s\x01 for \x04$%i!", g_ShopItems[key].WeaponName, g_ShopItems[key].WeaponPrice);
				GiveClientCash(client, BANK_CASH, -1 * g_ShopItems[key].WeaponPrice);
				
				RP_GiveItem(client, GetArrayCell(Array_ItemIds, key));
				
				g_ShopItems[key].StockAmount--;
				
				ShowWeaponInfoMenu(client, key, entity);
			}
			
			case 1:
			{
				if(RP_CountPlayerItems(client, GetArrayCell(Array_ItemIds, key)) <= 0)
				{
					RP_PrintToChat(client, "You don't have this weapon in your inventory!");
					
					return;
				}
				
				RP_PrintToChat(client, "You have successfully sold \x02%s\x01 for \x04$%i!", g_ShopItems[key].WeaponName, RoundToFloor(float(g_ShopItems[key].WeaponPrice) * WEAPON_SELL_MULTIPLIER));
				GiveClientCashNoGangTax(client, BANK_CASH, RoundToFloor(float(g_ShopItems[key].WeaponPrice) * WEAPON_SELL_MULTIPLIER));
				
				RP_DeleteItem(client, GetArrayCell(Array_ItemIds, key));
				
				g_ShopItems[key].StockAmount++;
				
				ShowWeaponInfoMenu(client, key, entity);
			}
			
			case 2:
			{
				new String:AuthId[35], NextCraft;
				
				if(!GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId)))
				{
					RP_PrintToChat(client, "Could not authenticate you to find your craft cooldown!");
					
					return;
				}
				
				new bool:result = GetTrieValue(Trie_Cooldown, AuthId, NextCraft);
				
				if(result && NextCraft > GetTime())
				{
					RP_PrintToChat(client, "You have a craft cooldown! You can craft a weapon again in %i seconds!", NextCraft - GetTime());
					
					return;
				}
				else if(!CanCraftWeapon(client, key))
				{
					RP_PrintToChat(client, "You don't have enough materials for this weapon!");
					
					return;
				}
				else if(RP_GetClientJob(client) != g_iCrafterJob)
				{
					RP_PrintToChat(client, "Only Weapon Crafters can craft weapons!");
					
					return;
				}
				
				if(hTimer_CraftWeapon[client] != INVALID_HANDLE)
				{
					CloseHandle(hTimer_CraftWeapon[client]);
					hTimer_CraftWeapon[client] = INVALID_HANDLE;
				}
				new Handle:DP;
				hTimer_CraftWeapon[client] = CreateDataTimer(1.0, Timer_BuildWeapon, DP, TIMER_FLAG_NO_MAPCHANGE);
				
				WritePackCell(DP, GetClientUserId(client));
				WritePackCell(DP, entity);
				WritePackCell(DP, key);
				WritePackCell(DP, TIME_TO_BUILD_WEAPON);
			}
		}
	}
}

public Action:Timer_BuildWeapon(Handle:hTimer, Handle:DP)
{
	ResetPack(DP);
	
	new client = GetClientOfUserId(ReadPackCell(DP));
	new entity = ReadPackCell(DP);
	new key = ReadPackCell(DP);
	new TimeLeft = ReadPackCell(DP);
	
	TimeLeft--;
	
	if(client == 0)
		return;
	
	hTimer_CraftWeapon[client] = INVALID_HANDLE;
	
	if (CheckDistance(client, entity) > 300.0)
	{
		RP_PrintToChat(client, "You are too far away from this NPC!");
		
		return;
	}
	
	else if(!IsPlayerAlive(client))
	{
		RP_PrintToChat(client, "Weapon Crafting stopped because you died!");
		
		return;
	}
	
	else if(!CanCraftWeapon(client, key))
	{
		RP_PrintToChat(client, "You don't have enough materials for this weapon!");
		
		return;
	}
	
	else if(TimeLeft > 0)
	{
		new Handle:MimicDP;
		hTimer_CraftWeapon[client] = CreateDataTimer(1.0, Timer_BuildWeapon, MimicDP, TIMER_FLAG_NO_MAPCHANGE);
		
		WritePackCell(MimicDP, GetClientUserId(client));
		WritePackCell(MimicDP, entity);
		WritePackCell(MimicDP, key);
		WritePackCell(MimicDP, TimeLeft);
		
		PrintHintText(client, "Crafting %s! Will complete in %i seconds.\nDo not go away from the NPC or it will fail!", g_ShopItems[key].WeaponName, TimeLeft);
		
		return;
	}
	
	new String:AuthId[35], NextCraft;
	
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	RP_PrintToChat(client, "You have successfully crafted \x02%s\x01 for \x04$%i!", g_ShopItems[key].WeaponName, g_ShopItems[key].CraftProfit);
				
	GiveClientCash(client, BANK_CASH, g_ShopItems[key].CraftProfit);
	
	g_ShopItems[key].StockAmount++;
	
	new WoodItem = GetArrayCell(Array_MaterialItemIds, 0);
	new MetalItem = GetArrayCell(Array_MaterialItemIds, 1);
	new IronItem = GetArrayCell(Array_MaterialItemIds, 2);
	
	for(new i=0;i < g_ShopItems[key].WoodCost;i++)
		RP_DeleteItem(client, WoodItem);

	for(new i=0;i < g_ShopItems[key].MetalCost;i++)
		RP_DeleteItem(client, MetalItem);
		
	for(new i=0;i < g_ShopItems[key].IronCost;i++)
		RP_DeleteItem(client, IronItem);
	
	if(g_ShopItems[key].isRifle)
		RP_AddClientEXP(client, RP_GetClientJob(client), 15);
		
	else
		RP_AddClientEXP(client, RP_GetClientJob(client), 10);
	
	ShowWeaponInfoMenu(client, key, entity);
	
	NextCraft = GetTime() + COOLDOWN_BETWEEN_CRAFTS;
	
	new level = RP_GetClientLevel(client, g_iCrafterJob);
	
	if(level >= 10)
	{
		NextCraft -= RoundToFloor(float(COOLDOWN_BETWEEN_CRAFTS) * 0.75);
	}
	else if(level >= 7)
	{
		NextCraft -= RoundToFloor(float(COOLDOWN_BETWEEN_CRAFTS) * 0.5);
	}
	
	SetTrieValue(Trie_Cooldown, AuthId, NextCraft);
}

ShowMaterialMenu(client, entity, item=0)
{	
	/*
	if(RP_GetClientJob(client) != g_iCrafterJob)
	{
		RP_PrintToChat(client, "Only Weapon Crafters can buy materials from me.");
		return;
	}
	*/
	new String:szMenuItem[64];
	new String:szEntityId[8];
	IntToString(entity, szEntityId, 5);
	new Handle:menu = CreateMenu(MenuHandler_MaterialMenu);
	RP_SetMenuTitle(menu, "Material Shop Menu\n● Bank cash: $%i\n ", GetClientCash(client, BANK_CASH));
	
	for(new i=0;i < sizeof(g_MaterialItems);i++)
	{
		if(g_MaterialItems[i].MaterialPrice <= 0)
			continue;
			
		FormatEx(szMenuItem, 64, "%s - $%i", g_MaterialItems[i].MaterialName, g_MaterialItems[i].MaterialPrice);
		AddMenuItem(menu, szEntityId, szMenuItem);
	}
	
	new cost = GetBuyMaxMaterialCost(client);
	FormatEx(szMenuItem, 64, "Buy Max - $%i", cost);
	AddMenuItem(menu, szEntityId, szMenuItem, cost > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	cost = GetSellMaxMaterialProfit(client);
	FormatEx(szMenuItem, 64, "Sell Max - $%i", cost);
	AddMenuItem(menu, szEntityId, szMenuItem, cost > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);	

	DisplayMenuAtItem(menu, client, item, MENU_TIME_FOREVER);
}

public MenuHandler_MaterialMenu(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		if(key == sizeof(g_MaterialItems))
		{
			new cost = GetBuyMaxMaterialCost(client);
			
			if (GetClientCash(client, BANK_CASH) < cost)
			{
				RP_PrintToChat(client, "You are missing \x02%i\x01 bank cash to buy the \x04%s!", cost - GetClientCash(client, BANK_CASH), cost);
				
				return;
			}
			
			RP_PrintToChat(client, "You have successfully bought \x02Every material possible\x01 for \x04$%i!", cost);
			
			GiveClientCash(client, BANK_CASH, -1 * cost);
			
			GiveMaxMaterials(client);
		}
		else if(key == sizeof(g_MaterialItems) + 1)
		{
			new profit = GetSellMaxMaterialProfit(client);
			
			RP_PrintToChat(client, "You have successfully sold all your materials for \x04$%i!", profit);
			
			GiveClientCash(client, BANK_CASH, profit);
			
			SellAllMaterials(client);
		}
		else
		{
			new String:szEntityId[8];
			GetMenuItem(menu, key, szEntityId, 5);
			new entity = StringToInt(szEntityId, 10);
			if (CheckDistance(client, entity) > 150.0)
			{
				RP_PrintToChat(client, "You are too far away from this NPC!");
			}
			else
			{
				if (GetClientCash(client, BANK_CASH) < g_MaterialItems[key].MaterialPrice)
				{
					RP_PrintToChat(client, "You are missing \x02%i\x01 bank cash to buy the \x04%s!", g_MaterialItems[key].MaterialPrice - GetClientCash(client, BANK_CASH), g_MaterialItems[key].MaterialName);
					
					return;
				}
				
				else if(RP_CountPlayerItems(client, GetArrayCell(Array_MaterialItemIds, key)) >= g_iCrafter_MaxMaterials[RP_GetClientLevel(client, g_iCrafterJob)])
				{
					RP_PrintToChat(client, "Maximum amount of a material you can hold is %i!", g_iCrafter_MaxMaterials[RP_GetClientLevel(client, g_iCrafterJob)]);
					
					return;
				}
				
				RP_PrintToChat(client, "You have successfully bought \x02%s\x01 for \x04$%i!", g_MaterialItems[key].MaterialName, g_MaterialItems[key].MaterialPrice);
				GiveClientCash(client, BANK_CASH, -1 * g_MaterialItems[key].MaterialPrice);
				
				RP_GiveItem(client, GetArrayCell(Array_MaterialItemIds, key));
				
				ShowMaterialMenu(client, entity, GetMenuSelectionPosition());
			}
		}
	}
}

public Thief_OnItemsSteal(client, target, &Handle:items)
{
	for(new i=0;i < sizeof(g_ShopItems);i++)
	{
		if(g_ShopItems[i].WeaponName[0] == EOS)
			break;
			
		new item = GetArrayCell(Array_ItemIds, i);
		
		if(g_ShopItems[i].WeaponPrice > 0)
		{
			if(RP_CountPlayerItems(client, item) >= MAX_WEAPONS_TO_HOLD_FORMULA(RP_GetClientTotalLevels(client)))
			{
				new pos = -1;
				
				while((pos = FindValueInArray(items, item)) != -1)
				{
					RemoveFromArray(items, pos);
				}
			}
			
			continue;
		}
		
		new pos = -1;
		
		while((pos = FindValueInArray(items, item)) != -1)
		{
			RemoveFromArray(items, pos);
		}
	}
	
	for(new i=0;i < sizeof(g_MaterialItems);i++)
	{
		new item = GetArrayCell(Array_MaterialItemIds, i);
		
		// If thief maxed materials || If victim is crafting
		if(RP_CountPlayerItems(client, item) >= g_iCrafter_MaxMaterials[RP_GetClientLevel(client, g_iCrafterJob)] || hTimer_CraftWeapon[target] != INVALID_HANDLE)
		{
			new pos = -1;
			
			while((pos = FindValueInArray(items, item)) != -1)
			{
				RemoveFromArray(items, pos);
			}
		}
	}
}

public Action:OnItemSent(client, player, item)
{
	new pos = FindValueInArray(Array_ItemIds, item);
		
	if(pos != -1)
	{
		if(g_ShopItems[pos].WeaponPrice > 0)
		{
			if(RP_CountPlayerItems(player, item) >= MAX_WEAPONS_TO_HOLD_FORMULA(RP_GetClientTotalLevels(player)))
			{
				RP_PrintToChat(client, "Target player cannot hold more weapons!");
						
				return Plugin_Handled;
			}
		}
	}
	new category = RP_GetItemCategory(item);
	
	if(category != g_iMaterialCategory)
		return Plugin_Continue;
	
	for(new i=0;i < sizeof(g_MaterialItems);i++)
	{
		new matItem = GetArrayCell(Array_MaterialItemIds, i);
		
		if(item != matItem)
			continue;
			
		else if(RP_CountPlayerItems(player, item) >= g_iCrafter_MaxMaterials[RP_GetClientLevel(player, g_iCrafterJob)])
		{
			RP_PrintToChat(client, "Target player cannot hold more %s!", g_MaterialItems[i].MaterialName);
						
			return Plugin_Handled;
		}
		
		break;
	}
	return Plugin_Continue;
}

public Action:OnItemUsed(client, item)
{
	new category = RP_GetItemCategory(item);
	
	if(category != g_iWeaponCategory)
	{
		if(category == g_iMaterialCategory)
		{
			RP_PrintToChat(client, "Materials cannot be used directly from your inventory");
			return Plugin_Handled;
		}
		return Plugin_Continue;
	}	
	
	new pos = FindValueInArray(Array_ItemIds, item);
	
	if(pos != -1)
	{
		new weapon = GivePlayerItem(client, g_ShopItems[pos].WeaponClassname);
		
		if(weapon == -1)
		{
			weapon = CreateEntityByName("game_player_equip");
		
			DispatchKeyValue(weapon, g_ShopItems[pos].WeaponClassname, "0");
			
			DispatchKeyValue(weapon, "spawnflags", "1");
			
			AcceptEntityInput(weapon, "use", client);
			
			//AcceptEntityInput(weapon, "Kill"); // Could throw errors for deleting -1.
		}
		RP_PrintToChat(client, "You have used your \x02%s!", g_ShopItems[pos].WeaponName);
		
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

public Action:Thief_RequestIdentity(client, const String:JobShortName[], &FakeLevel, String:LevelName[32], String:Model[PLATFORM_MAX_PATH])
{
	if(StrEqual(JobShortName, "WECR", false))
	{
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iCrafterJob, model, sizeof(model));

		if(model[0] != EOS)
			FormatEx(Model, sizeof(Model), model);

		FormatEx(LevelName, sizeof(LevelName), "Weapon Crafter");
		
		FakeLevel = RP_GetClientLevel(client, g_iCrafterJob);
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_NPC", true))
	{
		g_iShopNPC = RP_CreateNPC("models/player/custom_player/kuristaja/l4d2/ellis/ellisv2.mdl", "WEAPONS_SHOP");
		g_iMaterialNPC = RP_CreateNPC("models/player/custom_player/voikanaa/gtaiv/niko.mdl", "MATERIAL_SELLER");
	}
	else if (StrEqual(name, "RolePlay_Jobs", true))
	{
		g_iCrafterJob = RP_CreateJob("Weapon Crafter", "WECR", 11);
	}
}

stock bool:CanCraftWeapon(client, pos)
{
	new WoodItem = GetArrayCell(Array_MaterialItemIds, 0);
	new MetalItem = GetArrayCell(Array_MaterialItemIds, 1);
	new IronItem = GetArrayCell(Array_MaterialItemIds, 2);
	
	if(RP_CountPlayerItems(client, WoodItem) < g_ShopItems[pos].WoodCost)
	{
		return false;
	}
	
	else if(RP_CountPlayerItems(client, MetalItem) < g_ShopItems[pos].MetalCost)
	{
		return false;
	}
	
	else if(RP_CountPlayerItems(client, IronItem) < g_ShopItems[pos].IronCost)
	{
		return false;
	}
	
	return true;
}

stock GetBuyMaxMaterialCost(client)
{
	new TotalCost = 0;
	for(new i=0;i < sizeof(g_MaterialItems);i++)
	{
		if(g_MaterialItems[i].MaterialPrice <= 0)
			continue;
			
		new count = g_iCrafter_MaxMaterials[RP_GetClientLevel(client, g_iCrafterJob)] - RP_CountPlayerItems(client, GetArrayCell(Array_MaterialItemIds, i))
		
		TotalCost += count * g_MaterialItems[i].MaterialPrice;
	}
	
	return TotalCost;
}

stock GiveMaxMaterials(client)
{
	for(new i=0;i < sizeof(g_MaterialItems);i++)
	{
		if(g_MaterialItems[i].MaterialPrice <= 0)
			continue;
			
		new count = g_iCrafter_MaxMaterials[RP_GetClientLevel(client, g_iCrafterJob)] - RP_CountPlayerItems(client, GetArrayCell(Array_MaterialItemIds, i))
		
		for(new c=0;c < count;c++)
		{
			RP_GiveItem(client, GetArrayCell(Array_MaterialItemIds, i));
		}
	}
}


stock GetSellMaxMaterialProfit(client)
{
	new TotalCost = 0;
	for(new i=0;i < sizeof(g_MaterialItems);i++)
	{
		if(g_MaterialItems[i].MaterialPrice <= 0)
			continue;
			
		new count = RP_CountPlayerItems(client, GetArrayCell(Array_MaterialItemIds, i))
		
		TotalCost += RoundToFloor(float(count) * ( float(g_MaterialItems[i].MaterialPrice) * 0.9 ));
	}
	
	return TotalCost;
}

stock SellAllMaterials(client)
{
	for(new i=0;i < sizeof(g_MaterialItems);i++)
	{
		if(g_MaterialItems[i].MaterialPrice <= 0)
			continue;
			
		new count = RP_CountPlayerItems(client, GetArrayCell(Array_MaterialItemIds, i))
		
		for(new c=0;c < count;c++)
		{
			RP_DeleteItem(client, GetArrayCell(Array_MaterialItemIds, i));
		}
	}
}