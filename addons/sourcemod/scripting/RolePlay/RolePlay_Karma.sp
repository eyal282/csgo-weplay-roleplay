#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <Eyal-RP>
#include <fuckzones>

#define MIN_BOUNTY_REWARD 400
#define MAX_BOUNTY_REWARD 1400

public Plugin:myinfo =
{
	name = "RolePlay Karma",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = "https://steamcommunity.com/id/xflane/"
};

new g_iHitmanJob = -1;
new g_iLawyerJob = -1;
new g_iMedicJob = -1;
new g_iPoliceJob = -1;

new CASH_BONUS_ARREST_BOUNTY;

new g_iKarma[MAXPLAYERS+1];
new bool:LoadedFromTrie[MAXPLAYERS+1];
new Handle:g_smPlayersKarma;
new Handle:g_aBountyPlayers;
new Handle:g_aHPCPlayers;

new String:g_szBountyMessage[1024];
new sprLaserBeam;

new Handle:fw_ShouldSeeBountyMessage = INVALID_HANDLE;
new Handle:fw_OnKarmaChanged = INVALID_HANDLE;
new Handle:fw_OnKarmaChangedPost = INVALID_HANDLE;
new Handle:fw_OnBountySet = INVALID_HANDLE;

new bool:SpyKarma = false;
new bool:NoBountyJail = false;

new Handle:Trie_PoliceEco;

public RP_OnEcoLoaded()
{
	
	Trie_PoliceEco = RP_GetEcoTrie("Police");
	
	if(Trie_PoliceEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Police");
	
	new String:TempFormat[64];
	
	GetTrieString(Trie_PoliceEco, "CASH_BONUS_ARREST_BOUNTY", TempFormat, sizeof(TempFormat));
	
	CASH_BONUS_ARREST_BOUNTY = StringToInt(TempFormat);	
}
public Action:Command_SpyKarma(client, args)
{
	SpyKarma = !SpyKarma;
	
	return Plugin_Handled;
}

public Action:Command_NoBountyJail(client, args)
{
	NoBountyJail = !NoBountyJail;
	
	PrintToChatAll("Jail for death by bounty is now %s", NoBountyJail ? "Disabled" : "Enabled");
}
public OnPluginStart()
{
	NoBountyJail = false;
	
	g_aBountyPlayers = CreateArray(1);
	g_aHPCPlayers = CreateArray(1);
	
	g_smPlayersKarma = CreateTrie();
	
	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
	
	RegAdminCmd("sm_spykarma", Command_SpyKarma, ADMFLAG_ROOT);
	RegAdminCmd("sm_nobountyjail", Command_NoBountyJail, ADMFLAG_ROOT);
	
	fw_ShouldSeeBountyMessage = CreateGlobalForward("RolePlay_ShouldSeeBountyMessage", ET_Event, Param_Cell);
	fw_OnKarmaChanged = CreateGlobalForward("RolePlay_OnKarmaChanged", ET_Event, Param_Cell, Param_CellByRef, Param_String, Param_CellByRef);
	fw_OnKarmaChangedPost = CreateGlobalForward("RolePlay_OnKarmaChangedPost", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell);
	fw_OnBountySet = CreateGlobalForward("RolePlay_OnBountySet", ET_Event, Param_Cell);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		RP_UpdateScoreBoard_Karma(i);
	}
	
	if(RP_GetEcoTrie("Police") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public OnMapStart()
{
	sprLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", false);
	
	CreateTimer(1.0, Timer_NaturalKarmaLoss, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_NaturalKarmaLoss(Handle:hTimer)
{
	if(g_iLawyerJob == -1)
		g_iLawyerJob = RP_FindJobByShortName("LAW");
		
	if(g_iMedicJob == -1)
		g_iMedicJob = RP_FindJobByShortName("MED");
	
	if(g_iPoliceJob == -1)
		g_iPoliceJob = RP_FindJobByShortName("PM");
		
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(!IsPlayerAlive(i))
			continue;
			
		else if(RP_IsUserInDuel(i) || IsPlayerInAdminRoom(i))
			continue;

		Call_StartForward(fw_OnKarmaChanged);
		
		new karma;
		
		new String:Reason[64];
		karma = -1;
		
		new dummy_cell;
		
		if(g_iKarma[i] + karma < 0)
			karma = 0 - g_iKarma[i];
		
		FormatEx(Reason, sizeof(Reason), KARMA_LOSS_TIME_REASON);
		
		Call_PushCell(i);
		Call_PushCellRef(karma);
		Call_PushString(Reason);
		Call_PushCellRef(dummy_cell);
		
		new Action:Result;
		Call_Finish(Result);
		
		if(Result == Plugin_Handled || Result == Plugin_Stop)
			continue;	
		
		new Handle:data = CreateDataPack();
		
		WritePackCell(data, i);
		WritePackCell(data, karma);
		WritePackString(data, Reason);
		WritePackCell(data, 0);
		
		RequestFrame(DelayKarma, data);
		
		new pos;
		
		if(g_iKarma[i] < BOUNTY_KARMA)
		{
			pos = FindValueInArray(g_aBountyPlayers, i);
			if (pos != -1)
			{
				RemoveFromArray(g_aBountyPlayers, pos);
			}
		}
		
		if(g_iKarma[i] < ARREST_KARMA)
		{
			pos = FindValueInArray(g_aHPCPlayers, i);
			
			if (pos != -1)
			{
				RemoveFromArray(g_aHPCPlayers, pos);
			}
		}
	}
	
	CheckBountyMessage();
}

public Action RolePlay_OnKarmaChanged(int client, int &karma, char[] Reason, any &data)
{
	if(StrEqual(Reason, KARMA_TRESPASS_REASON))
	{
		if(g_iKarma[client] + karma >= BOUNTY_KARMA)
		{
			karma = (BOUNTY_KARMA - g_iKarma[client] - 1);
			
			if(karma < 0)
				karma = 0;
				
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public void RolePlay_OnKarmaChangedPost(int client, int karma, totalKarma, char[] Reason, any data)
{
	if(StrEqual(Reason, KARMA_TRESPASS_REASON))
	{
		PrintHintText(client, "You are<font color='#FF0000'> trespassing!!!</font>\nLeave<font color='#B3C100> before</font> you get <font color='#FF0000'>arrested!!!</font>");
	}
}

public Action:Event_OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!LoadedFromTrie[client])
	{
		LoadedFromTrie[client] = true;
		new String:szAuth[35];
		GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
		
		new karma;
		if (GetTrieValue(g_smPlayersKarma, szAuth, karma))
		{
			g_iKarma[client] = karma;
			
			RP_UpdateScoreBoard_Karma(client);
			
			RemoveFromTrie(g_smPlayersKarma, szAuth);
		}
	}
	
	RP_UpdateScoreBoard_Karma(client);
	
	SetPlayerBounty(client);
}

public RP_OnClientArrestedPost(victim, attacker, karma)
{
	if(karma >= BOUNTY_KARMA)
	{
		if(NoBountyJail)
		{	
			RP_SetKarma(victim, 0, true);
			RP_UnJailClient(victim);
		}	
		else
		{
			new cash = GetRandomInt(MIN_BOUNTY_REWARD, MAX_BOUNTY_REWARD) + CASH_BONUS_ARREST_BOUNTY;
			
			RP_PrintToChatAll("\x02%N\x01 has arrested the bounty player \x02%N!\x01 he received \x04$%i\x01!", attacker, victim, cash);
			
			RP_AddClientEXP(attacker, RP_GetClientJob(attacker), 5);
			
			GiveClientCashNoGangTax(attacker, BANK_CASH, cash);
		}
	}
}
public Action:Event_OnPlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (victim == 0 || attacker == 0 || victim == attacker)
	{
		return;
	}
	if (FindValueInArray(g_aBountyPlayers, victim) != -1)
	{
		if(g_iHitmanJob == -1)
			g_iHitmanJob = RP_FindJobByShortName("HM");
			
		RemoveFromArray(g_aBountyPlayers, FindValueInArray(g_aBountyPlayers, victim));
		new cash = GetRandomInt(MIN_BOUNTY_REWARD, MAX_BOUNTY_REWARD);
		RP_PrintToChatAll("\x02%N\x01 has killed the bounty player \x02%N!\x01 he received \x04$%i\x01!", attacker, victim, cash);
		GiveClientCash(attacker, BANK_CASH, cash);
		
		if(NoBountyJail)
		{
			RP_SetKarma(victim, 0, true);
			return;
		}	
		RP_JailClient(victim);
		
		if(g_iHitmanJob != -1)
			RP_AddClientEXP(attacker, g_iHitmanJob, 5);
	}
	else
	{
		if (GetClientTeam(attacker) == CS_TEAM_T)
		{
			new karma = KARMA_PER_KILL;
			
			Call_StartForward(fw_OnKarmaChanged);
			
			Call_PushCell(attacker);
			Call_PushCellRef(karma);
			Call_PushString(KARMA_KILL_REASON);
			Call_PushCellRef(victim);
			
			new Action:Result;
			Call_Finish(Result);
			
			if(Result == Plugin_Handled || Result == Plugin_Stop)
			{
					
				return;
			}
			
			new Handle:data = CreateDataPack();
			
			WritePackCell(data, attacker);
			WritePackCell(data, karma);
			WritePackString(data, KARMA_KILL_REASON);
			WritePackCell(data, victim);
			
			RequestFrame(DelayKarma, data);
			
			new pos;
			
			if(g_iKarma[attacker] + karma < BOUNTY_KARMA)
			{
				pos = FindValueInArray(g_aBountyPlayers, attacker);
				if (pos != -1)
				{
					RemoveFromArray(g_aBountyPlayers, pos);
				}
			}
			
			if(g_iKarma[attacker] + karma < ARREST_KARMA)
			{
				pos = FindValueInArray(g_aHPCPlayers, attacker);
				
				if (pos != -1)
				{
					RemoveFromArray(g_aHPCPlayers, pos);
				}
			}
		}
	}
	return;
}

public DelayKarma(Handle:pack)
{
	ResetPack(pack, false);
	new player = ReadPackCell(pack);
	new karma = ReadPackCell(pack);
	new String:Reason[64];
	
	ReadPackString(pack, Reason, sizeof(Reason));
	
	new data = ReadPackCell(pack);
	
	CloseHandle(pack);
	
	if (IsClientInGame(player))
	{
		AddKarma(player, karma);
	}
	
	Call_StartForward(fw_OnKarmaChangedPost);
	
	Call_PushCell(player);
	Call_PushCell(karma);
	Call_PushCell(g_iKarma[player]);
	Call_PushString(Reason);
	Call_PushCell(data);
	
	Call_Finish();
	
}

public OnClientConnected(client)
{
	LoadedFromTrie[client] = false;
}
public OnClientDisconnect(client)
{
	new pos = FindValueInArray(g_aBountyPlayers, client);

	if(pos != -1)
	{
		RemoveFromArray(g_aBountyPlayers, pos);
	}
	
	pos = FindValueInArray(g_aHPCPlayers, client);
	
	if(pos != -1)
	{
		RemoveFromArray(g_aHPCPlayers, pos);
	}
	
	if (g_iKarma[client] > 0)
	{
		new String:szAuth[35];
		GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
		SetTrieValue(g_smPlayersKarma, szAuth, g_iKarma[client], true);

		g_iKarma[client] = 0;
	}
	
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	//RegPluginLibrary("RolePlay_Karma");
	CreateNative("RP_AddKarma", _RP_AddKarma);
	CreateNative("RP_SetKarma", _RP_SetKarma);
	CreateNative("RP_GetKarma", _RP_GetKarma);
	CreateNative("RP_RemovePlayerBounty", _RP_RemovePlayerBounty);
	CreateNative("RP_GivePlayerBounty", _RP_GivePlayerBounty);
	return APLRes:0;
}

public _RP_RemovePlayerBounty(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	new pos = FindValueInArray(g_aBountyPlayers, client);
	
	if (pos != -1)
	{
		RemoveFromArray(g_aBountyPlayers, pos);
	}
			
	pos = FindValueInArray(g_aHPCPlayers, client);
	
	if (pos != -1)
	{
		RemoveFromArray(g_aHPCPlayers, pos);
	}
	return 0;
}

public _RP_GivePlayerBounty(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
		
	SetPlayerBounty(client);
	
	RP_UpdateScoreBoard_Karma(client);
	
	return 0;
}

public _RP_GetKarma(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	//RP_UpdateScoreBoard_Karma(client);
	
	return g_iKarma[client];
}

public _RP_SetKarma(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	g_iKarma[client] = GetNativeCell(2);
	
	RP_UpdateScoreBoard_Karma(client);
	
	new bool:bounty = GetNativeCell(3);
	
	if(bounty)
	{
		SetPlayerBounty(client);
		
		new pos;
		
		if(g_iKarma[client] < BOUNTY_KARMA)
		{
			pos = FindValueInArray(g_aBountyPlayers, client);
			if (pos != -1)
			{
				RemoveFromArray(g_aBountyPlayers, pos);
			}
		}
		
		if(g_iKarma[client] < ARREST_KARMA)
		{
			pos = FindValueInArray(g_aHPCPlayers, client);
			
			if (pos != -1)
			{
				RemoveFromArray(g_aHPCPlayers, pos);
			}
		}
	}
}

public _RP_AddKarma(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	new karma = GetNativeCell(2);
	
	new String:Reason[64];
	
	GetNativeString(4, Reason, sizeof(Reason));
	
	if(Reason[0] != EOS)
	{
		Call_StartForward(fw_OnKarmaChanged);

		new dummy_cell;
		
		Call_PushCell(client);
		Call_PushCellRef(karma);
		Call_PushString(Reason);
		Call_PushCellRef(dummy_cell);
		
		new Action:Result;
		Call_Finish(Result);
		
		if(Result == Plugin_Handled || Result == Plugin_Stop)
			return;
	}
	
	g_iKarma[client] += karma;
	
	RP_UpdateScoreBoard_Karma(client);
	
	new bool:bounty = GetNativeCell(3);
	
	if(bounty)
		SetPlayerBounty(client);
	
	Call_StartForward(fw_OnKarmaChangedPost);
	
	Call_PushCell(client);
	Call_PushCell(karma);
	Call_PushCell(g_iKarma[client]);
	Call_PushString(Reason);
	Call_PushCell(0);
	
	new Action:Result;
	Call_Finish(Result);
}

CheckBountyMessage()
{
	
	new size = GetArraySize(g_aBountyPlayers);
	
		
	if(size == 0)
	{	
		size = GetArraySize(g_aHPCPlayers);
		
		for(new a=0;a < size;a++)
		{
			new hpc = GetArrayCell(g_aHPCPlayers, a);

			if(GetClientTeam(hpc) == CS_TEAM_CT)
				continue;
				
			else if(!IsPlayerAlive(hpc))
				continue;
				
			for(new i=1;i <= MaxClients;i++)
			{
				if(!IsClientInGame(i) || GetClientTeam(i) != CS_TEAM_CT || i == hpc)
					continue;
				
				else if(g_iKarma[hpc] < HPC_KARMA && RP_GetClientLevel(i, g_iPoliceJob) < 10)
					continue;
					
				TE_SetupBeamLaser(hpc, i, sprLaserBeam, 0, 0, 0, 1.0, 2.0, 2.0, 10, 0.0, {0, 0, 255, 255}, 0);
				TE_SendToClient(i, 0.0);
				
				Call_StartForward(fw_ShouldSeeBountyMessage);
				
				Call_PushCell(i)
				
				new Action:Result;
				Call_Finish(Result);
				
				if(Result == Plugin_Handled || Result == Plugin_Stop)
					continue;

				BuildHPCMessage(i);
				PrintHintText(i, g_szBountyMessage);
			}
		}
		
		return;
	}
	
	for(new a=0;a < size;a++)
	{
		new bounty = GetArrayCell(g_aBountyPlayers, a);

		if(!IsPlayerAlive(bounty))
			continue;
			
		for(new i=1;i <= MaxClients;i++)
		{
			if (IsClientInGame(i) && i != bounty)
			{
				TE_SetupBeamLaser(bounty, i, sprLaserBeam, 0, 0, 0, 1.0, 2.0, 2.0, 10, 0.0, {255, 0, 0, 255}, 0);
				TE_SendToClient(i, 0.0);
			}
		}
	}

	BuildBountyMessage();
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		Call_StartForward(fw_ShouldSeeBountyMessage);
		
		Call_PushCell(i)
		
		new Action:Result;
		Call_Finish(Result);
		
		if(Result == Plugin_Handled || Result == Plugin_Stop)
			continue;

		PrintHintText(i, g_szBountyMessage);
	}
	
	//PrintToChatEyal("Bounty hint text sent");
}

AddKarma(client, karma)
{
	g_iKarma[client] += karma;

	RP_UpdateScoreBoard_Karma(client);
	
	SetPlayerBounty(client);
	
}

// This does not work if player doesn't have BOUNTY_KARMA amount of karma.

SetPlayerBounty(client)
{
	if(g_iKarma[client] >= BOUNTY_KARMA)
	{	
		Call_StartForward(fw_OnBountySet);
		
		Call_PushCell(client);
		
		new Action:Result;
		Call_Finish(Result);
		
		if(Result == Plugin_Handled || Result == Plugin_Stop)
		{
			return;
		}	
		
		if(FindValueInArray(g_aBountyPlayers, client) == -1)
		{
			PushArrayCell(g_aBountyPlayers, client);
		}
	}
	
	if(g_iKarma[client] >= ARREST_KARMA) // Because level 10 police views them as HPC
	{	
		Call_StartForward(fw_OnBountySet);
		
		Call_PushCell(client);
		
		new Action:Result;
		Call_Finish(Result);
		
		if(Result == Plugin_Handled || Result == Plugin_Stop)
		{
			return;
		}	
		
		if(FindValueInArray(g_aHPCPlayers, client) == -1)
		{
			PushArrayCell(g_aHPCPlayers, client);
		}
	}
}

BuildBountyMessage()
{
	g_szBountyMessage[0] = EOS;
	
	new size = GetArraySize(g_aBountyPlayers);
	
	for(new i=0;i < size;i++)
	{
		new target = GetArrayCell(g_aBountyPlayers, i);
		Format(g_szBountyMessage, sizeof(g_szBountyMessage), "%s%N | ", g_szBountyMessage, target);
	}
	
	if(size == 0)
		return;
		
	new len = strlen(g_szBountyMessage);
	g_szBountyMessage[len-2] = EOS;
	Format(g_szBountyMessage, 1024, "<font size=\"24\" color=\"#FB6542\"><u>Bounty Players</u></font><br><font size=\"18\" color=\"#FFBB00\">%s</font>", g_szBountyMessage);
	
}


BuildHPCMessage(client)
{
	g_szBountyMessage[0] = EOS;
	
	new size = GetArraySize(g_aHPCPlayers);
	
	for(new i=0;i < size;i++)
	{
		new hpc = GetArrayCell(g_aHPCPlayers, i);
		
		if(g_iKarma[hpc] < HPC_KARMA && RP_GetClientLevel(client, g_iPoliceJob) < 10)
			continue;
			
		if(GetClientTeam(hpc) != CS_TEAM_CT)
			Format(g_szBountyMessage, sizeof(g_szBountyMessage), "%s%N | ", g_szBountyMessage, hpc);
	}
	
	if(size == 0)
		return;
		
	new len = strlen(g_szBountyMessage);
	g_szBountyMessage[len-2] = EOS;
	Format(g_szBountyMessage, 1024, "<font size=\"24\" color=\"#0000FF\"><u>High Profile Criminals [ ARREST ONLY ]</u></font><br><font size=\"18\" color=\"#FFBB00\">%s</font>", g_szBountyMessage);
	
}
