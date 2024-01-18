#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <Eyal-RP>
#include <clientprefs>

#define MENUINFO_HIRELAWYER "Lawyer - Get Out of Jail"
#define MENUINFO_LAWYERHELPGANG "Lawyer - Help gangmate for Free"
#define MENUINFO_LOSEKARMA "Lawyer - Lose Karma"

new EngineVersion:g_Game;

new Float:VIP_LAWYER_XYZ[3];

public Plugin:myinfo =
{
	name = "RolePlay Lawyer Job",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = "https://steamcommunity.com/id/xflane/"
};

new g_iLawyerJob;

new String:g_szLevels[11][16];

new VIP_EXTRA_RELEASE_CHANCE = 20;

new LastLawyerButtons[MAXPLAYERS + 1];
new Float:ExpireAFKGracePeriod[MAXPLAYERS + 1];

new g_iReleaseChance[11];

new minWage[11];

new maxWage[11];

new Handle:cpLawyerWage = INVALID_HANDLE;

new Float:g_fNextLawyer[MAXPLAYERS + 1];

new Handle:Trie_LawyerEco;

public RP_OnEcoLoaded()
{
	
	Trie_LawyerEco = RP_GetEcoTrie("Lawyer");
	
	if(Trie_LawyerEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Lawyer");
		
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "RELEASE_CHANCE_LVL_#%i", i);
		
		if(!GetTrieString(Trie_LawyerEco, Key, TempFormat, sizeof(TempFormat)))
			break;
			
		g_iReleaseChance[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "MIN_WAGE_LVL_#%i", i);
		
		GetTrieString(Trie_LawyerEco, Key, TempFormat, sizeof(TempFormat));
		
		minWage[i] = StringToInt(TempFormat);		
		
		FormatEx(Key, sizeof(Key), "MAX_WAGE_LVL_#%i", i);
		
		GetTrieString(Trie_LawyerEco, Key, TempFormat, sizeof(TempFormat));
		
		maxWage[i] = StringToInt(TempFormat);	
		
		FormatEx(Key, sizeof(Key), "JOB_NAME_LVL_#%i", i);
		
		GetTrieString(Trie_LawyerEco, Key, TempFormat, sizeof(TempFormat));
		
		FormatEx(g_szLevels[i], sizeof(g_szLevels[]), TempFormat);
		
		i++;
	}
	
	GetTrieString(Trie_LawyerEco, "VIP_EXTRA_RELEASE_CHANCE", TempFormat, sizeof(TempFormat));
	
	VIP_EXTRA_RELEASE_CHANCE = StringToInt(TempFormat);	
	
	GetTrieString(Trie_LawyerEco, "VIP_LAWYER_XYZ", TempFormat, sizeof(TempFormat));
	
	StringToVector(TempFormat, VIP_LAWYER_XYZ);	
	
}

public OnPluginStart()
{
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}	
	
	RegConsoleCmd("sm_lawyer", Command_Lawyer, "Allows you to choose the price you take as a lawyer");
	
	cpLawyerWage = RegClientCookie("RolePlay_LawyerWage", "Amount of money you take for getting out of jail when working as a lawyer", CookieAccess_Public);
	
	if(RP_GetEcoTrie("Lawyer") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public OnClientPutInServer(client)
{
	Func_OnClientPutInServer(client)
}
public Func_OnClientPutInServer(client)
{
	ExpireAFKGracePeriod[client] = 0.0;
}


public Action:Command_Lawyer(client, args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_lawyer <cost>");
		
		return Plugin_Handled;
	}
	
	new String:Arg[11];
	GetCmdArg(1, Arg, sizeof(Arg));
	
	new amount = StringToInt(Arg);
	
	new level = RP_GetClientLevel(client, g_iLawyerJob);
	
	if(amount < minWage[level])
	{
		ReplyToCommand(client, "Minimum cost at level %i: $%i.", level, minWage[level]);
		
		return Plugin_Handled;
	}
	else if(amount > maxWage[level])
	{
		ReplyToCommand(client, "Maximum cost at level %i: $%i.", level, maxWage[level]);
		
		return Plugin_Handled;
	}
	
	SetClientLawyerWage(client, amount);
	
	RP_PrintToChat(client, "You now charge $%i when attempting to release a player as a lawyer.", amount);
	
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(client, &buttons)
{
	if(!(buttons == LastLawyerButtons[client]))
		LastLawyerButtons[client] = -1;
}

public RP_OnPlayerMenu(client, target, &Menu:menu, priority)
{
	if(priority != PRIORITY_LAWYER)
		return;
		
	if(RP_GetClientJob(target) == g_iLawyerJob)
	{
		if(RP_IsClientInJail(client) && !RP_IsClientInAdminJail(client) && !RP_IsClientInJail(target))
		{
			new String:szInfo[64];
			
			new wage = GetClientLawyerWage(target);
			
			FormatEx(szInfo, sizeof(szInfo), "%s|||%i", MENUINFO_HIRELAWYER, wage);
			new String:szFormatex[64];
			
			new TotalChance = g_iReleaseChance[RP_GetClientLevel(target, g_iLawyerJob)];
			
			if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
				TotalChance += VIP_EXTRA_RELEASE_CHANCE;
				
			if(!Are_Users_Same_Gang(client, target))
				TotalChance += Get_User_Luck_Bonus(client);
			
			new bool:CanAfford = GetClientCash(client, BANK_CASH) >= wage;
			if (LastLawyerButtons[target] != -1 && ExpireAFKGracePeriod[target] < GetGameTime())
			{
				FormatEx(szFormatex, 64, "Hire Lawyer - $%i [AFK]", wage);
				CanAfford = false;
			}
			else
				FormatEx(szFormatex, 64, "Hire Lawyer - $%i [%i%%]", wage, TotalChance);
			
			AddMenuItem(menu, szInfo, szFormatex, CanAfford ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
		else if(RP_GetClientLevel(target, g_iLawyerJob) >= 3)
		{
			new String:szFormatex[64];
			new bool:higherLevel = RP_GetClientLevel(target, g_iLawyerJob) >= 7;
			
			new karmaLost = higherLevel ? 100 : 50;
			new price = higherLevel ? 700 : 350;
			
			if(g_fNextLawyer[client] <= GetGameTime())
			{
				FormatEx(szFormatex, 64, "Lose %i Karma - $%i", karmaLost, price);
				
				AddMenuItem(menu, MENUINFO_LOSEKARMA, szFormatex, GetClientCash(client, BANK_CASH) >= price && RP_GetKarma(client) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			}
			else
			{
				FormatEx(szFormatex, 64, "Lose %i Karma [Cooldown: %is]", karmaLost, RoundToCeil(g_fNextLawyer[client] - GetGameTime()));
				
				AddMenuItem(menu, MENUINFO_LOSEKARMA, szFormatex, ITEMDRAW_DISABLED);
			}
		}
	}
	if(RP_GetClientJob(client) == g_iLawyerJob && RP_IsClientInJail(target) && !RP_IsClientInAdminJail(target) && !RP_IsClientInJail(client) && Are_Users_Same_Gang(client, target))
	{
		AddMenuItem(menu, MENUINFO_LAWYERHELPGANG, "Help Gang Mate [$0]");
	}
}

public RP_OnMenuPressed(client, target, const String:info[])
{
	new String:params[2][32];
	ExplodeString(info, "|||", params, 2, 32, false);
	
	new wage = StringToInt(params[1]);
	
	if(LastLawyerButtons[target] != -1 && ExpireAFKGracePeriod[target] < GetGameTime())
	{
		RP_PrintToChat(client, "Your lawyer is AFK.");
				
		return;
	}
		
	if(RP_GetClientJob(target) == g_iLawyerJob && StrEqual(params[0], MENUINFO_HIRELAWYER) && RP_IsClientInJail(client) && !RP_IsClientInAdminJail(client))
	{
		if (GetClientCash(client, BANK_CASH) < wage)
		{
			return;
		}
		else if(GetClientLawyerWage(target) != wage)
		{
			RP_PrintToChat(client, "Your lawyer has changed his price. Please try again.");
			return;
		}
		
		GiveClientCash(client, BANK_CASH, -1 * wage);
		new amount = GiveClientCash(target, BANK_CASH, wage);
		
		new TotalChance = g_iReleaseChance[RP_GetClientLevel(target, g_iLawyerJob)];
		
		if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
			TotalChance += VIP_EXTRA_RELEASE_CHANCE;
			
		if(!Are_Users_Same_Gang(client, target))
			TotalChance += Get_User_Luck_Bonus(client);	
		
		if(TotalChance >= GetRandomInt(1, 100))
		{
			RP_UnJailClient(client);
			RP_PrintToChat(client, "\x02%N\x01 helped you and \x04released\x01 you from the jail! You paid $%i!", target, wage);
			RP_PrintToChat(target, "You have helped \x02%N\x01 and released him from the jail! You got $%i!", client, amount);
			RP_AddClientEXP(target, g_iLawyerJob, 15);
			
			LastLawyerButtons[target] = GetClientButtons(target);
			
			ExpireAFKGracePeriod[target] = GetGameTime() + 10.0;
		}
		else
		{
			RP_PrintToChat(client, "\x02%N\x01 has tried to help you but \x02failed! You paid $%i!", target, wage);
			RP_PrintToChat(target, "You have failed to help \x02%N\x01! You got $%i!", client, amount);
		}
	}
	else if(RP_GetClientJob(target) == g_iLawyerJob && StrEqual(info, MENUINFO_LOSEKARMA))
	{
		new bool:higherLevel = RP_GetClientLevel(target, g_iLawyerJob) >= 7;
		
		new price = higherLevel ? 700 : 350;
		new karmaLost = higherLevel ? 100 : 50;
		
		if (GetClientCash(client, BANK_CASH) < price)
		{
			return;
		}
		else if(g_fNextLawyer[client] > GetGameTime())
		{
			RP_PrintToChat(client, "You are on a cooldown.")
		}
		else if(CheckDistance(client, target) > 350.0)
		{
			RP_PrintToChat(client, "You are too far away!");
		}
		
		GiveClientCash(client, BANK_CASH, -1 * price);
		new amount = GiveClientCash(target, BANK_CASH, price);

		if(karmaLost > RP_GetKarma(client))
			karmaLost = RP_GetKarma(client);
			
		g_fNextLawyer[client] = GetGameTime() + 60.0;
		
		RP_AddKarma(client, -1 * karmaLost, true, KARMA_LOSS_LAWYER_REASON);
		
		RP_PrintToChat(client, "\x02%N\x01 reduced your karma by %i! You paid $%i!", target, karmaLost, price);
		RP_PrintToChat(target, "You have reduced \x02%N\x01's karma by %i! You got $%i!", client, karmaLost, amount);
		RP_AddClientEXP(target, g_iLawyerJob, 5);
		
		LastLawyerButtons[target] = GetClientButtons(target);
		
		ExpireAFKGracePeriod[target] = GetGameTime() + 10.0;
	}
	else if(RP_GetClientJob(client) == g_iLawyerJob && StrEqual(info, MENUINFO_LAWYERHELPGANG) && RP_IsClientInJail(target) && !RP_IsClientInAdminJail(target))
	{
		new TotalChance = g_iReleaseChance[RP_GetClientLevel(client, g_iLawyerJob)];
		
		if(CheckCommandAccess(target, "sm_vip", ADMFLAG_CUSTOM2))
			TotalChance += VIP_EXTRA_RELEASE_CHANCE;
			
		TotalChance += Get_User_Luck_Bonus(target);	
		
		if(TotalChance >= GetRandomInt(1, 100))
		{
			RP_UnJailClient(target);
			RP_PrintToChat(client, "You have helped \x02%N\x01 and released him from the jail for free!", target);
			RP_PrintToChat(target, "\x02%N\x01 helped you and \x04released\x01 you from the jail for free!", client);
		}
		else
		{
			RP_PrintToChat(client, "You have failed to help \x02%N\x01 for free!", target);
			RP_PrintToChat(target, "\x02%N\x01 has tried to help you for free but \x02failed!", client);
		}
	}
}

public OnMapStart()
{
	for (new i = 0; i < sizeof(g_fNextLawyer);i++)
	{
		g_fNextLawyer[i] = 0.0;
	}
}

public bool:UpdateJobStats(client, job)
{
	if(job == -1)
		return false;
	
	if (job == g_iLawyerJob)
	{
		if (GetClientTeam(client) != 2)
		{
			CS_SwitchTeam(client, 2);
			CS_RespawnPlayer(client);
			
			return false; // Return because UpdateJobStats is called upon respawning.
		}
		
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iLawyerJob, model, sizeof(model));

		if(model[0] != EOS)
			SetEntityModel(client, model);
		
		CS_SetClientClanTag(client, "Lawyer");
		RP_SetClientJobName(client, g_szLevels[RP_GetClientLevel(client, g_iLawyerJob)]);
			
		new bool:anyVIP = AnyVIPInJail();
		
		if((CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2) || anyVIP) && !RP_IsClientInJail(client) )
		{
			new bool:anyJailed = false;
			
			for(new i=1;i <= MaxClients;i++)
			{
				if(!IsClientInGame(i))	
					continue;
					
				else if(RP_IsClientInJail(i) && !RP_IsClientInAdminJail(i))
				{
					anyJailed = true;
					break;
				}
			}
			
			if(anyJailed)
			{
				new RNG = 5;
				
				Menu menu = new Menu(Teleport_MenuHandler);
				RP_SetMenuTitle(menu, "Do you want to be teleported to the jail%s", (anyVIP && !CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2)) ? " to rescue the VIP?" : "?");
			
				for(int i=1;i <= RNG+1;i++)
				{
					char Temp[11];
					IntToString(RNG, Temp, sizeof(Temp));
					
					if(i == RNG)
						menu.AddItem(Temp, "Yes");
						
					else if(i == RNG + 1)
						menu.AddItem(Temp, "No");
						
					else
						menu.AddItem("", "", ITEMDRAW_NOTEXT);
				}
				
				//menu.Pagination = MENU_NO_PAGINATION;
				
				menu.Display(client, 7);
			}
		}
		
		new level = RP_GetClientLevel(client, g_iLawyerJob);
	
		
		if(level >= 10)
		{
			SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 50);
			SetEntityHealth(client, GetClientHealth(client) + 50);
		}
		else if(level >= 9)
		{
			SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 20);
			SetEntityHealth(client, GetClientHealth(client) + 20);
		}
		else if(level >= 2)
		{
			SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 10);
			SetEntityHealth(client, GetClientHealth(client) + 10);
		}
		else if(level >= 1)
		{
			SetEntityMaxHealth(client, GetEntityMaxHealth(client) + 5);
			SetEntityHealth(client, GetClientHealth(client) + 5);
		}
		
		if(level >= 4)
			SetClientArmor(client, 100);
			
		if(level >= 6)
			SetClientHelmet(client, true);
			
	}
	
	return false;
}

public int Teleport_MenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_End)
		delete menu;
		
	else if(action == MenuAction_Select)
	{
		char sRNG[32];
		menu.GetItem(item, sRNG, sizeof(sRNG));
		
		if(item == StringToInt(sRNG)-1)
		{
			TeleportEntity(client, VIP_LAWYER_XYZ, Float:{0.0, 0.0, 0.0}, NULL_VECTOR);
		}
	}
}



public Action:Thief_RequestIdentity(client, const String:JobShortName[], &FakeLevel, String:LevelName[32], String:Model[PLATFORM_MAX_PATH])
{
	if(StrEqual(JobShortName, "LAW", false))
	{
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iLawyerJob, model, sizeof(model));

		if(model[0] != EOS)
			FormatEx(Model, sizeof(Model), model);

		FormatEx(LevelName, sizeof(LevelName), "Lawyer");
		
		FakeLevel = RP_GetClientLevel(client, g_iLawyerJob);
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_Jobs", true))
	{
		g_iLawyerJob = RP_CreateJob("Lawyer", "LAW", 11);
	}
}

stock SetClientLawyerWage(client, amount)
{
	new String:strAmount[11];
	
	IntToString(amount, strAmount, sizeof(strAmount));
	
	SetClientCookie(client, cpLawyerWage, strAmount);
	
}

stock GetClientLawyerWage(client)
{
	new String:strAmount[11];
	
	GetClientCookie(client, cpLawyerWage, strAmount, sizeof(strAmount));
	
	new amount = StringToInt(strAmount);
	
	new level = RP_GetClientLevel(client, g_iLawyerJob);
	
	if(amount < minWage[level] || amount > maxWage[level])
		amount = maxWage[level];
		
	return amount;
}

stock bool:AnyVIPInJail()
{
	new bool:anyJailed = false;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))	
			continue;
		
		else if(!CheckCommandAccess(i, "sm_vip", ADMFLAG_CUSTOM2))
			continue;
			
		else if(RP_IsClientInJail(i) && !RP_IsClientInAdminJail(i))
		{
			anyJailed = true;
			break;
		}
	}
	
	return anyJailed;
}