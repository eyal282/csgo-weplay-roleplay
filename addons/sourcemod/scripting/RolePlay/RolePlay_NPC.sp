#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>
#include <fuckzones>

new String:szConfigFile[36] = "addons/sourcemod/configs/npc.ini";

#define KV_ROOT_NAME "Spawns"

new String:NPCPath[1024];

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "0.00",
	url = ""
};

new ArrayList:g_aNPCModel;
new ArrayList:g_aNPCShortName;

new g_iOldButtons[66];
new g_iEntityID[2048];
new Handle:g_hUseNPC;

public OnPluginStart()
{
	g_hUseNPC = CreateGlobalForward("OnUseNPC", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_aNPCModel = CreateArray(256);
	g_aNPCShortName = CreateArray(32);

	RegAdminCmd("sm_addnpc", Command_AddNPC, ADMFLAG_ROOT);
	RegAdminCmd("sm_proxdeletenpc", Command_DeleteNPC, ADMFLAG_ROOT);
	RegAdminCmd("sm_deletenpc", Command_DeleteNPC, ADMFLAG_ROOT);
	RegAdminCmd("sm_reloadnpc", Command_ReloadNPC, ADMFLAG_ROOT);
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	
	BuildPath(Path_SM, NPCPath, sizeof(NPCPath), "configs/npc.ini");
	
	
}

public Action:Command_ReloadNPC(client, args)
{
	ClearAllNPC();
	
	ReadSpawns();
	
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{	
	if (buttons & IN_USE && !(g_iOldButtons[client] & IN_USE))
	{
		if(!Zone_IsClientInZone(client, "NoNPC", false))
		{
			new doorTarget = GetClientAimTarget(client, false);
			
			new String:Classname[64] = "null";
				
			new Float:Origin[3], Float:NPCOrigin[3], Float:doorOrigin[3];
								
			GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
			
			new Float:distance = 65535.0;
			
			if(doorTarget != -1)
			{
				GetEntPropVector(doorTarget, Prop_Data, "m_vecOrigin", doorOrigin);
				GetEdictClassname(doorTarget, Classname, sizeof(Classname));
				
				distance = GetVectorDistance(Origin, doorOrigin, false);
			}
			
			if(strncmp(Classname, "prop_door", 9) != 0 && strncmp(Classname, "func_door", 9) != 0 && distance > 100.0)
			{
				new NPC = -1, WinnerNPC, Float:WinnerNPCDistance;
				
				while((NPC = FindEntityByTargetname(NPC, "RolePlay_NPC", false, false)) != -1)
				{
					GetEntPropVector(NPC, Prop_Data, "m_vecOrigin", NPCOrigin);
					
					distance = GetVectorDistance(Origin, NPCOrigin, false);
					
					if(distance > 150.0)
						continue;
						
					if(WinnerNPC == 0 || distance < WinnerNPCDistance)
					{
						WinnerNPC = NPC;
						WinnerNPCDistance = GetVectorDistance(Origin, NPCOrigin, false);
					}
				}
				
				NPC = WinnerNPC;
				
				if(NPC == 0)
					return;

				new target = GetClientAimTarget(client, true);
				
				new Float:TargetOrigin[3];
				
				if(target != -1)
				{
					GetEntPropVector(target, Prop_Data, "m_vecOrigin", TargetOrigin);
				}
				if(target == -1 || GetVectorDistance(Origin, NPCOrigin, false) < GetVectorDistance(Origin, TargetOrigin, false)) // not interacting with a player.
				{
					new Action:result;
					Call_StartForward(g_hUseNPC);
					Call_PushCell(client);
					Call_PushCell(g_iEntityID[NPC]);
					Call_PushCell(NPC);
					Call_Finish(result);
				}
			}
		}
	}
	g_iOldButtons[client] = buttons;
}


public bool:Trace_HitNPCOnly(entity, contentsMask) 
{ 
	if(entity <= MaxClients)
		return false;
		
	new String:TargetName[32]; 
	
	GetEntPropString(entity, Prop_Data, "m_iName", TargetName, sizeof(TargetName));
	
	return StrEqual(TargetName, "RolePlay_NPC");
}  

public Action:Event_RoundStart(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	ClearAllNPC();
	
	ReadSpawns();
}

public OnMapStart()
{
	ClearAllNPC();
	
	ReadSpawns();
	
	PrecacheModel("models/error.mdl", true);
}


ReadSpawns()
{
	CreateTimer(0.5, Timer_ReadSpawns, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ReadSpawns(Handle hTimer)
{
	char szNpcShortName[32];
	char szNpcModel[256];
	float origin[3] = { 0.0, ... };
	float angles[3] = { 0.0, ... };
	new KeyValues:kv = CreateKeyValues("Spawns");
	FileToKeyValues(kv, szConfigFile);
	if (!KvGotoFirstSubKey(kv, true))
	{
		return Plugin_Continue;
	}
	do {
		KvGetString(kv, "short_name", szNpcShortName, 32);
		
		new pos = FindStringInArray(g_aNPCShortName, szNpcShortName);
		
		if(pos == -1)
			continue;
			
		GetArrayString(g_aNPCModel, pos, szNpcModel, 256);

		if(szNpcModel[0] == EOS)
			continue;

		origin[0] = KvGetFloat(kv, "origin_x", 0.0);
		origin[1] = KvGetFloat(kv, "origin_y", 0.0);
		origin[2] = KvGetFloat(kv, "origin_z", 0.0);
		angles[0] = KvGetFloat(kv, "angles_x", 0.0);
		angles[1] = KvGetFloat(kv, "angles_y", 0.0);
		angles[2] = KvGetFloat(kv, "angles_z", 0.0);

		Spawn_NPC(origin, angles, szNpcModel, szNpcShortName);
	
	} while (KvGotoNextKey(kv, true));
	CloseHandle(kv);
	kv = null;

	return Plugin_Continue;
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_NPC");
	CreateNative("RP_CreateNPC", _RP_CreateNPC);
}

public _RP_CreateNPC(Handle:plugin, numParams)
{
	new String:szModel[256];
	GetNativeString(1, szModel, 256);
	new String:szShortName[256];
	GetNativeString(2, szShortName, 256);
	
	if (FindStringInArray(g_aNPCModel, szModel) != -1)
	{
		return FindStringInArray(g_aNPCModel, szModel);
	}

	PushArrayString(g_aNPCModel, szModel);
	PushArrayString(g_aNPCShortName, szShortName);
	return GetArraySize(g_aNPCModel) - 1;
}

Spawn_NPC(Float:origin[3], Float:angles[3], String:model[], String:className[])
{
	int  iEnt = CreateEntityByName("prop_dynamic_override", -1);
	DispatchKeyValue(iEnt, "disableshadows", "1");

	// Bone Followers vore 400 edicts.
	DispatchKeyValue(iEnt, "DisableBoneFollowers", "1");
	DispatchKeyValue(iEnt, "solid", "6");
	DispatchKeyValue(iEnt, "model", model);
	DispatchSpawn(iEnt);
	
	SetEntityMoveType(iEnt, MOVETYPE_NONE);
	SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", 12);
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 6);
	SetEntProp(iEnt, Prop_Send, "m_CollisionGroup", 1);
	
	TeleportEntity(iEnt, origin, angles, NULL_VECTOR);
	SetEntityModel(iEnt, model);
	
	SetEntPropString(iEnt, Prop_Data, "m_iName", "RolePlay_NPC");
	
	g_iEntityID[iEnt] = FindStringInArray(g_aNPCShortName, className);
	/*
	new touchEntity = CreateEntityByName("trigger_multiple");
	DispatchKeyValue(touchEntity, "classname", className);
	DispatchKeyValue(touchEntity, "solid", "6");
	DispatchKeyValue(touchEntity, "StartDisabled", "0");
	DispatchKeyValue(touchEntity, "model", "models/error.mdl");
	DispatchSpawn(touchEntity);
	SetEntityRenderMode(touchEntity, RenderMode:1);
	
	new Float:fMins[3] = {-250.0, -250.0, -250.0};
	new Float:fMaxs[3] = {512.0, 400.0, 450.0};
	SetEntPropVector(touchEntity, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(touchEntity, Prop_Send, "m_vecMaxs", fMaxs);
	SetEntProp(touchEntity, Prop_Send, "m_nSolidType", any:2, 4, 0);
	SetEntProp(touchEntity, Prop_Send, "m_CollisionGroup", any:4, 4, 0);
	SetEntProp(touchEntity, Prop_Send, "m_usSolidFlags", any:12, 4, 0);
	new iEffects = GetEntProp(touchEntity, Prop_Send, "m_fEffects", 4, 0);
	iEffects |= 32;
	SetEntProp(touchEntity, Prop_Send, "m_fEffects", iEffects, 4, 0);
	TeleportEntity(touchEntity, origin, Float:{0.0, 0.0, 0.0}, NULL_VECTOR);
	
	SetEntPropString(iEnt, Prop_Data, "m_iName", "RolePlay_NPC");
	
	g_iEntityID[touchEntity] = FindStringInArray(g_aNPCShortName, className);
	SDKHookEx(touchEntity, SDKHook_Touch, NPC_Touch);
	
	SetEntPropEnt(touchEntity, Prop_Send, "m_hOwnerEntity", iEnt);
	*/
	return iEnt;
}

stock ClearAllNPC()
{
	new ent = -1;
	
	while((ent = FindEntityByTargetname(ent, "RolePlay_NPC", false, false)) != -1)
	{
		AcceptEntityInput(ent, "Kill");
	}
}

public Action:Command_AddNPC(client, args)
{
	new Handle:hMenu = CreateMenu(AddNPC_MenuHandler);
	
	new String:TempFormat[128];
	
	for (new i = 0; i < GetArraySize(g_aNPCShortName);i++)
	{
		GetArrayString(g_aNPCShortName, i, TempFormat, sizeof(TempFormat));
		AddMenuItem(hMenu, TempFormat, TempFormat);
	}
	
	RP_SetMenuTitle(hMenu, "NPC Maker\nChoose what type of NPC you want to add:");
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public AddNPC_MenuHandler(Handle:hMenu, MenuAction:action, client, item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);
	
	else if (action == MenuAction_Select)
	{
		new Float:Origin[3], Float:Angles[3], String:ShortName[32];
		
		GetMenuItem(hMenu, item, ShortName, sizeof(ShortName));
		
		GetClientEyePosition(client, Origin);
		
		Origin[2] -= 64.0;
		GetClientEyeAngles(client, Angles);
		
		if(AddNewNPC(Origin, Angles, ShortName))
		{
			RP_PrintToChat(client, "NPC Added. sm_reloadnpc to show the new NPC.")
		}
	}
}

public Action:Command_DeleteNPC(client, args)
{
		
	new NPC = -1, WinnerNPC, Float:WinnerNPCDistance, Float:Origin[3], Float:NPCOrigin[3], Float:distance;
	
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
	
	
	while((NPC = FindEntityByTargetname(NPC, "RolePlay_NPC", false, false)) != -1)
	{
		GetEntPropVector(NPC, Prop_Data, "m_vecOrigin", NPCOrigin);
		
		distance = GetVectorDistance(Origin, NPCOrigin, false);
		
		if(distance > 150.0)
			continue;
			
		if(WinnerNPC == 0 || distance < WinnerNPCDistance)
		{
			WinnerNPC = NPC;
			WinnerNPCDistance = GetVectorDistance(Origin, NPCOrigin, false);
		}
	}
	
	NPC = WinnerNPC;
	
	if(NPC == 0)
	{
		RP_PrintToChat(client, "NPC Not found!");
		return Plugin_Handled;
	}
	
	GetEntPropVector(NPC, Prop_Data, "m_vecOrigin", NPCOrigin);
	if(DeleteExistingNPC(NPCOrigin))
	{
		RP_PrintToChat(client, "NPC Deleted");
	}
	else
	{
		RP_PrintToChat(client, "Couldn't find nearby NPC.")
	}
	
	return Plugin_Handled;
}

stock AddNewNPC(Float:Origin[3], Float:Angles[3], String:ShortName[])
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, NPCPath))
	{
		CreateEmptyKvFile(NPCPath);
		
		if(!FileToKeyValues(keyValues, NPCPath))
			SetFailState("Something that should never happen has happened.");
	}
	
	KvSavePosition(keyValues);
	
	if(!KvGotoFirstSubKey(keyValues, true))
	{
		CloseHandle(keyValues);
		return false;
	}
	
	new LastID;
	
	new String:sNPCID[11];
	
	do
	{
		KvGetSectionName(keyValues, sNPCID, sizeof(sNPCID));
		
		LastID = StringToInt(sNPCID);
	}
	while(KvGotoNextKey(keyValues))
	
	LastID++;
	
	IntToString(LastID, sNPCID, sizeof(sNPCID));
	
	KvGoBack(keyValues);
	
	KvJumpToKey(keyValues, sNPCID, true);
	
	KvSetString(keyValues, "short_name", ShortName);
	
	KvSetFloat(keyValues, "origin_x", Origin[0]);
	KvSetFloat(keyValues, "origin_y", Origin[1]);
	KvSetFloat(keyValues, "origin_z", Origin[2]);
	KvSetFloat(keyValues, "angles_x", Angles[0]);
	KvSetFloat(keyValues, "angles_y", Angles[1]);
	KvSetFloat(keyValues, "angles_z", Angles[2]);
		
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, NPCPath);
	CloseHandle(keyValues);
	
	return true;
}

stock bool:DeleteExistingNPC(Float:NPCOrigin[3])
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, NPCPath))
	{
		CloseHandle(keyValues);
		return false;
	}
	
	if(!KvGotoFirstSubKey(keyValues, true))
	{
		CloseHandle(keyValues);
		return false;
	}	
	
	new bool:Deleted, Float:Origin[3];
	
	do
	{
		Origin[0] = KvGetFloat(keyValues, "origin_x");
		Origin[1] = KvGetFloat(keyValues, "origin_y");
		Origin[2] = KvGetFloat(keyValues, "origin_z");
		
		if(GetVectorDistance(Origin, NPCOrigin, false) <= 1.0)
		{
			Deleted = true;
			KvDeleteThis(keyValues);
			break;
		}
	}
	while(KvGotoNextKey(keyValues))
	
	KvRewind(keyValues);
	
	if(Deleted)
	{
		KeyValuesToFile(keyValues, NPCPath);
		CloseHandle(keyValues);
		
		ServerCommand("sm_reloadnpc");
		return Deleted;
	}
	
	return false;
}

stock CreateEmptyKvFile(const String:Path[])
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, Path);
	
	CloseHandle(keyValues);
}