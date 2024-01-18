#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_NORECEIVESHADOW          (1 << 6)
#define EF_PARENT_ANIMATES          (1 << 9)

new const String:PLUGIN_VERSION[] = "1.0";

new ClientGlow[MAXPLAYERS+1];

new ClientLevel[MAXPLAYERS+1];

new g_iKarma[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "WePlay - RolePlay Karma Display",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Players above 800 karma glow to CT.",
	version = PLUGIN_VERSION,
	url = ""
}

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	
	//ServerCommand("sv_force_transmit_players 1");
	//ServerCommand("sv_force_transmit_ents 1");
}

public void OnPluginEnd()
{
	for(int i=1;i < MAXPLAYERS+1;i++)
	{
		UC_TryDestroyGlow(i);
	}
}

public RP_OnClientJailStatusPost(client)
{
	UC_TryDestroyGlow(client);
	
	if(!RP_IsClientInJail(client))
		UC_CreateGlow(client, {255, 0, 0});
}

public RolePlay_OnKarmaChangedPost(client, karma, totalKarma, String:Reason[], any:data)
{
	new oldKarma = g_iKarma[client];
	
	if(oldKarma >= ARREST_KARMA && (totalKarma < ARREST_KARMA || totalKarma >= BOUNTY_KARMA) )
		UC_TryDestroyGlow(client);
		
	else if((oldKarma < ARREST_KARMA || oldKarma >= BOUNTY_KARMA) && totalKarma >= ARREST_KARMA && totalKarma < BOUNTY_KARMA)
		UC_CreateGlow(client, {255, 0, 0});
	
	g_iKarma[client] = totalKarma;
}

public OnClientChangeJobPost(client, job)
{
	UC_TryDestroyGlow(client);
	
	if(job == -1)
	{
		ClientLevel[client] = -1;
		
		return;
	}
	
	ClientLevel[client] = RP_GetClientLevel(client, job);
}

public Action:Event_PlayerSpawn(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client == 0)
		return;
	
	UC_TryDestroyGlow(client);
}

public Action:Event_PlayerDeath(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client == 0)
		return;
	
	UC_TryDestroyGlow(client);
}

public OnClientDisconnect_Post(client)
{
	UC_TryDestroyGlow(client);
}

stock bool UC_CreateGlow(int client, int Color[3])
{
	ClientGlow[client] = 0;
	char Model[PLATFORM_MAX_PATH];

	// Get the original model path
	GetEntPropString(client, Prop_Data, "m_ModelName", Model, sizeof(Model));
	
	int GlowEnt = CreateEntityByName("prop_dynamic");
		
	if(GlowEnt == -1)
		return false;
		
	// This function no longer supports CSS
	
	DispatchKeyValue(GlowEnt, "model", Model);
	DispatchKeyValue(GlowEnt, "disablereceiveshadows", "1");
	DispatchKeyValue(GlowEnt, "disableshadows", "1");
	DispatchKeyValue(GlowEnt, "solid", "0");
	DispatchKeyValue(GlowEnt, "spawnflags", "256");
	DispatchKeyValue(GlowEnt, "renderamt", "0");
	SetEntProp(GlowEnt, Prop_Send, "m_CollisionGroup", 11);
	
	// Give glowing effect to the entity
	
	SetEntProp(GlowEnt, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(GlowEnt, Prop_Send, "m_nGlowStyle", 1);
	SetEntPropFloat(GlowEnt, Prop_Send, "m_flGlowMaxDist", 10000.0);
	
	// Set glowing color
	
	int VariantColor[4];
		
	for(int i=0;i < 3;i++)
		VariantColor[i] = Color[i];
		
	VariantColor[3] = 255
	
	SetVariantColor(VariantColor);
	AcceptEntityInput(GlowEnt, "SetGlowColor");

	
	// Spawn and teleport the entity
	DispatchSpawn(GlowEnt);
	
	int fEffects = GetEntProp(GlowEnt, Prop_Send, "m_fEffects");
	SetEntProp(GlowEnt, Prop_Send, "m_fEffects", fEffects|EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_PARENT_ANIMATES);
	
	// Set the activator and group the entity
	SetVariantString("!activator");
	AcceptEntityInput(GlowEnt, "SetParent", client);
	
	SetVariantString("primary");
	AcceptEntityInput(GlowEnt, "SetParentAttachment", GlowEnt, GlowEnt, 0);
	
	AcceptEntityInput(GlowEnt, "TurnOn");
	
	SetEntPropEnt(GlowEnt, Prop_Send, "m_hOwnerEntity", client);
	
	SDKHook(GlowEnt, SDKHook_SetTransmit, Hook_ShouldSeeGlow);
	ClientGlow[client] = GlowEnt;
	
	return true;

}


public Action Hook_ShouldSeeGlow(int glow, int viewer)
{
	
	if(!IsValidEntity(glow))
	{
		SDKUnhook(glow, SDKHook_SetTransmit, Hook_ShouldSeeGlow);
		return Plugin_Continue;
	}	
	
	int client = GetEntPropEnt(glow, Prop_Send, "m_hOwnerEntity");
	
	if(client == viewer)
		return Plugin_Handled;
		
	else if(GetClientTeam(client) == CS_TEAM_CT)
		return Plugin_Handled;
	
	int ObserverTarget = GetEntPropEnt(viewer, Prop_Send, "m_hObserverTarget"); // This is the player the viewer is spectating. No need to check if it's invalid ( -1 )
	
	if(ObserverTarget == client)
		return Plugin_Handled;
	
	else if(GetClientTeam(viewer) != CS_TEAM_CT)
		return Plugin_Handled;
	
	if(!CanSeeGlowByLevelDistance(client, viewer))
		return Plugin_Handled;
		
	
	return Plugin_Continue;
}

stock bool UC_TryDestroyGlow(int client)
{
	if(ClientGlow[client] != 0 && IsValidEntity(ClientGlow[client]))
	{
		AcceptEntityInput(ClientGlow[client], "TurnOff");
		AcceptEntityInput(ClientGlow[client], "Kill");
		ClientGlow[client] = 0;
		return true;
	}
	
	return false;
}

stock bool:CanSeeGlowByLevelDistance(observedClient, viewer)
{
	new Float:Origin[3], Float:viewerOrigin[3];
	
	GetEntPropVector(observedClient, Prop_Data, "m_vecOrigin", Origin);
	GetEntPropVector(viewer, Prop_Data, "m_vecOrigin", viewerOrigin);
	
	new Float:Distance = GetVectorDistance(Origin, viewerOrigin, false);
	
	switch(ClientLevel[viewer])
	{
		case 0, 1: return Distance < 64.0;
		case 2: return Distance < 128.0;
		case 3: return Distance < 150.0;
		case 4,5,6,7,8,9,10: return Distance < 256.0; // Levels 4 to 10
		default: return false;
	}
}