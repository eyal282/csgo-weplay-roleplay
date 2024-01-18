#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <Eyal-RP>

new Float:DUEL_TAX = 10.0; // Percentage of tax for duels.

new  String:DodgeballModel[] = "models/chicken/chicken.mdl";

new bool:BypassBlockers = false;

new DUEL_MIN_WAGE = 500;
new DUEL_MAX_WAGE = 1500;

enum enGame
{
	DUEL_S4SDeagle=0,
	DUEL_KNIFE,
	DUEL_1HPKNIFE,
	DUEL_BACKSTABS,
	DUEL_SCOPEAWP,
	DUEL_SCOPESSG08,
	DUEL_HSAWP,
	DUEL_DODGEBALL,
	DUEL_SUPERDEAGLE
}

new String:DuelNames[][] =
{
	"Shot4Shot Duel [Deagle]",
	"Knife Duel",
	"Knife Duel [1 HP]",
	"Backstab Duel",
	"Noscope Duel [AWP]",
	"Noscope Duel [Scout]",
	"AWP Headshot",
	"Dodgeball Duel",
	"Super Deagle Duel"
}

enum struct OriginsDuel
{
	float FirstOrigin[3];
	float SecondOrigin[3];
}

enum struct Duel
{
	enGame DuelGame;
	int FirstDuelist;
	int SecondDuelist;
	int PrizePool;
}
new Handle:hTimer_SwapShot = INVALID_HANDLE;
new Handle:hTimer_NotifyRestart = INVALID_HANDLE;
new Handle:hTimer_BlockAttacks = INVALID_HANDLE;
new Handle:hCookie_DuelBlock = INVALID_HANDLE;

new enGame:SelectedDuelGame[MAXPLAYERS+1];
new Float:g_LastInvitedDuel[MAXPLAYERS+1];
new g_InvitedClient[MAXPLAYERS+1] = {-1, ...};
new bool:g_Invited[MAXPLAYERS+1];
new g_WeaponRef[MAXPLAYERS+1];
new g_DuelAmount[MAXPLAYERS+1];

new Handle:Array_OriginsDuels;
new Handle:Array_Duels;


new EngineVersion:g_Game;

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};


native bool UsefulCommands_IsServerRestartScheduled();

/*
* This forward is fired when an admin stops the server restart.
*
* @noreturn 
*/

public void UsefulCommands_OnServerRestartAborted()
{
	if(hTimer_NotifyRestart != INVALID_HANDLE)
	{
		CloseHandle(hTimer_NotifyRestart);
		hTimer_NotifyRestart = INVALID_HANDLE;
	}
}

/*
* This forward is fired when an admin uses !restart [seconds]

* @return  					Amount of seconds your plugin demands waiting before restart is made.
							If returning more than the time input by !restart, it will fail. return -1 if you
*
*
* @notes					!restart defaults to 5 seconds. Returning more than that may burden the admins.
* @notes					While a completely bad practice, to stop all restarts you can workaround returning the biggest integer possible, 2147483647
*/

public int UsefulCommands_OnCountServerRestart()
{
	if(IsAnyDuelRunning())
		return 65;
		
	return 0;
}

/*
* This forward is fired x seconds before restart, x being the highest returned value from the forward UsefulCommands_OnCountServerRestart
*
* @param SecondsLeft		Amount of seconds left before the restart, or -1 if the restart is scheduled to next round.
*
* @noreturn 
*
*
* @notes					This is called immediately on a next round based server restart
*/

public void UsefulCommands_OnNotifyServerRestart(int SecondsLeft)
{		
	if(!IsAnyDuelRunning())
		return;
		
	hTimer_NotifyRestart = CreateTimer(60.0, Timer_NotifyServerRestart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_NotifyServerRestart(Handle:hTimer)
{
	if(!IsAnyDuelRunning())
		return;
		
	RP_PrintToChatAll("Duel was shut down automatically due to scheduled server restart!");

	RefundAllDuels();
}

RefundAllDuels()
{
	new size = GetArraySize(Array_Duels);
	
	for (new i = 0; i < size;i++)
	{
		Duel duel;
		
		GetArrayArray(Array_Duels, i, duel);
		
		
		GiveClientCashNoGangTax(duel.FirstDuelist, BANK_CASH, duel.PrizePool / 2);
		GiveClientCashNoGangTax(duel.SecondDuelist, BANK_CASH, duel.PrizePool / 2);
		
		RemoveAllWeapons(duel.FirstDuelist);
		CS_RespawnPlayer(duel.FirstDuelist);
		
		RemoveAllWeapons(duel.SecondDuelist);
		CS_RespawnPlayer(duel.SecondDuelist);
		
		duel.PrizePool = 0;
		duel.FirstDuelist = 0;
		duel.SecondDuelist = 0;
		
		SetArrayArray(Array_Duels, i, duel);
	}
}

new Handle:Trie_DuelsEco;

// Note to self: I think in the future after being proven that way, the only...
// method to prevent people stacking a duel arena is blocking all duels until all others finish during an !eco.
public RP_OnEcoLoaded()
{
	
	Trie_DuelsEco = RP_GetEcoTrie("Duels");
	
	if(Trie_DuelsEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Duels");
	
	ClearArray(Array_OriginsDuels);
	
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "DUEL_XYZ_FIRST_#%i", i);
		
		if(!GetTrieString(Trie_DuelsEco, Key, TempFormat, sizeof(TempFormat)))
			break;
		
		OriginsDuel originDuel;
		
		StringToVector(TempFormat, originDuel.FirstOrigin);
		
		FormatEx(Key, sizeof(Key), "DUEL_XYZ_SECOND_#%i", i);
		GetTrieString(Trie_DuelsEco, Key, TempFormat, sizeof(TempFormat));
		
		StringToVector(TempFormat, originDuel.SecondOrigin);
		
		PushArrayArray(Array_OriginsDuels, originDuel);
		
		i++;
	}
	
	new size = GetArraySize(Array_OriginsDuels);
	while(GetArraySize(Array_Duels) < size)
	{
		Duel duel;
		
		duel.FirstDuelist = 0;
		duel.SecondDuelist = 0;
		duel.PrizePool = 0;
		
		PushArrayArray(Array_Duels, duel);
	}
	
	GetTrieString(Trie_DuelsEco, "DUEL_MIN_WAGE", TempFormat, sizeof(TempFormat));
	
	DUEL_MIN_WAGE = StringToInt(TempFormat);	
	
	GetTrieString(Trie_DuelsEco, "DUEL_MAX_WAGE", TempFormat, sizeof(TempFormat));
	
	DUEL_MAX_WAGE = StringToInt(TempFormat);	
	
	GetTrieString(Trie_DuelsEco, "DUEL_TAX", TempFormat, sizeof(TempFormat));
	
	DUEL_TAX = StringToFloat(TempFormat);
	
	
}

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	Array_Duels = CreateArray(sizeof(Duel));
	Array_OriginsDuels = CreateArray(sizeof(OriginsDuel));

	hCookie_DuelBlock = RegClientCookie("RolePlay_IgnoreDuels", "Should !duel invites be declined automatically?", CookieAccess_Public);
	
	RegConsoleCmd("sm_duel", cmd_Duel, "Invite a player to a duel.");

	RegConsoleCmd("sm_duelblock", cmd_DuelBlock, "Block duel requests.");
	RegConsoleCmd("sm_duelaccept", cmd_DuelAccept, "Accept duel.");
	RegConsoleCmd("sm_da", cmd_DuelAccept, "Accept duel.");
	
	RegAdminCmd("sm_reloadduels", cmd_ReloadDuels, ADMFLAG_ROOT);
	
	HookEvent("player_death", duels_Death, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);

	HookEvent("weapon_reload", Event_WeaponFireOnEmpty, EventHookMode_Post);
	HookEvent("weapon_fire_on_empty", Event_WeaponFireOnEmpty, EventHookMode_Post);
	HookEvent("decoy_started", Event_DecoyStarted, EventHookMode_Post);
	
	SetCookieMenuItem(DuelBlockCookieMenu_Handler, 0, "Duel Block");
	
	for(new i=1;i <= MaxClients;i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public Action:cmd_ReloadDuels(client, args)
{
	if(IsAnyDuelRunning())
	{
		RP_PrintToChat(client, "Could not reload Duels plugin");
		return Plugin_Handled;
	}
	
	ReloadPlugin();
	
	return Plugin_Handled;
}

public OnMapStart()
{
	hTimer_SwapShot = INVALID_HANDLE;
	hTimer_NotifyRestart = INVALID_HANDLE;
	
	PrecacheModel(DodgeballModel, true);

	for(new i=1;i <= MaxClients;i++)
		g_LastInvitedDuel[i] = 0.0;
		
	hTimer_BlockAttacks = CreateTimer(1.0, Timer_BlockAttacks, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	
	new String:MapName[PLATFORM_MAX_PATH];
	
	GetCurrentMap(MapName, sizeof(MapName));
	
	
	Format(MapName, sizeof(MapName), "maps/%s.txt", MapName);
	
	AddFileToDownloadsTable(MapName);
}

public Action:Timer_BlockAttacks(Handle:hTimer)
{
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(!IsPlayerAlive(i))
			continue;
			
		else if(!IsClientDueling(i))
			continue;
		
		new enGame:CurrentGame = GetDuelGameByClient(i);
		
		if(GetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue") <= 0.0)
		{
			new activeWeapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
			
			SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.5);
			SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.5);
			
			continue;
		}
		
		else if(CurrentGame == DUEL_SCOPEAWP || CurrentGame == DUEL_SCOPESSG08)
		{
			new activeWeapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
			
			SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.5);
			
			continue;
		}
		
		else if(CurrentGame == DUEL_BACKSTABS)
		{
			new activeWeapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
			
			SetEntPropFloat(activeWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 1.5);
		}
	}
}

public int DuelBlockCookieMenu_Handler(int client, CookieMenuAction action, int info, char[] buffer, int maxlen)
{
	if(action != CookieMenuAction_SelectOption)
		return;
		
	ShowDuelBlockMenu(client);
} 
public void ShowDuelBlockMenu(int client)
{
	Handle hMenu = CreateMenu(DuelBlockMenu_Handler);
	
	AddMenuItem(hMenu, "", "Yes");
	AddMenuItem(hMenu, "", "No");


	SetMenuExitBackButton(hMenu, true);
	SetMenuExitButton(hMenu, true);
	RP_SetMenuTitle(hMenu, "Duel block status: %s\n\nEnable Duel Block?", IsClientDuelBlock(client) ? "Enabled" : "Disabled");
	DisplayMenu(hMenu, client, 30);
}

public int DuelBlockMenu_Handler(Handle hMenu, MenuAction action, int client, int item)
{
	if(action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if(item == MenuCancel_ExitBack)
	{
		ShowCookieMenu(client);
	}
	else if(action == MenuAction_Select)
	{
		SetClientDuelBlock(client, !item);
		
		ShowDuelBlockMenu(client);
	}
	return 0;
}

public Action:timer_FixDoors(Handle:handle, any:data)
{
	new entity = -1;
	new iHammerID;
	while ((entity = FindEntityByClassname(entity, "func_tanktrain")) != -1)
	{
		iHammerID = GetEntProp(entity, PropType:1, "m_iHammerID", 4, 0);
		if (iHammerID == 857646 || 857648)
		{
			AcceptEntityInput(entity, "StartBackward", -1, -1, 0);
			AcceptEntityInput(entity, "Lock", -1, -1, 0);
		}
	}
	return Plugin_Continue;
}


public OnEntityCreated(entity, const String:Classname[])
{	
	if(StrEqual(Classname, "decoy_projectile"))
    {
		SDKHook(entity, SDKHook_SpawnPost, SpawnPost_Grenade)
	}
}

public SpawnPost_Grenade(entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, SpawnPost_Grenade);
		
	if(!IsValidEdict(entity))
		return;
	
	new thrower = GetEntityOwner(entity);
	
	if(thrower == -1)
		return;
	
	else if(!IsClientDueling(thrower))
		return;
		
	RemoveAllWeapons(thrower);
	GivePlayerItem(thrower, "weapon_decoy");
	SetEntPropString(entity, Prop_Data, "m_iName", "Dodgeball");
	RequestFrame(Decoy_FixAngles, entity);
	SDKHook(entity, SDKHook_TouchPost, Event_DecoyTouch);
	RequestFrame(Decoy_Chicken, entity);
} 

public Decoy_Chicken(entity)
{
	SetEntityModel(entity, DodgeballModel);
} 

public Event_DecoyTouch(decoy, toucher)
{
	new String:Classname[50];
	GetEdictClassname(toucher, Classname, sizeof(Classname));
	if(!IsPlayer(toucher))
	{
		new SolidFlags = GetEntProp(toucher, Prop_Send, "m_usSolidFlags")
		
		if(!(SolidFlags & 0x0004)) // Buy zone and shit..
		{
			if(StrEqual(Classname, "func_breakable"))
			{
				AcceptEntityInput(decoy, "Kill");
				return;
			}	
			SetEntPropString(decoy, Prop_Data, "m_iName", "Dodgeball NoKill");
		}

	}	
	else
	{
		new String:TargetName[50];
		GetEntPropString(decoy, Prop_Data, "m_iName", TargetName, sizeof(TargetName));
		
		if(StrContains(TargetName, "NoKill", false) != -1)
			return;

		new thrower = GetEntityOwner(decoy);
		
		if(!IsClientDueling(thrower) || thrower == toucher)
			return;

		if(IsClientDueling(toucher))
		{
			FinishHim(toucher, thrower);
			AcceptEntityInput(decoy, "Kill");
		}
	}
}

public Decoy_FixAngles(entity)
{
	if(!IsValidEntity(entity))
		return;
	
	new Float:Angles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", Angles);
	
	Angles[2] = 0.0;
	Angles[0] = 0.0;
	SetEntPropVector(entity, Prop_Data, "m_angRotation", Angles);
	
	RequestFrame(Decoy_FixAngles, entity);
}


public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponCanUse, Event_WeaponPickup);
	SDKHook(client, SDKHook_TraceAttack, Event_TraceAttack);
	SDKHook(client, SDKHook_SetTransmit, Event_SetTransmit);
}

public Action:Event_SetTransmit(client, viewer)
{
	if(!IsPlayer(viewer))
		return Plugin_Continue; 
	
	new arena = GetClientDuelArena(viewer);
	
	if(arena == -1)
		return Plugin_Continue;
		
	else if(GetClientDuelArena(client) == arena)
		return Plugin_Continue;
		
	return Plugin_Handled;
		
}

public Action:Event_WeaponPickup(client, weapon) 
{
	if(!IsClientDueling(client))
		return Plugin_Continue;
		
	decl String:Classname[32]; 
	GetEdictClassname(weapon, Classname, sizeof(Classname)); 
	
	switch(GetDuelGameByClient(client))
	{
		case DUEL_S4SDeagle, DUEL_SUPERDEAGLE:
		{
			if(!StrEqual(Classname, "weapon_deagle", true))
			{
				AcceptEntityInput(weapon, "Kill");
				return Plugin_Handled;
			}	
		}
		case DUEL_KNIFE, DUEL_1HPKNIFE, DUEL_BACKSTABS:
		{
			if(!IsKnifeClass(Classname))
			{
				AcceptEntityInput(weapon, "Kill");
				return Plugin_Handled;
			}	
		}
		case DUEL_SCOPEAWP, DUEL_HSAWP:
		{
			if(!StrEqual(Classname, "weapon_awp", true))
			{
				AcceptEntityInput(weapon, "Kill");
				return Plugin_Handled;
			}	
		}
		case DUEL_SCOPESSG08:
		{
			if(!StrEqual(Classname, "weapon_ssg08", true))
			{
				AcceptEntityInput(weapon, "Kill");
				return Plugin_Handled;
			}	
		}
		case DUEL_DODGEBALL:
		{
			if(!StrEqual(Classname, "weapon_decoy", true))
			{
				AcceptEntityInput(weapon, "Kill");
				return Plugin_Handled;
			}	
		}
	}
	
	return Plugin_Continue;
}


public Action:CS_OnCSWeaponDrop(client, weapon)
{
	if(!IsClientDueling(client))
		return Plugin_Continue;
		
	return Plugin_Handled;
}
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(BypassBlockers)
		return Plugin_Continue;
	
	if( ( IsClientDueling(victim) && !IsClientDueling(attacker) ) || ( IsClientDueling(attacker) && !IsClientDueling(victim) ) )
	{
		damage = 0.0;
		
		return Plugin_Changed;
	}
	
	if(IsClientDueling(victim) && IsClientDueling(attacker))
	{	
		if(GetDuelGameByClient(victim) == DUEL_SUPERDEAGLE)
			BitchSlapBackwards(victim, attacker, 5150.0);
	}
	return Plugin_Continue;
}

public Action:OnItemUsed(int client, int item)
{
	if(IsClientDueling(client))
	{
		RP_PrintToChat(client, "You cannot use items while in a duel.");
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:RolePlay_OnKarmaChanged(client, &karma, String:Reason[])
{
	if(IsClientDueling(client))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:RolePlay_ShouldSeeBountyMessage(client)
{
	if(IsClientDueling(client))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
public Action:RolePlay_OnBountySet(client)
{
	if(IsClientDueling(client))
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:duels_Death(Handle:hEvent, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsClientDueling(client))
	{
		new arena = GetClientDuelArena(client);
		
		Duel duel;
		
		GetArrayArray(Array_Duels, arena, duel);
				
		new rival = GetClientRival(client);
		
		new prizePool;
		
		if(CheckCommandAccess(rival, "sm_vip", ADMFLAG_CUSTOM2))
			prizePool = duel.PrizePool;
		
		else
			prizePool = RoundFloat(float(duel.PrizePool) * (1.0 - (DUEL_TAX / 100.0)));
		
		new String:sPrice[16];
		AddCommas(prizePool, ",", sPrice, sizeof(sPrice));
		
		if(CheckCommandAccess(rival, "sm_vip", ADMFLAG_CUSTOM2))
			RP_PrintToChatAll("\x02%N\x01 has won \x02%N\x01 in the duel, and has receieved \x02$%s\x01 cash (0%%\x05 VIP tax\x01)!", rival, client, sPrice);
		
		else	
			RP_PrintToChatAll("\x02%N\x01 has won \x02%N\x01 in the duel, and has receieved \x02$%s\x01 cash (%.0f%% tax)!", rival, client, sPrice, DUEL_TAX);

		GiveClientCashNoGangTax(rival, BANK_CASH, prizePool);
		
		duel.PrizePool = 0;
		duel.FirstDuelist = 0;
		duel.SecondDuelist = 0;
		
		SetArrayArray(Array_Duels, arena, duel);
		
		g_InvitedClient[rival] = -1;
		g_InvitedClient[client] = -1;
		
		RemoveAllWeapons(rival);
		
		SetClientArmor(rival, 0);
		
		CS_RespawnPlayer(rival);
		
		RolePlayLog("%N has won %N in a duel for (%i).", rival, client, prizePool);
		
		TriggerTimer(hTimer_BlockAttacks, true);
		
		return Plugin_Continue;
	}
	return Plugin_Continue;
}


public Action:Event_TraceAttack(victim, &attacker, &inflictor, &Float:damage, &damagetype, &ammotype, hitbox, hitgroup)
{
	if(!IsClientDueling(attacker))
		return Plugin_Continue;

	new enGame:CurrentGame = GetDuelGameByClient(attacker);
	
	if(CurrentGame == DUEL_BACKSTABS)
	{
		
		new weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
			
		new String:Classname[50];
		GetEdictClassname(weapon, Classname, sizeof(Classname));
		if(strncmp(Classname, "weapon_knife", 12) == 0)
		{
			if(damage < 69) // Knife should deal 76 max.
			{
				damage = 0.0;
				return Plugin_Changed;
			}
		}
	}
	else if(CurrentGame == DUEL_HSAWP)
	{
		if(hitgroup != 1)
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action:Event_WeaponFireOnEmpty(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		
	if(!IsClientDueling(client))
		return;
		
	else if (GetDuelGameByClient(client) == DUEL_S4SDeagle)
		return;
	
	new weapon = EntRefToEntIndex(g_WeaponRef[client]);
	
	if(weapon == -1)
		return;
		
	SetClientAmmo(client, weapon, 90);
}

public Action:Event_WeaponFire(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(!IsClientDueling(client))
		return;
		
	else if (GetDuelGameByClient(client) != DUEL_S4SDeagle)
		return;
	
	new String:Classname[50];
	GetEventString(hEvent, "weapon", Classname, sizeof(Classname));
	
	if(IsKnifeClass(Classname))
		return;
	
	new rival = GetClientRival(client);
	PrintCenterText(rival, "It's your turn to shoot!");
	
	new entity = EntRefToEntIndex(g_WeaponRef[rival]);
	
	if(entity == INVALID_ENT_REFERENCE)
	{
		PrintCenterText(client, "Duel terminated due to bug.");
		PrintCenterText(rival, "Duel terminated due to bug.");
		
		Duel duel;
		
		new arena = GetClientDuelArena(client);
		
		GetArrayArray(Array_Duels, arena, duel);
		
		
		GiveClientCashNoGangTax(duel.FirstDuelist, BANK_CASH, duel.PrizePool / 2);
		GiveClientCashNoGangTax(duel.SecondDuelist, BANK_CASH, duel.PrizePool / 2);
		
		RemoveAllWeapons(duel.FirstDuelist);
		CS_RespawnPlayer(duel.FirstDuelist);
		
		RemoveAllWeapons(duel.SecondDuelist);
		CS_RespawnPlayer(duel.SecondDuelist);
		
		duel.PrizePool = 0;
		duel.FirstDuelist = 0;
		duel.SecondDuelist = 0;
		
		SetArrayArray(Array_Duels, arena, duel);
		
		return;
	}
	
	SetWeaponClip(entity, 1);
	
	if(hTimer_SwapShot != INVALID_HANDLE)
	{
		CloseHandle(hTimer_SwapShot);
		
		hTimer_SwapShot = INVALID_HANDLE;
	}
	
	new Handle:DP = INVALID_HANDLE;
	
	hTimer_SwapShot = CreateDataTimer(1.0, Timer_CheckSwapShot, DP, TIMER_FLAG_NO_MAPCHANGE);
	
	WritePackCell(DP, rival);
	WritePackCell(DP, 30);
}

public Action:Timer_CheckSwapShot(Handle:hTimer, Handle:DP)
{
	hTimer_SwapShot = INVALID_HANDLE;
	
	ResetPack(DP);
	
	new client = ReadPackCell(DP);
	
	new TimeLeft = ReadPackCell(DP) - 1;
	
	if(!IsClientDueling(client))
		return;
	
	if(TimeLeft <= 0)
	{
		new rival = GetClientRival(client);
		
		new ent1 = EntRefToEntIndex(g_WeaponRef[rival]);
		new ent2 = EntRefToEntIndex(g_WeaponRef[client]);
		
		if(ent1 == INVALID_ENT_REFERENCE || ent2 == INVALID_ENT_REFERENCE)
		{
			PrintCenterText(client, "Duel terminated due to bug.");
			PrintCenterText(rival, "Duel terminated due to bug.");
			
			Duel duel;
		
			new arena = GetClientDuelArena(client);
			
			GetArrayArray(Array_Duels, arena, duel);
			
			
			GiveClientCashNoGangTax(duel.FirstDuelist, BANK_CASH, duel.PrizePool / 2);
			GiveClientCashNoGangTax(duel.SecondDuelist, BANK_CASH, duel.PrizePool / 2);
			
			RemoveAllWeapons(duel.FirstDuelist);
			CS_RespawnPlayer(duel.FirstDuelist);
			
			RemoveAllWeapons(duel.SecondDuelist);
			CS_RespawnPlayer(duel.SecondDuelist);
			
			duel.PrizePool = 0;
			duel.FirstDuelist = 0;
			duel.SecondDuelist = 0;
			
			SetArrayArray(Array_Duels, arena, duel);
			
			return;
		}
		
		SetWeaponClip(ent1, 1);
		SetWeaponClip(ent2, 0);
		
		hTimer_SwapShot = CreateDataTimer(1.0, Timer_CheckSwapShot, DP, TIMER_FLAG_NO_MAPCHANGE);
		
		WritePackCell(DP, rival);
		WritePackCell(DP, 30);
	}
	else
	{
		
		new String:TempFormat[256];
		Format(TempFormat, sizeof(TempFormat), "[Duels] You have %i seconds to shoot before losing your turn", TimeLeft);
		Hud_Message(client, TempFormat, 255, 0, 0, -1.0, 0.21, 2.7, 0.1, 0.1);
		
		hTimer_SwapShot = CreateDataTimer(1.0, Timer_CheckSwapShot, DP, TIMER_FLAG_NO_MAPCHANGE);
		
		WritePackCell(DP, client);
		
		WritePackCell(DP, TimeLeft);
	}
}

public Action:Event_DecoyStarted(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{	
	new entity = GetEventInt(hEvent, "entityid");
	
	new String:TargetName[50];
	
	GetEntPropString(entity, Prop_Data, "m_iName", TargetName, sizeof(TargetName));
	
	if(StrContains(TargetName, "Dodgeball", true) == -1)
		return Plugin_Continue;
	
	AcceptEntityInput(entity, "Kill");
	
	return Plugin_Continue;
}

public OnClientConnected(client)
{
	g_LastInvitedDuel[client] = 0.0;
}
public OnClientDisconnect(client)
{
	if(g_InvitedClient[client] != -1)
		g_InvitedClient[g_InvitedClient[client]] = -1;
	
	g_LastInvitedDuel[client] = 0.0;
	
	if(!IsClientDueling(client))
		return;
	
	new arena = GetClientDuelArena(client);
	
	Duel duel;
	
	GetArrayArray(Array_Duels, arena, duel);
	
	new rival = GetClientRival(client);
	
	new prizePool;
	
	if(CheckCommandAccess(rival, "sm_vip", ADMFLAG_CUSTOM2))
		prizePool = duel.PrizePool;
	
	else
		prizePool = RoundFloat(float(duel.PrizePool) * (1.0 - (DUEL_TAX / 100.0)));
	
	new String:sPrice[16];
	AddCommas(prizePool, ",", sPrice, sizeof(sPrice));
	
	if(CheckCommandAccess(rival, "sm_vip", ADMFLAG_CUSTOM2))
		RP_PrintToChatAll("\x02%N\x01 has won \x02%N\x01 in the duel, and has receieved \x02$%s\x01 cash (0%%\x05 VIP tax\x01)!", rival, client, sPrice);
	
	else	
		RP_PrintToChatAll("\x02%N\x01 has won \x02%N\x01 in the duel, and has receieved \x02$%s\x01 cash (%.0f%% tax)!", rival, client, sPrice, DUEL_TAX);

	GiveClientCashNoGangTax(rival, BANK_CASH, prizePool);
	
	duel.PrizePool = 0;
	duel.FirstDuelist = 0;
	duel.SecondDuelist = 0;
	
	SetArrayArray(Array_Duels, arena, duel);
	
	g_InvitedClient[g_InvitedClient[client]] = -1;
	g_InvitedClient[client] = -1;
	
	RemoveAllWeapons(rival);
	
	SetClientArmor(rival, 0);
	
	CS_RespawnPlayer(rival);
	
	RolePlayLog("%N has won %N in a duel for (%i).", rival, client, prizePool);
	
	TriggerTimer(hTimer_BlockAttacks, true);
}



public Action:cmd_DuelAccept(client, args)
{
	
	if(g_InvitedClient[client] == -1 || !IsClientInGame(g_InvitedClient[client]))
	{
		RP_PrintToChat(client, "You don't have a duel invite, or he disconnected.");
		return Plugin_Handled;
	}
	
	else if(g_LastInvitedDuel[g_InvitedClient[client]] > GetGameTime() && g_InvitedClient[client] != -1)
		TryStartDuel(client);
		
	else
		RP_PrintToChat(client, "You don't have a duel invite.");
	
	return Plugin_Handled;
}
public Action:cmd_DuelBlock(client, args)
{
	new bool:isBlock = SetClientDuelBlock(client, !IsClientDuelBlock(client))
	
	RP_PrintToChat(client, "Duel block status is \x07%s", isBlock ? "enabled" : "disabled");
	
	return Plugin_Handled;
}

public Action:cmd_Duel(client, args)
{	
	if (args < 1)
	{
		RP_PrintToChat(client, "Syntax: /duel <cash amount>");
		return Plugin_Handled;
	}
	
	else if(g_LastInvitedDuel[client] > GetGameTime())
	{
		RP_PrintToChat(client, "Your last invitation did not expire yet.");
		
		return Plugin_Handled;
	}
	
	new String:arg[11];
	GetCmdArg(1, arg, sizeof(arg));
	new amount = StringToInt(arg, 10);

	new String:Reason[128];
	
	if(!IsClientEligibleForDuel(client, amount, Reason, sizeof(Reason)))
	{
		return Plugin_Handled;
	}
	
	g_DuelAmount[client] = amount;

	ShowGameMenu(client);

	return Plugin_Handled;
}

public ShowGameMenu(client)
{
	new Handle:hMenu = CreateMenu(Game_MenuHandler);
	
	for(new i=0;i < sizeof(DuelNames);i++)
		AddMenuItem(hMenu, "", DuelNames[i]);
	
	RP_SetMenuTitle(hMenu, "Select a game for the duel.");
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public Game_MenuHandler(Handle:hMenu, MenuAction:action, client, item)
{
	if(action == MenuAction_End)
		CloseHandle(hMenu);
	
	if(action == MenuAction_Select)
	{
		SelectedDuelGame[client] = view_as<enGame>(item);
	
		ShowOpponentMenu(client);
	}
}


public ShowOpponentMenu(client)
{	
	new String:UID[11], String:Name[64];
	new Handle:hMenu = CreateMenu(Opponent_MenuHandler);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(client == i)
			continue;
			
		else if(!IsClientInGame(i))
			continue;
		
		else if(!IsPlayerAlive(i))
			continue;
			
		else if(GetClientTeam(i) == CS_TEAM_CT)
			continue;
			
		else if(IsClientDuelBlock(i))
			continue;
			
		else if(!IsClientEligibleForDuel(i, g_DuelAmount[client]))
			continue;
		
		IntToString(GetClientUserId(i), UID, sizeof(UID));
		GetClientName(i, Name, sizeof(Name));
		AddMenuItem(hMenu, UID, Name);
	}
	
	RP_SetMenuTitle(hMenu, "Select a player to %s against.", DuelNames[SelectedDuelGame[client]]);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public Opponent_MenuHandler(Handle:hMenu, MenuAction:action, client, item)
{
	if(action == MenuAction_End)
		CloseHandle(hMenu);
	
	if(action == MenuAction_Select)
	{
		new String:UID[20], String:Display[1], style;
		GetMenuItem(hMenu, item, UID, sizeof(UID), style, Display, sizeof(Display));
		
		new target = GetClientOfUserId(StringToInt(UID));
		
		if(target == 0)
		{
			RP_PrintToChat(client, "Target player left the server.");
		}
		else if (GetClientCash(target, BANK_CASH) < g_DuelAmount[client])
		{
			RP_PrintToChat(client, "\x04%N \x01doesn't have enough \x07cash \x01in his bank.", target);

		}
		
		else if (g_LastInvitedDuel[target] > GetGameTime())
		{
			RP_PrintToChat(client, "\x04%N \x01has invited someone else to \x07duel", target);
		}
		else if (GetClientTeam(target) == 3)
		{
			RP_PrintToChat(client, "Dueling a \x07policeman");

		}
		else if (RP_IsClientInJail(target))
		{
			RP_PrintToChat(client, "You cant duel someone in \x07jail.");

		}
		else if (RP_GetKarma(client) >= ARREST_KARMA && GetPlayerCount(CS_TEAM_CT) > 0)
		{
			RP_PrintToChat(client, "You cant duel when you have more than %i karma.", ARREST_KARMA);

		}
		else if (RP_GetKarma(client) >= BOUNTY_KARMA)
		{
			RP_PrintToChat(client, "You cant duel when you have more than %i karma.", BOUNTY_KARMA);
		}
		else if(RP_IsPlayerSuiciding(target))
		{
			RP_PrintToChat(client, "You cannot duel someone who is committing \x07suicide.");

		}
		else if(!IsPlayerAlive(target))
		{
			RP_PrintToChat(client, "You cannot duel someone who is \x07dead.");
		}
		else if(IsClientDuelBlock(target))
		{
			RP_PrintToChat(client, "Your opponent does not accept duel invites");
		}
		else if(IsPlayerInAdminRoom(target))
		{
			RP_PrintToChat(client, "You cannot duel while in Admin Room!");
		}
		else
		{
			if(g_LastInvitedDuel[target] > GetGameTime())
			{
				RP_PrintToChat(client, "%N is already trying to accept a duel", target);
				
				return;
			}
			else if(g_InvitedClient[target] != -1 && g_LastInvitedDuel[g_InvitedClient[target]] > GetGameTime())
			{
				RP_PrintToChat(client, "%N is trying to accept a duel by %N, wait a bit to prevent sniping.", target, g_InvitedClient[target]);
				
				return;
			}

			g_InvitedClient[target] = client;
			g_InvitedClient[client] = -1; // Prevents accepting your own request, causing unknown bugs.
			
			g_LastInvitedDuel[client] = GetGameTime() + 15.0;
			
			ShowConfirmDuelMenu(client, target);
		}
	}
}

public ShowConfirmDuelMenu(client, target)
{
	
	new String:sPrice[16];
	AddCommas(g_DuelAmount[client], ",", sPrice, sizeof(sPrice));
	
	RP_PrintToChat(target, "\x04%N \x01wants to %s with you for $%s", client, DuelNames[SelectedDuelGame[client]], sPrice);
	RP_PrintToChat(target, "Use\x04 !duelaccept\x01 or\x04 !da\x01 to accept the duel");
}

public Confirm_MenuHandler(Handle:hMenu, MenuAction:action, target, item)
{
	if(action == MenuAction_End)
		CloseHandle(hMenu);
	
	if(action == MenuAction_Select)
	{
		switch(item)
		{
			case 5:
			{
				TryStartDuel(target);
			}
			
			default:
			{
				new client = g_InvitedClient[target];
				RP_PrintToChat(client, "\x04%N \x01declined the duel with \x07you", target);
				RP_PrintToChat(target, "You have declined the duel with \x07%N", g_InvitedClient[target]);
				RP_PrintToChat(target, "You can use !duelblock to permanently stop accepting duel requests.");
				
				g_LastInvitedDuel[target] = 0.0;
				g_LastInvitedDuel[client] = 0.0;
				
				g_Invited[target] = false;
				g_Invited[client] = false;
			}
		}
	}
}	

TryStartDuel(target)
{
	new client = g_InvitedClient[target];
	
	if(client == -1)
	{
		RP_PrintToChat(target, "\x01The player who asked you to a duel is not \x07connected.");
		return;
	}
	
	g_InvitedClient[client] = target;
	
	new amount = g_DuelAmount[client];
	
	if (GetClientCash(target, BANK_CASH) < amount || GetClientCash(target, BANK_CASH) < amount)
	{
		RP_PrintToChat(target, "You/opponent dont have enough cash in \x07bank.");
		return;
	}
	else if (GetClientTeam(client) == CS_TEAM_CT || GetClientTeam(target) == CS_TEAM_CT)
	{
		RP_PrintToChat(target, "Dueling as/with a policeman");
		return;
	}
	else if(AFKM_IsClientAFK(client) || AFKM_IsClientAFK(g_InvitedClient[client]))
	{
		RP_PrintToChat(client, "You cannot duel while you / opponent are \x07AFK!.");
		return;
	}

	else if (RP_IsClientInJail(client) || RP_IsClientInJail(target))
	{
		RP_PrintToChat(target, "You cant duel when you or your opponent in \x07jail.");
		return;
	}
	else if (RP_IsPlayerSuiciding(client) || RP_IsPlayerSuiciding(target))
	{
		RP_PrintToChat(target, "You cannot duel while you / opponent committing \x07suicide!");
		return;
	}
	else if(IsPlayerInAdminRoom(client) || IsPlayerInAdminRoom(target))
	{
		RP_PrintToChat(target, "You cannot duel while you / opponent in\x07 admin room!");
		return;
	}
	else if(!IsPlayerAlive(client) || !IsPlayerAlive(target))
	{
		RP_PrintToChat(target, "You cannot duel while you / opponent are\x07 dead!");
		return;
	}
	else if(UsefulCommands_IsServerRestartScheduled())
	{
		RP_PrintToChat(target, "You cannot duel when a server restart is planned by an admin!");
		return;
	}
	else if(IsClientDueling(client) || IsClientDueling(g_InvitedClient[client]))
	{
		RP_PrintToChat(target, "You cannot duel while you / opponent are \x07dueling!.");
		return;
	}
	else if(RP_IsUserInArena(client) || RP_IsUserInArena(target))
	{
		RP_PrintToChat(target, "You cannot duel while you / opponent are in \x07arena!.");
		return;
	}
	else if(RP_IsUserInEvent(client) || RP_IsUserInEvent(target))
	{
		RP_PrintToChat(target, "You cannot duel while you / opponent are in \x07event!.");
		return;		
	}

	new arena = FindUnoccupiedArena();
	
	if(arena == -1)
	{
		RP_PrintToChat(client, "All arenas are occupied. Please wait until one frees.");
		return;
	}
	
	Duel duel;
	OriginsDuel originDuel;
	
	GetArrayArray(Array_OriginsDuels, arena, originDuel);
	
	RP_TryUncuffClient(client);
	RP_TryUncuffClient(target);
	
	// Forces random position regardless of inviting, just for safety.
	if(GetRandomInt(0, 1) == 1)
	{
		duel.FirstDuelist = client;
		duel.SecondDuelist = target;
	}
	else
	{
		duel.FirstDuelist = target;
		duel.SecondDuelist = client;			
	}
	
	duel.DuelGame = SelectedDuelGame[client];
	duel.PrizePool = amount * 2;
	
	
	GiveClientCashNoGangTax(client, BANK_CASH, -1 * amount);
	GiveClientCashNoGangTax(target, BANK_CASH, -1 * amount);

	new Float:vel1[3], Float:vel2[3];
	
	vel1 = {0.0, 0.0, -256.0};
	vel2 = {0.0, 0.0, -256.0};
	
	vel1[0] = GetRandomFloat(-10.0, 10.0);
	vel2[0] = GetRandomFloat(-10.0, 10.0);
		
	TeleportEntity(client, originDuel.FirstOrigin, NULL_VECTOR, vel1);
	TeleportEntity(target, originDuel.SecondOrigin, NULL_VECTOR, vel2);
	
	SetEntityHealth(client, 100);
	SetEntityHealth(target, 100);
	
	RemoveAllWeapons(client);
	RemoveAllWeapons(target);
	
	switch(duel.DuelGame)
	{
		case DUEL_S4SDeagle:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_deagle"));
			g_WeaponRef[target] = EntIndexToEntRef(GivePlayerItem(target, "weapon_deagle"));
			
			SetClientAmmo(client, EntRefToEntIndex(g_WeaponRef[client]), 0);
			SetClientAmmo(target, EntRefToEntIndex(g_WeaponRef[target]), 0);
		}
		
		case DUEL_KNIFE:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_knife"));
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(target, "weapon_knife"));
		}
		
		case DUEL_1HPKNIFE:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_knife"));
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(target, "weapon_knife"));
			
			SetEntityHealth(client, 1);
			SetEntityHealth(target, 1);
		}
		case DUEL_BACKSTABS:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_knife"));
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(target, "weapon_knife"));
		}
		
		case DUEL_SCOPEAWP:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_awp"));
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(target, "weapon_awp"));
		}
		
		case DUEL_SCOPESSG08:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_ssg08"));
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(target, "weapon_ssg08"));
		}
		
		case DUEL_HSAWP:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_awp"));
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(target, "weapon_awp"));
		}
		
		case DUEL_DODGEBALL:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_decoy"));
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(target, "weapon_decoy"));
		}
		
		case DUEL_SUPERDEAGLE:
		{
			g_WeaponRef[client] = EntIndexToEntRef(GivePlayerItem(client, "weapon_deagle"));
			g_WeaponRef[target] = EntIndexToEntRef(GivePlayerItem(target, "weapon_deagle"));

			SetEntityHealth(client, 500);
			SetEntityHealth(target, 500);
		}
	}
	
	SetArrayArray(Array_Duels, arena, duel);
	CreateTimer(0.1, Timer_BlockAttacks, _, TIMER_FLAG_NO_MAPCHANGE);

	new String:sPrice[16];
	AddCommas(duel.PrizePool, ",", sPrice, sizeof(sPrice));
	
	RP_PrintToChatAll("A \x03%s \x01between \x02%N\x01 and \x02%N\x01 has started on arena #%i.", DuelNames[duel.DuelGame], client, target, arena + 1);
	RP_PrintToChatAll("The winner of the duel will receive \x02$%s\x01 cash.", sPrice);
	
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.0, 0);
	SetEntPropFloat(target, Prop_Data, "m_flLaggedMovementValue", 0.0, 0);
	
	SetClientArmor(client, 100);
	SetClientArmor(target, 100);
	

	Hud_Message(client, "[Duels] The duel will start in 3 seconds, be ready!", 255, 0, 0, -1.0, 0.21, 2.7, 0.1, 0.1);
	Hud_Message(target, "[Duels] The duel will start in 3 seconds, be ready!", 255, 0, 0, -1.0, 0.21, 2.7, 0.1, 0.1);

	new Handle:pack;
	CreateDataTimer(1.0, timer_Unfreeze, pack);
	
	WritePackCell(pack, GetClientUserId(client));
	WritePackCell(pack, GetClientUserId(target));
	WritePackCell(pack, 2);
}


public ResetClipAndFrame(client)
{		
	RequestFrame(ResetClip, client);
}
public ResetClip(client)
{
	if(!IsClientInGame(client))
		return;
		
	new target = g_InvitedClient[client];
	
	if(!IsClientInGame(target))
		return;
	
	new ent1 = EntRefToEntIndex(g_WeaponRef[target]);
	new ent2 = EntRefToEntIndex(g_WeaponRef[client]);
	
	if(ent1 == INVALID_ENT_REFERENCE || ent2 == INVALID_ENT_REFERENCE)
	{
		PrintCenterText(client, "Duel terminated due to bug.");
		PrintCenterText(target, "Duel terminated due to bug.");
		
		Duel duel;
		
		new arena = GetClientDuelArena(client);
		
		GetArrayArray(Array_Duels, arena, duel);
		
		
		GiveClientCashNoGangTax(duel.FirstDuelist, BANK_CASH, duel.PrizePool / 2);
		GiveClientCashNoGangTax(duel.SecondDuelist, BANK_CASH, duel.PrizePool / 2);
		
		RemoveAllWeapons(duel.FirstDuelist);
		CS_RespawnPlayer(duel.FirstDuelist);
		
		RemoveAllWeapons(duel.SecondDuelist);
		CS_RespawnPlayer(duel.SecondDuelist);
		
		duel.PrizePool = 0;
		duel.FirstDuelist = 0;
		duel.SecondDuelist = 0;
		
		SetArrayArray(Array_Duels, arena, duel);
		
		return;
	}
	
	if(GetRandomInt(0, 1) == 1)
	{
		SetWeaponClip(ent2, 0);
		SetWeaponClip(ent1, 1);
		
		new Handle:DP = INVALID_HANDLE;
		
		hTimer_SwapShot = CreateDataTimer(1.0, Timer_CheckSwapShot, DP, TIMER_FLAG_NO_MAPCHANGE);
		
		WritePackCell(DP, target);
		WritePackCell(DP, 30);
	}
	else
	{
		SetWeaponClip(ent2, 1);
		SetWeaponClip(ent1, 0);
		
		new Handle:DP = INVALID_HANDLE;
		
		hTimer_SwapShot = CreateDataTimer(1.0, Timer_CheckSwapShot, DP, TIMER_FLAG_NO_MAPCHANGE);
		
		WritePackCell(DP, client);
		WritePackCell(DP, 30);
	}
}
public Action:timer_Unfreeze(Handle:timer, Handle:pack)
{
	new client;
	new target;
	new timeLeft;
	ResetPack(pack, false);
	client = GetClientOfUserId(ReadPackCell(pack));
	target = GetClientOfUserId(ReadPackCell(pack));
	
	timeLeft = ReadPackCell(pack);
	
	if(client == 0 || target == 0)
		return;
	
	else if(!IsClientDueling(client) || !IsClientDueling(target))
		return;
		

	if(timeLeft <= 0)
	{
		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0, 0);
		SetEntPropFloat(target, Prop_Data, "m_flLaggedMovementValue", 1.0, 0);
		
		if(GetDuelGameByClient(client) == DUEL_S4SDeagle)
			ResetClipAndFrame(client);
		
		CreateTimer(0.1, Timer_BlockAttacks, _, TIMER_FLAG_NO_MAPCHANGE);
		
		return;
	}
	else
	{
		new String:TempFormat[64];
		FormatEx(TempFormat, sizeof(TempFormat), "[Duels] The duel will start in %i second%s, be ready!", timeLeft, timeLeft == 1 ? "" : "s");
		
		Hud_Message(client, TempFormat, 255, 0, 0, -1.0, 0.21, 2.7, 0.1, 0.1);
		Hud_Message(target, TempFormat, 255, 0, 0, -1.0, 0.21, 2.7, 0.1, 0.1);
	

		CreateDataTimer(1.0, timer_Unfreeze, pack);
		
		WritePackCell(pack, GetClientUserId(client));
		WritePackCell(pack, GetClientUserId(target));
		WritePackCell(pack, timeLeft - 1);
	}
}
public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_Main");
	CreateNative("RP_IsUserInDuel", Native_Duel);
}

public Native_Duel(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(23, "Invalid client index (%d)", client);
	}
	if (!IsClientConnected(client))
	{
		return ThrowNativeError(23, "Client %d is not connected", client);
	}
	
	return IsClientDueling(client);
}

public Hud_Message(client, String:Msg[], r, g, b, Float:xpos, Float:ypos, Float:holdtime, Float:fadeintime, Float:fadeouttime)
{
	new String:buffer[32];
	new String:sx[32];
	new String:sy[32];
	FloatToString(ypos, sy, 32);
	FloatToString(xpos, sx, 32);
	new String:fadein[32];
	new String:fadeout[32];
	new String:sholdtime[32];
	FloatToString(fadeintime, fadein, 32);
	FloatToString(fadeouttime, fadeout, 32);
	FloatToString(holdtime, sholdtime, 32);
	FormatEx(buffer, 32, "%i %i %i", r, g, b);
	new ent = CreateEntityByName("game_text", -1);
	DispatchKeyValue(ent, "channel", "1");
	DispatchKeyValue(ent, "color", buffer);
	DispatchKeyValue(ent, "color2", "0 0 0");
	DispatchKeyValue(ent, "effect", "0");
	DispatchKeyValue(ent, "fadein", fadein);
	DispatchKeyValue(ent, "fadeout", fadeout);
	DispatchKeyValue(ent, "fxtime", "0.25");
	DispatchKeyValue(ent, "holdtime", sholdtime);
	DispatchKeyValue(ent, "message", Msg);
	DispatchKeyValue(ent, "spawnflags", "0");
	DispatchKeyValue(ent, "x", sx);
	DispatchKeyValue(ent, "y", sy);
	DispatchSpawn(ent);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "display", client, -1, 0);
	DispatchKeyValue(ent, "OnUser1", "!self,Kill,,2.0,-1");
	AcceptEntityInput(ent, "FireUser1", -1, -1, 0);
	
}

stock bool IsClientEligibleForDuel(int client, int amount, char[] Reason="", int len=0)
{
	new String:TempFormat[16];
	
	if (amount < DUEL_MIN_WAGE)
	{
		AddCommas(DUEL_MIN_WAGE, ",", TempFormat, sizeof(TempFormat));
		Format(Reason, len, "%s Amount must be bigger than %s.", TempFormat);

	}
	
	else if(amount > DUEL_MAX_WAGE)
	{
		AddCommas(DUEL_MAX_WAGE, ",", TempFormat, sizeof(TempFormat));
		Format(Reason, len, "%s Amount must be lower than %s.", TempFormat);

	}
	else if (GetClientCash(client, BANK_CASH) < amount)
	{
		Format(Reason, len, "%s You dont have enough cash in your bank.");

	}
	
	else if(IsClientDueling(client))
	{
		Format(Reason, len, "%s You cannot start a duel while you dueling");
	}
	else if (g_LastInvitedDuel[client] > GetGameTime())
	{
		Format(Reason, len, "%s Please wait till your invitation to \x02%N\x01 will be expired.", g_InvitedClient[client]);
	}
	else if (GetClientTeam(client) == 3)
	{
		Format(Reason, len, "%s Dueling as a policeman");

	}
	else if (RP_IsClientInJail(client))
	{
		Format(Reason, len, "%s You cant duel when you are in jail.");

	}
	else if (RP_GetKarma(client) >= ARREST_KARMA && GetPlayerCount(CS_TEAM_CT) > 0)
	{
		Format(Reason, len, "%s You cant duel when you have more than %i karma.", ARREST_KARMA);

	}
	else if (RP_GetKarma(client) >= BOUNTY_KARMA)
	{
		Format(Reason, len, "%s You cant duel when you have more than %i karma.", BOUNTY_KARMA);
	}
	else if(RP_IsPlayerSuiciding(client))
	{
		Format(Reason, len, "%s You cannot duel while committing suicide!");

	}
	else if(!IsPlayerAlive(client))
	{
		Format(Reason, len, "%s You cannot duel while committing suicide!");
	}
	else if(IsPlayerInAdminRoom(client))
	{
		Format(Reason, len, "%s You cannot duel while in Admin Room!");
	}
	else if(UsefulCommands_IsServerRestartScheduled())
	{
		Format(Reason, len, "%s You cannot duel when an admin is planning a server restart!");
	}
	
	else
		return true;
		
	return false;
}


stock SetClientAmmo(client, weapon, ammo)
{
  SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", ammo); //set reserve to 0
    
  new ammotype = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
  if(ammotype == -1) return;
  
  SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, ammotype);
}

stock SetWeaponClip(weapon, clip)
{
	SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
}

stock bool:IsKnifeClass(const String:classname[])
{
	if(StrContains(classname, "knife") != -1 || StrContains(classname, "bayonet") > -1)
		return true;
		
	return false;
}


stock GetEntityOwner(entity)
{
	return GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
}


stock FinishHim(victim, attacker)
{
	if(!IsClientInGame(victim) || !IsClientInGame(attacker))
		return;
	
	BypassBlockers = true;
	
	new String:weaponToGive[50];
	FindPlayerWeapon(attacker, weaponToGive, sizeof(weaponToGive));
	
	RemoveAllWeapons(victim);
	RemoveAllWeapons(attacker);
	
	new inflictor = GivePlayerItem(attacker, weaponToGive);
	SetEntityHealth(victim, 100);

	SDKHooks_TakeDamage(victim, inflictor, attacker, 32767.0, DMG_SLASH);
	
	BypassBlockers = false;
	
	
}


stock bool:FindPlayerWeapon(attacker, String:buffer[], length)
{
	new weapon = -1;
	
	weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
	
	if(weapon != -1)
	{
		GetEdictClassname(weapon, buffer, length);
		return true;
	}
		
	Format(buffer, length, "weapon_knife");
	return false;
}


stock int IsClientDuelBlock(int client)
{		
	char strDuelBlock[50];
	GetClientCookie(client, hCookie_DuelBlock, strDuelBlock, sizeof(strDuelBlock));
	
	if(strDuelBlock[0] == EOS)
	{
		SetClientDuelBlock(client, false);
		return false;
	}
	
	return view_as<bool>(StringToInt(strDuelBlock));
}

stock bool SetClientDuelBlock(int client, bool value)
{
	char strDuelBlock[50];
	
	IntToString(view_as<int>(value), strDuelBlock, sizeof(strDuelBlock));
	SetClientCookie(client, hCookie_DuelBlock, strDuelBlock);
	
	return value;
}


// Must be called after IsClientInDuel == true;

stock enGame GetDuelGameByClient(client)
{
	Duel duel;
	
	new arena = GetClientDuelArena(client);
	
	GetArrayArray(Array_Duels, arena, duel);
	
	return duel.DuelGame;
}

stock bool IsClientDueling(client)
{		
	return GetClientDuelArena(client) != -1;
}


// Returns duel arena, startin from 0. Returns -1 if client is not dueling.
stock int GetClientDuelArena(client)
{
	if(client == 0)
		return -1;
		
	new size = GetArraySize(Array_Duels);
	
	Duel duel;
	
	for (new i = 0; i < size;i++)
	{
		GetArrayArray(Array_Duels, i, duel);
		
		if(duel.FirstDuelist == client || duel.SecondDuelist == client)
			return i;
	}
	
	return -1;
}

stock int FindUnoccupiedArena()
{
	new size = GetArraySize(Array_OriginsDuels);
	
	for (new i = 0; i < size;i++)
	{
		Duel duel;
		
		GetArrayArray(Array_Duels, i, duel);
		
		if(duel.FirstDuelist != 0)
			continue;
			
		return i;
	}
	
	return -1;
}	

stock int GetClientRival(client)
{
	if(!IsClientDueling(client))
		return 0;
		
	new arena = GetClientDuelArena(client);
	
	Duel duel;
	
	GetArrayArray(Array_Duels, arena, duel);
	
	if(duel.FirstDuelist == client)
		return duel.SecondDuelist;
		
	return duel.FirstDuelist;
}


AddCommas(value, const String:seperator[], String:buffer[], bufferLen)
{
	new divisor = 1000;
	while (value >= 1000 || value <= -1000)
	{
		new offcut = value % divisor;
		value = RoundToFloor(float(value) / float(divisor));
		Format(buffer, bufferLen, "%c%03.d%s", seperator, offcut, buffer);
	}
	Format(buffer, bufferLen, "%d%s", value, buffer);
}

stock BitchSlapBackwards(victim, weapon, Float:strength) // Stole the dodgeball tactic from https://forums.alliedmods.net/showthread.php?t=17116
{
	new Float:origin[3], Float:velocity[3];
	GetEntPropVector(weapon, Prop_Data, "m_vecOrigin", origin);
	GetVelocityFromOrigin(victim, origin, strength, velocity);
	velocity[2] = strength / 10.0;
	
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
}


stock GetVelocityFromOrigin(ent, Float:fOrigin[3], Float:fSpeed, Float:fVelocity[3]) // Will crash server if fSpeed = -1.0
{
	new Float:fEntOrigin[3];
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", fEntOrigin);
	
	// Velocity = Distance / Time
	
	new Float:fDistance[3];
	fDistance[0] = fEntOrigin[0] - fOrigin[0];
	fDistance[1] = fEntOrigin[1] - fOrigin[1];
	fDistance[2] = fEntOrigin[2] - fOrigin[2];

	new Float:fTime = ( GetVectorDistance(fEntOrigin, fOrigin) / fSpeed );
	
	if(fTime == 0.0)
		fTime = 1 / (fSpeed + 1.0);
		
	fVelocity[0] = fDistance[0] / fTime;
	fVelocity[1] = fDistance[1] / fTime;
 	fVelocity[2] = fDistance[2] / fTime;

	return (fVelocity[0] && fVelocity[1] && fVelocity[2]);
}

stock bool:IsAnyDuelRunning()
{
	for (new i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(!IsClientDueling(i))
			continue;
			
		return true;
	}
	
	return false;
}
