#include <sourcemod>
#include <sdkhooks>
#include <cstrike>

public Plugin:myinfo = {
	name = "Damage Indicator",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Shows where you damage and who you damage and how much.",
	version = "1.0",
	url = "NULL"
};

int DamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];
int LastDamageTaken[MAXPLAYERS+1][MAXPLAYERS+1];

public OnPluginStart()
{
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	
	RegAdminCmd("sm_showdamage", Command_ShowDamage, ADMFLAG_GENERIC, "Shows you damage done on a player this and last life");
	RegAdminCmd("sm_showdmg", Command_ShowDamage, ADMFLAG_GENERIC, "Shows you damage done on a player this and last life");
}

public Action:Command_ShowDamage(int client, int args)
{
	new String:Args[64];
	
	GetCmdArgString(Args, sizeof(Args));
	
	StripQuotes(Args);
	
	new target = FindTarget(client, Args, false, false);
	
	if(target == -1)
	{
		PrintToConsole(client, "%s was not found", Args);
		
		return Plugin_Handled;
	}
	PrintToConsole(client, "%N's Damage taken this life:", target);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		if(DamageTaken[target][i] > 0)
			PrintToConsole(client, "%N - %i damage", i, DamageTaken[target][i]);
	}
	
	PrintToConsole(client, "%N's Damage taken last life:", target);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		if(LastDamageTaken[target][i] > 0)
			PrintToConsole(client, "%N - %i damage", i, LastDamageTaken[target][i]);
	}
	
	return Plugin_Handled;
}

public Action:Event_PlayerHurt(Handle:hEvent, String:Name[], bool:dontBroadcast)
{
	/* hitgroup 0 = generic */
	/* hitgroup 1 = head */
	/* hitgroup 2 = chest */
	/* hitgroup 3 = stomach */
	/* hitgroup 4 = left arm */
	/* hitgroup 5 = right arm */
	/* hitgroup 6 = left leg */
	/* hitgroup 7 = right leg */
	new type = GetEventInt(hEvent, "type");
	
	if(type & DMG_FALL)
		return;
		
	new victim 			= GetClientOfUserId(GetEventInt(hEvent, "userid"));
	new attacker 		= GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	new damage 	= GetEventInt(hEvent, "dmg_health");	
	
	DamageTaken[victim][attacker] += damage;
}

public Action:Event_PlayerDeath(Handle:hEvent, String:Name[], bool:dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(victim == 0)
		return;
	
	for(new i=1;i <= MaxClients;i++)
	{
		LastDamageTaken[victim][i] = 0;
		
		new damage = DamageTaken[victim][i];
		
		DamageTaken[victim][i] = 0;
		
		if(!IsClientInGame(i))
			continue;
			
		LastDamageTaken[victim][i] = damage;
	}
}