#pragma semicolon 1

#define PLUGIN_AUTHOR "Deathknife"
#define PLUGIN_VERSION "1.01"

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

Handle SkyName = INVALID_HANDLE;

public Plugin myinfo = 
{
	name = "Skybox",
	author = PLUGIN_AUTHOR,
	description = "Sets the skybox based on the hour",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/Deathknife273/"
};

public OnPluginStart()
{
	SkyName = FindConVar("sv_skyname");
}

public OnMapStart()
{
	TriggerTimer(CreateTimer(60.0, Timer_SetSkybox, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE), true);
}
public void OnClientPutInServer(int client) {
	//Client's cookie cached. If bot, return
	
	SetSkybox(client);
}

public void SetSkybox(int client)
{
	if (IsFakeClient(client))
		return;
		
	new String:Time[32];
	
	FormatTime(Time, sizeof(Time), "%H");
	
	new SecondsSinceMidnight = StringToInt(Time) * 3600;
	
	FormatTime(Time, sizeof(Time), "%M");
	
	SecondsSinceMidnight += StringToInt(Time) * 60;
	
	if(SecondsSinceMidnight >= 21600 && SecondsSinceMidnight <= 28800)
	{
		SendConVarValue(client, SkyName, "vertigo");
	}
	else if(SecondsSinceMidnight >= 28800 && SecondsSinceMidnight <= 68400)
	{
		//char buffer[32];
		//GetConVarString(SkyName, buffer, sizeof(buffer));
		SendConVarValue(client, SkyName, "embassy");
	}
	else 
	{
		SendConVarValue(client, SkyName, "sky_csgo_night02");
	}
}

public Action:Timer_SetSkybox(Handle:hTimer)
{
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		SetSkybox(i);
	}
}