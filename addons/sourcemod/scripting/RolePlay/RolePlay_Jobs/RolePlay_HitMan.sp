#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <Eyal-RP>

new EngineVersion:g_Game;


public Plugin:myinfo =
{
	name = "RolePlay HitMan Job",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = "https://steamcommunity.com/id/xflane/"
};

new Handle:hCookie_HitmanScout = INVALID_HANDLE;
new Handle:hCookie_RevolverPref = INVALID_HANDLE;

new g_iHitmanJob;
new Float:g_fHitmanProtection[MAXPLAYERS+1];
new g_iHitman[MAXPLAYERS+1];
new g_iHitmanInviter[MAXPLAYERS+1];
new Float:g_fHitmanTime[MAXPLAYERS+1];

new bool:DismissedAsCop[MAXPLAYERS+1] = false;

new sprLaserBeam;
new String:g_szLevels[11][16];

new HITMAN_PRICE = 5000;
new g_iKarmaBonusBadCop[11];
new g_iCashBonus[11];

new g_iViewModel;
new g_iWorldModel;

new Float:HITMAN_TIME = 90.0;
new Float:HITMAN_PROTECTION_TIME = 180.0;
new Float:HITMAN_SERVER_EXP_MULTIPLIER = 0.1;
new Float:HITMAN_SERVER_CASH_MULTIPLIER = 0.1;

new Handle:Trie_HitmanEco;

public RP_OnEcoLoaded()
{
	
	Trie_HitmanEco = RP_GetEcoTrie("Hitman");
	
	if(Trie_HitmanEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Hitman");
		
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "CASH_BONUS_LVL_#%i", i);
		
		if(!GetTrieString(Trie_HitmanEco, Key, TempFormat, sizeof(TempFormat)))
			break;
			
		g_iCashBonus[i] = StringToInt(TempFormat);
		
		FormatEx(Key, sizeof(Key), "KARMA_BONUS_BAD_COP_LVL_#%i", i);
		
		GetTrieString(Trie_HitmanEco, Key, TempFormat, sizeof(TempFormat));
		
		g_iKarmaBonusBadCop[i] = StringToInt(TempFormat);		
		
		FormatEx(Key, sizeof(Key), "JOB_NAME_LVL_#%i", i);
		
		GetTrieString(Trie_HitmanEco, Key, TempFormat, sizeof(TempFormat));
		
		FormatEx(g_szLevels[i], sizeof(g_szLevels[]), TempFormat);
		
		i++;
	}
	
	GetTrieString(Trie_HitmanEco, "HITMAN_PRICE", TempFormat, sizeof(TempFormat));
	
	HITMAN_PRICE = StringToInt(TempFormat);	
	
	GetTrieString(Trie_HitmanEco, "HITMAN_TIME", TempFormat, sizeof(TempFormat));
	
	HITMAN_TIME = StringToFloat(TempFormat);	
	
	GetTrieString(Trie_HitmanEco, "HITMAN_PROTECTION_TIME", TempFormat, sizeof(TempFormat));
	
	HITMAN_PROTECTION_TIME = StringToFloat(TempFormat);	

	GetTrieString(Trie_HitmanEco, "HITMAN_SERVER_EXP_MULTIPLIER", TempFormat, sizeof(TempFormat));
	
	if(StringToFloat(TempFormat) <= 1.0)
		HITMAN_SERVER_EXP_MULTIPLIER = StringToFloat(TempFormat);	

	GetTrieString(Trie_HitmanEco, "HITMAN_SERVER_CASH_MULTIPLIER", TempFormat, sizeof(TempFormat));
	
	if(StringToFloat(TempFormat) <= 1.0)
		HITMAN_SERVER_CASH_MULTIPLIER = StringToFloat(TempFormat);	
	

}
public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_DrugsDealer");
	CreateNative("RP_GetClientHitmanVictim", _RP_GetClientHitmanVictim);
	CreateNative("RP_GiveClientHitmanJob", _RP_GiveClientHitmanJob);
	CreateNative("RP_GetClientHitmanAttacker", _RP_GetClientHitmanAttacker);
	CreateNative("RP_DismissAsCop", _RP_DismissAsCop);
}

public _RP_GetClientHitmanVictim(Handle:plugin, numParams)
{
	return g_iHitman[GetNativeCell(1)];
}

public int _RP_GiveClientHitmanJob(Handle plugin, int numParams)
{
	int target = GetNativeCell(1);
	int hitman = GetNativeCell(2);
	int inviter = GetNativeCell(3);
	bool cooldown = GetNativeCell(4);
	bool charge = GetNativeCell(5)

	if(inviter == 0)
		charge = false;

	g_iHitman[hitman] = target;
	g_fHitmanTime[hitman] = GetGameTime() + HITMAN_TIME;
	
	if(RP_GetClientLevel(hitman, g_iHitmanJob) >= 2)
		g_fHitmanTime[hitman] += 10.0;
		
	g_iHitmanInviter[hitman] = inviter;
	CreateTimer(1.0, Timer_ShowHitmanStatus, hitman, TIMER_REPEAT);

	if(inviter != 0)
		RP_PrintToChat(inviter, "You have orderd assassination on \x02%N!", target);

	if(cooldown)
		g_fHitmanProtection[target] = GetGameTime() + HITMAN_PROTECTION_TIME;

	if(charge)
		GiveClientCash(inviter, BANK_CASH, -1 * HITMAN_PRICE);

	return 0;
}

public _RP_GetClientHitmanAttacker(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(g_iHitman[i] == client)
			return i;
	}
	
	return 0;
}

public _RP_DismissAsCop(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	DismissedAsCop[client] = true;
	
	RP_SetClientJob(client, g_iHitmanJob);
	
	return 0;
}

public OnPluginStart()
{
	g_Game = GetEngineVersion();
	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	HookEvent("player_death", Event_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("weapon_fire", Event_PlayerDeath, EventHookMode_Post);
	
	AddTempEntHook("Shotgun Shot", Hook_FireBullets)
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		OnClientPutInServer(i);
	}
	
	hCookie_HitmanScout = RegClientCookie("RP_HitmanScout", "1 = Always spawn with Scout at hitman level 6+, 0 = Disabled", CookieAccess_Public);
	hCookie_RevolverPref = RegClientCookie("RP_RevolverPref", "1 = Spawn with Revolver, 0 = Spawn with Deagle", CookieAccess_Public);
	
	RegAdminCmd("sm_reloadhitman", cmd_ReloadHitman, ADMFLAG_ROOT);
	
	SetCookieMenuItem(RolePlayMenu_Handler, 0, "RolePlay");
	
	if(RP_GetEcoTrie("Hitman") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public Action:cmd_ReloadHitman(client, args)
{
	new jobCount = 0;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(g_iHitman[i] != 0 && RP_GetClientJob(i) == g_iHitmanJob)
		{
			jobCount++;
		}
	}
	
	if(jobCount > 0)
	{
		RP_PrintToChat(client, "Could not reload Hitman plugin. Found %i jobs.", jobCount);
		return Plugin_Handled;
	}
	ReloadPlugin();
	
	return Plugin_Handled;
}

public Action:Hook_FireBullets(const String:te_name[], const Players[], numClients, Float:delay)
{
	new client = 0;
	
	for (new i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		new bool:Found = false;
		
		for (new a = 0; a < numClients;a++)
		{
			if(Players[a] == i)
				Found = true;
		}
		
		if(!Found)
		{
			client = i;
			
			break;
		}
	}
	
	if(client == 0)
		return Plugin_Continue;
	
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	if(weapon == -1)
		return Plugin_Continue;

	// client is the player that fired the weapon	
	// weapon is the weapon that was fired.
	
	new String:Classname[64];
	
	GetEdictClassname(weapon, Classname, sizeof(Classname));
	
	if(!IsWeaponUSP(weapon) && !IsWeaponMP5(weapon) && !StrEqual(Classname, "weapon_ssg08"))
		return Plugin_Continue;
		
	else if(RP_GetClientJob(client) != g_iHitmanJob)
		return Plugin_Continue;
		
	else if(RP_GetClientLevel(client, g_iHitmanJob) < 10)
		return Plugin_Continue;
		
	return Plugin_Stop;
}
public OnClientConnected(client)
{
	g_fHitmanProtection[client] = 0.0;
	DismissedAsCop[client] = false;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, SDKEvent_OnTakeDamage);
}

public Action:SDKEvent_OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(attacker != victim && IsPlayer(attacker))
		return Plugin_Continue;
		
	new bool:isJobbed = false;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(g_iHitman[i] == victim)
		{
			isJobbed = true;
			break;
		}
	}
	
	if(!isJobbed)
		return Plugin_Continue;
		
	else if(damage < GetEntityHealth(victim))
		return Plugin_Continue;
	
	else if(!RP_IsClientInRP(victim))
		return Plugin_Continue;
		
	damage = float(GetEntityHealth(victim)) - 1.0;
	
	RemoveAllWeapons(victim);
	
	SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", 0.001);
	
	GivePlayerItem(victim, "weapon_knife");
	
	RP_PrintToChat(victim, "You tried to commit suicide while a hitman is hunting you.");
	
	return Plugin_Changed;
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
	
	if(RP_GetClientJob(victim) == g_iHitmanJob)
	{
		if(g_iHitman[victim] == client)
		{	
			return Plugin_Handled;
		}
	}
	if (!victim || !client)
		return Plugin_Continue;
	
	else if(RP_GetClientJob(client) != g_iHitmanJob)
		return Plugin_Continue;
	
	new level = RP_GetClientLevel(client, g_iHitmanJob);
		
	if(level < 4)
		return Plugin_Continue;
		
	else if(g_iHitman[client] != victim)
		return Plugin_Continue;
		
	new weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	if(weapon == -1)
		return Plugin_Continue;
	
	new String:Classname[64];
	
	GetEdictClassname(weapon, Classname, sizeof(Classname));
	
	if(!StrEqual(Classname, "weapon_usp_silencer", false) && !StrEqual(Classname, "weapon_hkp2000") && !IsWeaponMP5(weapon) && (!StrEqual(Classname, "weapon_ssg08")))
		return Plugin_Continue;
		
	karma -= 75;
	
	return Plugin_Changed;
	
}

public JumpShotKillFeed_OnDeathEventEdit(Handle:hEvent)
{
	new victim = GetClientOfUserId(GetEventInt(hEvent, "userid", 0));
	
	new attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker", 0));

	if (!victim || !attacker || attacker == victim)
		return;
	
	if(g_iHitman[attacker] == victim)
		SetEventBool(hEvent, "dominated", true);
		
	if(g_iHitman[victim] == attacker)
		SetEventBool(hEvent, "revenge", true);
}
// Makes icon when finishing your job, killing the hitman trying to kill you or killing with > 1,000$
public Action:Event_PlayerDeathPre(Event:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid", 0));
	
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));

	if (!victim || !attacker || attacker == victim)
		return Plugin_Continue;
	
	if(GetClientCash(victim, POCKET_CASH) >= 1000 && GetClientTeam(attacker) != CS_TEAM_CT)
		RP_PrintToChat(victim, "%N killed you for having more than $1,000 on you.", attacker);
		
	if(g_iHitman[attacker] == victim)
		event.SetBool("dominated", true);
		
	else if(g_iHitman[victim] == attacker)
		event.SetBool("revenge", true);
	
	return Plugin_Changed;
	/*
	if(RP_GetClientJob(attacker) != g_iHitmanJob)
		return Plugin_Continue;
		
	else if(g_iHitman[attacker] != victim)
		return Plugin_Continue;
	
	new level = RP_GetClientLevel(attacker, g_iHitmanJob);
	
	// Hitman with USP reduce karma and no message.
	if(level < 4)
		return Plugin_Continue;
		
	new weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
	
	if(weapon == -1)
		return Plugin_Continue;
	
	new String:Classname[64];
	
	GetEdictClassname(weapon, Classname, sizeof(Classname));
	
	if(!StrEqual(Classname, "weapon_usp_silencer", false) && !StrEqual(Classname, "weapon_hkp2000") && !IsWeaponMP5(weapon) && !StrEqual(Classname, "weapon_ssg08"))
		return Plugin_Continue;

	SetEventBroadcast(event, true);
	
	event.FireToClient(victim);
	
	return Plugin_Continue;
	*/
}

public Action:Event_PlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid", 0));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));

	if (!victim || !attacker)
	{
		return Plugin_Continue;
	}
	if(g_iHitman[attacker] == victim)
	{
		PrintHintText(victim, "<font color='#f44336'>Hitman <font color'#5D4037'>%N</font> completed his job and killed you!", attacker);
		RP_PrintToChat(victim, "\x02%N\x01 has completed his hitman job and killed you.", attacker);

		if(g_iHitmanInviter[attacker] != 0)
		{
			RP_PrintToChat(g_iHitmanInviter[attacker], "\x02%N\x01 has completed the hitman job.", attacker);
			RP_PrintToChat(attacker, "You have killed \x04%N\x01 and completed your job! You got $%i", victim, g_iCashBonus[RP_GetClientLevel(attacker, g_iHitmanJob)]);
	
			RP_AddClientEXP(attacker, g_iHitmanJob, 15);
			GiveClientCash(attacker, BANK_CASH, g_iCashBonus[RP_GetClientLevel(attacker, g_iHitmanJob)]);
		}
		else
		{
			int amount = RoundToFloor(15.0 * HITMAN_SERVER_EXP_MULTIPLIER);
			RP_AddClientEXP(attacker, g_iHitmanJob, amount);

			amount = RoundToFloor(g_iCashBonus[RP_GetClientLevel(attacker, g_iHitmanJob)] * HITMAN_SERVER_CASH_MULTIPLIER);
			RP_PrintToChat(attacker, "You have killed \x04%N\x01 and completed your job! You got $%i", victim, amount);
			GiveClientCash(attacker, BANK_CASH, amount);
		}
		g_iHitman[attacker] = 0;
	}
	if (attacker == g_iHitman[victim])
	{
		RP_PrintToChat(attacker, "You have killed \x02%N\x01 who had hitman job on you, the job was cancelled.", victim);
		RP_PrintToChat(victim, "You have failed your hitman job, \x02%N\x01 has received his money back.", g_iHitmanInviter[victim]);
		
		RP_AddClientEXP(attacker, g_iHitmanJob, 8);
		
		if(g_iHitmanInviter[victim] != 0)
		{
			RP_PrintToChat(g_iHitmanInviter[victim], "\x02%N\x01 failed his job, you got the money back.", victim);

			if(GetClientTeam(g_iHitmanInviter[victim]) == CS_TEAM_CT)
			{
				new level = RP_GetClientLevel(g_iHitmanInviter[victim], RP_GetClientJob(g_iHitmanInviter[victim]));
				RP_AddKarma(g_iHitmanInviter[victim], g_iKarmaBonusBadCop[level], true, "Crooked Cop Hitman Failed");

				if(RP_GetKarma(g_iHitmanInviter[victim]) > BOUNTY_KARMA)
				{
					DismissedAsCop[g_iHitmanInviter[victim]] = true;

					RP_SetClientJob(g_iHitmanInviter[victim], g_iHitmanJob);
				}	
				RP_PrintToChat(g_iHitmanInviter[victim], "You got %i karma for your failed hitman job as a policeman", g_iKarmaBonusBadCop[level]);
			}

			GiveClientCash(g_iHitmanInviter[victim], BANK_CASH, HITMAN_PRICE);
		}

		g_iHitman[victim] = 0;
	}
	return Plugin_Continue;
}

public Action:Timer_ShowHitmanStatus(Handle:timer, any:client)
{
	if (!g_iHitman[client])
	{
		return Plugin_Stop;
	}
	if (g_iHitmanInviter[client] != 0 && !IsClientInGame(g_iHitmanInviter[client]))
	{
		RP_PrintToChat(client, "The client who asked you to do a hitman job \x02disconnected\x01, the money is yours!");
		GiveClientCash(client, BANK_CASH, HITMAN_PRICE);
		g_iHitman[client] = 0;
		return Plugin_Stop;
	}
	if (!IsClientInGame(g_iHitman[client]))
	{
		RP_PrintToChat(client, "Your hitman job disconnected! \x02%N\x01 got his money back.", g_iHitmanInviter[client]);

		if(g_iHitmanInviter[client] != 0)
		{
			RP_PrintToChat(g_iHitmanInviter[client], "\x02%N\x01 hitman job disconnected, you got your money back.", client);
			GiveClientCash(g_iHitmanInviter[client], BANK_CASH, HITMAN_PRICE);
		}
		g_iHitman[client] = 0;
		return Plugin_Stop;
	}
	if (GetGameTime() > g_fHitmanTime[client])
	{
		RP_PrintToChat(client, "You have failed your hitman job (time up), \x02%N\x01 has received his money back.", g_iHitmanInviter[client]);

		if(g_iHitmanInviter[client] != 0)
		{
			RP_PrintToChat(g_iHitmanInviter[client], "\x02%N\x01 failed his job, you got the money back.", client);
			GiveClientCash(g_iHitmanInviter[client], BANK_CASH, HITMAN_PRICE);
		}
		
		RP_PrintToChat(g_iHitman[client], "\x02%N\x01 failed his hitman job on you.", client);
		PrintHintText(g_iHitman[client], "%N failed his hitman job on you.", client);
		g_iHitman[client] = 0;
		return Plugin_Stop;
	}
	PrintHintText(client, "<font color='#f44336'><u>Hitman</u></font><br><font color'#5D4037'>Target: </font><font color='#E91E63'>%N</font>\nTime Left: </font><font color='#E91E63'>%.0f seconds!</font>", g_iHitman[client], g_fHitmanTime[client] - GetGameTime());
	TE_SetupBeamLaser(g_iHitman[client], client, sprLaserBeam, 0, 0, 0, 1.0, 2.0, 2.0, 10, 0.0, {0, 255, 0, 255}, 0);
	TE_SendToClient(client, 0.0);
	return Plugin_Continue;
}

public OnClientDisconnect(client)
{
	if (g_iHitman[client])
	{
		if(g_iHitmanInviter[client] != 0)
		{
			RP_PrintToChat(g_iHitmanInviter[client], "\x02%N\x01 disconnected, you got the money back.", client);
			GiveClientCash(g_iHitmanInviter[client], BANK_CASH, HITMAN_PRICE);
		}
		g_iHitman[client] = 0;
	}
}


public RP_OnPhoneMenu(client, &Menu:menu, priority)
{
	if(priority != PRIORITY_HITMAN)
		return;
		
	new String:szIndex[8];
	IntToString(g_iHitmanJob, szIndex, 6);

	new String:szFormatex[64];
	FormatEx(szFormatex, 64, "Order an Assassination - $%i", HITMAN_PRICE);

	AddMenuItem(menu, szIndex, szFormatex, GetClientCash(client, BANK_CASH) >= HITMAN_PRICE ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
}


public RP_OnPhoneMenuPressed(client, const String:info[])
{
	if (g_iHitmanJob == StringToInt(info, 10))
	{
		if (GetClientCash(client, BANK_CASH) >= HITMAN_PRICE)
		{
			new String:szIndex[8];
			new String:szBuffer[64];
			new Menu:menu = CreateMenu(MenuHandler_HitmanList);
			RP_SetMenuTitle(menu, "Hitman Menu - Order Assassination\n Choose a hitman in the server:\n Hitman Price: $%i\n ", HITMAN_PRICE);
			
			new total;
			for(new i=1;i <= MaxClients;i++)
			{

				if (!IsClientInGame(i) || client == i || !IsValidTeam(i) || RP_GetClientJob(i) != g_iHitmanJob || (!CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2) && !CheckCommandAccess(i, "sm_vip", ADMFLAG_CUSTOM2)))
				{
				}
				else
				{
					if(g_iHitman[i] != 0)
					{
						IntToString(GetClientUserId(i), szIndex, 6);
						FormatEx(szBuffer, sizeof(szBuffer), "%N [Has Job]", i);
						AddMenuItem(menu, szIndex, szBuffer, ITEMDRAW_DISABLED);
					}
					else
					{
						IntToString(GetClientUserId(i), szIndex, 6);
						GetClientName(i, szBuffer, 32);
						AddMenuItem(menu, szIndex, szBuffer, ITEMDRAW_DEFAULT);
					}
					total++;
				}
			}
			if (total == 0)
			{
				if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
					AddMenuItem(menu, "", "There are no eligible players", 0);
					
				else
					AddMenuItem(menu, "", "There are no VIP hitmans online", 0);
			}
			DisplayMenu(menu, client, 0);
			
			return;
		}
		RP_PrintToChat(client, "You dont have enough money");
	}
}


public MenuHandler_HitmanList(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
	{
		new String:szIndex[8];
		GetMenuItem(menu, key, szIndex, 6);
		new hitman = GetClientOfUserId(StringToInt(szIndex));
		
		if(hitman == 0)
		{
			RP_PrintToChat(client, "\x04Hitman was not found.");
			return;
		}
		if(g_iHitman[hitman] != 0)
		{
			RP_PrintToChat(client, "\x04Hitman \x01already has a \x07job.");
			return;
		}
		else if(RP_GetClientJob(hitman) != g_iHitmanJob)
		{
			RP_PrintToChat(client, "\x04Hitman \x01has retired his \x07job.");
			return;
		}
		
		ShowHitmanTargetMenu(client, hitman)
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

public RP_OnPlayerMenu(client, target, &Menu:menu, priority)
{
	if(priority != PRIORITY_HITMAN)
		return;
	
	new hitman = target;
	
	if (RP_GetClientJob(hitman) == g_iHitmanJob && !RP_IsClientInJail(hitman))
	{
		new String:szIndex[8];
		IntToString(g_iHitmanJob, szIndex, 6);
	
		new String:szFormatex[64];
		FormatEx(szFormatex, 64, "Order an Assassination - $%i", HITMAN_PRICE);

		AddMenuItem(menu, szIndex, szFormatex, GetClientCash(client, BANK_CASH) >= HITMAN_PRICE && g_iHitman[hitman] == 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}
}


public RP_OnMenuPressed(client, target, const String:info[])
{
	if (g_iHitmanJob == StringToInt(info, 10))
	{
		if (GetClientCash(client, BANK_CASH) >= HITMAN_PRICE)
		{
			new hitman = target;
			ShowHitmanTargetMenu(client, hitman)
			
			return;
		}
		RP_PrintToChat(client, "You dont have enough money");
	}
}

ShowHitmanTargetMenu(client, hitman)
{
	new String:szIndex[8];
	IntToString(hitman, szIndex, 6);
	new String:szBuffer[64];
	new Menu:menu = CreateMenu(MenuHandler_OrderHitman);
	RP_SetMenuTitle(menu, "Hitman Menu - Order Assassination\n Talking with %N\n Hitman Price: $%i\n ", hitman, HITMAN_PRICE);
	AddMenuItem(menu, szIndex, "", ITEMDRAW_IGNORE);
	
	new Float:time = GetGameTime();
	new total;
	for(new i=1;i <= MaxClients;i++)
	{

		if (!IsClientInGame(i) || hitman == i || client == i || !IsValidTeam(i))
		{
		}
		else
		{
			if (g_fHitmanProtection[i] > time)
			{
				FormatEx(szBuffer, 64, "%N [Cooldown %.1f seconds]", i, g_fHitmanProtection[i] - time);
				AddMenuItem(menu, "", szBuffer, ITEMDRAW_DISABLED);
			}
			else if(IsClientNoKillZone(i))
			{
				FormatEx(szBuffer, 64, "%N [No Kill Zone]", i);
				AddMenuItem(menu, "", szBuffer, ITEMDRAW_DISABLED);
			}
			else
			{
				IntToString(GetClientUserId(i), szIndex, 6);
				GetClientName(i, szBuffer, 32);
				AddMenuItem(menu, szIndex, szBuffer, 0);
			}
			
			total++;
		}
	}
	if (total == 0)
	{
		AddMenuItem(menu, "", "There are no eligible players", 0);
	}
	DisplayMenu(menu, client, 0);
}


public MenuHandler_OrderHitman(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
	{
		new String:szIndex[8];
		GetMenuItem(menu, 0, szIndex, 6);
		new hitman = StringToInt(szIndex);
		GetMenuItem(menu, key, szIndex, 6);
		new target = GetClientOfUserId(StringToInt(szIndex));
		
		if(target == 0)
		{
			RP_PrintToChat(client, "\x04Target was not found.");
			return;
		}
		if(g_iHitman[hitman] != 0)
		{
			RP_PrintToChat(client, "\x04Hitman \x01already has a \x07job.");
			return;
		}
		else if(IsClientNoKillZone(target))
		{
			RP_PrintToChat(client, "Target is inside \x07no kill zone.");
			return;
		}
		else if(g_fHitmanProtection[target] > GetGameTime())
		{
			RP_PrintToChat(client, "Target is protected by\x07 cooldown");
			return;
		}
		else if(RP_GetClientJob(hitman) != g_iHitmanJob)
		{
			RP_PrintToChat(client, "\x04Hitman \x01has retired his \x07job.");
			return;
		}
		
		g_iHitman[hitman] = target;
		g_fHitmanTime[hitman] = GetGameTime() + HITMAN_TIME;
		
		if(RP_GetClientLevel(hitman, g_iHitmanJob) >= 2)
			g_fHitmanTime[hitman] += 10.0;
			
		g_iHitmanInviter[hitman] = client;
		g_fHitmanProtection[target] = GetGameTime() + HITMAN_PROTECTION_TIME;
		GiveClientCash(client, BANK_CASH, -1 * HITMAN_PRICE);
		CreateTimer(1.0, Timer_ShowHitmanStatus, hitman, TIMER_REPEAT);
		RP_PrintToChat(client, "You have orderd assassination on \x02%N!", target);
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

public OnMapStart()
{
	sprLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}

public OnClientChangeJobPost(int client, int job, int oldjob, bool:respawn)
{
	if(g_iHitmanJob == oldjob && job != oldjob && !respawn && g_iHitman[client] != 0)
	{
		RP_PrintToChat(client, "You retired your hitman job! \x02%N\x01 got his money back.", g_iHitmanInviter[client]);

		if(g_iHitmanInviter[client] != 0)
		{
			RP_PrintToChat(g_iHitmanInviter[client], "\x02%N\x01 retired from being a Hitman, you got your money back.", client);
			GiveClientCash(g_iHitmanInviter[client], BANK_CASH, HITMAN_PRICE);
		}
		g_iHitman[client] = 0;
	}
	
	else if(job == g_iHitmanJob && !respawn)
		RP_PrintToChat(client, "Hint! Hold W while spamming R to break into a house.");
}

public bool:UpdateJobStats(client, job)
{
	if(job == -1)
		return false;
	
	if (g_iHitmanJob == job)
	{
		if (GetClientTeam(client) != CS_TEAM_T)
		{
			CS_SwitchTeam(client, CS_TEAM_T);
			
			if(!DismissedAsCop[client])
			{
				CS_RespawnPlayer(client);
			
				return false; // Return because UpdateJobStats is called upon respawning.
			}
		}
		
		char model[PLATFORM_MAX_PATH];
		RP_GetJobModel(g_iHitmanJob, model, sizeof(model));

		if(model[0] != EOS)
			SetEntityModel(client, model);
		
		CS_SetClientClanTag(client, "Hitman");
		RP_SetClientJobName(client, g_szLevels[RP_GetClientLevel(client, g_iHitmanJob)]);
		
		if(!DismissedAsCop[client])
		{
			new level = RP_GetClientLevel(client, g_iHitmanJob); 
				
			switch(level)
			{
				case 1, 2:
				{
					RP_GivePlayerItem(client, "weapon_glock");
				}
				case 3, 4, 5:
				{
					RP_GivePlayerItem(client, "weapon_usp_silencer");
				}
				case 6:
				{
					if(IsClientHitmanScout(client))
						RP_GivePlayerItem(client, "weapon_ssg08");
					
					else
						RP_GivePlayerItem(client, "weapon_ump45");
						
					RP_GivePlayerItem(client, "weapon_usp_silencer");
				}
				case 7, 8:
				{
					if(IsClientHitmanScout(client))
						RP_GivePlayerItem(client, "weapon_ssg08");
					
					else
						RP_GivePlayerItem(client, "weapon_mp5sd");
						
					RP_GivePlayerItem(client, "weapon_usp_silencer");
				}
				case 9, 10:
				{
					if(IsClientHitmanScout(client))
						RP_GivePlayerItem(client, "weapon_ssg08");
					
					else
						RP_GivePlayerItem(client, "weapon_ak47");
						
					RP_GivePlayerItem(client, "weapon_usp_silencer");
					RP_GivePlayerItem(client, "weapon_tagrenade");
				}
			}
			
			if(level >= 4)
				SetClientArmor(client, 100);
				
			if(level >= 7)
				SetClientHelmet(client, true);
		}
		
	//	SDKHook(client, SDKHook_PostThinkPost, SDKEvent_PostThinkPost);
		
		DismissedAsCop[client] = false;
	}
	
	/*
	if(GetClientTeam(client) == CS_TEAM_T)
		SDKHook(client, SDKHook_PostThinkPost, SDKEvent_PostThinkPost);
		
	else
		SDKUnhook(client, SDKHook_PostThinkPost, SDKEvent_PostThinkPost);
	*/
	return false;
}
/*
public SDKEvent_PostThinkPost(client)
{
	SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
}
*/
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_Jobs", true))
	{
		g_iHitmanJob = RP_CreateJob("Hitman", "HM", 11);
	}
}


public int RolePlayMenu_Handler(int client, CookieMenuAction action, int info, char[] buffer, int maxlen)
{
	if(action != CookieMenuAction_SelectOption)
		return;
		
	ShowGunPrefMenu(client);
} 
public void ShowGunPrefMenu(int client)
{
	Handle hMenu = CreateMenu(GunPrefMenu_Handler);
	
	char TempFormat[64];
	
	Format(TempFormat, sizeof(TempFormat), "Hitman Scout [LVL 6+]: %s", IsClientHitmanScout(client) ? "ON" : "OFF");
	AddMenuItem(hMenu, "", TempFormat);	
	
	Format(TempFormat, sizeof(TempFormat), "Loadout: %s", IsClientRevolverPref(client) ? "Revolver" : "Deagle");
	AddMenuItem(hMenu, "", TempFormat);	

	SetMenuExitBackButton(hMenu, true);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, client, 30);
}


public int GunPrefMenu_Handler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if(action == MenuAction_Cancel && item == MenuCancel_ExitBack)
	{
		ShowCookieMenu(client);
	}
	else if(action == MenuAction_Select)
	{
		switch(item)
		{
			case 0: SetClientHitmanScout(client, !IsClientHitmanScout(client));
			case 1: SetClientRevolverPref(client, !IsClientRevolverPref(client));
		}
		
		ShowGunPrefMenu(client);
	}
	return 0;
}

stock bool IsValidTeam(int client)
{
	return GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(client) == CS_TEAM_T;
}

stock GetEntityHealth(entity)
{
	return GetEntProp(entity, Prop_Send, "m_iHealth", entity);
}


stock bool IsClientHitmanScout(int client)
{
	char strHitmanScout[11];
	GetClientCookie(client, hCookie_HitmanScout, strHitmanScout, sizeof(strHitmanScout));
	
	if(strHitmanScout[0] == EOS)
	{
		SetClientHitmanScout(client, false);
		return false;
	}
	
	return view_as<bool>(StringToInt(strHitmanScout));
}

stock bool SetClientHitmanScout(int client, bool value)
{
	char strHitmanScout[11];
	
	IntToString(value, strHitmanScout, sizeof(strHitmanScout));
	SetClientCookie(client, hCookie_HitmanScout, strHitmanScout);
	
	return value;
}

// IsClientRevolverPref is in xoxo.inc
stock bool SetClientRevolverPref(int client, bool value)
{
	char strRevolverPref[11];
	
	IntToString(value, strRevolverPref, sizeof(strRevolverPref));
	SetClientCookie(client, hCookie_RevolverPref, strRevolverPref);
	
	return value;
}
