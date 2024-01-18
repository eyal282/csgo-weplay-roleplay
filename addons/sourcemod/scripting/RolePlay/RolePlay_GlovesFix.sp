#include <sourcemod>

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
}

public OnMapStart()
{
	PrecacheModel("models/weapons/ct_arms.mdl", true);
	PrecacheModel("models/weapons/t_arms.mdl", true);
}

public Action:PlayerSpawn(Handle:event, String:name[], bool:dbc)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid", 0));
	
	if (client)
	{
		switch (GetClientTeam(client))
		{
			case 2:
			{
				SetEntPropString(client, PropType:0, "m_szArmsModel", "models/weapons/t_arms.mdl", 0);
			}
			case 3:
			{
				SetEntPropString(client, PropType:0, "m_szArmsModel", "models/weapons/ct_arms.mdl", 0);
			}
			default:
			{
			}
		}
	}
	return Action:0;
}

public bool UpdateJobStats(int client, int job)
{
	if(!IsClientInGame(client))
		return;
		
	switch (GetClientTeam(client))
	{
		case 2:
		{
			SetEntPropString(client, PropType:0, "m_szArmsModel", "models/weapons/t_arms.mdl", 0);
		}
		case 3:
		{
			SetEntPropString(client, PropType:0, "m_szArmsModel", "models/weapons/ct_arms.mdl", 0);
		}
		default:
		{
		}
	}
}

 