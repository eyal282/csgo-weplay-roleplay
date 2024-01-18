#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <fuckzones>
#include <Eyal-RP>

#define VIP_TIME 600 // Time in jail to go into a VIP cell

new EngineVersion:g_Game;

#define JAIL_REASON_LOADED_FROM_TRIE "Loaded From Trie"

new String:ClientAdminName[MAXPLAYERS+1][64], String:ClientReason[MAXPLAYERS+1][256];

new Handle:dbAdminJail = INVALID_HANDLE;
new bool:dbFullConnected;
new bool:ClientLoadedFromDB[MAXPLAYERS+1]

public Plugin:myinfo =
{
	name = "RolePlay Jail",
	description = "roleplay jail plugin",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = "http://steamcommunity.com/id/xflane/"
};

new String:szConfigFile[] = "addons/sourcemod/configs/jb_cells.ini";
new ArrayList:g_aJailCells;
new ArrayList:g_aVIPCells;
new ArrayList:g_aAdminCells;
new ArrayList:g_aJailPlayers;
new ArrayList:g_aAdminJailPlayers;

new Handle:g_hShowJailTimeTask;

new Handle:fwJailStatusPost = INVALID_HANDLE;
new Handle:fwTeleportToJail = INVALID_HANDLE;

new g_iJailTime[MAXPLAYERS+1], g_iAdminJailTime[MAXPLAYERS+1];
new bool:LoadedFromTrie[MAXPLAYERS+1];
new StringMap:g_smPlayersJail;
new StringMap:g_smPlayersInitJail;

new g_iLawyerJob = -1;

Handle Trie_JailEco;

public OnMapStart()
{
	g_hShowJailTimeTask = INVALID_HANDLE;
	
	LoadDirOfModels("models/player/custom_player/kuristaja/jailbreak/prisoner1/");
	LoadDirOfModels("materials/models/player/kuristaja/jailbreak/prisoner1/");
	LoadDirOfModels("materials/models/player/kuristaja/jailbreak/shared/");
	PrecacheModel("models/player/custom_player/kuristaja/jailbreak/prisoner1/prisoner1.mdl", true);
}


public RP_OnEcoLoaded()
{
	
	Trie_JailEco = RP_GetEcoTrie("Jail");
	
	if(Trie_JailEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Jail");
		
	new String:TempFormat[64];

	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "JAIL_CELL_XYZ_#%i", i);
		
		new String:sOrigin[32];
		
		if(!GetTrieString(Trie_JailEco, Key, sOrigin, sizeof(sOrigin)))
			break;
		
		float fOrigin[3];

		StringToVector(sOrigin, fOrigin);

		PushArrayArray(g_aJailCells, fOrigin);

		FormatEx(Key, sizeof(Key), "JAIL_CELL_VIP_XYZ_#%i", i);

		if(GetTrieString(Trie_JailEco, Key, sOrigin, sizeof(sOrigin)))
		{
			StringToVector(sOrigin, fOrigin);

			PushArrayArray(g_aVIPCells, fOrigin);
		}

		FormatEx(Key, sizeof(Key), "JAIL_CELL_ADMIN_XYZ_#%i", i);

		if(GetTrieString(Trie_JailEco, Key, sOrigin, sizeof(sOrigin)))
		{
			StringToVector(sOrigin, fOrigin);

			PushArrayArray(g_aAdminCells, fOrigin);
		}
		
		i++;
	}
}

public OnPluginStart()
{
	g_Game = GetEngineVersion();
	
	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	fwJailStatusPost = CreateGlobalForward("RP_OnClientJailStatusPost", ET_Event, Param_Cell);
	fwTeleportToJail = CreateGlobalForward("RP_OnClientTeleportToJail", ET_Ignore, Param_Cell);
	
	g_aJailCells = CreateArray(3);
	g_aVIPCells = CreateArray(3);
	g_aAdminCells = CreateArray(3);
	g_aJailPlayers = CreateArray(1);
	g_aAdminJailPlayers = CreateArray(1);
	g_smPlayersJail = CreateTrie();
	g_smPlayersInitJail = CreateTrie();
	
	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Post);

	//ReadCells();
	
	ConnectDatabase();
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		OnClientPutInServer(i);
		
		if(!IsClientAuthorized(i))
			continue;
			
		LoadedFromTrie[i] = true;
		
		
	}

	if(RP_GetEcoTrie("Jail") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}


public ConnectDatabase()
{
	new String:error[256];

	new Handle:hndl = SQL_Connect("eyal_rp", true, error, 255);
	
	if (hndl == INVALID_HANDLE)
	{
		PrintToServer("Could not connect [SQL]: %s", error);
	}
	else
	{
		dbAdminJail = hndl;
		
		SQL_TQuery(dbAdminJail, SQLCB_Error, "CREATE TABLE IF NOT EXISTS AdminJail_players (AuthId VARCHAR(32) NOT NULL UNIQUE, TimeLeft INT(11) NOT NULL, Reason VARCHAR(256) NOT NULL, AdminName VARCHAR(64) NOT NULL, AdminAuthId VARCHAR(32) NOT NULL, Name VARCHAR(64) NOT NULL)", 0, DBPrio_High);
		
		dbFullConnected = true;
		
		for(new i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
		
			else if(!IsClientAuthorized(i))
				continue;
			
			LoadClientData(i);
		}
	}
}

public SQLCB_Error(Handle:owner, Handle:hndl, const char[] Error, QueryUniqueID) 
{ 
    /* If something fucked up. */ 
	if (hndl == null) 
		LogError("%s --> %i", Error, QueryUniqueID); 
} 

public SQLCB_ErrorIgnore(Handle:owner, Handle:hndl, const char[] Error, Data) 
{ 
} 

public Action:Event_OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	SetEntityRenderMode(client, RENDER_NORMAL);
	
	if(!LoadedFromTrie[client])
	{
		LoadedFromTrie[client] = true;
		
		new String:szAuth[35];
		if(GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth)))
		{
			new time;
			if(GetTrieValue(g_smPlayersJail, szAuth, time))
			{		
				RP_SetKarma(client, time * 5, false);
				
				JailClient(client, JAIL_REASON_LOADED_FROM_TRIE);
				
				TeleportToJail(client);
				
				RemoveFromTrie(g_smPlayersJail, szAuth);
			}
			
			if(dbFullConnected)
				LoadClientData(client);
		}
	}
	if((g_iJailTime[client] > 0 || g_iAdminJailTime[client] > 0) && (FindValueInArray(g_aJailPlayers, client) != -1 || FindValueInArray(g_aAdminJailPlayers, client) != -1))
	{
		RequestFrame(Frame_TeleportToJail, client);
	}
	return Plugin_Continue;
}

LoadClientData(client)
{
	new String:AuthId[35]
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	new String:sQuery[256];
	SQL_FormatQuery(dbAdminJail, sQuery, sizeof(sQuery), "SELECT * FROM AdminJail_players WHERE AuthId = '%s'", AuthId);

	SQL_TQuery(dbAdminJail, SQLCB_LoadClientData, sQuery, GetClientUserId(client));
}

public SQLCB_LoadClientData(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == null)
	{
		LogError(error);
		
		return;
	}

	new client = GetClientOfUserId(data);
	if(client == 0)
	{
		return;
	}
	else 
	{
		if(SQL_GetRowCount(hndl) == 1)
		{
			SQL_FetchRow(hndl);
			
			new TimeLeft = SQL_FetchInt(hndl, 1);
			
			new String:AdminAuthId[32];
			SQL_FetchString(hndl, 2, ClientReason[client], sizeof(ClientReason[]));
			SQL_FetchString(hndl, 3, ClientAdminName[client], sizeof(ClientAdminName[]));
			SQL_FetchString(hndl, 4, AdminAuthId, sizeof(AdminAuthId));
			
			AdminJailClient(client, TimeLeft, ClientReason[client], ClientAdminName[client], AdminAuthId);
			
			TeleportToJail(client);
			
			RequestFrame(Frame_TeleportToJail, client);
		}
		else
		{
			ClientLoadedFromDB[client] = true;
		}
	}
}
public OnClientConnected(client)
{
	LoadedFromTrie[client] = false;
	
	g_iJailTime[client] = 0;
	g_iAdminJailTime[client] = 0;
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamagePost, SDKEvent_OnTakeDamagePost);
}

public SDKEvent_OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if(victim == 0)
		return;
	
	else if(!(damagetype & DMG_CRUSH))
		return;

	else if(IsPlayer(attacker))
		return;

	else if(!RP_IsClientInJail(victim))
		return;
		
	else if(RP_IsClientInAdminJail(victim))
		return;
	
	else if(damage < 10.0)
		return;
	
	RP_PrintToChat(victim, "Your sentence was reduced for gassing yourself");
	
	g_iJailTime[victim]--;
	
	if(CheckCommandAccess(victim, "sm_vip", ADMFLAG_CUSTOM2))
		g_iJailTime[victim]--;
		
	if(g_iJailTime[victim] - GetTime() < 3)
		FreeClientFromJail(victim);
}
public OnClientDisconnect(client)
{
	new String:szAuth[35];
	
	new authorized = GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));

	if(FindValueInArray(g_aJailPlayers, client) != -1 && g_iJailTime[client] - GetTime() > 10)
	{
		RemoveFromArray(g_aJailPlayers, FindValueInArray(g_aJailPlayers, client));
			
		if(!authorized || !LoadedFromTrie[client])
			return;
			
		SetTrieValue(g_smPlayersJail, szAuth, g_iJailTime[client] - GetTime(), true);
	}
	else
		RemoveFromTrie(g_smPlayersJail, szAuth);
		
	if(IsClientInAdminJail(client) && g_iAdminJailTime[client] - GetTime() > 10)
	{
		RemoveFromArray(g_aAdminJailPlayers, FindValueInArray(g_aAdminJailPlayers, client));

		if(authorized)
		{
			new String:sQuery[512];
			SQL_FormatQuery(dbAdminJail, sQuery, sizeof(sQuery), "UPDATE AdminJail_players SET TimeLeft = %i WHERE AuthId = '%s'", g_iAdminJailTime[client] - GetTime(), szAuth);
	
			SQL_TQuery(dbAdminJail, SQLCB_ErrorIgnore, sQuery);
		}
	}
	g_iJailTime[client] = 0;
	g_iAdminJailTime[client] = 0;
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_Jail");
	CreateNative("RP_JailClient", _RP_JailClient);
	CreateNative("RP_UnJailClient", _RP_UnJailClient);
	
	CreateNative("RP_AdminJailClient", _RP_AdminJailClient);
	CreateNative("RP_AdminUnJailClient", _RP_AdminUnJailClient);
	
	CreateNative("RP_AdminJailSteamId", _RP_AdminJailSteamId);
	CreateNative("RP_AdminUnJailSteamId", _RP_AdminUnJailSteamId);
	
	CreateNative("RP_IsClientInJail", _RP_IsClientInJail);
	CreateNative("RP_IsClientInAdminJail", _RP_IsClientInAdminJail);
	
	CreateNative("RP_TryTeleportToJail", _RP_TryTeleportToJail);
	
	return APLRes:0;
}

public _RP_JailClient(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(FindValueInArray(g_aJailPlayers, client) == -1)
	{
		
		new String:Name[64];
		GetPluginFilename(plugin, Name, sizeof(Name));
		JailClient(client, Name);
		return 1;
	}
	return 0;
}

public _RP_UnJailClient(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	FreeClientFromJail(client);
	return 0;
}

public _RP_AdminJailClient(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(FindValueInArray(g_aAdminJailPlayers, client) == -1)
	{
		new time = GetNativeCell(2);
		
		new String:Reason[256];
		GetNativeString(3, Reason, sizeof(Reason));
		
		new String:AdminName[64];
		GetNativeString(4, AdminName, sizeof(AdminName));
		
		new String:AdminAuthId[32];
		GetNativeString(5, AdminAuthId, sizeof(AdminAuthId));
		
		AdminJailClient(client, time, Reason, AdminName, AdminAuthId);
		return 1;
	}
	return 0;
}

public _RP_AdminUnJailClient(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	FreeClientFromAdminJail(client);
	return 0;
}

public _RP_AdminJailSteamId(Handle:plugin, numParams)
{
	new String:AuthId[35];
	GetNativeString(1, AuthId, sizeof(AuthId));

	new time = GetNativeCell(2);
	
	new String:Reason[256];
	GetNativeString(3, Reason, sizeof(Reason));
	
	new String:AdminName[64];
	GetNativeString(4, AdminName, sizeof(AdminName));
	
	new String:AdminAuthId[32];
	GetNativeString(5, AdminAuthId, sizeof(AdminAuthId));
	
	AdminJailSteamId(AuthId, time, Reason, AdminName, AdminAuthId);
	
	return 0;
}

public _RP_AdminUnJailSteamId(Handle:plugin, numParams)
{
	new String:AuthId[35];
	GetNativeString(1, AuthId, sizeof(AuthId));
	
	FreeSteamIdFromAdminJail(AuthId);
	return 0;
}


public _RP_IsClientInJail(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	return g_iJailTime[client] > 0 || g_iAdminJailTime[client] > 0;
}

public _RP_IsClientInAdminJail(Handle:plugin, numParams)
{
	return IsClientInAdminJail(GetNativeCell(1));
}

public _RP_TryTeleportToJail(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if((g_iJailTime[client] > 0 || g_iAdminJailTime[client] > 0) && (FindValueInArray(g_aJailPlayers, client) != -1 || FindValueInArray(g_aAdminJailPlayers, client) != -1))
	{
		RequestFrame(Frame_TeleportToJail, client);
	}

}

public Action:Timer_JailPlayers(Handle:timer, any:data)
{
	new adminSize = GetArraySize(g_aAdminJailPlayers);
	new size = GetArraySize(g_aJailPlayers);
	
	if (size < 1 && adminSize < 1)
	{
		g_hShowJailTimeTask = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	static String:szTime[32];

	if(size >= 1)
	{
		for(new i=0;i < size;i++)
		{
			if(i >= GetArraySize(g_aJailPlayers)) // Array can have its size reduced
				break;
				
			new player = GetArrayCell(g_aJailPlayers, i);
			
			if(g_iJailTime[player] - GetTime({0,0}) > 0)
			{
				FormatTime(szTime, 32, "%M:%S", g_iJailTime[player] - GetTime());
				PrintHintText(player, "<font color=\"#B3C100\">Jail</font>\n<font color=\"#4CB5F5\">Time Left: %s", szTime);
			}
			else
			{
				FreeClientFromJail(player);
				i--; // Because FreeClientFromJail uses RemoveFromArray(g_aJailPlayers,...)
			}
		}
	}
	
	if(adminSize >= 1)
	{
		for(new i=0;i < adminSize;i++)
		{
			if(i >= GetArraySize(g_aAdminJailPlayers)) // Array can have its size reduced
				break;
				
			new player = GetArrayCell(g_aAdminJailPlayers, i);
			
			if(g_iAdminJailTime[player] - GetTime({0,0}) > 0)
			{
				FormatTime(szTime, 32, "%M:%S", g_iAdminJailTime[player] - GetTime());
				PrintHintText(player, "Jailed by Admin</font><font color=\"#FF0000\">%s</font>\nReason:<font color=\"#00BFFF\"> %s </font>\nTime Left: %s", ClientAdminName[player], ClientReason[player], szTime);
			}
			else
			{
				FreeClientFromAdminJail(player);
				i--; // Because FreeClientFromJail uses RemoveFromArray(g_aAdminJailPlayers,...)
			}
		}
	}
	return Plugin_Continue;
}

FreeClientFromJail(client)
{
	g_iJailTime[client] = 0;
	
	new pos = FindValueInArray(g_aJailPlayers, client);
	
	if(pos != -1)
		RemoveFromArray(g_aJailPlayers, pos);
		
	new String:szAuth[35];
	GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
	
	RemoveFromTrie(g_smPlayersJail, szAuth);
		
	Call_StartForward(fwJailStatusPost);
	
	Call_PushCell(client);
	
	Call_Finish();
	
	CS_RespawnPlayer(client);
	
}

public Zone_OnClientLeave(client, const char[] zone)
{
	if(RP_IsClientInJail(client) && !Zone_IsClientInZone(client, "SafeZone Jail", true) && !IsPlayerInAdminRoom(client) && !RP_IsUserInArena(client) && !RP_IsUserInDuel(client))
		RequestFrame(Frame_TeleportToJail, client);
}

FreeClientFromAdminJail(client)
{
	g_iAdminJailTime[client] = 0;
	
	new pos = FindValueInArray(g_aAdminJailPlayers, client);
	
	if(pos != -1)
		RemoveFromArray(g_aAdminJailPlayers, pos);
		
	new String:szAuth[35];
	GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
	
	new String:sQuery[256];
	SQL_FormatQuery(dbAdminJail, sQuery, sizeof(sQuery), "DELETE FROM AdminJail_players WHERE AuthId = '%s'", szAuth);
	
	SQL_TQuery(dbAdminJail, SQLCB_ErrorIgnore, sQuery);
	
	if(!IsPlayerInAdminRoom(client))
		CS_RespawnPlayer(client);
	
	RemoveFromTrie(g_smPlayersInitJail, szAuth);
	
	Call_StartForward(fwJailStatusPost);
	
	Call_PushCell(client);
	
	Call_Finish();
	
	CS_RespawnPlayer(client);
}


FreeSteamIdFromAdminJail(const String:AuthId[])
{
	new String:sQuery[256];
	SQL_FormatQuery(dbAdminJail, sQuery, sizeof(sQuery), "DELETE FROM AdminJail_players WHERE AuthId = '%s'", AuthId);
	
	SQL_TQuery(dbAdminJail, SQLCB_ErrorIgnore, sQuery);
	
	new client = FindClientByAuthId(AuthId);
	
	if(client != 0)
	{
		
		g_iAdminJailTime[client] = 0;
		
		new pos = FindValueInArray(g_aAdminJailPlayers, client);
		
		if(pos != -1)
			RemoveFromArray(g_aAdminJailPlayers, pos);
			
		if(!IsPlayerInAdminRoom(client))
			CS_RespawnPlayer(client);
		
		RemoveFromTrie(g_smPlayersInitJail, AuthId);
		
		Call_StartForward(fwJailStatusPost);
		
		Call_PushCell(client);
		
		Call_Finish();
		
		CS_RespawnPlayer(client);
	}
}

JailClient(client, String:reason[])
{
	new karma = RP_GetKarma(client);
	
	//LogError("%N - Karma Jail: %i | Reason: %s", client, karma, reason);
	new iJailTime = karma / 5;
	
	if (iJailTime > 840)
	{
		iJailTime = 840;
	}
	
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	if(StrContains(reason, "Command", false) == -1 && !StrEqual(reason, JAIL_REASON_LOADED_FROM_TRIE))
	{
		SetTrieValue(g_smPlayersInitJail, AuthId, iJailTime);
		
		if(IsWeekend())
			iJailTime = RoundToFloor(float(iJailTime) / 1.5);
			
		if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2, true))
			iJailTime /= 2;
			
		if(g_iLawyerJob == -1)
			g_iLawyerJob = RP_FindJobByShortName("LAW");
			
		
		new level = RP_GetClientLevel(client, g_iLawyerJob);
		
		
		if(level >= 8)
			iJailTime -= RoundToFloor(float(iJailTime) * 0.4);
			
		else if(level >= 5)
			iJailTime -= RoundToFloor(float(iJailTime) * 0.2);
			
		
	}
	
	RP_SetKarma(client, 0, true);
	
	g_iJailTime[client] = GetTime() + iJailTime;
	
	PushArrayCell(g_aJailPlayers, client);
	
	if (g_hShowJailTimeTask == INVALID_HANDLE)
	{
		g_hShowJailTimeTask = CreateTimer(1.0, Timer_JailPlayers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	
	Call_StartForward(fwJailStatusPost);
	
	Call_PushCell(client);
	
	Call_Finish();
	
	TeleportToJail(client);
}

AdminJailClient(client, time, const String:reason[], const String:AdminName[], const String:AdminAuthId[])
{
	//LogError("%N - Karma Jail: %i | Reason: %s", client, karma, reason);
	
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	g_iAdminJailTime[client] = GetTime() + time;
	
	PushArrayCell(g_aAdminJailPlayers, client);
	
	FormatEx(ClientAdminName[client], sizeof(ClientAdminName[]), AdminName);
	FormatEx(ClientReason[client], sizeof(ClientReason[]), reason);
	
	new String:szAuth[35];
	GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
	
	new String:sQuery[512];
	SQL_FormatQuery(dbAdminJail, sQuery, sizeof(sQuery), "INSERT IGNORE INTO AdminJail_players (AuthId, TimeLeft, Reason, AdminName, AdminAuthId, Name) VALUES ('%s', %i, '%s', '%s', '%s', '%N')", AuthId, time, reason, AdminName, AdminAuthId, client);

	SQL_TQuery(dbAdminJail, SQLCB_ErrorIgnore, sQuery);
	
	if (g_hShowJailTimeTask == INVALID_HANDLE)
	{
		g_hShowJailTimeTask = CreateTimer(1.0, Timer_JailPlayers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	
	SetEntityRenderMode(client, RENDER_NONE);
	
	TeleportToJail(client);
	//SDKHook(client, SDKHook_SetTransmit, SDKEvent_AdminJailSetTransmit);
}


AdminJailSteamId(const String:AuthId[], time, const String:reason[], const String:AdminName[], const String:AdminAuthId[])
{
	//LogError("%N - Karma Jail: %i | Reason: %s", client, karma, reason);

	
	new String:sQuery[512];
	SQL_FormatQuery(dbAdminJail, sQuery, sizeof(sQuery), "INSERT IGNORE INTO AdminJail_players (AuthId, TimeLeft, Reason, AdminName, AdminAuthId, Name) VALUES ('%s', %i, '%s', '%s', '%s', '')", AuthId, time, reason, AdminName, AdminAuthId);

	SQL_TQuery(dbAdminJail, SQLCB_ErrorIgnore, sQuery);
	
	new client = FindClientByAuthId(AuthId);
	
	if(client != 0)
	{
		
		g_iAdminJailTime[client] = GetTime() + time;
		
		PushArrayCell(g_aAdminJailPlayers, client);
		
		FormatEx(ClientAdminName[client], sizeof(ClientAdminName[]), AdminName);
		FormatEx(ClientReason[client], sizeof(ClientReason[]), reason);
		
		if (g_hShowJailTimeTask == INVALID_HANDLE)
		{
			g_hShowJailTimeTask = CreateTimer(1.0, Timer_JailPlayers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
		
		SetEntityRenderMode(client, RENDER_NONE);
		
		TeleportToJail(client);
	}
	//SDKHook(client, SDKHook_SetTransmit, SDKEvent_AdminJailSetTransmit);
}

public Frame_TeleportToJail(client)
{
	if(!IsClientInGame(client)) // In one frame no player replacement can be made, only a client can leave.
		return;
		

	TeleportToJail(client);
}

TeleportToJail(client)
{
	if (!IsPlayerAlive(client))
		return;

	new Float:cell[3];
	
	new String:AuthId[35];
	
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	new iJailTime;
	
	GetTrieValue(g_smPlayersInitJail, AuthId, iJailTime);
	
	if(IsClientInAdminJail(client))
	{
		GetArrayArray(g_aAdminCells, GetRandomInt(0, GetArraySize(g_aAdminCells) - 1), cell);
		
		SetEntityRenderMode(client, RENDER_NONE);
	}	
	else if(GetArraySize(g_aVIPCells) > 0 && iJailTime >= VIP_TIME)
		GetArrayArray(g_aVIPCells, GetRandomInt(0, GetArraySize(g_aVIPCells) - 1), cell);
	
	else
		GetArrayArray(g_aJailCells, GetRandomInt(0, GetArraySize(g_aJailCells) - 1), cell);
		
	TeleportEntity(client, cell, NULL_VECTOR, NULL_VECTOR);
	
	Call_StartForward(fwTeleportToJail);
	
	Call_PushCell(client);
	
	Call_Finish();
	
	RequestFrame(RemoveWeapons, client);
	
	if(RP_IsClientInJail(client))
		RP_SetKarma(client, 0, true);
		
	SetEntityModel(client, "models/player/custom_player/kuristaja/jailbreak/prisoner1/prisoner1.mdl");
}

public RemoveWeapons(any:client)
{
	if(!IsClientInGame(client))
		return;
		
	RemoveAllWeapons(client);
	
	if(!IsClientInAdminJail(client))
		GivePlayerItem(client, "weapon_knife");
}

ReadCells()
{
	new Float:origin[3] = 0.0;
	new Handle:kv = CreateKeyValues("JailCells", "", "");
	FileToKeyValues(kv, szConfigFile);
	if (!KvGotoFirstSubKey(kv, true))
	{
		
	}
	do {
		new String:Name[32];
		KvGetSectionName(kv, Name, sizeof(Name));
		
		origin[0] = KvGetFloat(kv, "origin_x", 0.0);
		origin[1] = KvGetFloat(kv, "origin_y", 0.0);
		origin[2] = KvGetFloat(kv, "origin_z", 0.0);
		
		if(StrContains(Name, "VIP", false) != -1)
			PushArrayArray(g_aVIPCells, origin);
			
		else if(StrContains(Name, "Admin", false) != -1)
			PushArrayArray(g_aAdminCells, origin);
			
		else	
			PushArrayArray(g_aJailCells, origin);
			
	} while (KvGotoNextKey(kv, true));
	
	CloseHandle(kv);
	kv = INVALID_HANDLE;
}

stock bool:IsClientInAdminJail(client)
{
	return g_iAdminJailTime[client] > 0;
}


stock FindClientByAuthId(const String:AuthId[])
{
	new String:iAuthId[35];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		else if (!IsClientAuthorized(i))
			continue;
		
		GetClientAuthId(i, AuthId_Engine, iAuthId, sizeof(iAuthId));
		
		if (StrEqual(AuthId, iAuthId, true))
			return i;
	}
	
	return 0;
}