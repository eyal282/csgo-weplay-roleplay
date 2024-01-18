#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <Eyal-RP>

public Plugin:myinfo =
{
	name = "Slow Hop",
	description = "Limits players speed after every jump",
	author = "LumiStance",
	version = "0.2-lm",
	url = "http://srcds.lumistance.com/"
};

new Handle:g_ConVar_Limit;

new Float:g_VelocityLimit;

public OnPluginStart()
{
	g_ConVar_Limit = CreateConVar("sm_slowhop_limit", "420.0", "Maximum velocity a play is allowed when jumping. 0 Disables limiting.", 64, false, 0.0, false, 0.0);
	AutoExecConfig(true, "slowhop", "sourcemod");
	SetConVarString(CreateConVar("sm_slowhop_version", "0.2-lm", "[SM] Slow Hop Version", 131392, false, 0.0, false, 0.0), "0.2-lm", false, false);
	HookConVarChange(g_ConVar_Limit, Event_CvarChange);
	HookEvent("player_jump", Event_PlayerJump, EventHookMode_Post);
}

public OnMapStart()
{
	ServerCommand("sv_staminamax 0; sv_staminajumpcost 0; sv_staminalandcost 0");
}

public OnConfigsExecuted()
{
	RefreshCvarCache();
}

public Event_CvarChange(Handle:convar, String:oldValue[], String:newValue[])
{
	RefreshCvarCache();
}

RefreshCvarCache()
{
	g_VelocityLimit = GetConVarFloat(g_ConVar_Limit);
}

public Action:Event_PlayerJump(Handle:event, String:name[], bool:dontBroadcast)
{
	if (g_VelocityLimit)
	{
		CreateTimer(0.1, Event_PostJump, GetEventInt(event, "userid"));
	}
}

public Action:Event_PostJump(Handle:timer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return;
		
	else if(!IsValidEntity(client)) // Don't ask questions don't hear lies
		return;
		
	decl Float:vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	
	new Float:scale = g_VelocityLimit / SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0));
	
	if (scale < 1.0)
	{
		vVel[0] = vVel[0] * scale;
		vVel[1] = vVel[1] * scale;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}
}

 