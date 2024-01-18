#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <collisionhook>
#include <fuckzones>

new const String:PLUGIN_VERSION[] = "1.0";

public Plugin:myinfo = 
{
	name = "Never get stuck inside players",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Allows you to pass through players if you are stuck inside them.",
	version = PLUGIN_VERSION,
	url = ""
}

enum Collision_Group_t
{
    COLLISION_GROUP_NONE  = 0,
    COLLISION_GROUP_DEBRIS,            // Collides with nothing but world and static stuff
    COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
    COLLISION_GROUP_INTERACTIVE_DEBRIS,    // Collides with everything except other interactive debris or debris
    COLLISION_GROUP_INTERACTIVE,    // Collides with everything except interactive debris or debris
    COLLISION_GROUP_PLAYER,
    COLLISION_GROUP_BREAKABLE_GLASS,
    COLLISION_GROUP_VEHICLE,
    COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
                                        // TF2, this filters out other players and CBaseObjects
    COLLISION_GROUP_NPC,            // Generic NPC group
    COLLISION_GROUP_IN_VEHICLE,        // for any entity inside a vehicle
    COLLISION_GROUP_WEAPON,            // for any weapons that need collision detection
    COLLISION_GROUP_VEHICLE_CLIP,    // vehicle clip brush to restrict vehicle movement
    COLLISION_GROUP_PROJECTILE,        // Projectiles!
    COLLISION_GROUP_DOOR_BLOCKER,    // Blocks entities not permitted to get near moving doors
    COLLISION_GROUP_PASSABLE_DOOR,    // Doors that the player shouldn't collide with
    COLLISION_GROUP_DISSOLVING,        // Things that are dissolving are in this group
    COLLISION_GROUP_PUSHAWAY,        // Nonsolid on client and server, pushaway in player code

    COLLISION_GROUP_NPC_ACTOR,        // Used so NPCs in scripts ignore the player.
    COLLISION_GROUP_NPC_SCRIPTED,    // USed for NPCs in scripts that should not collide with each other

    LAST_SHARED_COLLISION_GROUP
}; 

new bool:StuckInsideEachother[MAXPLAYERS+1][MAXPLAYERS+1];

#define CHECK_DELAY 0.4

new Handle:hcv_SolidTeammates;

public APLRes:AskPluginLoad2(Handle:myself)
{
	RegPluginLibrary("Never_Stuck_Inside_Players");
}

public OnPluginStart()
{
	hcv_SolidTeammates = FindConVar("mp_solid_teammates");
}
public OnMapStart()
{
	CreateTimer(CHECK_DELAY, Timer_CheckStuckPlayers, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action:Timer_CheckStuckPlayers(Handle:hTimer)
{
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		for(new otherClient=1;otherClient <= MaxClients;otherClient++)
		{
			if(!IsClientInGame(otherClient))
				continue;
				
			StuckInsideEachother[i][otherClient] = false;
				
			
			if(!IsPlayerAlive(i) || !IsPlayerAlive(otherClient))
				continue;
				
			
			if(ArePlayersStuckInsideEachother(i, otherClient))
			{
				if(!(
				(view_as<Collision_Group_t>(GetEntProp(i, Prop_Send, "m_CollisionGroup")) == COLLISION_GROUP_DEBRIS_TRIGGER && view_as<Collision_Group_t>(GetEntProp(otherClient, Prop_Send, "m_CollisionGroup")) == COLLISION_GROUP_DEBRIS_TRIGGER)
				|| (hcv_SolidTeammates != INVALID_HANDLE && GetConVarInt(hcv_SolidTeammates) != 1 && GetClientTeam(i) == GetClientTeam(otherClient)))
				)
					StuckInsideEachother[i][otherClient] = true;
			}
			
			if(Zone_IsClientInZone(i, "Trespassing", false) || Zone_IsClientInZone(otherClient, "Trespassing", false))
				StuckInsideEachother[i][otherClient] = true;
		}
	}
}

public Action:CH_PassFilter(ent1, ent2, &bool:result)
{
	if(!IsPlayer(ent1) || !IsPlayer(ent2))
		return Plugin_Continue;
	
	if(StuckInsideEachother[ent1][ent2] || StuckInsideEachother[ent2][ent1])
	{
		result = false;
		
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}


stock bool:IsPlayer(client)
{
	if(client <= 0)
		return false;
		
	else if(client > MaxClients)
		return false;
		
	return true;
}


stock bool ArePlayersStuckInsideEachother(int client, int otherClient)
{
	float vecMin[3], vecMax[3], vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
    
	GetClientAbsOrigin(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceRayHitSecondPlayer, otherClient);
	
	return TR_DidHit();
}


public bool TraceRayHitSecondPlayer(int entityhit, int mask, otherClient) 
{
    return entityhit == otherClient;
}