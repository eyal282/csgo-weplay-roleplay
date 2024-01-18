#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
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
	
	ServerCommand("mp_backup_round_file \"\"");
	ServerCommand("mp_backup_round_file_last \"\"");
	ServerCommand("mp_backup_round_file_pattern \"\"");
	ServerCommand("mp_backup_round_auto 0");
	
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);
}

public OnMapStart()
{
	ServerCommand("mp_backup_round_file \"\"");
	ServerCommand("mp_backup_round_file_last \"\"");
	ServerCommand("mp_backup_round_file_pattern \"\"");
	ServerCommand("mp_backup_round_auto 0");
}

public Action:Event_OnPlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid", 0));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker", 0));

	if (!victim || !attacker)
	{
		return;
	}
	
	SetEntProp(attacker, Prop_Data, "m_iFrags", 0, 4, 0);
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_ScoreBoard");
	CreateNative("RP_UpdateScoreBoard", _RP_UpdateScoreBoard);
	CreateNative("RP_UpdateScoreBoard_Karma", _RP_UpdateScoreBoard_Karma);
}

public _RP_UpdateScoreBoard(Handle:plugin, numParams)
{
	UpdateScoreBoard(GetNativeCell(1));
	return 0;
}

public _RP_UpdateScoreBoard_Karma(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	CS_SetClientContributionScore(client, RP_GetKarma(client));
	return 0;
}

UpdateScoreBoard(client)
{
	CS_SetClientContributionScore(client, RP_GetKarma(client));
	SetEntProp(client, Prop_Data, "m_iFrags", 0, 4, 0);
}

 