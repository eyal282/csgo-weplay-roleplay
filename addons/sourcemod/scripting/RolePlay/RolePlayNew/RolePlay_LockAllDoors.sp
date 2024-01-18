
#include <sourcemod>
#include <sdktools>
#include <Eyal-RP>

#define PLUGIN_VERSION "1.0"
#pragma newdecls required

#pragma semicolon 1

public void OnPluginStart()
{
    RegAdminCmd("sm_lockalldoors", Command_LockAllDoors, ADMFLAG_GENERIC);
    RegAdminCmd("sm_doorall", Command_LockAllDoors, ADMFLAG_GENERIC);
    RegAdminCmd("sm_unlockalldoors", Command_UnlockAllDoors, ADMFLAG_GENERIC);
    RegAdminCmd("sm_undoorall", Command_UnlockAllDoors, ADMFLAG_GENERIC);
}

public Action Command_LockAllDoors(int client, int args)
{
    int entity = -1;

    while((entity = FindEntityByClassname(entity, "func_door")) != -1)
    {
        TryLockDoor(entity);
    }
    
    entity = -1;

    while((entity = FindEntityByClassname(entity, "func_door_rotating")) != -1)
    {
        TryLockDoor(entity);
    }

    entity = -1;

    while((entity = FindEntityByClassname(entity, "prop_door_rotating")) != -1)
    {
        TryLockDoor(entity);
    }

    RP_PrintToChatAll("\x04%N\x01 locked all doors", client);

    return Plugin_Handled;
}


public Action Command_UnlockAllDoors(int client, int args)
{
    int entity = -1;

    while((entity = FindEntityByClassname(entity, "func_door")) != -1)
    {
        TryUnlockDoor(entity);
    }

    entity = -1;

    while((entity = FindEntityByClassname(entity, "func_door_rotating")) != -1)
    {
        TryUnlockDoor(entity);
    }

    entity = -1;

    while((entity = FindEntityByClassname(entity, "prop_door_rotating")) != -1)
    {
        TryUnlockDoor(entity);
    }

    RP_PrintToChatAll("\x04%N\x01 unlocked all doors", client);

    return Plugin_Handled;
}

public void TryLockDoor(int entity)
{
    char iName[128];
    GetEntPropString(entity, Prop_Data, "m_iName", iName, sizeof(iName));

    if(strncmp(iName, "RolePlay_Door_", 14) == 0)
        return;

    AcceptEntityInput(entity, "Close");
    AcceptEntityInput(entity, "Lock");
}

public void TryUnlockDoor(int entity)
{
    char iName[128];
    GetEntPropString(entity, Prop_Data, "m_iName", iName, sizeof(iName));

    if(strncmp(iName, "RolePlay_Door_", 14) == 0)
        return;

    AcceptEntityInput(entity, "Unlock");
}