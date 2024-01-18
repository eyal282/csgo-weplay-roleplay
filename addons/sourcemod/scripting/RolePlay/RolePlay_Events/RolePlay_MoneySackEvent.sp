#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "0.00",
	url = ""
};

#define KV_ROOT_NAME "Spawns"

new String:SpawnsPath[1024];

new Handle:g_hMoneySackTimer;

new Handle:Array_Spawns = INVALID_HANDLE;

new MIN_SACK_AMOUNT = 1;
new MAX_SACK_AMOUNT = 1;

new MIN_SACK_REWARD = 0;
new MAX_SACK_REWARD = 5;

new Float:SACK_DELAY = 5000.0;

new Handle:Trie_MoneySackEco;

public RP_OnEcoLoaded()
{	
	Trie_MoneySackEco = RP_GetEcoTrie("Money Sack");
	
	if(Trie_MoneySackEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Money Sack");
		
	new String:TempFormat[64];
	
	GetTrieString(Trie_MoneySackEco, "MIN_SACK_AMOUNT", TempFormat, sizeof(TempFormat));
	
	MIN_SACK_AMOUNT = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MoneySackEco, "MAX_SACK_AMOUNT", TempFormat, sizeof(TempFormat));
	
	MAX_SACK_AMOUNT = StringToInt(TempFormat);
	
	GetTrieString(Trie_MoneySackEco, "MIN_SACK_REWARD", TempFormat, sizeof(TempFormat));
	
	MIN_SACK_REWARD = StringToInt(TempFormat);	
	
	GetTrieString(Trie_MoneySackEco, "MAX_SACK_REWARD", TempFormat, sizeof(TempFormat));
	
	MAX_SACK_REWARD = StringToInt(TempFormat);
	
	GetTrieString(Trie_MoneySackEco, "SACK_DELAY", TempFormat, sizeof(TempFormat));
	
	SACK_DELAY = StringToFloat(TempFormat);
	
	
	if(g_hMoneySackTimer != INVALID_HANDLE)
	{
		CloseHandle(g_hMoneySackTimer);
		g_hMoneySackTimer = INVALID_HANDLE;
	}
	
	g_hMoneySackTimer = CreateTimer(SACK_DELAY, Timer_SpawnMoneySacks, _, TIMER_REPEAT);
}

public OnPluginStart()
{
	Array_Spawns = CreateArray(3);
	RegAdminCmd("sm_spawnsack", Command_SpawnSack, ADMFLAG_ROOT, "", "", 0);
	
	BuildPath(Path_SM, SpawnsPath, sizeof(SpawnsPath), "configs/money_sacks.ini");
	
	RegAdminCmd("sm_createsack", Command_CreateSack, ADMFLAG_ROOT);
	RegAdminCmd("sm_removeallsacks", Command_RemoveAllSacks, ADMFLAG_ROOT);
	
	LoadConfigFile();
	
	if(RP_GetEcoTrie("Money Sack") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

public LoadConfigFile()
{
	ClearArray(Array_Spawns);
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, SpawnsPath))
	{
		CreateEmptyKvFile(SpawnsPath);
		CloseHandle(keyValues);
		return false;
	}	

	if(!KvGotoFirstSubKey(keyValues))
	{
		CloseHandle(keyValues);
		return false;
	}
	
	new SectionIndex = 1, String:SectionName[11];
	do
	{
		IntToString(SectionIndex, SectionName, sizeof(SectionName));
		KvSetSectionName(keyValues, SectionName);
		
		new Float:Origin[3];
		
		Origin[0] = KvGetFloat(keyValues, "origin_x");
		Origin[1] = KvGetFloat(keyValues, "origin_y");
		Origin[2] = KvGetFloat(keyValues, "origin_z");
		
		PushArrayArray(Array_Spawns, Origin);
		
		SectionIndex++;
	}
	while(KvGotoNextKey(keyValues));
	
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, SpawnsPath);
	
	CloseHandle(keyValues);
	
	

		
	return true;
}


public Action:Command_CreateSack(client, args)
{
	if(!IsHighManagement(client))
	{
		// Bar color
		return Plugin_Handled;
	}
	new Float:Origin[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
	
	AddNewSpawn(Origin);
	
	RP_PrintToChat(client, "Created Money Sack spot at your location");
	
	return Plugin_Handled;
}

public Action:Command_RemoveAllSacks(client, args)
{
	if(!IsHighManagement(client))
	{
		// Bar color
		return Plugin_Handled;
	}

	DeleteAllSpawns();
	RP_PrintToChat(client, "Successfully deleted all spawns");
	return Plugin_Handled;
}

public Action:Timer_SpawnMoneySacks(Handle:timer, any:data)
{	
	StartMoneysackEvent();
}

public OnMapStart()
{
	LoadDirOfModels("models/pyroteknik/");
	LoadDirOfModels("materials/models/pyroteknik/money_sack/");
	PrecacheModel("models/pyroteknik/money_sack_nobreak.mdl", false);
}

public Action:Command_SpawnSack(client, args)
{
	if(!IsHighManagement(client))
	{
		RP_PrintToChat(client, "Sorry! but you cant use this command.");
		return Plugin_Handled;
	}	
	
	RP_PrintToChatAll("\x02%N\x01 has started the moneysack event!", client);
	StartMoneysackEvent();
	return Plugin_Handled;
}

StartMoneysackEvent()
{
	
	RP_PrintToChatAll("Someone hacked the server! watchout!!");
	PrintToChatAll(" \x02------HACKER--------\x01");
	PrintToChatAll(" \x02Spawned random money sacks around the map, collect them for money.");
	PrintToChatAll(" \x02------HACKER--------\x01");
	CleanMoneySacks();
	new amountToSpawn = GetRandomInt(MIN_SACK_AMOUNT, MAX_SACK_AMOUNT);
	
	if(amountToSpawn >= GetArraySize(Array_Spawns))
	{
		PrintToChatAll("Error: Not enough money sack spawns are in the server");
		return;
	}
	new i;
	while (i < amountToSpawn)
	{
		CreateMoneySack();
		i++;
	}
	
	LoadConfigFile(); // Spawns are deleted from array for better randomness
}

public MoneySackTouch(entity, client)
{
	if (!client || client >= MaxClients)
	{
		return;
	}
	
	new iCash = GetRandomInt(MIN_SACK_REWARD, MAX_SACK_REWARD);
	
	iCash = GiveClientCash(client, POCKET_CASH, iCash)
	
	RP_PrintToChatAll("\x02%N\x01 has picked a moneysack and found \x04$%i!", client, iCash);
	AcceptEntityInput(entity, "Kill", -1, -1, 0);
}

CreateMoneySack()
{
	new sack = CreateEntityByName("prop_physics_override", -1);
	if (IsValidEntity(sack))
	{
		DispatchKeyValue(sack, "model", "models/pyroteknik/money_sack_nobreak.mdl");
		DispatchKeyValue(sack, "disableshadows", "1");
		DispatchKeyValue(sack, "disablereceiveshadows", "1");
		DispatchKeyValue(sack, "solid", "1");
		DispatchKeyValue(sack, "PerformanceMode", "1");
		DispatchKeyValue(sack, "targetname", "money_sack");
		DispatchSpawn(sack);
		
		new pos = GetRandomInt(0, GetArraySize(Array_Spawns) - 1);
		
		new Float:Origin[3];
		GetArrayArray(Array_Spawns, pos, Origin);
		RemoveFromArray(Array_Spawns, pos);
		
		new Float:Angles[3];
		
		if(GetRandomInt(0, 1) == 1)
			Angles[0] = GetRandomFloat(10.0, 90.0);
			
		else
			Angles[0] = GetRandomFloat(-10.0, -90.0);

		SetEntProp(sack, Prop_Data, "m_nSolidType", SOLID_BBOX);
		SetEntProp(sack, Prop_Data, "m_usSolidFlags", FSOLID_TRIGGER);
		SetEntProp(sack, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
		SetEntProp(sack, Prop_Send, "m_nSolidType", SOLID_BBOX);
		SetEntProp(sack, Prop_Send, "m_usSolidFlags", FSOLID_TRIGGER);
		SetEntProp(sack, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS_TRIGGER);
		
		TeleportEntity(sack, Origin, Angles, NULL_VECTOR);
		SDKHookEx(sack, SDKHook_TouchPost, MoneySackTouch);
		SDKHook(sack, SDKHook_OnTakeDamage, SDKEvent_NeverTakeDamage);
		
		CreateTimer(300.0, Timer_ExpireSack, EntIndexToEntRef(sack), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:SDKEvent_NeverTakeDamage(victimEntity)
{
	return Plugin_Handled;
}	

public Action:Timer_ExpireSack(Handle:hTimer, Ref)
{
	new sack = EntRefToEntIndex(Ref);
	
	if(sack != -1)
		AcceptEntityInput(sack, "Kill", -1, -1, 0);
}

CleanMoneySacks()
{
	new String:szTargetName[32];
	new ent;
	while ((ent = FindEntityByClassname(ent, "prop_physics_override")) != -1)
	{
		if (IsValidEntity(ent))
		{
			GetTargetName(ent, szTargetName, 32);
			if (StrEqual(szTargetName, "money_sack", true))
			{
				AcceptEntityInput(ent, "Kill", -1, -1, 0);
			}
		}
	}
}

GetTargetName(entity, String:buf[], len)
{
	GetEntPropString(entity, Prop_Data, "m_iName", buf, len, 0);
}



stock AddNewSpawn(Float:Origin[3])
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, SpawnsPath))
	{
		CreateEmptyKvFile(SpawnsPath);
		
		if(!FileToKeyValues(keyValues, SpawnsPath))
			SetFailState("Something that should never happen has happened.");
	}	

	new String:SectionName[11];
	if(!KvGotoFirstSubKey(keyValues))
		SectionName = "1"

	else
	{	
		do
		{
			KvGetSectionName(keyValues, SectionName, sizeof(SectionName));
		}
		while(KvGotoNextKey(keyValues))
		
		new iSectionName = StringToInt(SectionName);
		
		IntToString(iSectionName + 1, SectionName, sizeof(SectionName));
		
		KvGoBack(keyValues);
	}
	KvJumpToKey(keyValues, SectionName, true);
	
	KvSetFloat(keyValues, "origin_x", Origin[0]);
	KvSetFloat(keyValues, "origin_y", Origin[1]);
	KvSetFloat(keyValues, "origin_z", Origin[2]);
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, SpawnsPath);
	CloseHandle(keyValues);
	
	LoadConfigFile();
	
	return true;
}

stock bool:DeleteAllSpawns()
{
	CreateEmptyKvFile(SpawnsPath);
	
	LoadConfigFile();
}
stock CreateEmptyKvFile(const String:Path[])
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, Path);
	
	CloseHandle(keyValues);
}
