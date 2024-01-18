#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <Eyal-RP>

new Handle:g_hKillTimer[MAXPLAYERS+1];

new Handle:fw_OnPlayerSuiciding = INVALID_HANDLE;

public OnPluginStart()
{
	AddCommandListener(Command_Kill, "kill");
	AddCommandListener(Command_Kill, "explode");
	AddCommandListener(Command_Kill, "explodevector");
	AddCommandListener(Command_Kill, "killvector");
	
	fw_OnPlayerSuiciding = CreateGlobalForward("RP_OnPlayerSuiciding", ET_Event, Param_Cell);
	
	
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_Main");
	CreateNative("RP_IsPlayerSuiciding", _RP_IsPlayerSuiciding);
	CreateNative("RP_StopPlayerSuiciding", _RP_StopPlayerSuiciding);

}

public _RP_IsPlayerSuiciding(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(23, "Invalid client  index (%d)", client);
	}
	if (!IsClientConnected(client))
	{
		return ThrowNativeError(23, "Client %d is not connected", client);
	}
	if (g_hKillTimer[client] != INVALID_HANDLE)
	{
		return 1;
	}
	return 0;
}

public _RP_StopPlayerSuiciding(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		ThrowNativeError(23, "Invalid client  index (%d)", client);
	}
	if (!IsClientConnected(client))
	{
		ThrowNativeError(23, "Client %d is not connected", client);
	}
	if (g_hKillTimer[client] != INVALID_HANDLE)
	{
		ClearKill(client);
	}
}

public Action:Command_Kill(client, String:command[], argc)
{	
	if(g_hKillTimer[client] != INVALID_HANDLE)
		return Plugin_Stop;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(CheckCommandAccess(i, "sm_slay", ADMFLAG_GENERIC))
		{
			RP_PrintToChat(client, "Cannot suicide with admins online. Use !fk if you're stuck.");
			return Plugin_Stop;
		}
	}
	
	new Action:result;

	Call_StartForward(fw_OnPlayerSuiciding);
	
	Call_PushCell(client);
	
	Call_Finish(result);
	
	if(result == Plugin_Handled || result == Plugin_Stop)
		return Plugin_Stop;
		
	g_hKillTimer[client] = CreateTimer(6.0, KillPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	
	RP_PrintToChat(client, "You will get killed in \x046\x01 seconds.");
	return Plugin_Stop;
}

public Action:KillPlayer(Handle:timer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if (client == 0)
		return;
	
	ForcePlayerSuicide(client);
	RP_PrintToChatAll("\x02%N\x01 has chosen the easy way out.", client);
	g_hKillTimer[client] = INVALID_HANDLE;
}

public OnClientDisconnect(client)
{
	ClearKill(client);
}

public OnClientPutInServer(client)
{
	ClearKill(client);
}

ClearKill(client)
{
	if(g_hKillTimer[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hKillTimer[client]);
		g_hKillTimer[client] = INVALID_HANDLE;
	}
}