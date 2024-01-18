#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <Eyal-RP> 

new EngineVersion:g_Game;

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

public OnPluginStart()
{
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	HookEvent("player_connect_full", Event_OnFullConnect, EventHookMode_Post);
	
	AddCommandListener(command_JoinTeam, "jointeam");
}

public Action:command_JoinTeam(client, String:command[], argc)
{
	if(!IsValidTeam(client))
		CS_SwitchTeam(client, CS_TEAM_T);
		
	return Plugin_Stop;
}

public Action:Event_OnFullConnect(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid", 0));
	if(client != 0)
	{
		CS_SwitchTeam(client, CS_TEAM_T);
	}
}
 
stock bool:IsValidTeam(client)
{
	return GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT
}	