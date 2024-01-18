#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <Eyal-RP>
#include <emitsoundany>

int TRUE_DUMMY_VALUE = 0;

#define WHILE_TRUE TRUE_DUMMY_VALUE=0; while(TRUE_DUMMY_VALUE == 0)
#define DOOR_SELL_MULTIPLIER 0.75

#define SECONDS_IN_A_DAY 86400

#define RENT_PRICE_FORMULA(%1) RoundToCeil(float(%1) * 0.05) // The rent of a given door is 5% of the door's price

//new g_iHouseBreakerJob;

#define KV_ROOT_NAME "Spawns"
/*
new String:g_szLevels[6][15] =
{
	"Lock Picker",
	"Porch Climber",
	"Burglar",
	"Sneak Thief",
	"Safe Robber",
	"Bank Robber"
};
*/
new CRACK_CHANCE_DECREASE_PER_1M;
new CRACK_CHANCE_DECREASE_MAX;

new CRACK_CHANCE_DECREASE_FOR_VIP_DOOR

new Float:CRACK_CHANCE_MULTIPLIER_FOR_CONNECTED_DOOR

new g_iCrackChance[11];

new sprLaserBeam;
new g_iViewModel;
new EngineVersion:g_Game;

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

new String:szConfigFile[36] = "addons/sourcemod/configs/doors.ini"
new ArrayList:g_aHammerToEntity;
new g_iHammerToEntity[2048];
new Float:g_fNextOpen[2048];
new ArrayList:g_aDoors;
new ArrayList:g_aRentDoors;
new Door:g_dDoor[2048];
new RentDoor:g_dRentDoor[2048];
new g_iCrackProgress[MAXPLAYERS+1][2048];
new Float:g_fNextLock[2048];
new ArrayList:g_aConnectedDoors;
new ConnectedDoor:g_dConnectedDoor[2048];
new g_iOwnedDoor[MAXPLAYERS+1];
new g_iOldButtons[MAXPLAYERS+1];
new Float:g_fNextHouseMessage[MAXPLAYERS+1];
new Float:g_fNextHouseSound[MAXPLAYERS+1];
new Float:g_fLastTime[MAXPLAYERS+1];
new Database:g_hDatabase;

new Float:g_fStartCrack[MAXPLAYERS+1][2048];

new g_iHitmanJob = -1;

enum enDoorState
{
	STATE_INVALID = -1,
	STATE_CLOSED = 0,
	STATE_OPENING = 1,
	STATE_OPENED = 2,
	STATE_CLOSING = 3
}

enum BankState
{
	STATE_NONE=0,
	STATE_DEPOSIT,
	STATE_WITHDRAW
}

new BankState:HouseVaultState[MAXPLAYERS+1];
int LastEntity[MAXPLAYERS+1] = { -1, ... };

LoadJobModel()
{
	LoadDirOfModels("materials/models/player/kuristaja/cso2/sas/");
	LoadDirOfModels("models/player/custom_player/kuristaja/cso2/sas/");
	PrecacheModel("models/player/custom_player/kuristaja/cso2/sas/sas2.mdl", true);
	LoadDirOfModels("models/weapons/Dzucht/crowbar/");
	LoadDirOfModels("materials/models/weapons/V_crowbar/");
	g_iViewModel = PrecacheModel("models/weapons/Dzucht/crowbar/crowbar.mdl", true);
	
	sprLaserBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}
/*
public bool UpdateJobStats(int client, int job)
{
	
	if (job == g_iHouseBreakerJob)
	{
		if (GetClientTeam(client) != CS_TEAM_T)
		{
			CS_SwitchTeam(client, CS_TEAM_T);
			CS_RespawnPlayer(client);
			
			return; // Return because UpdateJobStats is called upon respawning.
		}
		SetEntityModel(client, "models/player/custom_player/kuristaja/cso2/sas/sas2.mdl");
		
		CS_SetClientClanTag(client, g_szLevels[RP_GetClientLevel(client, g_iHouseBreakerJob)]);
		RP_SetClientJobName(client, g_szLevels[RP_GetClientLevel(client, g_iHouseBreakerJob)]);
		
		switch (RP_GetClientLevel(client, g_iHouseBreakerJob))
		{
			case 3:
			{
				GivePlayerItem(client, "weapon_glock18");
				SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
			}
			case 4:
			{
				GivePlayerItem(client, "weapon_usp_silencer");
				SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
			}
			case 5:
			{
				GivePlayerItem(client, "weapon_sawedoff");
				SetEntProp(client, Prop_Send, "m_bHasHelmet", any:1, 4, 0);
				SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
			}
			default:
			{
			}
		}
	}
}
*/
/*
public Action:Thief_RequestIdentity(client, const String:JobShortName[], &FakeLevel, String:LevelName[32], String:Model[PLATFORM_MAX_PATH])
{
	if(StrEqual(JobShortName, "HBREAKER", false))
	{
		FormatEx(Model, sizeof(Model), "models/player/custom_player/kuristaja/cso2/sas/sas2.mdl");
		FormatEx(LevelName, sizeof(LevelName), g_szLevels[RP_GetClientLevel(client, g_iHouseBreakerJob)]);
		
		FakeLevel = RP_GetClientLevel(client, g_iHouseBreakerJob);
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
*/
/* 
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_Jobs", true))
	{
		//g_iHouseBreakerJob = RP_CreateJob("House Breaker", "HBREAKER", 6);
	}
}
*/

new Handle:GarbageTriesArray = INVALID_HANDLE;

Handle hTimer_GuideDoor[MAXPLAYERS+1] = { INVALID_HANDLE, ... };

methodmap Door < StringMap
{	
	public Door(int hammer, int price, bool gangOnly, bool vipOnly, bool invertInside)
	{
		if(GarbageTriesArray == INVALID_HANDLE)
			GarbageTriesArray = CreateArray(1);
			
		StringMap temp = new StringMap();
		temp.SetValue("hammer", hammer, true);
		temp.SetValue("price", price, true);
		temp.SetValue("vipOnly", vipOnly, true);
		temp.SetValue("gangOnly", gangOnly, true);
		temp.SetValue("key", new ArrayList(1, 0), true);
		temp.SetValue("doors", new ArrayList(1, 0), true);
		temp.SetValue("invertInside", invertInside);
		
		PushArrayCell(GarbageTriesArray, temp);
		
		return view_as<Door>(temp);
	}

	public ArrayList GetKeyArray()
	{
		ArrayList arr;
		GetTrieValue(this, "key", arr);
		return arr;
	}

	public int GetPrice(int client=0)
	{
		int price;
		GetTrieValue(this, "price", price);
		
		if(client == 0)
			return price;
			
		else
		{
			if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
				price = RoundToFloor((float(price) * 0.75));
				
			return price;
		}
	}
	
	public bool SetGangOwned(const char[] GangTag)
	{
		SetTrieString(this, "GangOwned", GangTag);
	}
	public void GetGangOwned(char[] buffer, int len)
	{
		GetTrieString(this, "GangOwned", buffer, len);
	}

	public void SetName(const char[] name)
	{
		SetTrieString(this, "name", name, true);
	}

	public void GetName(char[] output, int size)
	{
		GetTrieString(this, "name", output, size);
	}
	
	public void SetBank(int amount)
	{
		SetTrieValue(this, "bank", amount, true);
	}

	public int GetBank()
	{
		int bank;
		GetTrieValue(this, "bank", bank);
		return bank;
	}
	
	public int GetHammer()
	{
		int hammer;
		GetTrieValue(this, "hammer", hammer);
		return hammer;
	}

	public void SetOwned(bool owned)
	{
		SetTrieValue(this, "owned", owned, true);
	}

	public bool GetOwned()
	{
		bool owned;
		GetTrieValue(this, "owned", owned);
		return owned;
	}

	public void SetUnix(int unix)
	{
		SetTrieValue(this, "unix", unix, true);
	}

	public int GetUnix()
	{
		int unix;
		GetTrieValue(this, "unix", unix);
		return unix;
	}
	
	public int IsGangOnly()
	{
		int gangOnly;
		GetTrieValue(this, "gangOnly", gangOnly);
		return gangOnly;
	}
	
	public int IsVIPOnly()
	{
		int vipOnly;
		GetTrieValue(this, "vipOnly", vipOnly);
		return vipOnly;
	}
	
	public int IsInvertInside()
	{
		int invertInside;
		GetTrieValue(this, "invertInside", invertInside);
		return invertInside;
	}
}

methodmap ConnectedDoor < StringMap
{
	public ConnectedDoor(int hammer, Door main, bool pickable)
	{
		if(GarbageTriesArray == INVALID_HANDLE)
			GarbageTriesArray = CreateArray(1);
			
		StringMap temp = new StringMap();
		temp.SetValue("hammer", hammer, true);
		temp.SetValue("main", main, true);
		temp.SetValue("pickable", pickable, true);
		
		PushArrayCell(GarbageTriesArray, temp);
		
		return view_as<ConnectedDoor>(temp);
	}

	public int GetHammer()
	{
		int hammer;
		GetTrieValue(this, "hammer", hammer);
		return hammer;
	}

	public Door GetMainDoor()
	{
		Door door;
		GetTrieValue(this, "main", door);
		return door;
	}
	
	public bool IsPickable()
	{
		bool pickable;
		GetTrieValue(this, "pickable", pickable);
		return pickable;
	}
}


methodmap RentDoor < StringMap
{
	public RentDoor(int hammer, int price, bool invertInside)
	{
		if(GarbageTriesArray == INVALID_HANDLE)
			GarbageTriesArray = CreateArray(1);
			
		StringMap temp = new StringMap();
		temp.SetValue("hammer", hammer, true);
		temp.SetValue("price", price, true);
		temp.SetValue("key", new ArrayList(1, 0), true);
		temp.SetValue("invertInside", invertInside);
		
		PushArrayCell(GarbageTriesArray, temp);
		
		return view_as<RentDoor>(temp);
	}

	public ArrayList GetKeyArray()
	{
		ArrayList arr;
		GetTrieValue(this, "key", arr);
		return arr;
	}

	public int GetPrice()
	{
		int price;
		GetTrieValue(this, "price", price);
		return price;
	}
	
	public void SetName(const char[] name)
	{
		SetTrieString(this, "name", name, true);
	}

	public void GetName(char[] output, int size)
	{
		GetTrieString(this, "name", output, size);
	}
	
	public int GetHammer()
	{
		int hammer;
		GetTrieValue(this, "hammer", hammer);
		return hammer;
	}

	public void SetOwned(bool owned)
	{
		SetTrieValue(this, "owned", owned, true);
	}

	public bool GetOwned()
	{
		bool owned;
		GetTrieValue(this, "owned", owned);
		return owned;
	}

	public void SetUnix(int unix)
	{
		SetTrieValue(this, "unix", unix, true);
	}

	public int GetUnix()
	{
		int unix;
		GetTrieValue(this, "unix", unix);
		return unix;
	}
	
	public int IsInvertInside()
	{
		int invertInside;
		GetTrieValue(this, "invertInside", invertInside);
		return invertInside;
	}
}


new Handle:Trie_DoorsEco;
new Handle:Trie_GangShields;

public RP_OnEcoLoaded()
{
	
	Trie_DoorsEco = RP_GetEcoTrie("Doors");
	
	if(Trie_DoorsEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Doors");
		
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "CRACK_CHANCE_LVL_#%i", i);
		
		if(!GetTrieString(Trie_DoorsEco, Key, TempFormat, sizeof(TempFormat)))
		{
			break;
		}
			
		g_iCrackChance[i] = StringToInt(TempFormat);
		
		i++;
	}
	
	GetTrieString(Trie_DoorsEco, "CRACK_CHANCE_DECREASE_PER_1M", TempFormat, sizeof(TempFormat));
	
	CRACK_CHANCE_DECREASE_PER_1M = StringToInt(TempFormat);	
	
	GetTrieString(Trie_DoorsEco, "CRACK_CHANCE_DECREASE_MAX", TempFormat, sizeof(TempFormat));
	
	CRACK_CHANCE_DECREASE_MAX = StringToInt(TempFormat);	
	
	GetTrieString(Trie_DoorsEco, "CRACK_CHANCE_DECREASE_FOR_VIP_DOOR", TempFormat, sizeof(TempFormat));
	
	CRACK_CHANCE_DECREASE_FOR_VIP_DOOR = StringToInt(TempFormat);	
	
	GetTrieString(Trie_DoorsEco, "CRACK_CHANCE_MULTIPLIER_FOR_CONNECTED_DOOR", TempFormat, sizeof(TempFormat));
	
	CRACK_CHANCE_MULTIPLIER_FOR_CONNECTED_DOOR = StringToFloat(TempFormat);	
	

}

public OnPluginStart()
{	
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	if (!g_hDatabase)
	{
		new String:error[256];
		g_hDatabase = SQL_Connect("eyal_rp", true, error, 255);
		if (!g_hDatabase)
		{
			PrintToServer("Could not connect [SQL]: %s", error);
		}
	}
	
	if(g_hDatabase)
		SQL_TQuery(g_hDatabase, SQL_NoAction, "CREATE TABLE IF NOT EXISTS `rp_doors` ( `hammerid` int(16) NOT NULL UNIQUE, `AuthId` varchar(32) UNIQUE, `GangTag` varchar(32) UNIQUE, `name` VARCHAR(32) NOT NULL, `unix` INT(16) NOT NULL, `bank` INT(11) NOT NULL )", 0, DBPrio_Normal);
			
	g_aHammerToEntity = CreateArray(1, 0);
	g_aDoors = CreateArray(1, 0);
	g_aRentDoors = CreateArray(1, 0);
	g_aConnectedDoors = CreateArray(1, 0);
	
	Trie_GangShields = CreateTrie();

	for(new i=1;i <= MaxClients;i++)
	{	
		if (IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);

			if(Is_User_Gang(i) != RANK_NULL)
				LoadClientGangDoor(i);
		}
	}
	CreateTimer(60.0, Timer_CheckDoors, 0, TIMER_REPEAT);
	
	HookEvent("player_death", Event_PlayerState, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerState, EventHookMode_Post);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	
	RegAdminCmd("sm_refunddoors", Command_RefundDoors, ADMFLAG_ROOT);
	
	RegConsoleCmd("sm_door", Command_Door, "Guides you towards your house / gang house");

	if (RP_GetEcoTrie("Doors") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}

// Killed or spawned
public Action:Event_PlayerState(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(client == 0)
		return;
		
	for(new i=0;i < sizeof(g_iCrackProgress[]);i++)
	{
		g_iCrackProgress[client][i] = 0;
	}
}

public Action:Event_RoundStart(Handle:hEvent, const String:Name[], bool:dontBroadcast)
{
	OnRoundStart();
}

public void OnRoundStart()
{
	// Appears at OnMapStart
	
	for(new i=0;i < GetArraySize(g_aDoors);i++)
	{
		new Door:door = GetArrayCell(g_aDoors, i);
		
		new entity = GetEntityFromHammerID(door.GetHammer())
		
		SDKUnhook(entity, SDKHookType:10, OnDoorTouch);
	}
	
	for(new i=0;i < GetArraySize(g_aConnectedDoors);i++)
	{
		new ConnectedDoor:door = GetArrayCell(g_aConnectedDoors, i);
		
		new entity = GetEntityFromHammerID(door.GetHammer())
		
		SDKUnhook(entity, SDKHookType:10, OnConnectedDoorTouch);
	}
	
	for(new i=0;i < GetArraySize(g_aRentDoors);i++)
	{
		new RentDoor:rDoor = GetArrayCell(g_aRentDoors, i);
		
		new entity = GetEntityFromHammerID(rDoor.GetHammer())
		
		SDKUnhook(entity, SDKHookType:10, OnRentedDoorTouch);
	}
	
	ReadDoors();
	
	new entity = -1;
	ClearArray(g_aHammerToEntity);
	while ((entity = FindEntityByClassname(entity, "prop_door_rotating")) != -1)
	{
		AddDoor(entity, GetEntProp(entity, Prop_Data, "m_iHammerID"));
		g_fNextOpen[entity] = 0.0;
		g_fNextLock[entity] = 0.0;
		SDKHook(entity, SDKHook_Use, OnDoorUsed);
	}
	
	entity = -1;
	
	while ((entity = FindEntityByClassname(entity, "func_door_rotating")) != -1)
	{
		AddDoor(entity, GetEntProp(entity, Prop_Data, "m_iHammerID"));
		g_fNextOpen[entity] = 0.0;
		g_fNextLock[entity] = 0.0;
		SDKHook(entity, SDKHook_Use, OnDoorUsed);
	}
	
	entity = -1;
	
	while ((entity = FindEntityByClassname(entity, "func_door")) != -1)
	{
		AddDoor(entity, GetEntProp(entity, Prop_Data, "m_iHammerID"));
		g_fNextOpen[entity] = 0.0;
		g_fNextLock[entity] = 0.0;
		SDKHook(entity, SDKHook_Use, OnDoorUsed);
	}
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT hammerid,name,unix,bank from rp_doors");
	SQL_TQuery(g_hDatabase, SQL_LoadDoors, szQuery, 0, DBPrio_Normal);
}

public Action:Command_RefundDoors(client, args)
{
	if(!IsHighManagement(client))
	{
		RP_PrintToChat(client, "You must be High Management to use this command");
		return Plugin_Handled;
	}	
	
	new String:ServerName[64];
	
	new Handle:convar = FindConVar("hostname");
	
	GetConVarString(convar, ServerName, sizeof(ServerName));
	
	if(!StrEqual(ServerName, "REFUND DOORS"))
	{
		RP_PrintToChat(client, "For safety reasons, this command cannot activate unless the server is named \x07REFUND DOORS");
		
		return Plugin_Handled;
	}
	
	new Door:door;
	
	for(new i=0;i < GetArraySize(g_aDoors);i++)
	{
		door = GetArrayCell(g_aDoors, i, 0, false);

		if (door.GetOwned())
		{
			new String:szQuery[256];
			SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT AuthId, GangTag, bank from rp_doors WHERE hammerid = '%i'", door.GetHammer());
			SQL_TQuery(g_hDatabase, SQL_RefundDoor, szQuery, door);
		}
	}
	
	
	RP_PrintToChat(client, "Refunded all doors of their owners for the full amount.");
	
	return Plugin_Handled;
}

public Action:Command_Door(client, args)
{
	if(hTimer_GuideDoor[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_GuideDoor[client]);
		hTimer_GuideDoor[client] = INVALID_HANDLE;
		
		RP_PrintToChat(client, "Stopped tracking your house");
		return Plugin_Handled;
	}
	
	RP_PrintToChat(client, "Began Tracking sequence to your house... Use !door to stop tracking.");
	
	TriggerTimer(hTimer_GuideDoor[client] = CreateTimer(1.0, Timer_GuideDoor, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE), true);
	
	return Plugin_Handled;
}

public Action:Timer_GuideDoor(Handle:timer, any:UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
	{
		hTimer_GuideDoor[client] = INVALID_HANDLE;
		return;
	}
	
	new bool:Found = false;
	
	if(g_iOwnedDoor[client])
	{
		TE_SetupBeamLaser(g_iOwnedDoor[client], client, sprLaserBeam, 0, 0, 0, 1.0, 2.0, 2.0, 10, 0.0, {240, 255, 0, 255}, 0);
		TE_SendToClient(client, 0.0);
		
		Found = true;
	}
	
	
	new Door:door;
		
	if(Get_User_Gang(client) != -1)
	{
		new String:GangTag[32];
		
		Get_User_Gang_Tag(client, GangTag, sizeof(GangTag));
		
		for(new i=0;i < GetArraySize(g_aDoors);i++)
		{
			door = GetArrayCell(g_aDoors, i, 0, false);
			
			new String:DoorGangTag[32];
			
			door.GetGangOwned(DoorGangTag, sizeof(DoorGangTag));
		
			if(StrEqual(DoorGangTag, GangTag))
			{
				TE_SetupBeamLaser(GetEntityFromHammerID(door.GetHammer()), client, sprLaserBeam, 0, 0, 0, 1.0, 2.0, 2.0, 10, 0.0, {75, 0, 130, 255}, 0);
				TE_SendToClient(client, 0.0);
				
				Found = true;
				
				break;
			}
		}
	}
	if(Found)
		hTimer_GuideDoor[client] = CreateTimer(1.0, Timer_GuideDoor, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
		
	else
	{	
		RP_PrintToChat(client, "Could not find your house / gang house. Tracking sequence ended.");
		hTimer_GuideDoor[client] = INVALID_HANDLE;
	}
}

public SQL_RefundDoor(Handle:owner, Handle:hndl, String:error[], Door:door)
{
	if (hndl == INVALID_HANDLE)
		ThrowError(error);
		
	else if(SQL_GetRowCount(hndl) != 1)
		return;
	
	if (SQL_FetchRow(hndl))
	{
		new String:AuthId[35];
		SQL_FetchString(hndl, 0, AuthId, sizeof(AuthId));
		
		new String:GangTag[35];
		SQL_FetchString(hndl, 1, GangTag, sizeof(GangTag));
		
		new bank = SQL_FetchInt(hndl, 2);
		
		new String:DoorName[64];
		door.GetName(DoorName, sizeof(DoorName));
		door.SetBank(0);
		int result = -1;
		
		new entity = GetEntityFromHammerID(door.GetHammer());
			
		door.SetOwned(false);
		
		new amount = RoundToFloor(float(door.GetPrice())) + bank;
		
		if(StrEqual(GangTag, ""))
		{
			result = GiveAuthIdCash(AuthId, amount);
		}
		else
		{
			result = 0;
			
			Add_GangBank(GangTag, amount);
		}
		
		if(result != -1)
		{
			new String:szQuery[256];
			SQL_FormatQuery(g_hDatabase, szQuery, 256, "DELETE From rp_doors where hammerid = %i", door.GetHammer());
			SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, 0, DBPrio_Normal);
			new ArrayList:keys = door.GetKeyArray();
			new target;
			
			RolePlayLog("Door %s(%i) was refunded by the server owner at $%i!", DoorName, door.GetHammer(), amount);
			for(new j=0;j < GetArraySize(keys);j++)
			{
				target = GetArrayCell(keys, j, 0, false);
				
				if (g_iOwnedDoor[target] == entity)
				{
					g_iOwnedDoor[target] = 0;
				}
			}
			
			ClearArray(keys);
		}
	}
}

public Action:Timer_CheckDoors(Handle:timer, any:data)
{
	new unix = GetTime();
	new Door:door;
		
	for(new i=0;i < GetArraySize(g_aDoors);i++)
	{
		door = GetArrayCell(g_aDoors, i, 0, false);

		if (door.GetOwned() && unix > door.GetUnix())
		{
			new String:szQuery[256];
			SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT AuthId, GangTag, bank from rp_doors WHERE hammerid = '%i'", door.GetHammer());
			SQL_TQuery(g_hDatabase, SQL_CheckDoorBank, szQuery, door);
		}
	}
}


public SQL_CheckDoorBank(Handle:owner, Handle:hndl, String:error[], Door:door)
{
	if (hndl == INVALID_HANDLE)
		ThrowError(error);
		
	else if(SQL_GetRowCount(hndl) != 1)
		return;
	
	if (SQL_FetchRow(hndl))
	{
		new String:AuthId[35];
		SQL_FetchString(hndl, 0, AuthId, sizeof(AuthId));
		
		new String:GangTag[35];
		SQL_FetchString(hndl, 1, GangTag, sizeof(GangTag));
		
		new bank = SQL_FetchInt(hndl, 2);
		
		if(bank < RENT_PRICE_FORMULA(door.GetPrice()))
		{
			new String:DoorName[64];
			door.GetName(DoorName, sizeof(DoorName));
			door.SetBank(0);
			int result = -1;
			
			new entity = GetEntityFromHammerID(door.GetHammer());
				
			door.SetOwned(false);
			
			new amount = RoundToFloor(float(door.GetPrice()) * DOOR_SELL_MULTIPLIER) + bank;
			
			if(StrEqual(GangTag, ""))
			{
				result = GiveAuthIdCash(AuthId, amount);
			}
			else
			{
				result = 0;
				
				Add_GangBank(GangTag, amount);
			}
			
			if(result != -1)
			{
				new String:szQuery[256];
				SQL_FormatQuery(g_hDatabase, szQuery, 256, "DELETE From rp_doors where hammerid='%i'", door.GetHammer());
				SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, 0, DBPrio_Normal);
				new ArrayList:keys = door.GetKeyArray();
				new target;
				
				for(new j=0;j < GetArraySize(keys);j++)
				{
					target = GetArrayCell(keys, j, 0, false);
					
					if (g_iOwnedDoor[target] == entity)
					{
						g_iOwnedDoor[target] = 0;
					}
				}

				door.SetOwned(false);
				
				if(!StrEqual(GangTag, ""))
				{
					door.SetGangOwned(GANG_NULL);
				}
				
				RolePlayLog("The door %s(%i) was refunded at $%i for not having money in vault. [$%i/$%i]", DoorName, door.GetHammer(), amount, bank, RENT_PRICE_FORMULA(door.GetPrice()));
				
				ClearArray(keys);
			}
		}
		else
		{	
			new unix = GetTime() + SECONDS_IN_A_DAY;
			new String:szQuery[256];
			SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_doors SET bank = bank - %i, unix = %i where hammerid='%i'", RENT_PRICE_FORMULA(door.GetPrice()), unix, door.GetHammer());
			SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, 0, DBPrio_Normal);
			
			door.SetUnix(unix);
			door.SetBank(door.GetBank() - RENT_PRICE_FORMULA(door.GetPrice()));
		}
	}
}

public On_Gang_Shield_Loaded(const char[] GangTag, int ShieldPercent)
{
	SetTrieValue(Trie_GangShields, GangTag, ShieldPercent);
}
public On_Gang_Disbanded(const String:GangTag[])
{
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "DELETE From rp_doors where GangTag = '%s'", GangTag);
	SQL_TQuery(g_hDatabase, SQL_NoError, szQuery, 0, DBPrio_Normal); // No error because maybe there isn't a house for the gang.
	
	new size = GetArraySize(g_aDoors);
	
	new String:DoorGangTag[32];
	
	for(new i=0;i < size;i++)
	{
		new Door:door = GetArrayCell(g_aDoors, i)
		
		door.GetGangOwned(DoorGangTag, sizeof(DoorGangTag));
		
		if(StrEqual(DoorGangTag, GangTag))
		{
			door.SetOwned(false);
		
			door.SetGangOwned(GANG_NULL);
		}
	}
	
	RolePlayLog("Tried deleting door belonging to disbanded gang tag: %s", GangTag);
}

public On_Player_Kicked_From_Gang(client, const char[] GangTag)
{
	new size = GetArraySize(g_aDoors);
	
	new String:DoorGangTag[32];
	
	for(new i=0;i < size;i++)
	{
		new Door:door = GetArrayCell(g_aDoors, i)
		
		door.GetGangOwned(DoorGangTag, sizeof(DoorGangTag));
		
		if(StrEqual(DoorGangTag, GangTag))
		{
			new Handle:keys = door.GetKeyArray();
			
			new slot = FindValueInArray(keys, client);
			
			if(slot != -1)
				RemoveFromArray(keys, slot);
				
			break;
		}
	}
}

public On_Player_Loaded_Gang(client, gang)
{
	if(gang == -1)
		return;
		
	LoadClientGangDoor(client);

}

public void LoadClientGangDoor(int client)
{
	new String:szGangTag[32];
	Get_User_Gang_Tag(client, szGangTag, 32);
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT hammerid from rp_doors where GangTag ='%s'", szGangTag);
	SQL_TQuery(g_hDatabase, SQL_LoadDoorGang, szQuery, GetClientSerial(client), DBPrio_Normal);
}

public OnClientPostAdminCheck(client)
{
	new String:szAuth[32];
	GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
	new String:szQuery[256];
	SQL_FormatQuery(g_hDatabase, szQuery, 256, "SELECT hammerid from rp_doors where AuthId='%s'", szAuth);
	SQL_TQuery(g_hDatabase, SQL_LoadDoor, szQuery, GetClientSerial(client), DBPrio_Normal);
	
	g_fNextHouseMessage[client] = 0.0;
	g_fNextHouseSound[client] = 0.0;
}

public OnClientDisconnect(client)
{
	if(hTimer_GuideDoor[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_GuideDoor[client]);
		hTimer_GuideDoor[client] = INVALID_HANDLE;	
	}
	HouseVaultState[client] = STATE_NONE;
	
	new size = GetArraySize(g_aDoors);
	
	for(new i=0;i < size;i++)
	{
		new Door:door = GetArrayCell(g_aDoors, i)
		
		new Handle:keys = door.GetKeyArray();
		
		new slot = FindValueInArray(keys, client);
		
		if(slot != -1)
			RemoveFromArray(keys, slot);
	}
	
	size = GetArraySize(g_aRentDoors);
	
	for(new i=0;i < size;i++)
	{
		new Door:rDoor = GetArrayCell(g_aRentDoors, i)
		
		new Handle:keys = rDoor.GetKeyArray();
		
		new slot = FindValueInArray(keys, client);
		
		if(slot != -1)
			RemoveFromArray(keys, slot);
	}
	
	if (g_iOwnedDoor[client])
	{
		new entity = g_iOwnedDoor[client];
		new Door:door = g_dDoor[g_iOwnedDoor[client]];
		new RentDoor:rDoor = g_dRentDoor[g_iOwnedDoor[client]];
		
		if(door)
		{
			new Handle:keys = door.GetKeyArray();
			
			ClearArray(keys);
		}
		else if(rDoor)
		{
			new ArrayList:keys = rDoor.GetKeyArray();
			
			ClearArray(keys);
			rDoor.SetOwned(false);

			g_iOwnedDoor[client] = 0;
			
			AcceptEntityInput(entity, "Unlock");
			AcceptEntityInput(entity, "Open");
			AcceptEntityInput(entity, "Close");
		}
	}
	
	for(new i=0;i < GetArraySize(g_aDoors);i++)
	{
		new Door:door = GetArrayCell(g_aDoors, i);
		
		new pos = FindValueInArray(door.GetKeyArray(), client);
		
		if(pos != -1)
			RemoveFromArray(door.GetKeyArray(), pos);
	}

	g_iOwnedDoor[client] = 0;
	g_fLastTime[client] = 0.0;
}

public OnMapStart()
{
	for(new i=0;i < sizeof(hTimer_GuideDoor);i++)
	{
		hTimer_GuideDoor[i] = INVALID_HANDLE;
	}
	
	AddFileToDownloadsTable("sound/roleplay/door_knock.mp3");
	PrecacheSoundAny("roleplay/door_knock.mp3", false);
	LoadJobModel();
	AddFileToDownloadsTable("sound/roleplay/door_key.mp3");
	PrecacheSoundAny("roleplay/door_key.mp3", false);
	
	OnRoundStart();
	
	for(int i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(!IsClientAuthorized(i))
			continue;
			
		On_Player_Loaded_Gang(i, Get_User_Gang(i));
	}
	
}

AddDoor(entity, HammerID)
{
	new Door:door = FindDoorByHammerID(HammerID);
	new ConnectedDoor:connectedDoor = FindConnectedDoorByHammerID(HammerID);
	
	if (door)
	{
		g_dDoor[entity] = door;
		SDKHookEx(entity, SDKHookType:10, OnDoorTouch);
		AcceptEntityInput(entity, "Lock", -1, -1, 0);

		char iName[128];

		if(door.GetPrice() == 1100000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type1_#%i", HammerID)

		else if(door.GetPrice() == 1200000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type2_#%i", HammerID)

		else if(door.GetPrice() == 1300000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type3_#%i", HammerID)

		else if(door.GetPrice() == 1400000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type4_#%i", HammerID)

		else if(door.GetPrice() == 1500000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type5_#%i", HammerID)

		else if(door.GetPrice() == 1600000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type6_#%i", HammerID)

		else if(door.GetPrice() == 1700000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type7_#%i", HammerID)

		else if(door.GetPrice() == 1800000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type8_#%i", HammerID)

		else if(door.GetPrice() == 1900000000)
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Type9_#%i", HammerID)

		else
			FormatEx(iName, sizeof(iName), "RolePlay_Door_#%i", HammerID)
		SetEntPropString(entity, Prop_Data, "m_iName", iName);

		PushArrayCell(g_aHammerToEntity, HammerID);
		g_iHammerToEntity[GetArraySize(g_aHammerToEntity) - 1] = entity;
		
		HookSingleEntityOutput(entity, "OnFullyOpen", DoorOutput_OnFullyOpen, false);
		HookSingleEntityOutput(entity, "OnFullyClosed", DoorOutput_OnFullyClosed, false);
	}
	else if(connectedDoor)
	{
		PushArrayCell(g_aHammerToEntity, HammerID);
		g_iHammerToEntity[GetArraySize(g_aHammerToEntity) - 1] = entity;
		g_dConnectedDoor[entity] = connectedDoor;
		SDKHookEx(entity, SDKHookType:10, OnConnectedDoorTouch);
		AcceptEntityInput(entity, "Lock", -1, -1, 0);
		char iName[128];
		FormatEx(iName, sizeof(iName), "RolePlay_Door_Connected_#%i", HammerID)
		SetEntPropString(entity, Prop_Data, "m_iName", iName);
		
		HookSingleEntityOutput(entity, "OnFullyOpen", ConnectedDoorOutput_OnFullyOpen, false);
		HookSingleEntityOutput(entity, "OnFullyClosed", ConnectedDoorOutput_OnFullyClosed, false);
	}
	else 
	{
		new RentDoor:rDoor = FindRentedDoorByHammerID(HammerID);
		
		if(rDoor)
		{
			PushArrayCell(g_aHammerToEntity, HammerID);
			g_iHammerToEntity[GetArraySize(g_aHammerToEntity) - 1] = entity;
			g_dRentDoor[entity] = rDoor;
			SDKHookEx(entity, SDKHookType:10, OnRentedDoorTouch);
			AcceptEntityInput(entity, "Lock", -1, -1, 0);
			char iName[128];
			FormatEx(iName, sizeof(iName), "RolePlay_Door_Rented_#%i", HammerID)
			SetEntPropString(entity, Prop_Data, "m_iName", iName);
			
			HookSingleEntityOutput(entity, "OnFullyOpen", RentedDoorOutput_OnFullyOpen, false);
			HookSingleEntityOutput(entity, "OnFullyClosed", RentedDoorOutput_OnFullyClosed, false);
		}
	}
}

public void DoorOutput_OnFullyOpen(const String:output[], caller, activator, Float:delay)
{
	new Door:door = g_dDoor[caller];
	
	if(!door.GetOwned())
	{
		AcceptEntityInput(caller, "Unlock");
		AcceptEntityInput(caller, "Close");
	}
}

public void DoorOutput_OnFullyClosed(const String:output[], caller, activator, Float:delay)
{
	new Door:door = g_dDoor[caller];
	
	if(!door.GetOwned())
	{
		AcceptEntityInput(caller, "Lock");
	}
}

public void ConnectedDoorOutput_OnFullyOpen(const String:output[], caller, activator, Float:delay)
{
	new ConnectedDoor:cDoor = g_dConnectedDoor[caller];
	
	new Door:door = cDoor.GetMainDoor();
	
	if(!door.GetOwned())
	{
		AcceptEntityInput(caller, "Unlock");
		AcceptEntityInput(caller, "Close");
	}
}

public void ConnectedDoorOutput_OnFullyClosed(const String:output[], caller, activator, Float:delay)
{
	new ConnectedDoor:cDoor = g_dConnectedDoor[caller];
	
	new Door:door = cDoor.GetMainDoor();
	
	if(!door.GetOwned())
	{
		AcceptEntityInput(caller, "Lock");
	}
}


public void RentedDoorOutput_OnFullyOpen(const String:output[], caller, activator, Float:delay)
{
	new RentDoor:rDoor = g_dRentDoor[caller];
	
	if(!rDoor.GetOwned())
	{
		AcceptEntityInput(caller, "Unlock");
		AcceptEntityInput(caller, "Close");
	}
}

public void RentedDoorOutput_OnFullyClosed(const String:output[], caller, activator, Float:delay)
{
	new RentDoor:rDoor = g_dRentDoor[caller];
	
	if(!rDoor.GetOwned())
	{
		AcceptEntityInput(caller, "Lock");
	}
}

public OnConnectedDoorTouch(entity, client)
{
	if (!client || client > MaxClients)
	{
		return;
	}
	
	new buttons = GetClientButtons(client);

	if (buttons & IN_RELOAD && !(g_iOldButtons[client] & IN_RELOAD))
	{
		new ConnectedDoor:cDoor = g_dConnectedDoor[entity];
		
		new Door:door = cDoor.GetMainDoor();

		new MainDoorEntity = GetEntityFromHammerID(door.GetHammer());
		
		if(MainDoorEntity == -1)
			return;

		new String:GangTag[32];
		door.GetGangOwned(GangTag, sizeof(GangTag));
		
		new String:ClientGangTag[32];
		Get_User_Gang_Tag(client, ClientGangTag, sizeof(ClientGangTag));
		
		if(g_iOwnedDoor[client] == MainDoorEntity || ( GetClientTeam(client) == CS_TEAM_T && ( FindValueInArray(door.GetKeyArray(), client) != -1 || (  Get_User_Gang(client) != -1 && StrEqual(GangTag, ClientGangTag, false) ))) )
		{
			new String:szEntityId[8];
			IntToString(entity, szEntityId, 5);
			new Menu:menu = CreateMenu(MenuHandler_ConnectedKeyDoor, MenuAction:28);
			RP_SetMenuTitle(menu, "Door Menu\n ");
			AddMenuItem(menu, szEntityId, "Unlock Door", 0);
			AddMenuItem(menu, szEntityId, "Lock Door", 0);
			DisplayMenu(menu, client, 0);
		}
		else if(CanClientBreakHouse(client) && cDoor.IsPickable())
		{
			if(GetEntProp(entity, Prop_Data, "m_bLocked"))
			{
				if(g_iCrackProgress[client][entity] == 0)
					g_fStartCrack[client][entity] = GetGameTime();
					
				if(g_fNextHouseSound[client] <= GetGameTime())
				{
					g_fNextHouseSound[client] = GetGameTime() + 3.0;
					
					EmitSoundToAllAny("roleplay/door_knock.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
				}
				
				g_fNextHouseMessage[client] = GetGameTime() + 1.0;
				
				g_iCrackProgress[client][entity] += 2;
				
				new TotalChance = g_iCrackChance[RP_GetClientLevel(client, RP_GetClientJob(client))];
				
				new TotalChanceDecrease = (door.GetPrice() / 1000000) * CRACK_CHANCE_DECREASE_PER_1M;
				
				new GangShield = 0;
				
				if(!StrEqual(GangTag, ""))
					GetTrieValue(Trie_GangShields, GangTag, GangShield);

				TotalChanceDecrease += GangShield;
				
				TotalChanceDecrease -= Get_User_Luck_Bonus(client);
				
				if(door.IsVIPOnly())
					TotalChanceDecrease += CRACK_CHANCE_DECREASE_FOR_VIP_DOOR;
				
				TotalChance -= TotalChanceDecrease;
				
				TotalChance = RoundToFloor(float(TotalChance) * CRACK_CHANCE_MULTIPLIER_FOR_CONNECTED_DOOR);
				
				EnforcePercentage(TotalChance);
				
				PrintHintText(client, "Breaking the lock...\nProgress %i%%\nSpam the R Key (%i%% to break)", g_iCrackProgress[client][entity], TotalChance);
				
				if(g_iCrackProgress[client][entity] >= 100)
				{
					g_iCrackProgress[client][entity] = 0;
					
					if(TotalChance >= GetRandomInt(1, 100))
					{
						g_fNextLock[entity] = GetGameTime() + 2.5;
						
						AcceptEntityInput(entity, "Unlock", -1, -1, 0);
						
						RP_PrintToChat(client, "You have cracked the door lock!");
						
						//RP_AddClientEXP(client, RP_GetClientJob(client), 10);
					}
					else
					{
						RP_PrintToChat(client, "You have failed to unlock the door, what a bad luck.");
						
						//RP_AddClientEXP(client, RP_GetClientJob(client), 3);
					}
				}
			}
		}
	}
	
	g_iOldButtons[client] = buttons;
	return;
}

public Action:OnDoorUsed(entity, client)
{
	if(g_fNextOpen[entity] > GetGameTime())
	{
		return Plugin_Handled;
	}
			
	g_fNextOpen[entity] = GetGameTime() + 1.5;
	return Plugin_Continue;
}

public OnDoorTouch(entity, client)
{
	if (!client || client > MaxClients)
	{
		return;
	}
	
	new Door:door = g_dDoor[entity];

	// If price exceeds 1 billion
	if(door.GetPrice() >= 1000000000)
		return;

	new buttons = GetClientButtons(client);
	
	new bool:IsInside = IsClientInsideHouse(client, entity, door);
	
	new String:sPrice[16];
	
	if (door.GetOwned() || g_dConnectedDoor[entity])
	{
		if (buttons & IN_RELOAD && !(g_iOldButtons[client] & IN_RELOAD))
		{
			new String:GangTag[32];
			door.GetGangOwned(GangTag, sizeof(GangTag));
			
			new String:ClientGangTag[32];
			Get_User_Gang_Tag(client, ClientGangTag, sizeof(ClientGangTag));
			
			if (g_iOwnedDoor[client] == entity)
			{	
				new String:szFormat[32];
				
				FormatTime(szFormat, 32, "%d/%m/%Y %T", door.GetUnix());
				
				new String:szEntityId[8];
				IntToString(entity, szEntityId, 5);
				new Menu:menu = CreateMenu(MenuHandler_Door, MenuAction:28);
				RP_SetMenuTitle(menu, "Door Menu\nNext Rent: %s.\nNote: Rent is paid from the house vault\nIf your house vault can't afford the rent, your house will be sold!", szFormat);
				
				AddMenuItem(menu, szEntityId, "Unlock Door", 0);
				AddMenuItem(menu, szEntityId, "Lock Door\n ", 0);
				AddMenuItem(menu, szEntityId, "Give Keys", 0);
				AddMenuItem(menu, szEntityId, "Delete Keys\n ", 0);
				
				AddCommas(RoundToFloor(float(door.GetPrice(client)) * DOOR_SELL_MULTIPLIER), ",", sPrice, sizeof(sPrice));
				
				FormatEx(szFormat, sizeof(szFormat), "Sell Door - $%s", sPrice);
				AddMenuItem(menu, szEntityId, szFormat)
				
				AddMenuItem(menu, szEntityId, "House Vault");
				
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
			
			else if( IsInside || ( GetClientTeam(client) == CS_TEAM_T && ( FindValueInArray(door.GetKeyArray(), client) != -1 || ( !StrEqual(ClientGangTag, "") && StrEqual(GangTag, ClientGangTag, false) ))) )
			{
				new String:szFormat[32];
				
				FormatTime(szFormat, 32, "%d/%m/%Y %T", door.GetUnix());
				
				new String:szEntityId[8];
				IntToString(entity, szEntityId, 5);
				new Menu:menu = CreateMenu(MenuHandler_Door, MenuAction:28);
				RP_SetMenuTitle(menu, "Door Menu\nNext Rent: %s.\nNote: Rent is paid from the house vault", szFormat);
				
				if( IsInside || ( GetClientTeam(client) == CS_TEAM_T && ( FindValueInArray(door.GetKeyArray(), client) != -1 || ( Get_User_Gang(client) != -1 && StrEqual(GangTag, ClientGangTag, false) ))) ) // Similar condition to above, but Get_User_Gang ensures a debted gang cannot mess with the door.
				{
					AddMenuItem(menu, szEntityId, "Unlock Door", 0);
					AddMenuItem(menu, szEntityId, "Lock Door\n ", 0);
				}
				else
				{
					AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
					AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
				}
				
				if(!StrEqual(ClientGangTag, "") && StrEqual(GangTag, ClientGangTag, false) && Is_User_Gang_Give_Keys(client))
				{
					if(Get_User_Gang(client) != -1 && StrEqual(GangTag, ClientGangTag, false) && Is_User_Gang_Give_Keys(client))
					{
						AddMenuItem(menu, szEntityId, "Give Keys", 0);
						AddMenuItem(menu, szEntityId, "Delete Keys\n ", 0);
					}
					else
					{
						AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
						AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
					}
					
				}
				else
				{
					AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
					AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
				}
				
				if(!StrEqual(GangTag, GANG_NULL) && StrEqual(GangTag, ClientGangTag, false) && Is_User_Manage_Gang_Door(client))
				{			
					AddCommas(RoundToFloor(float(door.GetPrice()) * DOOR_SELL_MULTIPLIER), ",", sPrice, sizeof(sPrice));
					
					FormatEx(szFormat, sizeof(szFormat), "Sell Door - $%s", sPrice);
					
					AddMenuItem(menu, szEntityId, szFormat);
					
					AddMenuItem(menu, szEntityId, "House Vault");
				}
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
			
			else if(CanClientBreakHouse(client))
			{
				if(GetEntProp(entity, Prop_Data, "m_bLocked"))
				{
					if(g_iCrackProgress[client][entity] == 0)
						g_fStartCrack[client][entity] = GetGameTime();
						
					if(g_fNextHouseSound[client] <= GetGameTime())
					{
						g_fNextHouseSound[client] = GetGameTime() + 3.0;
						
						EmitSoundToAllAny("roleplay/door_knock.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
					}
					
					g_fNextHouseMessage[client] = GetGameTime() + 1.0;
					
					g_iCrackProgress[client][entity] += 2;
					
					new TotalChance = g_iCrackChance[RP_GetClientLevel(client, RP_GetClientJob(client))];
					
					new TotalChanceDecrease = RoundToCeil((float(door.GetPrice()) / 1000000.0) * float(CRACK_CHANCE_DECREASE_PER_1M));
					
					TotalChanceDecrease -= Get_User_Luck_Bonus(client);
					
					if(door.IsVIPOnly())
						TotalChanceDecrease += CRACK_CHANCE_DECREASE_FOR_VIP_DOOR;
					
					new GangShield = 0;
					
					if(!StrEqual(GangTag, ""))
						GetTrieValue(Trie_GangShields, GangTag, GangShield);
	
					TotalChanceDecrease += GangShield;
				
					TotalChance -= TotalChanceDecrease;
					
					EnforcePercentage(TotalChance);
					
					PrintHintText(client, "Breaking the lock...\nProgress %i%%\nSpam the R Key (%i%% to break)", g_iCrackProgress[client][entity], TotalChance);
					
					if(g_iCrackProgress[client][entity] >= 100)
					{
						//PrintToChatEyal("%.2f", GetGameTime() - g_fStartCrack[client][entity]);
						g_iCrackProgress[client][entity] = 0;
						
						if(TotalChance >= GetRandomInt(1, 100))
						{
							g_fNextLock[entity] = GetGameTime() + 2.5;
							
							AcceptEntityInput(entity, "Unlock", -1, -1, 0);
							
							RP_PrintToChat(client, "You have cracked the door lock!");
							
							//RP_AddClientEXP(client, RP_GetClientJob(client), 10);
						}
						else
						{
							RP_PrintToChat(client, "You have failed to unlock the door, what a bad luck.");
							
							//RP_AddClientEXP(client, RP_GetClientJob(client), 3);
				 		}
					}
				}
			}
			else
			{	
				
				new String:DoorName[64];
				
				door.GetName(DoorName, sizeof(DoorName));
				
				AddCommas(door.GetPrice(client), ",", sPrice, sizeof(sPrice));
				
				PrintHintText(client, "House - Door\n%s's House\nPrice: $%s", DoorName, sPrice);
			}
		}
		else if(!(buttons & IN_RELOAD) && g_fNextHouseMessage[client] <= GetGameTime())
		{
			new String:DoorName[64];
			
			door.GetName(DoorName, sizeof(DoorName));
			
			AddCommas(door.GetPrice(client), ",", sPrice, sizeof(sPrice));
			
			PrintHintText(client, "House - Door\n%s's House\nPrice: $%s", DoorName, sPrice);
		}
	}
	else
	{	
		AddCommas(door.GetPrice(), ",", sPrice, sizeof(sPrice));
		
		if(buttons & IN_RELOAD)
		{
			if(IsInside)
			{
				new String:szFormat[32];
				
				FormatTime(szFormat, 32, "%d/%m/%Y %T", door.GetUnix());
				
				new String:szEntityId[8];
				IntToString(entity, szEntityId, 5);
				new Menu:menu = CreateMenu(MenuHandler_Door, MenuAction:28);
				RP_SetMenuTitle(menu, "Door Menu");
				
				AddMenuItem(menu, szEntityId, "Unlock Door", 0);
				AddMenuItem(menu, szEntityId, "Lock Door\n ", 0);
				
				AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
				
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
			else
			{
				new String:szEntityId[8];
				IntToString(entity, szEntityId, 5);
				
				new Menu:menu = CreateMenu(MenuHandler_DoorBuy, MenuAction:28);
				RP_SetMenuTitle(menu, "Buy Door Menu\n ");
				
				new String:TempFormat[64];
				
				AddMenuItem(menu, "", "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, "", "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, "", "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, "", "", ITEMDRAW_NOTEXT);
				
				if(door.IsGangOnly())
				{
					FormatEx(TempFormat, sizeof(TempFormat), "Buy Door - $%s [Gang Restricted]", sPrice);
					AddMenuItem(menu, szEntityId, TempFormat, ITEMDRAW_DISABLED);
				}
				
				else if(door.IsVIPOnly())
				{
					AddCommas(door.GetPrice(client), ",", sPrice, sizeof(sPrice));
					
					FormatEx(TempFormat, sizeof(TempFormat), "Buy Door - $%s [VIP Restricted]", sPrice);
					AddMenuItem(menu, szEntityId, TempFormat, CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
					
					AddCommas(door.GetPrice(), ",", sPrice, sizeof(sPrice));
				
					FormatEx(TempFormat, sizeof(TempFormat), "Buy Door - $%s. [GANG]", sPrice);
					AddMenuItem(menu, szEntityId, TempFormat, CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2) && Is_User_Manage_Gang_Door(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
				}
				
				else
				{
					AddCommas(door.GetPrice(client), ",", sPrice, sizeof(sPrice));
						
					FormatEx(TempFormat, sizeof(TempFormat), "Buy Door - $%s", sPrice);
					AddMenuItem(menu, szEntityId, TempFormat);
					
					AddCommas(door.GetPrice(), ",", sPrice, sizeof(sPrice));
				
					FormatEx(TempFormat, sizeof(TempFormat), "Buy Door - $%s. [GANG]", sPrice);
					AddMenuItem(menu, szEntityId, TempFormat, Is_User_Manage_Gang_Door(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
				}

				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
		}
		else
		{
			AddCommas(door.GetPrice(), ",", sPrice, sizeof(sPrice));
			PrintHintText(client, "House - Door\nPrice: $%s\nPress R to purchase.", sPrice);
		}
	}
	
	g_iOldButtons[client] = buttons;
}

public OnRentedDoorTouch(entity, client)
{
	if (!client || client > MaxClients)
	{
		return;
	}

	new RentDoor:rDoor = g_dRentDoor[entity];

	// If price exceeds 1 billion
	if(rDoor.GetPrice() >= 1000000000)
		return;
	
	new buttons = GetClientButtons(client);
	
	new bool:IsInside = RentDoor_IsClientInsideHouse(client, entity, rDoor);
	
	new String:DoorName[64];
			
	rDoor.GetName(DoorName, sizeof(DoorName));
	
	if (rDoor.GetOwned())
	{
		new MinutesLeft = RoundToFloor(float((rDoor.GetUnix() - GetTime())) / 60.0);
		
		if(MinutesLeft <= 0)
		{
	
			PrintToRentDoorKeysAndOwner(rDoor, " \x05[%s's Door] \x02%N\x01 has just unrented the door.", DoorName, client);

			new ArrayList:keys = rDoor.GetKeyArray();
			
			ClearArray(keys);
			rDoor.SetOwned(false);

			g_iOwnedDoor[client] = 0;
			
			AcceptEntityInput(entity, "Unlock");
			AcceptEntityInput(entity, "Open");
			AcceptEntityInput(entity, "Close");
		}
		if (buttons & IN_RELOAD && !(g_iOldButtons[client] & IN_RELOAD))
		{	
			if (g_iOwnedDoor[client] == entity)
			{	
				new String:szEntityId[8];
				IntToString(entity, szEntityId, 5);
				
				new Menu:menu = CreateMenu(MenuHandler_RentedDoor, MenuAction:28);
				RP_SetMenuTitle(menu, "Rented Door Menu\nExpires in %i minutes", MinutesLeft);
				
				AddMenuItem(menu, szEntityId, "Unlock Door", 0);
				AddMenuItem(menu, szEntityId, "Lock Door\n ", 0);
				AddMenuItem(menu, szEntityId, "Give Keys", 0);
				AddMenuItem(menu, szEntityId, "Delete Keys\n ", 0);
				
				AddMenuItem(menu, szEntityId, "Stop Renting Door")
				
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
			
			else if(IsInside || FindValueInArray(rDoor.GetKeyArray(), client) != -1)
			{
				new String:szEntityId[8];
				IntToString(entity, szEntityId, 5);
				
				new Menu:menu = CreateMenu(MenuHandler_RentedDoor, MenuAction:28);
				RP_SetMenuTitle(menu, "Rented Door Menu\nExpires in %i minutes", MinutesLeft);
				
				AddMenuItem(menu, szEntityId, "Unlock Door", 0);
				AddMenuItem(menu, szEntityId, "Lock Door\n ", 0);
				
				AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
				
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
			
			else
			{
				if(GetEntProp(entity, Prop_Data, "m_bLocked"))
				{
					if(g_iCrackProgress[client][entity] == 0)
						g_fStartCrack[client][entity] = GetGameTime();
						
					if(g_fNextHouseSound[client] <= GetGameTime())
					{
						g_fNextHouseSound[client] = GetGameTime() + 3.0;
						
						EmitSoundToAllAny("roleplay/door_knock.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
					}
					
					g_fNextHouseMessage[client] = GetGameTime() + 1.0;
					
					g_iCrackProgress[client][entity] += 2;
					
					PrintHintText(client, "Breaking the lock...\nProgress %i%%\nSpam the R Key", g_iCrackProgress[client][entity]);
					
					if(g_iCrackProgress[client][entity] >= 100)
					{
						//PrintToChatEyal("%.2f", GetGameTime() - g_fStartCrack[client][entity]);
						g_iCrackProgress[client][entity] = 0;
						
						new TotalChance = 100;//g_iCrackChance[RP_GetClientLevel(client, RP_GetClientJob(client))];
						
						if(TotalChance >= GetRandomInt(1, 100))
						{
							g_fNextLock[entity] = GetGameTime() + 2.5;
							
							AcceptEntityInput(entity, "Unlock", -1, -1, 0);
							
							RP_PrintToChat(client, "You have cracked the door lock!");
							
							//RP_AddClientEXP(client, RP_GetClientJob(client), 10);
						}
						else
						{
							RP_PrintToChat(client, "You have failed to unlock the door, what a bad luck.");
							
							//RP_AddClientEXP(client, RP_GetClientJob(client), 3);
				 		}
					}
				}
			}
		}
		else if(!(buttons & IN_RELOAD) && g_fNextHouseMessage[client] <= GetGameTime())
		{
			PrintHintText(client, "House - Rented Door\n%s's House", DoorName);
		}
	}
	else
	{	
	
		new String:sPrice[16];
		
		AddCommas(rDoor.GetPrice(), ",", sPrice, sizeof(sPrice));
		
		if(buttons & IN_RELOAD)
		{
			if(IsInside)
			{
				
				new String:szEntityId[8];
				IntToString(entity, szEntityId, 5);
				
				new Menu:menu = CreateMenu(MenuHandler_RentedDoor, MenuAction:28);
				RP_SetMenuTitle(menu, "Rented Door Menu");
				
				AddMenuItem(menu, szEntityId, "Unlock Door", 0);
				AddMenuItem(menu, szEntityId, "Lock Door\n ", 0);
				
				AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, szEntityId, "", ITEMDRAW_NOTEXT);
				
				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
			else
			{
				new String:szEntityId[8];
				IntToString(entity, szEntityId, 5);
				
				new Menu:menu = CreateMenu(MenuHandler_RentDoorBuy, MenuAction:28);
				RP_SetMenuTitle(menu, "Rent Door Menu\n ");
				
				new String:TempFormat[64];
				
				AddMenuItem(menu, "", "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, "", "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, "", "", ITEMDRAW_NOTEXT);
				AddMenuItem(menu, "", "", ITEMDRAW_NOTEXT);
				
				FormatEx(TempFormat, sizeof(TempFormat), "Rent Door for 2 Hours - $%s", sPrice);
				AddMenuItem(menu, szEntityId, TempFormat);

				DisplayMenu(menu, client, MENU_TIME_FOREVER);
			}
		}
		else
			PrintHintText(client, "House - Door for Rent\nPrice: $%s\nPress R to rent for 2 hours.", sPrice);
	}
	
	g_iOldButtons[client] = buttons;
}
public MenuHandler_ConnectedKeyDoor(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId, 10);
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this door!");
		}
		else
		{
			new ConnectedDoor:cDoor = g_dConnectedDoor[entity];
			new Door:door = cDoor.GetMainDoor();
			
			new String:DoorName[64];
			
			door.GetName(DoorName, sizeof(DoorName));
			
			switch (key)
			{
				case 0:
				{
						EmitSoundToAllAny("roleplay/door_key.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						AcceptEntityInput(entity, "Unlock", -1, -1, 0);
						AcceptEntityInput(entity, "Open", 0, -1, 0);
	
						PrintToDoorKeysAndOwner(door, " \x05[%s's Door] \x02%N\x01 has just unlocked a connected door!", DoorName, client);
				}
				case 1:
				{
					if(g_fNextLock[entity] <= GetGameTime())
					{
						if(GetDoorState(entity) != STATE_CLOSED && GetDoorState(entity) != STATE_INVALID)
						{
							RP_PrintToChat(client, "You cannot lock a door while it's open.");
							
							return;
						}
						
						EmitSoundToAllAny("roleplay/door_key.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						
						if(!cDoor.IsPickable())
							AcceptEntityInput(entity, "Close", -1, -1, 0);
							
						AcceptEntityInput(entity, "Lock", -1, -1, 0);
						PrintToDoorKeysAndOwner(door, " \x05[%s's Door] \x02%N\x01 has just locked a connected door!", DoorName, client);
					}
				}
				default:
				{
				}
			}
		}
	}
}

public MenuHandler_Door(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId, 10);
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this door!");
		}
		else
		{
			new Door:door = g_dDoor[entity];
		

			new bool:IsInside = IsClientInsideHouse(client, entity, door);
		
			new String:GangTag[32];
			door.GetGangOwned(GangTag, sizeof(GangTag));
			
			new String:ClientGangTag[32];
			Get_User_Gang_Tag(client, ClientGangTag, sizeof(ClientGangTag));
			
			// Not gang related to door
			bool bGangType = -1;

			if(StrEqual(GangTag, ClientGangTag, false))
			{
				if(Get_User_Gang(client) == -1)
					bGangType = 0; // Gang related to door, but in debt.

				else
					bGangType = 1; // Gang related to door.
			}
			if( g_iOwnedDoor[client] == entity || IsInside || (GetClientTeam(client) == CS_TEAM_T && ( FindValueInArray(door.GetKeyArray(), client) != -1 || bGangType != -1 )))
			{				
				new String:DoorName[64];
				door.GetName(DoorName, sizeof(DoorName));
				
				switch (key)
				{
					case 0:
					{
						if( bGangType != 0)
						{
							EmitSoundToAllAny("roleplay/door_key.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							AcceptEntityInput(entity, "Unlock", -1, -1, 0);
							AcceptEntityInput(entity, "Open", 0, -1, 0);
							PrintToDoorKeysAndOwner(door, " \x05[%s's Door] \x02%N\x01 has just unlocked the door!", DoorName, client);
						}
					}
					case 1:
					{
						if( bGangType != 0)
						{
							if(g_fNextLock[entity] <= GetGameTime())
							{
								if(GetDoorState(entity) != STATE_CLOSED && GetDoorState(entity) != STATE_INVALID)
								{
									RP_PrintToChat(client, "You cannot lock a door while it's open.");
									
									return;
								}
								
								EmitSoundToAllAny("roleplay/door_key.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
								AcceptEntityInput(entity, "Lock", -1, -1, 0);
								PrintToDoorKeysAndOwner(door, " \x05[%s's Door] \x02%N\x01 has just locked the door!", DoorName, client);
							}
						}
					}
					case 2:
					{
						if( bGangType != 0)
						{
							new ArrayList:keys = door.GetKeyArray();
							new Menu:keyMenu = CreateMenu(MenuHandler_GiveKeys, MenuAction:28);
							RP_SetMenuTitle(keyMenu, "Door - Give Keys Menu\n ");
							new String:szInfo[32];
							new String:szName[32];
							new clients;
							
							for(new i=1;i <= MaxClients;i++)
							{
								if (IsClientInGame(i))
								{
									if (FindValueInArray(keys, i, 0) == -1 && ( StrEqual(GangTag, GANG_NULL) || ( !StrEqual(GangTag, GANG_NULL) && !Are_Users_Same_Gang(client, i) ) ))
									{
										FormatEx(szInfo, sizeof(szInfo), "%i %i", GetClientUserId(i), entity);
										GetClientName(i, szName, 32);
										AddMenuItem(keyMenu, szInfo, szName, 0);
										clients++;
									}
								}
							}
							if (!clients)
							{
								AddMenuItem(keyMenu, "0", "No available players.", 1);
							}
							DisplayMenu(keyMenu, client, 0);
						}
					}
					case 3:
					{
						if(bGangType != 0)
						{
							new String:szName[36];
							new String:szInfo[32];
							GetClientName(client, szName, 32);
							Format(szName, 35, "%s - YOU\n ", szName);
							new ArrayList:keys = door.GetKeyArray();
							new Menu:keyMenu = CreateMenu(MenuHandler_DeleteKeys, MenuAction:28);
							RP_SetMenuTitle(keyMenu, "Door - Remove Keys Menu\n ");
							AddMenuItem(keyMenu, "", szName, 1);
		
							for(new i=0;i < GetArraySize(keys);i++)
							{
								new target = GetArrayCell(keys, i);
								
								if(client != target && ( StrEqual(GangTag, GANG_NULL) || !StrEqual(GangTag, GANG_NULL) && !Are_Users_Same_Gang(client, target) ))
								{
									GetClientName(target, szName, 32);
									FormatEx(szInfo, sizeof(szInfo), "%i %i", GetClientUserId(target), entity);
									AddMenuItem(keyMenu, szInfo, szName, 0);
								}
							}
							DisplayMenu(keyMenu, client, 0);
						}
					}
					case 4:
					{
						ShowConfirmSellDoorMenu(client, szEntityId);
					}
					case 5:
					{
						LastEntity[client] = entity;
						
						ShowHouseVaultMenu(client);
					}
				}
			}
		}
	}
}


public MenuHandler_RentedDoor(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId, 10);
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this door!");
		}
		else
		{
			new RentDoor:rDoor = g_dRentDoor[entity];
			
			new String:DoorName[64];
			rDoor.GetName(DoorName, sizeof(DoorName));
			
			switch (key)
			{
				case 0:
				{
					EmitSoundToAllAny("roleplay/door_key.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
					AcceptEntityInput(entity, "Unlock", -1, -1, 0);
					AcceptEntityInput(entity, "Open", 0, -1, 0);
					PrintToRentDoorKeysAndOwner(rDoor, " \x05[%s's Door] \x02%N\x01 has just unlocked the door!", DoorName, client);
				}
				case 1:
				{
					if(g_fNextLock[entity] <= GetGameTime())
					{
						if(GetDoorState(entity) != STATE_CLOSED && GetDoorState(entity) != STATE_INVALID)
						{
							RP_PrintToChat(client, "You cannot lock a door while it's open.");
							
							return;
						}
						EmitSoundToAllAny("roleplay/door_key.mp3", entity, 0, 75, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
						AcceptEntityInput(entity, "Lock", -1, -1, 0);
						PrintToRentDoorKeysAndOwner(rDoor, " \x05[%s's Door] \x02%N\x01 has just locked the door!", DoorName, client);
					}
				}
				case 2:
				{
					new ArrayList:keys = rDoor.GetKeyArray();
					new Menu:keyMenu = CreateMenu(MenuHandler_RentGiveKeys, MenuAction:28);
					RP_SetMenuTitle(keyMenu, "Rented Door - Give Keys Menu\n ");
					new String:szIndexId[4];
					new String:szName[32];
					new clients;
					
					for(new i=1;i <= MaxClients;i++)
					{
						if (IsClientInGame(i))
						{
							IntToString(i, szIndexId, 3);
							if (FindValueInArray(keys, i, 0) == -1)
							{
								GetClientName(i, szName, 32);
								AddMenuItem(keyMenu, szIndexId, szName, 0);
								clients++;
							}
						}
					}
					if (!clients)
					{
						AddMenuItem(keyMenu, "0", "No available players.", 1);
					}
					
					DisplayMenu(keyMenu, client, 0);
				}
				case 3:
				{
					new String:szName[36];
					new String:szIndexId[4];
					GetClientName(client, szName, 32);
					Format(szName, 35, "%s - YOU\n ", szName);
					new ArrayList:keys = rDoor.GetKeyArray();
					new Menu:keyMenu = CreateMenu(MenuHandler_RentDeleteKeys, MenuAction:28);
					RP_SetMenuTitle(keyMenu, "Rented Door - Remove Keys Menu\n ");
					AddMenuItem(keyMenu, "", szName, 1);
					new i;
					while (GetArraySize(keys) > i)
					{
						if (client != GetArrayCell(keys, i, 0, false))
						{
							GetClientName(GetArrayCell(keys, i, 0, false), szName, 32);
							IntToString(GetArrayCell(keys, i, 0, false), szIndexId, 3);
							AddMenuItem(keyMenu, szIndexId, szName, 0);
						}
						i++;
					}
					DisplayMenu(keyMenu, client, 0);
				}
				case 4:
				{
					PrintToRentDoorKeysAndOwner(rDoor, " \x05[%s's Door] \x02%N\x01 has just unrented the door.", DoorName, client);

					new ArrayList:keys = rDoor.GetKeyArray();
					
					ClearArray(keys);
					rDoor.SetOwned(false);

					g_iOwnedDoor[client] = 0;
					
					AcceptEntityInput(entity, "Unlock");
					AcceptEntityInput(entity, "Open");
					AcceptEntityInput(entity, "Close");
				}
				default:
				{
				}
			}
		}
	}
}

ShowConfirmSellDoorMenu(client, const String:szEntityId[])
{
	new Menu:menu = CreateMenu(MenuHandler_ConfirmSellDoor, MenuAction:28);
	RP_SetMenuTitle(menu, "Door Menu\nAre you sure you want to sell your door?\nFor safety measures, hold E and W while pressing Yes to finish the sale");
	AddMenuItem(menu, szEntityId, "Yes", 0);
	AddMenuItem(menu, szEntityId, "No", 0);
	DisplayMenu(menu, client, 0);
}

public MenuHandler_ConfirmSellDoor(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		
		new entity = StringToInt(szEntityId, 10);
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this door!");
		}
		else
		{
			new Door:door = g_dDoor[entity];
			
			new String:DoorName[64];
			door.GetName(DoorName, sizeof(DoorName));
			
			if(key == 0)
			{
	
				new buttons = GetClientButtons(client);
				
				if(!(buttons & IN_FORWARD) || !(buttons & IN_USE))
				{
					RP_PrintToChat(client, "To sell your door, you must press E and W while pressing Yes.");
					
					return;
				}
				
				new String:GangTag[32], String:ClientGangTag[32];
									
				door.GetGangOwned(GangTag, sizeof(GangTag));

				Get_User_Gang_Tag(client, ClientGangTag, sizeof(ClientGangTag));

				if(!StrEqual(GangTag, GANG_NULL) && (!Is_User_Manage_Gang_Door(client) || !StrEqual(ClientGangTag, GangTag)))
					return;
					
				new String:szQuery[256];
				SQL_FormatQuery(g_hDatabase, szQuery, 256, "DELETE From rp_doors where hammerid='%i'", door.GetHammer());
				SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, 0, DBPrio_Normal);
				new ArrayList:keys = door.GetKeyArray();

				ClearArray(keys);
				door.SetOwned(false);

				door.SetGangOwned(GANG_NULL);

				new price;
				if(StrEqual(GangTag, GANG_NULL))
				{
					price = RoundFloat(float(door.GetPrice(client)) * DOOR_SELL_MULTIPLIER);
					
					g_iOwnedDoor[client] = 0;
					GiveClientCashNoGangTax(client, BANK_CASH, door.GetBank() + price);
				}
					
				else
				{
					price = RoundFloat(float(door.GetPrice()) * DOOR_SELL_MULTIPLIER);
					Add_User_GangBank(client, door.GetBank() + price);
				}	
				
				PrintToDoorKeysAndOwner(door, " \x05[%s's Door] \x02%N\x01 has just sold the door for \x04$%i!", DoorName, client, price);
				RolePlayLog("%N has just sold the door %s(%i) for %i", client, DoorName, door.GetHammer(), price);
				
				door.SetBank(0);
				
				AcceptEntityInput(entity, "Unlock");
				AcceptEntityInput(entity, "Open");
				AcceptEntityInput(entity, "Close");
				
				for(new i=0;i < GetArraySize(g_aConnectedDoors);i++)
				{
					new ConnectedDoor:cDoor = GetArrayCell(g_aConnectedDoors, i);
					
					new Door:MainDoor = cDoor.GetMainDoor();

					if(door == MainDoor)
					{
						new ConnectedDoorEntity = GetEntityFromHammerID(cDoor.GetHammer());
						
						if(ConnectedDoorEntity != -1)
						{
							AcceptEntityInput(ConnectedDoorEntity, "Unlock");
							AcceptEntityInput(ConnectedDoorEntity, "Open");
							AcceptEntityInput(ConnectedDoorEntity, "Close");
						}
					}
				}
			}
		}
	}
}

ShowHouseVaultMenu(client)
{
	new Door:door = g_dDoor[LastEntity[client]];
			
	new String:DoorName[64];
	door.GetName(DoorName, sizeof(DoorName));
	new Menu:menu = CreateMenu(MenuHandler_HouseVault, MenuAction:28);
	
	new String:dummy_gang_tag[3];
	door.GetGangOwned(dummy_gang_tag, sizeof(dummy_gang_tag));
	
	if(StrEqual(dummy_gang_tag, GANG_NULL))
		RP_SetMenuTitle(menu, "Door Menu\nBank Cash: $%i\nHouse Vault balance: $%i\nDaily Rent Cost: $%i", GetClientCash(client, BANK_CASH), door.GetBank(), RENT_PRICE_FORMULA(door.GetPrice()));
		
	else
		RP_SetMenuTitle(menu, "Door Menu\nGang Bank Cash: $%i\nHouse Vault balance: $%i\nDaily Rent Cost: $%i", Get_User_GangBank(client), door.GetBank(), RENT_PRICE_FORMULA(door.GetPrice()));
		
	new String:szEntityId[8];
	IntToString(LastEntity[client], szEntityId, sizeof(szEntityId));
	
	AddMenuItem(menu, szEntityId, "Deposit", 0);
	AddMenuItem(menu, szEntityId, "Withdraw", 0);
	
	DisplayMenu(menu, client, 0);
}


public MenuHandler_HouseVault(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		
		if(key == 0)
			HouseVaultState[client] = STATE_DEPOSIT;
			
		else
			HouseVaultState[client] = STATE_WITHDRAW;
		
		RP_PrintToChat(client, "Type cash amount to %s or \x02-1\x01 to cancel!", HouseVaultState[client] == STATE_DEPOSIT ? "deposit" : "withdraw");
	}
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	if (HouseVaultState[client] == STATE_NONE)
		return Plugin_Continue;

	if (StrEqual(sArgs, "-1", true))
	{
		RP_PrintToChat(client, "Operation cancelled!");
	}
	else
	{
		new Door:door = g_dDoor[LastEntity[client]];
		
		new cash = StringToInt(sArgs, 10);
		
		if (cash < 1)
		{
			RP_PrintToChat(client, "This cash amount is not valid, try again.");
		}
		else
		{
			switch(HouseVaultState[client])
			{
				case STATE_DEPOSIT:
				{
					new String:GangTag[32], String:ClientGangTag[32];
									
					door.GetGangOwned(GangTag, sizeof(GangTag));
	
					Get_User_Gang_Tag(client, ClientGangTag, sizeof(ClientGangTag));
	
					if(!StrEqual(GangTag, GANG_NULL) && (!Is_User_Manage_Gang_Door(client) || !StrEqual(ClientGangTag, GangTag)))
					{
						HouseVaultState[client] = STATE_NONE;
						
						return Plugin_Stop;
					}
					
					if(StrEqual(GangTag, GANG_NULL))
					{
						if (GetClientCash(client, BANK_CASH) < cash)
						{
							RP_PrintToChat(client, "You don't have enough cash in your bank!");
							
							HouseVaultState[client] = STATE_NONE;
	
							ShowHouseVaultMenu(client);
							
							return Plugin_Stop;
						}
						
						new String:szQuery[256], String:szAuth[32];
						
						GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
						
						SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_doors SET bank = bank + %i WHERE hammerid='%i'", cash, door.GetHammer());
						
						SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery);
						
						door.SetBank(door.GetBank() + cash);
						
						GiveClientCashNoGangTax(client, BANK_CASH, -1 * cash);
						RP_PrintToChat(client, "You deposited \x02%i\x01 cash to your house vault!", cash);
					}
					else
					{
						if (Get_User_GangBank(client) < cash)
						{
							RP_PrintToChat(client, "You don't have enough cash in your gang's bank!");
							
							HouseVaultState[client] = STATE_NONE;
							
							ShowHouseVaultMenu(client);
							
							return Plugin_Stop;
						}
						
						new String:szQuery[256], String:szAuth[32];
						
						GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
						
						SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_doors SET bank = bank + %i WHERE hammerid='%i'", cash, door.GetHammer());
						
						SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery);
						
						door.SetBank(door.GetBank() + cash);
						
						Add_User_GangBank(client, -1 * cash);
						
						RP_PrintToChat(client, "You deposited \x02%i\x01 cash to your house vault from your gang's bank!", cash);
					}
				}
				
				case STATE_WITHDRAW:
				{
					new String:GangTag[32], String:ClientGangTag[32];
									
					door.GetGangOwned(GangTag, sizeof(GangTag));
	
					Get_User_Gang_Tag(client, ClientGangTag, sizeof(ClientGangTag));
	
					if(!StrEqual(GangTag, GANG_NULL) && (!Is_User_Manage_Gang_Door(client) || !StrEqual(ClientGangTag, GangTag)))
					{
						HouseVaultState[client] = STATE_NONE;
						
						return Plugin_Stop;
					}
					
					if(StrEqual(GangTag, GANG_NULL))
					{
						if (door.GetBank() < cash)
						{
							RP_PrintToChat(client, "You don't have enough cash in your house vault!");
							
							HouseVaultState[client] = STATE_NONE;
	
							ShowHouseVaultMenu(client);
							
							return Plugin_Stop;
						}
						
						new String:szQuery[256], String:szAuth[32];
						
						GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
						
						SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_doors SET bank = bank - %i WHERE hammerid='%i'", cash, door.GetHammer());
						
						SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery);
						
						door.SetBank(door.GetBank() - cash);
						
						GiveClientCashNoGangTax(client, BANK_CASH, cash);
						RP_PrintToChat(client, "You withdrew \x02%i\x01 cash from your house vault!", cash);
					}
					else
					{
						if(door.GetBank() < cash)
						{
							RP_PrintToChat(client, "You don't have enough cash in your house vault!");
							
							HouseVaultState[client] = STATE_NONE;
							
							ShowHouseVaultMenu(client);
							
							return Plugin_Stop;
						}
						
						new String:szQuery[256], String:szAuth[32];
						
						GetClientAuthId(client, AuthId_Engine, szAuth, sizeof(szAuth));
						
						SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_doors SET bank = bank - %i WHERE hammerid='%i'", cash, door.GetHammer());
						
						SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery);
						
						door.SetBank(door.GetBank() - cash);
						
						Add_User_GangBank(client,  cash);
						RP_PrintToChat(client, "You withdrew \x02%i\x01 cash from your house vault to your gang's bank!", cash);
					}
				}
			}
		}
	}
	
	HouseVaultState[client] = STATE_NONE;
	
	CreateTimer(0.1, Timer_ShowHouseVaultMenu, GetClientUserId(client));
	
	return Plugin_Stop;
}

public Action:Timer_ShowHouseVaultMenu(Handle:hTimer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return;
		
	ShowHouseVaultMenu(client);
}

public MenuHandler_GiveKeys(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szInfo[32], String:sUserId[11], String:szEntity[11];
		GetMenuItem(menu, key, szInfo, sizeof(szInfo));
		
		new len = BreakString(szInfo, sUserId, sizeof(sUserId));
		
		FormatEx(szEntity, sizeof(szEntity), szInfo[len]);
		
		new target = GetClientOfUserId(StringToInt(sUserId));
		
		new entity = StringToInt(szEntity);
		
		if (target)
		{
			new Door:door = g_dDoor[entity];
			
			if(door)
			{
				new String:DoorName[64];
				door.GetName(DoorName, sizeof(DoorName));
				
				PushArrayCell(door.GetKeyArray(), target);
				PrintToDoorKeysAndOwner(door, " \x05[%s's Door] \x02%N\x01 has gave \x04%N\x01 a key!", DoorName, client, target);
			}
		}
	}
}


public MenuHandler_DeleteKeys(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szInfo[32], String:sUserId[11], String:szEntity[11];
		GetMenuItem(menu, key, szInfo, sizeof(szInfo));
		
		new len = BreakString(szInfo, sUserId, sizeof(sUserId));
		
		FormatEx(szEntity, sizeof(szEntity), szInfo[len]);
		
		new target = GetClientOfUserId(StringToInt(sUserId));
		
		new entity = StringToInt(szEntity);
		
		if (target)
		{
			new Door:door = g_dDoor[entity];
			
			new String:DoorName[64];
			door.GetName(DoorName, sizeof(DoorName));
			
			new ArrayList:keyArr = door.GetKeyArray();
			
			new slot = FindValueInArray(keyArr, target, 0)
			
			if(slot != -1)
			{
				PrintToDoorKeysAndOwner(door, " \x05[%s's Door] \x02%N\x01 has removed \x04%N\x01 key!", DoorName, client, target);
				RemoveFromArray(keyArr, slot);
			}
		}
	}
}

public MenuHandler_DoorBuy(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null
	}
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId, 10);
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this door!");
		}
		else
		{
			new time = GetTime() + SECONDS_IN_A_DAY;
			new String:szAuth[32];
			GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
			new String:szQuery[256];
			
			new Door:door = g_dDoor[entity];
			
			new price;
			
			if (key == 4)
			{
				price = door.GetPrice(client);
					
				if (door.GetOwned())
				{
					RP_PrintToChat(client, "This door is owned by another player!");
					return;
				}
				else if (door.IsGangOnly())
				{
					RP_PrintToChat(client, "This door is restricted to gangs!");
					return;
				}
				else if (door.IsVIPOnly() && !CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
				{
					RP_PrintToChat(client, "This door is restricted to VIP.");
					return;
				}
				else if (price > GetClientCash(client, BANK_CASH))
				{
					RP_PrintToChat(client, "You don't have enough money in your bank to buy this house!");
					return;
				}
				
				else if (g_iOwnedDoor[client])
				{
					RP_PrintToChat(client, "You already got a \x02door!");
					
					return;
					
				}
				
				GiveClientCashNoGangTax(client, BANK_CASH, -1 * price);
				
				new String:szName[32];
				GetClientName(client, szName, 32);
				new String:szSecuredName[64];
				SQL_EscapeString(g_hDatabase, szName, szSecuredName, sizeof(szSecuredName));
				SQL_FormatQuery(g_hDatabase, szQuery, 256, "INSERT INTO rp_doors (hammerid, AuthId, GangTag, name, unix, bank) VALUES ('%i', '%s', NULL, '%s', '%i', 0)", GetEntProp(entity, Prop_Data, "m_iHammerID"), szAuth, szSecuredName, time);
				door.SetName(szSecuredName);
				
				g_iOwnedDoor[client] = entity;
				
				door.SetOwned(true);
				door.SetGangOwned(GANG_NULL);
			}
			else
			{
				price = door.GetPrice();
				
				if (door.GetOwned())
				{
					RP_PrintToChat(client, "This door is owned by another player!");
					return;
				}
				else if (door.IsVIPOnly() && !CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
				{
					RP_PrintToChat(client, "This door is restricted to VIP.");
					return;
				}
				else if(!Is_User_Manage_Gang_Door(client))
				{
					RP_PrintToChat(client, "Only the gang leader can buy his gang a door!");
					return;
				}	
				else if (price > Get_User_GangBank(client))
				{
					RP_PrintToChat(client, "Your gang dont have enough money to afford this door!");
					return;
				}
				
				new String:ClientGangTag[32];
				
				Get_User_Gang_Tag(client, ClientGangTag, sizeof(ClientGangTag));
				
				for(new i=0;i < GetArraySize(g_aDoors);i++)
				{
					new Door:ArrayDoor = GetArrayCell(g_aDoors, i);
					
					new String:GangTag[32];
					
					ArrayDoor.GetGangOwned(GangTag, sizeof(GangTag));
					
					if(StrEqual(ClientGangTag, GangTag))
					{
						RP_PrintToChat(client, "Your gang already owns a door!");
						return;
					}
				}
				
				Add_User_GangBank(client, -1 * price);
				new String:szGangDoorName[64];
				
				door.SetGangOwned(ClientGangTag);
				
				new String:szGangName[32];
				Get_User_Gang_Name(client, szGangName, 32);
				new String:szSecuredName[64];
				SQL_EscapeString(g_hDatabase, ClientGangTag, szSecuredName, sizeof(szSecuredName));
				
				Format(szGangName, 64, "%s Gang", szGangName);
				SQL_EscapeString(g_hDatabase, szGangName, szGangDoorName, sizeof(szGangDoorName));
				
				SQL_FormatQuery(g_hDatabase, szQuery, 256, "INSERT INTO rp_doors (hammerid, AuthId, GangTag, name, unix, bank) VALUES ('%i', NULL, '%s', '%s', '%i', 0)", GetEntProp(entity, Prop_Data, "m_iHammerID"), szSecuredName, szGangDoorName, time);
				door.SetName(szGangDoorName);
			}
			
			SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, 0, DBPrio_Normal);
			door.SetUnix(time);
			door.SetOwned(true);
			//PushArrayCell(door.GetKeyArray(), client); // Deleted in 19/12/2020, feels useless always.
			
			new String:DoorName[64];
			door.GetName(DoorName, sizeof(DoorName));
			
			RolePlayLog("%N has just bought the door %s(%i) for %i.", client, DoorName, door.GetHammer(), price);
			RP_PrintToChat(client, "You have just bought the door for \x02$%i!", price);
		}
	}
}

public MenuHandler_RentGiveKeys(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szIndexId[4];
		GetMenuItem(menu, key, szIndexId, 3);
		
		new target = StringToInt(szIndexId, 10);
		
		if (target)
		{
			new RentDoor:rDoor = g_dRentDoor[g_iOwnedDoor[client]];
			
			new String:DoorName[64];
			rDoor.GetName(DoorName, sizeof(DoorName));
			
			PushArrayCell(rDoor.GetKeyArray(), target);
			PrintToRentDoorKeysAndOwner(g_dRentDoor[g_iOwnedDoor[client]], " \x05[%s's Door] \x02%N\x01 has gave \x04%N\x01 a key!", DoorName, client, target);
		}
	}
}


public MenuHandler_RentDeleteKeys(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		new String:szIndexId[4];
		GetMenuItem(menu, key, szIndexId, 3);
		new target = StringToInt(szIndexId, 10);
		
		new RentDoor:rDoor = g_dRentDoor[g_iOwnedDoor[client]]
		
		new String:DoorName[64];
		rDoor.GetName(DoorName, sizeof(DoorName));
		
		if (target)
		{
			PrintToRentDoorKeysAndOwner(rDoor, " \x05[%s's Door] \x02%N\x01 has removed \x04%N\x01 key!", DoorName, client, target);
			new ArrayList:keyArr = rDoor.GetKeyArray();
			RemoveFromArray(keyArr, FindValueInArray(keyArr, target, 0));
		}
	}
}


public MenuHandler_RentDoorBuy(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null
	}	
	else if (action == MenuAction_Select)
	{
		new String:szEntityId[8];
		GetMenuItem(menu, key, szEntityId, 5);
		new entity = StringToInt(szEntityId, 10);
		
		if (CheckDistance(client, entity) > 150.0)
		{
			RP_PrintToChat(client, "You are too far away from this door!");
		}
		else
		{
			new RentDoor:rDoor = g_dRentDoor[entity];
			
			if (key == 4)
			{
				if (rDoor.GetOwned())
				{
					RP_PrintToChat(client, "This door is rented by another player!");
					return;
				}
				else if (rDoor.GetPrice() > GetClientCash(client, BANK_CASH))
				{
					RP_PrintToChat(client, "You don't have enough money in your bank to rent this house!");
					return;
				}
				else if (g_iOwnedDoor[client])
				{
					RP_PrintToChat(client, "You already got a \x02door!");
					
					return;
					
				}
				
				GiveClientCashNoGangTax(client, BANK_CASH, -1 * rDoor.GetPrice());
				
				new String:szName[32];
				GetClientName(client, szName, 32);
				new String:szSecuredName[64];
				SQL_EscapeString(g_hDatabase, szName, szSecuredName, sizeof(szSecuredName));
				rDoor.SetName(szSecuredName);
				
				g_iOwnedDoor[client] = entity;
				
				rDoor.SetOwned(true);

				rDoor.SetUnix(GetTime() + 7200); // 7200 is of course the seconds in 2 hours.
				rDoor.SetOwned(true);
				PushArrayCell(rDoor.GetKeyArray(), client);
				
				new String:DoorName[64];
				rDoor.GetName(DoorName, sizeof(DoorName));
				
				RP_PrintToChat(client, "You have just rented the door for \x02$%i!", rDoor.GetPrice());
			}
		}
	}
}

public SQL_LoadDoorGang(Handle:owner, Handle:handle, String:error[], any:data)
{
	new client = GetClientFromSerial(data);
	if (!client)
	{
		return;
	}
	if (handle)
	{
		new entity;
		if (SQL_FetchRow(handle))
		{
			entity = GetEntityFromHammerID(SQL_FetchInt(handle, 0));
			
			if(entity == -1)
				return;
				
			new Door:door = g_dDoor[entity];
			
			new String:GangTag[32];
			Get_User_Gang_Tag(client, GangTag, sizeof(GangTag));
			
			door.SetGangOwned(GangTag);
			
			if (entity == -1 || FindValueInArray(door.GetKeyArray(), client, 0) != -1)
			{
				return;
			}
			//PushArrayCell(door.GetKeyArray(), client); // Deleted in 19/12/2020 along with other lines, feels totally useless.
		}
		return;
	}
	LogError("[1] SQL query failed: %s", error);
}

public SQL_LoadDoor(Handle:owner, Handle:handle, String:error[], any:data)
{
	new client = GetClientFromSerial(data);
	if (!client)
	{
		return;
	}
	if (handle)
	{
		new entity;

		if (SQL_FetchRow(handle))
		{
			entity = GetEntityFromHammerID(SQL_FetchInt(handle, 0));

			if (entity != -1)
			{
				new String:szAuth[32];
				GetClientAuthId(client, AuthId_Engine, szAuth, 32, true);
				
				new Door:door = g_dDoor[entity];
				
				door.SetGangOwned(GANG_NULL);
				
				g_iOwnedDoor[client] = entity;
				
				PushArrayCell(door.GetKeyArray(), client);
				
				new String:szName[32];
				GetClientName(client, szName, 32);
				new String:szSecuredName[64];
				SQL_EscapeString(g_hDatabase, szName, szSecuredName, sizeof(szSecuredName));
				
				new String:szQuery[256];
				
				SQL_FormatQuery(g_hDatabase, szQuery, 256, "UPDATE rp_doors SET name = '%s' WHERE AuthId='%s'", szSecuredName, szAuth);
				SQL_TQuery(g_hDatabase, SQL_NoAction, szQuery, _, DBPrio_Normal);
			}
		}
		return;
	}
	LogError("[1] SQL query failed: %s", error);
}

public SQL_LoadDoors(Handle:owner, Handle:handle, String:error[], any:data)
{
	if(handle)
	{
		if (!SQL_GetRowCount(handle))
		{
			return;
		}
		new String:szName[32];
		new ent;
		while (SQL_FetchRow(handle))
		{
			ent = GetEntityFromHammerID(SQL_FetchInt(handle, 0));
			if(ent != -1)
			{
				new Door:door = g_dDoor[ent]
				SQL_FetchString(handle, 1, szName, 32);
				door.SetName(szName);
				door.SetOwned(true);
				door.SetUnix(SQL_FetchInt(handle, 2));
				door.SetBank(SQL_FetchInt(handle, 3));
			}
		}
		return;
	}
	LogError("[1] SQL query failed: %s", error);
}

public SQL_NoAction(Handle:owner, Handle:handle, String:szError[], any:data)
{
	if (!handle)
	{
		LogError("[Error %i] SQL query failed: %s", data, szError);
	}
}

public SQL_NoError(Handle:owner, Handle:handle, String:szError[], any:data)
{

}

PrintToDoorKeysAndOwner(Door:door, String:msg[], any:...)
{
	new String:szBuffer[256];
	VFormat(szBuffer, 255, msg, 3);
	new ArrayList:keys = door.GetKeyArray();
	
	new size = GetArraySize(keys);
	
	for(new i=0;i < size;i++)
	{	
		if(i >= size)
			break;
			
		RP_PrintToChat(GetArrayCell(keys, i, 0, false), szBuffer);
		
		new count = RemoveArrayDuplicateCells(keys, i);
		
		i -= count;
		
		size = GetArraySize(keys);
	}
}


PrintToRentDoorKeysAndOwner(RentDoor:rDoor, String:msg[], any:...)
{
	new String:szBuffer[256];
	VFormat(szBuffer, 255, msg, 3);
	new ArrayList:keys = rDoor.GetKeyArray();
	
	new size = GetArraySize(keys);
	
	for(new i=0;i < size;i++)
	{	
		if(i >= size)
			break;
		 
		RP_PrintToChat(GetArrayCell(keys, i, 0, false), szBuffer);
		
		new count = RemoveArrayDuplicateCells(keys, i);
		
		i -= count;
		
		size = GetArraySize(keys);
	}
}
GetEntityFromHammerID(HammerID)
{
	new i = FindValueInArray(g_aHammerToEntity, HammerID, 0);
	if (i != -1)
	{
		return g_iHammerToEntity[i];
	}
	return -1;
}

Door:FindDoorByHammerID(hammerid)
{
	new Door:door;
	new i;
	while (GetArraySize(g_aDoors) > i)
	{
		door = GetArrayCell(g_aDoors, i, 0, false);
		if (hammerid == door.GetHammer())
		{
			return door;
		}
		i++;
	}
	return Door:0;
}

ConnectedDoor:FindConnectedDoorByHammerID(hammerid)
{
	new ConnectedDoor:door;
	new i;
	while (GetArraySize(g_aConnectedDoors) > i)
	{
		door = GetArrayCell(g_aConnectedDoors, i, 0, false);
		if (hammerid == door.GetHammer())
		{
			return door;
		}
		i++;
	}
	return ConnectedDoor:0;
}


RentDoor:FindRentedDoorByHammerID(hammerid)
{
	new RentDoor:rDoor;
	new i;
	while (GetArraySize(g_aRentDoors) > i)
	{
		rDoor = GetArrayCell(g_aRentDoors, i, 0, false);
		if (hammerid == rDoor.GetHammer())
		{
			return rDoor;
		}
		i++;
	}
	return RentDoor:0;
}

ReadDoors()
{	
	ClearArray(g_aHammerToEntity);
	ClearArray(g_aConnectedDoors);
	ClearArray(g_aDoors);
	ClearArray(g_aRentDoors);
	
	if(GarbageTriesArray == INVALID_HANDLE)
		GarbageTriesArray = CreateArray(1);
		
	ClearArray(GarbageTriesArray);
	
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);

	if(!FileToKeyValues(keyValues, szConfigFile))
	{
		CreateEmptyKvFile(szConfigFile);
		return;
	}	
	
	// This line also happens to indicate if no doors are added, rented doors will not function.
	if(!KvJumpToKey(keyValues, "Doors"))
	{
		CloseHandle(keyValues);
		return;
	}	
	
	if(!KvGotoFirstSubKey(keyValues, false))
	{
		CloseHandle(keyValues);
		return;
	}	
	do
	{	
		new String:SectionName[32];
		
		KvGetSectionName(keyValues, SectionName, sizeof(SectionName));
		
		new hammer = StringToInt(SectionName);
		
		new price = KvGetNum(keyValues, "price", 0);
		
		new bool:vipOnly = view_as<bool>(KvGetNum(keyValues, "vipOnly", false))
		new bool:gangOnly = view_as<bool>(KvGetNum(keyValues, "gangOnly", false))
		new bool:invertInside = view_as<bool>(KvGetNum(keyValues, "invertInside", false));
		
		new Door:door = new Door(hammer, price, gangOnly, vipOnly, invertInside);
		
		new i=1;
		
		WHILE_TRUE
		{
			new String:Key[32];
			
			FormatEx(Key, sizeof(Key), "connected_door_%i", i);
			
			hammer = KvGetNum(keyValues, Key, -1);
			
			if(hammer == -1)
				break;
			
			new ConnectedDoor:cDoor = new ConnectedDoor(hammer, door, true);
			
			PushArrayCell(g_aConnectedDoors, cDoor);
			
			i++;
		}
		
		i=1;
		
		WHILE_TRUE
		{
			new String:Key[32];
			
			FormatEx(Key, sizeof(Key), "connected_door_no_pick_%i", i);
			
			hammer = KvGetNum(keyValues, Key, -1);
			
			if(hammer == -1)
				break;
			
			new ConnectedDoor:cDoor = new ConnectedDoor(hammer, door, false);
			
			PushArrayCell(g_aConnectedDoors, cDoor);
			
			i++;
		}
		
		PushArrayCell(g_aDoors, door);
	}
	while(KvGotoNextKey(keyValues));
	
	KvRewind(keyValues);
	
	if(!KvJumpToKey(keyValues, "Rented Doors"))
	{
		PrintToChatEyal("A");
		CloseHandle(keyValues);
		return;
	}
	else if(!KvGotoFirstSubKey(keyValues, false))
	{
		PrintToChatEyal("B");
		CloseHandle(keyValues);
		return;
	}	
	
	do
	{	
		new String:SectionName[32];
		
		KvGetSectionName(keyValues, SectionName, sizeof(SectionName));
		
		new hammer = StringToInt(SectionName);
		
		new price = KvGetNum(keyValues, "price", 0);
		
		new bool:invertInside = view_as<bool>(KvGetNum(keyValues, "invertInside", false));
		
		new RentDoor:rDoor = new RentDoor(hammer, price, invertInside);
		
		PushArrayCell(g_aRentDoors, rDoor);
	}
	while(KvGotoNextKey(keyValues));
	
	CloseHandle(keyValues);
}
AddCommas(value, const String:seperator[], String:buffer[], bufferLen)
{
	buffer[0] = EOS;
	
	new divisor = 1000;
	while (value >= 1000 || value <= -1000)
	{
		new offcut = value % divisor;
		value = RoundToFloor(float(value) / float(divisor));
		Format(buffer, bufferLen, "%c%03.d%s", seperator, offcut, buffer);
	}
	Format(buffer, bufferLen, "%d%s", value, buffer);
}

stock CreateEmptyKvFile(const String:Path[])
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, Path);
	
	CloseHandle(keyValues);
}

stock bool:CanClientBreakHouse(client)
{
	new job = RP_GetClientJob(client);
	
	//if(job == g_iHouseBreakerJob)
		//return true;
		
	if(g_iHitmanJob == -1)
		g_iHitmanJob = RP_FindJobByShortName("HM");
		
		
	new String:JobShortName[32];
	
	RP_GetClientJobShortName(client, JobShortName, sizeof(JobShortName));

	if(CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM2))
		return true;

	else if(job == -1)
		return false;
		
	else if(RP_GetClientLevel(client, g_iHitmanJob) >= 8)
		return true;
		
	else if(RP_GetClientLevel(client, g_iHitmanJob) >= 5 && RP_GetClientLevel(client, job) >= 5)
		return true;
		
	else if(StrEqual(JobShortName, "PM", false) && ( RP_GetClientLevel(client, job) >= 1 || CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC) ))
		return true;
	
	else if(job == g_iHitmanJob)/* && RP_GetClientLevel(client, job) >= 0*/
		return true;
		
	return false;
}

stock RemoveArrayDuplicateCells(Handle:Array, slot)
{
	new count = 0;
	
	for(new i=0;i < GetArraySize(Array);i++)
	{
		if(i == slot)
			continue;
			
		if(GetArrayCell(Array, slot) == GetArrayCell(Array, i))
		{
			RemoveFromArray(Array, i);
			count++;
		}
	}
	
	return count;
}

stock bool:IsClientInsideHouse(client, entity, Door:door)
{
	new Float:Origin[3], Float:doorOrigin[3];	
	
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", doorOrigin);
	
	new Float:AngleVectors[3], Float:v[3];
	
	SubtractVectors(Origin, doorOrigin, v);
	GetVectorAngles(v, AngleVectors); 
	
	if(AngleVectors[1] > 180.0)
		AngleVectors[1] -= 180.0;
		
	new bool:IsInside = AngleVectors[1] > 90.0;
	
	if(door.IsInvertInside())
		IsInside = !IsInside;
		
	return IsInside;
}


stock bool:RentDoor_IsClientInsideHouse(client, entity, RentDoor:rDoor)
{
	new Float:Origin[3], Float:doorOrigin[3];	
	
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", Origin);
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", doorOrigin);
	
	new Float:AngleVectors[3], Float:v[3];
	
	SubtractVectors(Origin, doorOrigin, v);
	GetVectorAngles(v, AngleVectors); 
	
	if(AngleVectors[1] > 180.0)
		AngleVectors[1] -= 180.0;
		
	new bool:IsInside = AngleVectors[1] > 90.0;
	
	if(rDoor.IsInvertInside())
		IsInside = !IsInside;
		
	return IsInside;
}

stock EnforcePercentage(&percent)
{
	if(percent > 100)
		percent = 100;
		
	else if(percent < 0)
		percent = 0;
}

stock enDoorState GetDoorState(entity)
{
	
	if(!HasEntProp(entity, Prop_Data, "m_eDoorState"))
		return STATE_INVALID; 
		
	return view_as<enDoorState>(GetEntProp(entity, Prop_Data, "m_eDoorState"));
}