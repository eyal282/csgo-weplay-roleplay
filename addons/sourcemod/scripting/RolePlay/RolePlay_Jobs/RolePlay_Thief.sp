#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>

new MIN_LEVEL_STEAL_WEAPON = 2147483647;

new Float:STEAL_COOLDOWN = 60.0;
new Float:FAIL_STEAL_COOLDOWN = 60.0;
new Float:WEAPON_STEAL_COOLDOWN = 120.0;
new Float:FAIL_WEAPON_STEAL_COOLDOWN = 120.0;

#define MENUINFO_STEAL "Thief - Steal"
#define MENUINFO_STEALWEAPON "Thief - Steal Weapon"

public Plugin:myinfo =
{
	name = "RolePlay Thief Job",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = "https://steamcommunity.com/id/xflane/"
};

new Handle:g_hItemsSteal;
new Handle:g_hRequestIdentity;

new g_iThiefJob;
new g_iIdentity[MAXPLAYERS+1];
new Float:g_fThiefDelay[66][66];

new String:g_szIdentityShortNames[][] =
{
	"DRUD",
	"LAW",
	"WECR"
}

new String:g_szLevels[11][16];

new g_iStealItems[11];

new g_iStealChance[11];

new g_iWeaponStealChance[11];

new g_iNoWeaponToStealChance[11];

int g_iNoStealItems[64];


new Handle:Trie_ThiefEco;

public RP_OnEcoLoaded()
{
	
	Trie_ThiefEco = RP_GetEcoTrie("Thief");
	
	if(Trie_ThiefEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Thief");
		
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "ITEMS_TO_STEAL_LVL_#%i", i);
		
		if(!GetTrieString(Trie_ThiefEco, Key, TempFormat, sizeof(TempFormat)))
			break;
			
		g_iStealItems[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "JOB_NAME_LVL_#%i", i);
		
		GetTrieString(Trie_ThiefEco, Key, TempFormat, sizeof(TempFormat));
		
		FormatEx(g_szLevels[i], sizeof(g_szLevels[]), TempFormat);
		
		FormatEx(Key, sizeof(Key), "STEAL_CHANCE_LVL_#%i", i);
		
		GetTrieString(Trie_ThiefEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iStealChance[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "WEAPON_STEAL_CHANCE_LVL_#%i", i);
		
		GetTrieString(Trie_ThiefEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iWeaponStealChance[i] = StringToInt(TempFormat);
		
		if(MIN_LEVEL_STEAL_WEAPON > i && g_iWeaponStealChance[i] > 0.0)
			MIN_LEVEL_STEAL_WEAPON = i;
			
		FormatEx(Key, sizeof(Key), "NO_WEAPONS_TO_STEAL_CHANCE_LVL_#%i", i);
		
		GetTrieString(Trie_ThiefEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iNoWeaponToStealChance[i] = StringToInt(TempFormat);
		
		i++;
	}
	
	
	GetTrieString(Trie_ThiefEco, "STEAL_COOLDOWN", TempFormat, sizeof(TempFormat));
	
	STEAL_COOLDOWN = StringToFloat(TempFormat);
	
	GetTrieString(Trie_ThiefEco, "FAIL_STEAL_COOLDOWN", TempFormat, sizeof(TempFormat));
	
	FAIL_STEAL_COOLDOWN = StringToFloat(TempFormat);	
	
	GetTrieString(Trie_ThiefEco, "WEAPON_STEAL_COOLDOWN", TempFormat, sizeof(TempFormat));
	
	WEAPON_STEAL_COOLDOWN = StringToFloat(TempFormat);	
	
	GetTrieString(Trie_ThiefEco, "FAIL_WEAPON_STEAL_COOLDOWN", TempFormat, sizeof(TempFormat));
	
	FAIL_WEAPON_STEAL_COOLDOWN = StringToFloat(TempFormat);	
	
	i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "NO_STEAL_ITEMS_#%i", i);
		
		if(!GetTrieString(Trie_ThiefEco, Key, TempFormat, sizeof(TempFormat)))
			break;

		g_iNoStealItems[i] = RP_GetItemId(TempFormat);

		i++;
	}
}

public OnPluginStart()
{
	g_hItemsSteal = CreateGlobalForward("Thief_OnItemsSteal", ET_Ignore, Param_Cell, Param_Cell, Param_CellByRef);
	g_hRequestIdentity = CreateGlobalForward("Thief_RequestIdentity", ET_Event, Param_Cell, Param_String, Param_CellByRef, Param_String, Param_String);
	
	LoadTranslations("common.phrases");
	
	RegAdminCmd("sm_isthief", Command_IsThief, ADMFLAG_CONVARS);
	
	if(RP_GetEcoTrie("Thief") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}


public Thief_OnItemsSteal(client, target, &Handle:items)
{
	for(new i=0;i < sizeof(g_iNoStealItems);i++)
	{
		int item = g_iNoStealItems[i];
		
		int pos;
		
		while((pos = FindValueInArray(items, item)) != -1)
		{
			RemoveFromArray(items, pos);
		}
	}
}
public Action:Command_IsThief(client, args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_isthief <#userid|name>");
		return Plugin_Handled;
	}
	
	new String:Args[64];
	
	GetCmdArgString(Args, sizeof(Args));
	
	StripQuotes(Args);
	
	new target = FindTarget(client, Args, false, false);
	
	if(target <= 0)
		return Plugin_Handled;
		
	RP_PrintToChat(client, "%N is %sa thief", target, RP_GetClientJob(target) == g_iThiefJob ? " " : " NOT ");
	return Plugin_Handled;
}

public RP_OnPlayerMenu(client, target, &Menu:menu, priority)
{
	if(priority != PRIORITY_THIEF)
		return;
	
	else if(RP_IsClientInJail(client))
		return;
		
	if (g_iThiefJob == RP_GetClientJob(client))
	{
		if (g_fThiefDelay[client][target] > GetGameTime())
		{
			new String:szFormatex[64];
			FormatEx(szFormatex, 64, "Steal Items [%.1f Cooldown]", g_fThiefDelay[client][target] - GetGameTime());
			AddMenuItem(menu, MENUINFO_STEAL, szFormatex, ITEMDRAW_DISABLED);
		
			FormatEx(szFormatex, 64, "Steal Weapons [%.1f Cooldown]", g_fThiefDelay[client][target] - GetGameTime());
			
			if(RP_GetClientLevel(client, RP_GetClientJob(client)) >= MIN_LEVEL_STEAL_WEAPON)
				AddMenuItem(menu, MENUINFO_STEALWEAPON, szFormatex, ITEMDRAW_DISABLED);
		}
		else
		{
			AddMenuItem(menu, MENUINFO_STEAL, "Steal Items", ITEMDRAW_DEFAULT);

			if(RP_GetClientLevel(client, g_iThiefJob) >= MIN_LEVEL_STEAL_WEAPON)
				AddMenuItem(menu, MENUINFO_STEALWEAPON, "Steal Weapons [High Fail]", ITEMDRAW_DEFAULT);
		}
	}
}

public RP_OnMenuPressed(client, target, const String:info[])
{
//	new var1;
	if(g_iThiefJob == RP_GetClientJob(client))
	{
		if(StrEqual(info, MENUINFO_STEAL))
		{
			new String:szBuffer[64];
			new String:szIndex[8];
			IntToString(target, szIndex, 6);
			new Handle:menu = CreateMenu(MenuHandler_StealMenu);
			
			RP_SetMenuTitle(menu, "Steal Menu\n Stealing from %N", target);
			AddMenuItem(menu, szIndex, "", 6);
			new item;

			for(new i=0;i < g_iStealItems[RP_GetClientLevel(client, g_iThiefJob)];i++)
			{
				new Handle:items = RP_GetClientItems(target);
				
				new Handle:itemsClone = CloneArray(items); // Used to track memory leak cause.
				
				CloseHandle(items);
				
				Call_StartForward(g_hItemsSteal);
				
				Call_PushCell(client);
				Call_PushCell(target);
				Call_PushCellRef(itemsClone);
				
				Call_Finish();
				
				if(GetArraySize(itemsClone) == 0)
					item = -1;
					
				else
					item = GetArrayCell(itemsClone, GetRandomInt(0, GetArraySize(itemsClone)-1));
				
				CloseHandle(itemsClone);
				
				if (item == -1)
				{
					AddMenuItem(menu, "", "No items to steal.", 1);
					DisplayMenu(menu, client, 0);
					
					return;
				}
				RP_GetItemName(item, szBuffer, 64);
				IntToString(item, szIndex, 6);
				AddMenuItem(menu, szIndex, szBuffer, 0);
			}
			DisplayMenu(menu, client, 0);
		}
		else if(StrEqual(info, MENUINFO_STEALWEAPON))
		{	
			if (CheckDistance(client, target) > 150.0)
			{
				RP_PrintToChat(client, "You are too far away!");
			}
			
			else if(IsClientNoKillZone(client) || IsClientNoKillZone(target))
			{
				RP_PrintToChat(client, "You cannot steal in a no kill zone.");
			}
			
			else if(RP_IsUserInArena(target))
			{
				RP_PrintToChat(client, "You cannot steal in !ja.");
			}
			
			else if(RP_IsUserInDuel(target))
			{
				RP_PrintToChat(client, "You cannot steal in a duel.");
			}
			
			else if(RP_IsClientCuffed(target))
			{
				RP_PrintToChat(client, "You cannot steal from a frozen player.");
			}
			
			else if(g_fThiefDelay[client][target] > GetGameTime())
			{
				RP_PrintToChat(client, "You already stole from this player.");
			}
			
			else if(!IsPlayerAlive(client))
			{
				RP_PrintToChat(client, "You cannot steal if you are dead.");
			}
			else
			{
				new item = -1;
				
				new category = RP_GetCategoryByName("Weapons");
					
				new Handle:items = RP_GetClientItemsByCategory(target, category);
				
				new Handle:itemsClone = CloneArray(items); // Used to track memory leak cause.
				
				CloseHandle(items);
				
				Call_StartForward(g_hItemsSteal);
				
				Call_PushCell(client);
				Call_PushCell(target);
				Call_PushCellRef(itemsClone);

				Call_Finish();
				
				if(GetArraySize(itemsClone) == 0)
					item = -1;
					
				else
					item = GetArrayCell(itemsClone, GetRandomInt(0, GetArraySize(itemsClone)-1));
				
				CloseHandle(itemsClone);
				
				new String:szBuffer[32];
				
				if(item != -1)
				{
					RP_GetItemName(item, szBuffer, 32);
				}
				else
				{
								
					new TotalChance = g_iNoWeaponToStealChance[RP_GetClientLevel(client, g_iThiefJob)];
			
					TotalChance += Get_User_Luck_Bonus(client);
					TotalChance -= Get_User_Luck_Bonus(target);
					
					if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2) || TotalChance >= GetRandomInt(1, 100))
						RP_PrintToChat(client, "You have failed! the player has\x07 no weapons to steal.");
						
					else
					{
						RP_PrintToChat(target, "\x02%N\x01 has tried to steal\x03 WEAPON from you and failed.", client);
						RP_PrintToChat(client, "You have failed! the player caught you stealing\x03 WEAPON.");
						
						g_fThiefDelay[client][target] = GetGameTime() + 2.0;
					}
					return;
				}
				
				new TotalChance = g_iWeaponStealChance[RP_GetClientLevel(client, g_iThiefJob)];
		
				TotalChance += Get_User_Luck_Bonus(client);
				TotalChance -= Get_User_Luck_Bonus(target);
				
				if (TotalChance >= GetRandomInt(1, 100))
				{
					if (RP_CountPlayerItems(target, item))
					{
						RP_DeleteItem(target, item);
						RP_GiveItem(client, item);
						RP_PrintToChat(client, "You have stolen \x02%s\x01 from \x04%N!", szBuffer, target);
						RP_PrintToChat(target, "\x02%N\x01 has stolen \x04%s\x01 from you! haha!", client, szBuffer);
						RP_AddClientEXP(client, g_iThiefJob, 20);
						
						//RP_AddKarma(client, KARMA_PER_WEAPON_STEAL, true, KARMA_STEAL_REASON);
						g_fThiefDelay[client][target] = GetGameTime() + WEAPON_STEAL_COOLDOWN;
						
						if(RP_GetClientLevel(client, g_iThiefJob) >= 7)
							g_fThiefDelay[client][target] -= 30.0;
							
						else if(RP_GetClientLevel(client, g_iThiefJob) >= 7)
							g_fThiefDelay[client][target] -= 5.0;
					}
					
					return;
				}
				RP_PrintToChat(target, "\x02%N\x01 has tried to steal\x03 WEAPON from you and failed.", client);
				RP_PrintToChat(client, "You have failed! the player caught you stealing\x03 WEAPON.\x01 ( %i%%)", TotalChance);
				
				if(RP_GetClientLevel(client, g_iThiefJob) < 7)
					g_fThiefDelay[client][target] = GetGameTime() + FAIL_WEAPON_STEAL_COOLDOWN;
				
				//RP_AddKarma(client, KARMA_PER_FAILED_STEAL, true, KARMA_STEAL_REASON);
			}
		}
	}
}

public MenuHandler_StealMenu(Handle:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		
		return;
	}
	
	else if (action == MenuAction_Select)
	{
		new String:szIndex[8];
		GetMenuItem(menu, 0, szIndex, 6);
		new target = StringToInt(szIndex, 10);
		
		if (CheckDistance(client, target) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away!");
		}
		
		else if(IsClientNoKillZone(client) || IsClientNoKillZone(target))
		{
			RP_PrintToChat(client, "You cannot steal in a no kill zone.");
		}
		
		else if(RP_IsUserInArena(target))
		{
			RP_PrintToChat(client, "You cannot steal in !ja.");
		}
		
		else if(RP_IsUserInDuel(target))
		{
			RP_PrintToChat(client, "You cannot steal in a duel.");
		}
		
		else if(RP_IsClientCuffed(target))
		{
			RP_PrintToChat(client, "You cannot steal from a frozen player.");
		}
		
		else if(g_fThiefDelay[client][target] > GetGameTime())
		{
			RP_PrintToChat(client, "You already stole from this player.");
		}
		
		else if(!IsPlayerAlive(client))
		{
			RP_PrintToChat(client, "You cannot steal if you are dead.");
		}
		else
		{
			GetMenuItem(menu, key, szIndex, 6);
			new item = StringToInt(szIndex, 10);
			
			new String:szBuffer[32];
			RP_GetItemName(item, szBuffer, 32);
			
			new TotalChance = g_iStealChance[RP_GetClientLevel(client, g_iThiefJob)];
			
			TotalChance += Get_User_Luck_Bonus(client);
			TotalChance -= Get_User_Luck_Bonus(target);
			
			if (TotalChance >= GetRandomInt(1, 100))
			{
				if (RP_CountPlayerItems(target, item))
				{
					RP_DeleteItem(target, item);
					RP_GiveItem(client, item);
					RP_PrintToChat(client, "You have stole \x02%s\x01 from \x04%N!", szBuffer, target);
					RP_PrintToChat(target, "\x02%N\x01 has stole \x04%s\x01 from you! haha!", client, szBuffer);
					RP_AddClientEXP(client, g_iThiefJob, 10);
					
					//RP_AddKarma(client, KARMA_PER_STEAL, true, KARMA_STEAL_REASON);
					g_fThiefDelay[client][target] = GetGameTime() + STEAL_COOLDOWN;
				}
				
				return;
			}
			RP_PrintToChat(target, "\x02%N\x01 has tried to steal item from you and failed.", client);
			RP_PrintToChat(client, "You have failed! the player caught you stealing. ( %i%% )", TotalChance);
			
			g_fThiefDelay[client][target] = GetGameTime() + FAIL_STEAL_COOLDOWN;
			//RP_AddKarma(client, KARMA_PER_FAILED_STEAL, true, KARMA_STEAL_REASON);
		}
	}
}

public bool:UpdateJobStats(client, job)
{
	if(job == -1)
		return false;
		
	if (job == g_iThiefJob)
	{
		if (GetClientTeam(client) != 2)
		{
			CS_SwitchTeam(client, 2);
			CS_RespawnPlayer(client);
			
			return false; // Return because UpdateJobStats is called upon respawning.
		}
		
		g_iIdentity[client] = GetRandomInt(0, sizeof(g_szIdentityShortNames)-1);
		
		new String:szIdentity[32];
		new String:szModel[PLATFORM_MAX_PATH];
		new Action:result;
		
		Call_StartForward(g_hRequestIdentity);
		
		new FakeLevel;
		Call_PushCell(client);
		Call_PushString(g_szIdentityShortNames[g_iIdentity[client]]); // example: DRUD, MED, TH...
		Call_PushCellRef(FakeLevel);
		Call_PushStringEx(szIdentity, sizeof(szIdentity), SM_PARAM_STRING_COPY|SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
		Call_PushStringEx(szModel, sizeof(szModel), SM_PARAM_STRING_COPY|SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
		
		Call_Finish(result);
		
		if(result == Plugin_Continue)
		{
			LogError("\n\n\n\n\n\nIdentity not given to thief by identity %s", g_szIdentityShortNames[g_iIdentity[client]]);
			RP_PrintToChat(client, "Couldn't find you fake name as thief ( %s )", g_szIdentityShortNames[g_iIdentity[client]]);
		}
		else
		{
			CS_SetClientClanTag(client, szIdentity);
			SetEntityModel(client, szModel);
		}
		
		RP_SetClientJobName(client, g_szLevels[RP_GetClientLevel(client, g_iThiefJob)]);
		
		new level = RP_GetClientLevel(client, g_iThiefJob);
			
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
				RP_GivePlayerItem(client, "weapon_ump45");
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
			
		if(level >= 10)
		{
			SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 10);
			SetEntityHealth(client, GetClientHealth(client) + 10);
		}
			
	}
	
	return false;
}

public OnClientChangeJobPost(int client, int job, int oldjob, bool:respawn)
{
	if(job == g_iThiefJob && !respawn)
		RP_PrintToChat(client, "Hint! You can go to the market / weapon shop to rob it!");

}

public OnMapStart()
{
	new i = 1;
	while (i <= MaxClients)
	{
		new j = 1;
		while (j <= MaxClients)
		{
			g_fThiefDelay[i][j] = 0.0;
			j++;
		}
		i++;
	}
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_Jobs", true))
	{
		g_iThiefJob = RP_CreateJob("Thief", "TH", 11);
	}
}

