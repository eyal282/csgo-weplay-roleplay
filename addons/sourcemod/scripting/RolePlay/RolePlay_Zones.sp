#pragma semicolon 1
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <fuckzones>
#include <Eyal-RP>

new Handle:g_hDatabase;

new bool:g_bGM[MAXPLAYERS+1];
new bool:g_bInvisible[MAXPLAYERS+1];
new bool:g_bSuperEars[MAXPLAYERS+1];
new bool:g_bServerMute;

public Plugin:myinfo =
{
	name = "SM DEV Zones - NoDamage",
	author = "Franc1sco franug",
	description = "",
	version = "3.1",
	url = "http://steamcommunity.com/id/franug"
};

public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] error, int length)
{
	CreateNative("IsClientNoKillZone", Native_IsClientNoKillZone);
	CreateNative("IsClientSuperEars", Native_IsClientSuperEars);
	CreateNative("SetClientSuperEars", Native_SetClientSuperEars);
}

public any Native_IsClientNoKillZone(Handle caller, int numParams)
{
	new client = GetNativeCell(1);
	
	return Zone_IsClientInZone(client, "SafeZone", false) || g_bGM[client] || IsPlayerInAdminRoom(client);
}

public any Native_IsClientSuperEars(Handle caller, int numParams)
{
	new client = GetNativeCell(1);
	
	return g_bSuperEars[client];
}

public any Native_SetClientSuperEars(Handle caller, int numParams)
{
	new client = GetNativeCell(1);
	
	g_bSuperEars[client] = view_as<bool>(GetNativeCell(2));
}

public OnPluginStart()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		OnClientPutInServer(i);
	}
	
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	RegAdminCmd("sm_gm", Command_GM, ADMFLAG_ROOT);
	RegAdminCmd("sm_superears", Command_SuperEars, ADMFLAG_CONVARS);

	AddCommandListener(Listener_Buy, "buy");
	
	LoadTranslations("common.phrases");
	if (!g_hDatabase)
	{
		new String:error[256];
		g_hDatabase = SQL_Connect("eyal_rp", true, error, 255);
		if (!g_hDatabase)
		{
			PrintToServer("Could not connect [SQL]: %s", error);
		}
	}
	
	if(g_hDatabase)
		SQL_TQuery(g_hDatabase, SQL_NoAction, "CREATE TABLE IF NOT EXISTS `rp_gm` ( `AuthId` varchar(32) NOT NULL UNIQUE )", any:0, DBPriority:1);
}

public Action:Event_PlayerSpawn(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new UserId = GetEventInt(hEvent, "userid");
	
	CreateTimer(1.0, Timer_RenderMode, UserId, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Listener_Buy(client, const String:Name[], args)
{
	if(!g_bGM[client])
		return Plugin_Continue;
		
	new String:Arg[11];
	
	GetCmdArg(1, Arg, sizeof(Arg));
	
	if(StrEqual(Arg, "primammo", false))
	{
		ShowGMMenu(client);
	}
	
	return Plugin_Continue;
}

ShowGMMenu(client)
{
	new Handle:hMenu = CreateMenu(GM_MenuHandler);	
		

	new String:TempFormat[64];
	FormatEx(TempFormat, sizeof(TempFormat), "Invisible - %s", g_bInvisible[client] ? "Enabled" : "Disabled");
	
	AddMenuItem(hMenu, "", TempFormat);
	
	FormatEx(TempFormat, sizeof(TempFormat), "Super Ears - %s", g_bSuperEars[client] ? "Enabled" : "Disabled");
	
	AddMenuItem(hMenu, "", TempFormat);
	
	FormatEx(TempFormat, sizeof(TempFormat), "Server Mute - %s", g_bServerMute ? "Enabled" : "Disabled");
	
	AddMenuItem(hMenu, "", TempFormat);
	
	AddMenuItem(hMenu, "", "Noclip");
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}
public GM_MenuHandler(Handle:hMenu, MenuAction:action, client, item)
{
	if(action == MenuAction_End)
		CloseHandle(hMenu);
	
	if(action == MenuAction_Select)
	{
		switch(item)
		{
			case 0:
			{
				g_bInvisible[client] = !g_bInvisible[client];
				
				if(g_bInvisible[client])
					RequestFrame(Frame_Invisible, client);
					
				else
					SetEntityRenderMode(client, RENDER_NORMAL);
			}
			
			case 1:
			{
				g_bSuperEars[client] = !g_bSuperEars[client];
			}
			
			case 2:
			{
				g_bServerMute = !g_bServerMute;
				
				if(g_bServerMute)
					FakeClientCommand(client, "sm_muteall");
					
				else 
					FakeClientCommand(client, "sm_unmuteall");
			}
			case 3:
			{
				if(GetEntityMoveType(client) != MOVETYPE_NOCLIP)
				{
					SetEntityMoveType(client, MOVETYPE_NOCLIP);
					
					SetEntityRenderMode(client, RENDER_NONE);
				}	
				else
				{
					SetEntityMoveType(client, MOVETYPE_WALK);
					
					CreateTimer(0.0, Timer_RenderMode, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
		
		ShowGMMenu(client);
	}
}	

public Frame_Invisible(client)
{
	if(!IsClientInGame(client)) // In a single frame a client can only get invalidated, not replaced.
		return;
		
	SetEntityRenderMode(client, RENDER_NONE);
}

public Action:Command_SuperEars(client, args)
{
	g_bSuperEars[client] = !g_bSuperEars[client];
	
	RP_PrintToChat(client, "Super ears is %s for you", g_bSuperEars[client] ? "enabled" : "disabled");
	
	return Plugin_Handled;
}
public Action:Command_GM(client, args)
{
	g_bGM[client] = !g_bGM[client];
	
	new String:AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	
	if(g_bGM[client])
	{
		new String:sQuery[512];
		SQL_FormatQuery(g_hDatabase, sQuery, sizeof(sQuery), "INSERT IGNORE INTO rp_gm (AuthId) VALUES ('%s')", AuthId);

		SQL_TQuery(g_hDatabase, SQL_NoError, sQuery, DBPrio_High);
		
		RP_PrintToChat(client, "GM Mode Enabled");
		
		if(GetClientTeam(client) == CS_TEAM_CT)
			ChangeClientTeam(client, CS_TEAM_T);
	}
	else
	{
		new String:sQuery[512];
		SQL_FormatQuery(g_hDatabase, sQuery, sizeof(sQuery), "DELETE FROM rp_gm WHERE AuthId = '%s'", AuthId);
	
		SQL_TQuery(g_hDatabase, SQL_NoError, sQuery, DBPrio_High);
		
		RP_PrintToChat(client, "GM Mode Disabled");
	}
	
	
	RemoveAllWeapons(client);
	TeleportEntity(client, {0.0, 0.0, 0.0});
	
	RequestFrame(Frame_Suicide, client);
	
	return Plugin_Handled;
}

public Frame_Suicide(client)
{
	if(!IsClientInGame(client)) // In one frame a client cannot be replaced, only invalidated.
		return;
		
	ForcePlayerSuicide(client);
}
public SQL_NoAction(Handle:owner, Handle:handle, String:szError[], any:data)
{
	if (!handle)
	{
		LogError("[Error %i] SQL query failed: %s", data, szError);
	}
	return;
}

public SQL_NoError(Handle:owner, Handle:handle, String:szError[], any:data)
{
}
public OnClientPutInServer(client)
{
   SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
   SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}


public OnClientPostAdminCheck(client)
{
	Func_OnClientPostAdminCheck(client);
}

public Func_OnClientPostAdminCheck(client)
{
	g_bInvisible[client] = false;
	g_bSuperEars[client] = false;
	g_bGM[client] = false;
	
	if(!CheckCommandAccess(client, "sm_cca_root", ADMFLAG_ROOT))
		return;
		
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT * FROM rp_gm WHERE AuthId = '%s'", szAuth);

	SQL_TQuery(g_hDatabase, SQL_LoadData, szQuery, GetClientSerial(client), DBPrio_High);
	return;
}

public SQL_LoadData(Handle:owner, Handle:handle, String:error[], any:data)
{
	new client = GetClientFromSerial(data);
	
	if (!client)
		return;

	if(handle)
	{	
		if(SQL_GetRowCount(handle) > 0)
		{
			g_bGM[client] = true;
			
			PrintToChatAll("Game Master %N joined the server!", client);
		}
	}
}

public bool:UpdateJobStats(client, job)
{
	if(!IsClientInGame(client))
		return false;
		
	if(g_bGM[client] && CheckCommandAccess(client, "sm_cca_root", ADMFLAG_ROOT))
	{
		if(job != -1)
		{
			RP_SetClientJob(client, -1);
			
			RemoveAllWeapons(client);
		}

			
		GivePlayerItem(client, "weapon_knife");
	}
	
	return false;
}

public Action:Timer_RenderMode(Handle:hTimer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return;
	
	else if(!g_bGM[client])
		return;
		
	else if(!CheckCommandAccess(client, "sm_cca_root", ADMFLAG_ROOT))
		return;
	CS_UpdateClientModel(client);
		
	if(g_bInvisible[client])
		SetEntityRenderMode(client, RENDER_NONE);
		
	else
		SetEntityRenderMode(client, RENDER_WORLDGLOW);
		
	SetEntityRenderColor(client, 0, 255, 255, 255);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	new Action:ReturnType = Plugin_Continue;
	
	if(g_bGM[victim])
	{
		damage = 0.0;
		
		ReturnType = Plugin_Changed;
	}	
	else if(!IsValidClient(victim) || !IsValidClient(attacker)) return Plugin_Continue;
	
	if(g_bGM[victim] || g_bGM[attacker])
	{
		if(!g_bInvisible[victim])
			PrintHintText(attacker, "<font size=\"26\" color=\"#00ff00\"><b><u>You cannot kill game masters.</b></u></font>");
			
		return Plugin_Handled;
	}	
	if(!IsPlayerInAdminRoom(victim) || !IsPlayerInAdminRoom(attacker))
	{
		if((!Zone_IsClientInZone(victim, "SafeZone", false) && !Zone_IsClientInZone(attacker, "SafeZone", false)) || (Zone_IsClientInZone(victim, "SafeZone Jail", true) && AreClientsHitmanRelated(victim, attacker))) return ReturnType;
	}
	
	PrintHintText(attacker, "<font size=\"26\" color=\"#00ff00\"><b><u>You cannot kill players here</b></u></font>");
	return Plugin_Handled;
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if(!IsValidClient(victim) || !IsValidClient(attacker)) return;
	
	if(!Zone_IsClientInZone(victim, "SafeZone", false) && !Zone_IsClientInZone(attacker, "SafeZone", false)) return;
	
	SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", 1.0);
}

public void fuckZones_OnStartTouchZone_Post(int client, int entity, const char[] zoneName, int type)
{
	if(strncmp(zoneName, "SafeZone", 8) == 0 && !Zone_IsClientInZone(client, "SafeZone", false) && StrContains(zoneName, "NoText", false) == -1)
	{
		PrintHintText(client, "<font size=\"26\" color=\"#00ff00\"><b><u>No Kill Zone</b></u></font>");
	}
}

public IsValidClient( client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}
	