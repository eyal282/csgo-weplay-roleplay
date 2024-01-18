#include <autoexecconfig>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <Eyal-RP>

#define GANG_RENAME_PRICE 25000
#define GANG_PREFIX_PRICE 250000

#define SECONDS_IN_A_WEEK 604800

#define EF_BONEMERGE       (1 << 0)
#define EF_NOSHADOW        (1 << 4)
#define EF_NORECEIVESHADOW (1 << 6)
#define EF_PARENT_ANIMATES (1 << 9)

char NET_WORTH_ORDER_BY_FORMULA[512];

bool dbFullConnected = false;

int GangColors[][] = {
	{255, 0,  0  }, // red
	{ 0,  255, 0  }, // green
	{ 137, 209, 183}, // green כהה
	{ 4,  1,  254}, // Blue
	{ 194, 1,  254}, // perpol
	{ 194, 255, 254}, // d תכלת
	{ 75, 150, 102}, // d ירוק בהיר
	{ 47, 44, 16 }, // d חום
	{ 193, 168, 16 }, // d צהוב זהב
	{ 193, 103, 16 }, // d כתום
	{ 193, 103, 111}, // d pink
	{ 193, 36, 111}, // d pink כהה
	{ 193, 255, 111}, // d green כהה
	{ 253, 255, 111}, // d Yellow כהה
	{ 10, 107, 111}, // d תכלת כהה
	{ 126, 3,  0  }, // d חום חזק
	{ 126, 108, 170}, // d סגלגל
	{ 240, 156, 20 }, // d כתמתם
	{ 234, 30, 80 }, // d ורדורד
	{ 156, 120, 80 }, // d חםחם
	{ 156, 120, 229}, // d סגול פנים
	{ 156, 120, 229}, // d ורוד כהה
	{ 33, 120, 229}, // d כחלכל
	{ 33, 120, 7  }, // d ירקרק
	{ 254, 120, 7  }, // d כתום חזק
	{ 161, 207, 254}, // d תכלת חלש
	{ 254, 207, 254}, // d ורוד פוקסי
	{ 137, 147, 148}, // d אפור
	{ 252, 64, 100}, // d אדם דם
	{ 58, 64, 100}, // d אפור חלש
	{ 55, 51, 72 }, // d שחרחר
	{ 145, 127, 162}  // d סגל גל בהיר
};

Handle dbGangs = INVALID_HANDLE;

Handle fwClientLoaded     = INVALID_HANDLE;
Handle fwGangShieldLoaded = INVALID_HANDLE;
Handle fwClientKicked     = INVALID_HANDLE;
Handle fwGangDisbanded    = INVALID_HANDLE;

Handle Trie_Donated;
Handle Trie_DonatedWeek;

#define GANG_HEALTHCOST     7500
#define GANG_HEALTHMAX      5
#define GANG_HEALTHINCREASE 2

#define GANG_INITSIZE     2
#define GANG_SIZEINCREASE 1
#define GANG_SIZECOST     50000
#define GANG_SIZEMAX      7

#define GANG_LUCKINCREASE 2
#define GANG_LUCKCOST     250000
#define GANG_LUCKMAX      5

#define GANG_SHIELDINCREASE 2
#define GANG_SHIELDCOST     200000
#define GANG_SHIELDMAX      10

// Variables about the client's gang.

bool ClientSpyGang[MAXPLAYERS + 1];

char ClientGang[MAXPLAYERS + 1][32], ClientTag[MAXPLAYERS + 1][32], ClientPrefix[MAXPLAYERS + 1][32], ClientMotd[MAXPLAYERS + 1][192];
int ClientPrefixMethod[MAXPLAYERS + 1], ClientRank[MAXPLAYERS + 1];
bool  ClientLoadedFromDb[MAXPLAYERS + 1];

int ClientGangSizePerk[MAXPLAYERS + 1], ClientLuckPerk[MAXPLAYERS + 1], ClientShieldPerk[MAXPLAYERS + 1];

// ClientAccessManage basically means if the client can either invite, kick, upgrade, promote or MOTD.
int ClientAccessManage[MAXPLAYERS + 1], ClientAccessInvite[MAXPLAYERS + 1], ClientAccessKick[MAXPLAYERS + 1], ClientAccessPromote[MAXPLAYERS + 1], ClientAccessUpgrade[MAXPLAYERS + 1], ClientAccessMOTD[MAXPLAYERS + 1], ClientAccessManageMoney[MAXPLAYERS + 1], ClientAccessGiveKeys[MAXPLAYERS + 1];

// Extra Variables.

int GangStepDownTarget[MAXPLAYERS + 1],ClientGangCash[MAXPLAYERS + 1], ClientGangTax[MAXPLAYERS + 1], ClientGangNextWeekly[MAXPLAYERS + 1], ClientActionEdit[MAXPLAYERS + 1];
bool GangAttemptDonate[MAXPLAYERS + 1], GangAttemptLeave[MAXPLAYERS + 1], GangAttemptDisband[MAXPLAYERS + 1], GangAttemptStepDown[MAXPLAYERS + 1], MotdShown[MAXPLAYERS + 1];

char GangCreateName[MAXPLAYERS + 1][32], GangCreateTag[MAXPLAYERS + 1][10];
int ClientMembersCount[MAXPLAYERS + 1], ClientWhiteGlow[MAXPLAYERS + 1], ClientColorfulGlow[MAXPLAYERS + 1], ClientGlowColorSlot[MAXPLAYERS + 1]; // White glow is how gang members see themselves, colorful glow is how other players see gang members.
bool CachedSpawn[MAXPLAYERS + 1];    

int g_iThiefJob = -1;

Handle Array_GangIds = INVALID_HANDLE;

Handle hcv_CostCreate = INVALID_HANDLE;
Handle hcv_WeeklyTax  = INVALID_HANDLE;

char CvarCostCreateName[] = "rp_gang_cost_create";
char CvarCostWeekly[]     = "rp_gang_cost_weekly";

public Plugin myinfo =
{
	name        = "JB Gangs",
	author      = "Eyal282",
	description = "Gang System for JailBreak, ported into RolePlay",
	version     = "1.0",
	url         = "NULL"
};

public OnMapStart()
{
	CreateTimer(1.0, Timer_CheckWeekly, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(31.0, Timer_CheckWeekly, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action Timer_CheckWeekly(Handle hTimer)
{
	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT GangTag, GangCash FROM GangSystem_Gangs WHERE GangNextWeekly < %i", GetTime());
	SQL_TQuery(dbGangs, SQLCB_CheckWeekly, sQuery);
}

public SQLCB_CheckWeekly(Handle owner, Handle hndl, char[] error, any data)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	if (SQL_GetRowCount(hndl) == 0)
		return;

	while (SQL_FetchRow(hndl))
	{
		char GangTag[32];
		SQL_FetchString(hndl, 0, GangTag, sizeof(GangTag));

		Transaction transaction = SQL_CreateTransaction();

		char sQuery[256];
		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = GangCash - %i WHERE GangTag = '%s'", GetConVarInt(hcv_WeeklyTax), GangTag);
		SQL_AddQuery(transaction, sQuery);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangNextWeekly = %i WHERE GangTag = '%s'", GetTime() + SECONDS_IN_A_WEEK, GangTag);
		SQL_AddQuery(transaction, sQuery);

		Handle DP = CreateDataPack();

		WritePackString(DP, GangTag);

		SQL_ExecuteTransaction(dbGangs, transaction, SQLTrans_GangUpdated, INVALID_FUNCTION, DP, DBPrio_High);
	}
}

public OnPluginStart()
{
	char HostName[64];

	GetConVarString(FindConVar("hostname"), HostName, sizeof(HostName));

	// Format(NET_WORTH_ORDER_BY_FORMULA, sizeof(NET_WORTH_ORDER_BY_FORMULA), "GangCash");

	dbFullConnected = false;

	dbGangs = INVALID_HANDLE;

	ConnectDatabase();

	AddCommandListener(CommandListener_Say, "say");
	AddCommandListener(CommandListener_Say, "say_team");

	RegConsoleCmd("sm_renamegang", Command_RenameGang);
	RegConsoleCmd("sm_prefixgang", Command_PrefixGang);
	RegConsoleCmd("sm_gangmotd", Command_GangMotd);
	RegConsoleCmd("sm_gangtax", Command_GangTax);
	RegConsoleCmd("sm_creategang", Command_CreateGang);
	RegConsoleCmd("sm_gangtag", Command_CreateGangTag);
	RegConsoleCmd("sm_confirmleavegang", Command_LeaveGang);
	RegConsoleCmd("sm_confirmdisbandgang", Command_DisbandGang);
	RegConsoleCmd("sm_confirmstepdowngang", Command_StepDown);
	RegConsoleCmd("sm_gang", Command_Gang);
	RegAdminCmd("sm_testtt", Command_Testtt, ADMFLAG_ROOT);

	RegAdminCmd("sm_spygang", Command_SpyGang, ADMFLAG_ROOT, "Allows you to spy gang chats.");
	RegAdminCmd("sm_breachgang", Command_BreachGang, ADMFLAG_ROOT, "Breaches into a gang as a member.");
	RegAdminCmd("sm_breachgangrank", Command_BreachGangRank, ADMFLAG_ROOT, "Sets your rank within your gang.");

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_ping", Event_PlayerPingPre, EventHookMode_Pre);
	HookEvent("player_changename", Event_ChangeName, EventHookMode_Pre);

	// AddNormalSoundHook(SoundHook_FilterPingSound);
	Array_GangIds = CreateArray(32);

	fwClientLoaded     = CreateGlobalForward("On_Player_Loaded_Gang", ET_Ignore, Param_Cell, Param_Cell);
	fwClientKicked     = CreateGlobalForward("On_Player_Kicked_From_Gang", ET_Ignore, Param_Cell, Param_String);
	fwGangShieldLoaded = CreateGlobalForward("On_Gang_Shield_Loaded", ET_Ignore, Param_String, Param_Cell);
	fwGangDisbanded    = CreateGlobalForward("On_Gang_Disbanded", ET_Ignore, Param_String);

	hcv_CostCreate = CreateProtectedConVar(CvarCostCreateName, "100000");
	hcv_WeeklyTax  = CreateProtectedConVar(CvarCostWeekly, "100000");

	Trie_Donated     = CreateTrie();
	Trie_DonatedWeek = CreateTrie();

	// HandleGameData();
}

public Action Command_SpyGang(int client, int args)
{
	ClientSpyGang[client] = !ClientSpyGang[client];

	RP_PrintToChat(client, "You are no%s spying gang chats", ClientSpyGang[client] ? "w" : " longer");

	return Plugin_Handled;
}

public OnConfigsExecuted()
{
	Format(NET_WORTH_ORDER_BY_FORMULA, sizeof(NET_WORTH_ORDER_BY_FORMULA), "%i + GangCash + GangSizePerk*0.5*%i*(GangSizePerk+1) + GangLuckPerk*0.5*%i*(GangLuckPerk+1) + GangShieldPerk*0.5*%i*(GangShieldPerk+1)", GetConVarInt(hcv_CostCreate), GANG_SIZECOST, GANG_LUCKCOST, GANG_SHIELDCOST);
}

public OnAllPluginsLoaded()
{
	ServerCommand("sm_cvar protect %s", CvarCostCreateName);
	ServerCommand("sm_cvar protect %s", CvarCostWeekly);
}

public Action OnClientCommandKeyValues(client, KeyValues kv)
{
	char SectionName[32];

	if (KvGetSectionName(kv, SectionName, sizeof(SectionName)) && StrEqual(SectionName, "ClanTagChanged", false))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public OnLibraryAdded(const char[] name)
{
	/*
	#if defined _updater_included
	if (StrEqual(name, "updater"))
	{
	    Updater_AddPlugin(UPDATE_URL);
	}
	#endif
	*/
}

public OnPluginEnd()
{
	for (int i = 1; i < MAXPLAYERS + 1; i++)
	{
		TryDestroyGlow(i);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		TryRemoveGangPrefix(i);
	}
}

public Action Event_PlayerPingPre(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	if (GetEventBool(hEvent, "filtered_by_sourcemod_plugin"))
		return Plugin_Continue;

	int entity = GetEventInt(hEvent, "entityid");

	int owner = GetEntPropEnt(entity, Prop_Send, "m_hPlayer");

	if (owner == -1)
		return Plugin_Continue;

	else if (GetClientTeam(owner) != CS_TEAM_T)
		return Plugin_Continue;

	if (!IsClientGang(owner))
	{
		AcceptEntityInput(entity, "Kill");

		return Plugin_Handled;
	}

	SDKHook(entity, SDKHook_SetTransmit, SDKEvent_PingSetTransmit);
	/*
	Event hNewEvent = CreateEvent("cs_win_panel_round", true);

	SetEventInt(hNewEvent, "entityid", entity);
	SetEventInt(hNewEvent, "x", GetEventInt(hEvent, "x"));
	SetEventInt(hNewEvent, "y", GetEventInt(hEvent, "y"));
	SetEventInt(hNewEvent, "z", GetEventInt(hEvent, "z"));

	SetEventInt(hNewEvent, "urgent", GetEventInt(hEvent, "urgent"));

	SetEventBool(hNewEvent, "filtered_by_sourcemod_plugin", true);

	for (int i = 1; i <= MaxClients; i++)
	{
	    if (!IsClientInGame(i))
	        continue;

	    else if (GetClientTeam(i) == CS_TEAM_CT)
	        continue;

	    else if(!AreClientsSameGang(owner, i))
	        continue;

	    hNewEvent.FireToClient(i);
	}

	return Plugin_Handled;
	*/

	return Plugin_Continue;
}

public Action SDKEvent_PingSetTransmit(pingEntity, viewer)
{
	if (!IsPlayer(viewer))
		return Plugin_Continue;

	int owner = GetEntPropEnt(pingEntity, Prop_Send, "m_hPlayer");

	if (owner == -1)
		return Plugin_Continue;

	else if (!AreClientsSameGang(owner, viewer))
		return Plugin_Handled;

	return Plugin_Continue;
}
/*
public Action SoundHook_FilterPingSound(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if(!StrEqual(sample, "player/playerping.wav"))
        return Plugin_Continue;

    PrintToChatEyal("%i", entity);

    if(!IsPlayer(entity))
        return Plugin_Continue;

    if(entity == -1)
        return Plugin_Continue;

    else if(GetClientTeam(entity) != CS_TEAM_T)
        return Plugin_Continue;

    else if(!IsClientGang(entity))
        return Plugin_Stop;

    numClients = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        else if (GetClientTeam(i) == CS_TEAM_CT)
            continue;

        else if(!AreClientsSameGang(entity, i))
            continue;

        clients[numClients++] = i;
    }

    return Plugin_Changed;
}
*/
public Action Event_PlayerSpawn(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (client == 0)
		return;

	CachedSpawn[client] = false;
	RequestFrame(Event_PlayerSpawnPlusFrame, GetEventInt(hEvent, "userid"));

	if (ClientMotd[client][0] != EOS && !MotdShown[client])
	{
		PrintToChat(client, " \x01=======\x07GANG MOTD\x01=========");
		PrintToChat(client, " \x01[\x03%s\x01] %s", ClientGang[client], ClientMotd[client]);
		PrintToChat(client, " \x01=======\x07GANG MOTD\x01=========");
		MotdShown[client] = true;
	}
}

public Event_PlayerSpawnPlusFrame(UserId)
{
	int client = GetClientOfUserId(UserId);

	if (CachedSpawn[client])
		return;

	else if (!IsValidPlayer(client))
		return;

	else if (!IsPlayerAlive(client))
		return;

	else if (!IsClientGang(client))
		return;

	CachedSpawn[client] = true;

	TryDestroyGlow(client);
}

public Action Event_ChangeName(Handle hEvent, const char[] Name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (client == 0)
		return Plugin_Continue;

	else if (ClientPrefix[client][0] == EOS)
		return Plugin_Continue;

	char NewName[64];

	GetEventString(hEvent, "newname", NewName, sizeof(NewName));

	if (StrContains(NewName, ClientPrefix[client]) == 0)    // Client's name starts with the prefix.
		return Plugin_Continue;

	Format(NewName, sizeof(NewName), "%s%s", ClientPrefix[client], NewName);

	SetClientNameHidden(client, NewName);

	SetEventString(hEvent, "newname", NewName);

	SetEventBroadcast(hEvent, true);

	return Plugin_Changed;
}
/*
CreateGlow(client)
{
    if(EntRefToEntIndex(ClientWhiteGlow[client]) != INVALID_ENT_REFERENCE && EntRefToEntIndex(ClientColorfulGlow[client]) != INVALID_ENT_REFERENCE)
        return;

    if(ClientWhiteGlow[client] != 0 || ClientColorfulGlow[client] != 0)
    {
        TryDestroyGlow(client);
        ClientWhiteGlow[client] = 0;
        ClientColorfulGlow[client] = 0;
    }

    CreateWhiteGlow(client);

    CreateColorfulGlow(client);
}

CreateWhiteGlow(client)
{
    int String:Model[PLATFORM_MAX_PATH];
    int Float:Origin[3], Float:Angles[3];

    // Get the original model path
    GetEntPropString(client, Prop_Data, "m_ModelName", Model, sizeof(Model));

    // Find the location of the weapon
    GetClientEyePosition(client, Origin);
    Origin[2] -= 75.0;
    GetClientEyeAngles(client, Angles);
    int GlowEnt = CreateEntityByName("prop_dynamic_glow");

    DispatchKeyValue(GlowEnt, "model", Model);
    DispatchKeyValue(GlowEnt, "disablereceiveshadows", "1");
    DispatchKeyValue(GlowEnt, "disableshadows", "1");
    DispatchKeyValue(GlowEnt, "solid", "0");
    DispatchKeyValue(GlowEnt, "spawnflags", "256");
    DispatchKeyValue(GlowEnt, "renderamt", "0");
    SetEntProp(GlowEnt, Prop_Send, "m_CollisionGroup", 11);

    // Spawn and teleport the entity
    DispatchSpawn(GlowEnt);

    int fEffects = GetEntProp(GlowEnt, Prop_Send, "m_fEffects");
    SetEntProp(GlowEnt, Prop_Send, "m_fEffects", fEffects|EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_PARENT_ANIMATES);

    // Give glowing effect to the entity
    SetEntProp(GlowEnt, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(GlowEnt, Prop_Send, "m_nGlowStyle", 1);
    SetEntPropFloat(GlowEnt, Prop_Send, "m_flGlowMaxDist", 10000.0);

    // Set glowing color
    SetVariantColor({255, 255, 255, 255});
    AcceptEntityInput(GlowEnt, "SetGlowColor");

    // Set the activator and group the entity
    SetVariantString("!activator");
    AcceptEntityInput(GlowEnt, "SetParent", client);

    SetVariantString("primary");
    AcceptEntityInput(GlowEnt, "SetParentAttachment", GlowEnt, GlowEnt, 0);

    AcceptEntityInput(GlowEnt, "TurnOn");

    SetEntPropEnt(GlowEnt, Prop_Send, "m_hOwnerEntity", client);

    int String:iName[32];

    FormatEx(iName, sizeof(iName), "Gang-Glow %i", GetClientUserId(client));
    SetEntPropString(GlowEnt, Prop_Data, "m_iName", iName);

    SDKHook(GlowEnt, SDKHook_SetTransmit, Hook_ShouldSeeWhiteGlow);

    CreateTimer(0.1, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.3, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.5, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(1.0, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(1.1, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);

    ClientWhiteGlow[client] = GlowEnt;
}


CreateColorfulGlow(client)
{
    int String:Model[PLATFORM_MAX_PATH];
    int Float:Origin[3], Float:Angles[3];

    // Get the original model path
    GetEntPropString(client, Prop_Data, "m_ModelName", Model, sizeof(Model));

    // Find the location of the weapon
    GetClientEyePosition(client, Origin);
    Origin[2] -= 75.0;
    GetClientEyeAngles(client, Angles);
    int GlowEnt = CreateEntityByName("prop_dynamic_glow");

    DispatchKeyValue(GlowEnt, "model", Model);
    DispatchKeyValue(GlowEnt, "disablereceiveshadows", "1");
    DispatchKeyValue(GlowEnt, "disableshadows", "1");
    DispatchKeyValue(GlowEnt, "solid", "0");
    DispatchKeyValue(GlowEnt, "spawnflags", "256");
    DispatchKeyValue(GlowEnt, "renderamt", "0");
    SetEntProp(GlowEnt, Prop_Send, "m_CollisionGroup", 11);

    // Spawn and teleport the entity
    DispatchSpawn(GlowEnt);

    int fEffects = GetEntProp(GlowEnt, Prop_Send, "m_fEffects");
    SetEntProp(GlowEnt, Prop_Send, "m_fEffects", fEffects|EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_PARENT_ANIMATES);

    // Give glowing effect to the entity
    SetEntProp(GlowEnt, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(GlowEnt, Prop_Send, "m_nGlowStyle", 1);
    SetEntPropFloat(GlowEnt, Prop_Send, "m_flGlowMaxDist", 10000.0);

    // Set glowing color

    int VarColor[4] = {255, 255, 255, 255};

    for(int i=0;i < 3;i++)
    {
        VarColor[i] = GangColors[ClientGlowColorSlot[client]][i];
    }

    SetVariantColor(VarColor);
    AcceptEntityInput(GlowEnt, "SetGlowColor");

    // Set the activator and group the entity
    SetVariantString("!activator");
    AcceptEntityInput(GlowEnt, "SetParent", client);

    SetVariantString("primary");
    AcceptEntityInput(GlowEnt, "SetParentAttachment", GlowEnt, GlowEnt, 0);

    AcceptEntityInput(GlowEnt, "TurnOn");

    SetEntPropEnt(GlowEnt, Prop_Send, "m_hOwnerEntity", client);

    int String:iName[32];

    FormatEx(iName, sizeof(iName), "Gang-Glow %i", GetClientUserId(client));
    SetEntPropString(GlowEnt, Prop_Data, "m_iName", iName);

    SDKHook(GlowEnt, SDKHook_SetTransmit, Hook_ShouldSeeColorfulGlow);

    CreateTimer(0.1, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.3, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(0.5, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(1.0, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(1.1, Timer_CheckGlowPlayerModel, EntIndexToEntRef(GlowEnt), TIMER_FLAG_NO_MAPCHANGE);

    ClientColorfulGlow[client] = GlowEnt;
}

public Action:Timer_CheckGlowPlayerModel(Handle:hTimer, Ref)
{
    int GlowEnt = EntRefToEntIndex(Ref);

    if(GlowEnt == INVALID_ENT_REFERENCE)
        return;

    int client = GetEntPropEnt(GlowEnt, Prop_Send, "m_hOwnerEntity");

    if(client == -1)
        return;

    int String:Model[PLATFORM_MAX_PATH];

    // Get the original model path
    GetEntPropString(client, Prop_Data, "m_ModelName", Model, sizeof(Model));

    SetEntityModel(GlowEnt, Model);
}

public Action:Hook_ShouldSeeWhiteGlow(glow, viewer)
{
    if(!IsValidEntity(glow))
        return Plugin_Continue;

    int client = GetEntPropEnt(glow, Prop_Send, "m_hOwnerEntity");

    if(client == viewer)
        return Plugin_Handled;

    else if(!AreClientsSameGang(client, viewer))
        return Plugin_Handled;

    else if(GetClientTeam(viewer) != GetClientTeam(client))
        return Plugin_Handled;

    int ObserverTarget = GetEntPropEnt(viewer, Prop_Send, "m_hObserverTarget"); // This is the player the viewer is spectating. No need to check if it's invalid ( -1 )

    if(ObserverTarget == client)
        return Plugin_Handled;

    return Plugin_Continue;
}


public Action:Hook_ShouldSeeColorfulGlow(glow, viewer)
{
    if(!IsValidEntity(glow))
        return Plugin_Continue;

    int client = GetEntPropEnt(glow, Prop_Send, "m_hOwnerEntity");

    if(AreClientsSameGang(client, viewer))
        return Plugin_Handled;

    int ObserverTarget = GetEntPropEnt(viewer, Prop_Send, "m_hObserverTarget"); // This is the player the viewer is spectating. No need to check if it's invalid ( -1 )

    if(ObserverTarget == client)
        return Plugin_Handled;

    return Plugin_Continue;
}
*/
TryDestroyGlow(client)
{
	if (ClientWhiteGlow[client] != 0 && IsValidEntity(ClientWhiteGlow[client]))
	{
		AcceptEntityInput(ClientWhiteGlow[client], "Kill");
		ClientWhiteGlow[client] = 0;
	}

	if (ClientColorfulGlow[client] != 0 && IsValidEntity(ClientColorfulGlow[client]))
	{
		AcceptEntityInput(ClientColorfulGlow[client], "Kill");
		ClientColorfulGlow[client] = 0;
	}

	int ent = -1;    // Some bugs don't fix themselves...

	while ((ent = FindEntityByClassname(ent, "prop_dynamic_glow")) != -1)
	{
		char iName[32];
		GetEntPropString(ent, Prop_Data, "m_iName", iName, sizeof(iName));

		if (strncmp(iName, "Gang-Glow", 9) != 0)
			continue;

		char dummy_value[1], sUserId[11];
		int pos;
		pos = BreakString(iName, dummy_value, 0);

		BreakString(iName[pos], sUserId, sizeof(sUserId));

		int i = GetClientOfUserId(StringToInt(sUserId));

		if (i == 0 || !IsPlayerAlive(i) || i == client)
		{
			AcceptEntityInput(ent, "Kill");
		}
	}
}

public OnClientSettingsChanged(client)
{
	if (IsClientInGame(client))
	{
		StoreClientLastInfo(client);
	}
}

public ConnectDatabase()
{
	char error[256];

	Handle hndl = SQL_Connect("eyal_rp", true, error, 255);

	if (hndl == INVALID_HANDLE)
	{
		LogError("Could not connect [SQL]: %s", error);
	}
	else
	{
		dbGangs = hndl;

		SQL_TQuery(dbGangs, SQLCB_Error, "CREATE TABLE IF NOT EXISTS GangSystem_Members (GangTag VARCHAR(32) NOT NULL, AuthId VARCHAR(32) NOT NULL UNIQUE, GangRank INT(20) NOT NULL, LastName VARCHAR(64) NOT NULL, GangInviter VARCHAR(32) NOT NULL, GangJoinDate INT(20) NOT NULL, LastConnect INT(20) NOT NULL)", 0, DBPrio_High);
		SQL_TQuery(dbGangs, SQLCB_Error, "CREATE TABLE IF NOT EXISTS GangSystem_Gangs (GangName VARCHAR(32) NOT NULL UNIQUE, GangTag VARCHAR(10) NOT NULL UNIQUE, GangMotd VARCHAR(192) NOT NULL, GangCash INT(20) NOT NULL, GangSizePerk INT(20) NOT NULL)", 1, DBPrio_High);
		SQL_TQuery(dbGangs, SQLCB_Error, "CREATE TABLE IF NOT EXISTS GangSystem_Donations (GangTag VARCHAR(32) NOT NULL, AuthId VARCHAR(32) NOT NULL, AmountDonated INT(11), timestamp INT(32))", 1, DBPrio_High);

		/*
		    Table GangSystem_Gangs ( ORDER NOT GUARANTEED!!! Use SQL_FetchIntByName over SQL_FetchInt!!! )
		    GangName VARCHAR(32) NOT NULL UNIQUE,
		    GangTag VARCHAR(10) NOT NULL UNIQUE
		    GangMotd VARCHAR(100) NOT NULL,
		    GangCash INT(20) NOT NULL,
		    GangSizePerk INT(20) NOT NULL,
		    GangLuckPerk INT(20) NOT NULL,
		    GangShieldPerk INT(20) NOT NULL,
		    GangMinRankInvite INT(11) NOT NULL,
		    GangMinRankKick INT(11) NOT NULL,
		    GangMinRankUpgrade INT(11) NOT NULL,
		    GangMinRankManageMoney INT(11) NOT NULL,
		    GangMinRankGiveKeys INT(11) NOT NULL,
		    GangMinRankMOTD INT(11) NOT NULL,
		    GangNextWeekly INT(11) NOT NULL,
		    GangMemberTax INT(11) NOT NULL,
		*/
		SQL_TQuery(dbGangs, SQLCB_Error, "CREATE TABLE IF NOT EXISTS GangSystem_upgradelogs (GangTag VARCHAR(32) NOT NULL, AuthId VARCHAR(32) NOT NULL, Perk VARCHAR(32) NOT NULL, BValue INT NOT NULL, AValue INT NOT NULL, timestamp INT NOT NULL)", 3, DBPrio_High);

		char sQuery[512];

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Members DROP COLUMN GangName");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Members DROP COLUMN GangDonated");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Members ADD COLUMN GangTag VARCHAR(32) NOT NULL DEFAULT 'NULL'");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangMinRankInvite INT(11) NOT NULL DEFAULT %i", RANK_OFFICER);
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangMinRankKick INT(11) NOT NULL DEFAULT %i", RANK_OFFICER);
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangMinRankPromote INT(11) NOT NULL DEFAULT %i", RANK_MANAGER);
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangMinRankUpgrade INT(11) NOT NULL DEFAULT %i", RANK_COLEADER);
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangMinRankMOTD INT(11) NOT NULL DEFAULT %i", RANK_MANAGER);
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangFFPerk INT(11) NOT NULL DEFAULT 0");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangLuckPerk INT(11) NOT NULL DEFAULT 0");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangShieldPerk INT(11) NOT NULL DEFAULT 0");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangNextWeekly INT(11) NOT NULL DEFAULT 0");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangMemberTax INT(11) NOT NULL DEFAULT 0");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangMinRankManageMoney INT(11) NOT NULL DEFAULT %i", RANK_LEADER);
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangMinRankGiveKeys INT(11) NOT NULL DEFAULT %i", RANK_LEADER);
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangPrefix VARCHAR(32) NOT NULL DEFAULT ''", RANK_LEADER);
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_Gangs ADD COLUMN GangPrefixMethod INT(6) NOT NULL DEFAULT 0");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_upgradelogs DROP COLUMN GangName");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "ALTER TABLE GangSystem_upgradelogs ADD COLUMN GangTag VARCHAR(32) NOT NULL DEFAULT 'NULL'");
		SQL_TQuery(dbGangs, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);

		dbFullConnected = true;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsValidPlayer(i))
				continue;

			else if (!IsClientAuthorized(i))
				continue;

			LoadClientGang(i);
		}
	}
}

public SQLCB_Error(Handle owner, Handle hndl, const char[] error, int QueryUniqueID)
{
	/* If something fucked up. */
	if (hndl == null)
		LogError("%s --> %i", error, QueryUniqueID);
}

public SQLCB_ErrorIgnore(Handle owner, Handle hndl, const char[] error, int QueryUniqueID)
{
}

public OnClientPutInServer(client)
{
	//	DHookEntity(DHook_PlayerMaxSpeed, true, client);

	ClientWhiteGlow[client]    = 0;
	ClientColorfulGlow[client] = 0;

	ClientSpyGang[client] = false;
}

public OnClientConnected(client)
{
	ResetVariables(client, true);
}

// Doesn't reset prefix yet!

void ResetVariables(int client, bool login = true)
{
	ClientAccessManage[client]      = RANK_LEADER;
	ClientAccessInvite[client]      = RANK_LEADER;
	ClientAccessKick[client]        = RANK_LEADER;
	ClientAccessPromote[client]     = RANK_LEADER;
	ClientAccessUpgrade[client]     = RANK_LEADER;
	ClientAccessMOTD[client]        = RANK_LEADER;
	ClientAccessManageMoney[client] = RANK_LEADER;
	ClientAccessGiveKeys[client]    = RANK_LEADER;

	ClientGlowColorSlot[client] = -1;

	ClientGangCash[client]       = 0;
	ClientGangNextWeekly[client] = 0;

	if (login)
	{
		GangAttemptLeave[client]    = false;
		GangAttemptDisband[client]  = false;
		GangAttemptStepDown[client] = false;
		GangStepDownTarget[client]  = -1;
		ClientGang[client]          = GANG_NULL;
		ClientRank[client]          = RANK_NULL;
	}
	ClientMotd[client]         = "";
	ClientTag[client]          = "";
	ClientPrefixMethod[client] = 0;
	ClientLoadedFromDb[client] = false;
}

public OnClientDisconnect(client)
{
	char AuthId[35], Name[64];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	Format(Name, sizeof(Name), "%N", client);

	StoreAuthIdLastInfo(AuthId, Name);    // Safer

	TryDestroyGlow(client);

	if (!IsClientGang(client))
		return;

	bool gangDisconnected = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (client == i)
			continue;

		else if (AreClientsSameGang(client, i))
		{
			gangDisconnected = false;
			break;
		}
	}

	if (gangDisconnected)
	{
		int pos = FindStringInArray(Array_GangIds, ClientTag[client]);

		if (pos != -1)
			RemoveFromArray(Array_GangIds, pos);
	}
}

public OnClientPostAdminCheck(client)
{
	if (!dbFullConnected)
		return;

	MotdShown[client] = false;

	LoadClientGang(client);
}

LoadClientGang(client, LowPrio = false)
{
	char AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Members WHERE AuthId = '%s'", AuthId);

	if (!LowPrio)
		SQL_TQuery(dbGangs, SQLCB_LoadClientGang, sQuery, GetClientUserId(client));

	else
		SQL_TQuery(dbGangs, SQLCB_LoadClientGang, sQuery, GetClientUserId(client), DBPrio_Low);
}

public SQLCB_LoadClientGang(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	int client = GetClientOfUserId(data);
	if (client == 0)
	{
		return;
	}
	else
	{
		StoreClientLastInfo(client);

		if (SQL_GetRowCount(hndl) != 0)
		{
			SQL_FetchRow(hndl);

			DBResultSet query = view_as<DBResultSet>(hndl);

			SQL_FetchStringByName(query, "GangTag", ClientTag[client], sizeof(ClientTag[]));
			ClientRank[client] = SQL_FetchIntByName(query, "GangRank");

			for (int  i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;

				if (client == i)
					continue;

				if (!AreClientsSameGang(client, i))
					continue;

				ClientGlowColorSlot[client] = ClientGlowColorSlot[i];
			}

			if (ClientGlowColorSlot[client] == -1)
			{
				for (int i = 0; i < sizeof(GangColors); i++)
				{
					bool glowTaken = false;

					for (int compareClient = 1; compareClient <= MaxClients; compareClient++)
					{
						if (!IsClientInGame(compareClient))
							continue;

						else if (!IsClientGang(compareClient))
							continue;

						if (ClientGlowColorSlot[compareClient] == i)
						{
							glowTaken = true;
						}
					}

					if (!glowTaken)
					{
						ClientGlowColorSlot[client] = i;

						break;
					}
				}
			}
			char sQuery[256];

			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Gangs WHERE GangTag = '%s'", ClientTag[client]);
			SQL_TQuery(dbGangs, SQLCB_LoadGangByClient, sQuery, GetClientUserId(client), DBPrio_High);
		}
		else
		{
			ClientLoadedFromDb[client] = true;
			ClientPrefix[client]       = "";

			if (IsPlayerAlive(client))
				TryDestroyGlow(client);
		}
	}
}

public SQLCB_LoadGangByClient(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	int client = GetClientOfUserId(data);
	if (client == 0)
	{
		return;
	}
	else
	{
		if (SQL_GetRowCount(hndl) != 0)
		{
			SQL_FetchRow(hndl);

			DBResultSet query = view_as<DBResultSet>(hndl);

			SQL_FetchStringByName(query, "GangName", ClientGang[client], sizeof(ClientGang[]));
			SQL_FetchStringByName(query, "GangTag", ClientTag[client], sizeof(ClientTag[]));
			SQL_FetchStringByName(query, "GangMotd", ClientMotd[client], sizeof(ClientMotd[]));

			TryRemoveGangPrefix(client);

			char Name[64];

			GetClientName(client, Name, sizeof(Name));

			SQL_FetchStringByName(query, "GangPrefix", ClientPrefix[client], sizeof(ClientPrefix[]));
			ClientPrefixMethod[client] = SQL_FetchIntByName(query, "GangPrefixMethod");

			if (ClientPrefixMethod[client] == 0 && ClientPrefix[client][0] != EOS)
			{
				Format(ClientPrefix[client], sizeof(ClientPrefix[]), "[%s] ", ClientPrefix[client]);
			}

			if (ClientPrefix[client][0] != EOS)
			{
				Format(Name, sizeof(Name), "%s%s", ClientPrefix[client], Name);

				SetClientNameHidden(client, Name);
			}

			ClientGangCash[client] = SQL_FetchIntByName(query, "GangCash");

			if (ClientGangCash[client] >= 0)
			{
				ClientGangSizePerk[client] = SQL_FetchIntByName(query, "GangSizePerk");
				ClientLuckPerk[client]     = SQL_FetchIntByName(query, "GangLuckPerk");
				ClientShieldPerk[client]   = SQL_FetchIntByName(query, "GangShieldPerk");
			}

			
	
			Call_StartForward(fwGangShieldLoaded);

			Call_PushString(ClientTag[client]);
			Call_PushCell(ClientShieldPerk[client] * GANG_SHIELDINCREASE);

			Call_Finish();

			ClientAccessInvite[client]      = SQL_FetchIntByName(query, "GangMinRankInvite");
			ClientAccessKick[client]        = SQL_FetchIntByName(query, "GangMinRankKick");
			ClientAccessPromote[client]     = SQL_FetchIntByName(query, "GangMinRankPromote");
			ClientAccessManageMoney[client] = SQL_FetchIntByName(query, "GangMinRankManageMoney");
			ClientAccessGiveKeys[client]    = SQL_FetchIntByName(query, "GangMinRankGiveKeys");
			ClientAccessUpgrade[client]     = SQL_FetchIntByName(query, "GangMinRankUpgrade");
			ClientAccessMOTD[client]        = SQL_FetchIntByName(query, "GangMinRankMOTD");
			ClientGangNextWeekly[client]    = SQL_FetchIntByName(query, "GangNextWeekly");
			ClientGangTax[client]           = SQL_FetchIntByName(query, "GangMemberTax");

			int Smallest = ClientAccessInvite[client];

			if (ClientAccessKick[client] < Smallest)
				Smallest = ClientAccessKick[client];

			if (ClientAccessPromote[client] < Smallest)
				Smallest = ClientAccessPromote[client];

			if (ClientAccessUpgrade[client] < Smallest)
				Smallest = ClientAccessUpgrade[client];

			if (ClientAccessMOTD[client] < Smallest)
				Smallest = ClientAccessMOTD[client];

			if (ClientAccessManageMoney[client] < Smallest)
				Smallest = ClientAccessManageMoney[client];

			if (ClientAccessGiveKeys[client] < Smallest)
				Smallest = ClientAccessGiveKeys[client];
			ClientAccessManage[client] = Smallest;

			// if(IsPlayerAlive(client))
			// CreateGlow(client);

			char sQuery[256];
			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Members WHERE GangTag = '%s'", ClientTag[client]);

			SQL_TQuery(dbGangs, SQLCB_CheckMemberCount, sQuery, GetClientUserId(client));

			ClientLoadedFromDb[client] = true;

			if (FindStringInArray(Array_GangIds, ClientTag[client]) == -1)
				PushArrayString(Array_GangIds, ClientTag[client]);

			Call_StartForward(fwClientLoaded);

			Call_PushCell(client);
			Call_PushCell(GetClientGangId(client));

			Call_Finish();
		}
		else    // Gang was deleted
		{
			char AuthId[35];
			GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

			KickAuthIdFromGang(AuthId, ClientTag[client]);

			ClientGang[client] = GANG_NULL;

			ClientPrefix[client] = "";

			if (IsPlayerAlive(client))
				TryDestroyGlow(client);

			ClientLoadedFromDb[client] = true;
		}
	}
}

stock KickClientFromGang(int client, const char[] GangTag)
{
	char AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	KickAuthIdFromGang(AuthId, GangTag);
}

stock KickAuthIdFromGang(const char[] AuthId, const char[] GangTag)
{
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "DELETE FROM GangSystem_Members WHERE AuthId = '%s' AND GangTag = '%s'", AuthId, GangTag);
	SQL_TQuery(dbGangs, SQLCB_Error, sQuery, 5);

	int client = FindClientByAuthId(AuthId);

	if (client != 0)
	{
		TryRemoveGangPrefix(client);

		Call_StartForward(fwClientKicked);

		Call_PushCell(client);
		Call_PushString(GangTag);

		Call_Finish();
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		else if (!StrEqual(ClientTag[i], GangTag, true))
			continue;

		ResetVariables(i);

		LoadClientGang(i);
	}

	UpdateInGameAuthId(AuthId);
}

public DonateGang_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Select)
	{
		if (!IsClientGang(client))
			return;

		if (item + 1 == 1)
		{
			char strAmount[20], strIgnoreable[1];
			int amount;
			GetMenuItem(hMenu, item, strAmount, sizeof(strAmount), amount, strIgnoreable, 0);

			amount = StringToInt(strAmount);
			DonateToGang(client, amount);
		}
	}
}

public Action CommandListener_Say(int client, const char[] command, int args)
{
	if (!IsValidPlayer(client))
		return Plugin_Continue;

	else if (!IsClientGang(client))
		return Plugin_Continue;

	char sArgs[256];
	GetCmdArgString(sArgs, sizeof(sArgs));
	StripQuotes(sArgs);

	if (GangAttemptDonate[client])
	{
		GangAttemptDonate[client] = false;

		int amount = StringToInt(sArgs);

		if (amount < 1000)
		{
			RP_PrintToChat(client, "Minimum amount to donate is $1,000");
			return Plugin_Stop;
		}
		if (!IsStringNumber(sArgs) || sArgs[0] == EOS || amount <= 0)
		{
			RP_PrintToChat(client, "Invalid amount! Operation canceled.");
			return Plugin_Stop;
		}
		else if (amount > GetClientCash(client, BANK_CASH))
		{
			RP_PrintToChat(client, "\x05You \x01cannot donate more cash than you \x07have.");
			return Plugin_Stop;
		}
		Handle hMenu = CreateMenu(DonateGang_MenuHandler);

		AddMenuItem(hMenu, sArgs, "Yes");
		AddMenuItem(hMenu, "", "No");

		RP_SetMenuTitle(hMenu, "Gang Donation\n\nAre you sure you want to donate $%i?", amount);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

		return Plugin_Stop;
	}

	if (sArgs[0] == '~' || sArgs[0] == '#' || sArgs[0] == '$')
	{
		char FirstChar[3];
		FormatEx(FirstChar, sizeof(FirstChar), "%c%s", sArgs[0], sArgs[1] == ' ' ? " " : "");
		ReplaceStringEx(sArgs, sizeof(sArgs), FirstChar, "");

		if (sArgs[0] == EOS)
		{
			RP_PrintToChat(client, "\x01Gang message cannot be \x07empty.");
			return Plugin_Stop;
		}
		char RankName[32];
		GetRankName(GetClientRank(client), RankName, sizeof(RankName));

		PrintToChatGang(ClientGang[client], "\x04[Gang Chat] \x05%s \x04%N\x01 : %s", RankName, client, sArgs);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			if (ClientSpyGang[i])
				PrintToChat(i, " \x04[\x05Spy Gang Chat\x01] \x05%s \x04%N\x01 : %s", RankName, client, sArgs);
		}
		return Plugin_Stop;
	}

	RequestFrame(ListenerSayPlusFrame, GetClientUserId(client));
	return Plugin_Continue;
}

public ListenerSayPlusFrame(UserId)
{
	int client = GetClientOfUserId(UserId);

	if (IsClientGang(client))
	{
		if (GangAttemptDisband[client] || GangAttemptLeave[client] || GangAttemptStepDown[client])
			RP_PrintToChat(client, "The operation has been \x07aborted!");

		GangAttemptDisband[client]  = false;
		GangAttemptLeave[client]    = false;
		GangAttemptStepDown[client] = false;
		GangStepDownTarget[client]  = -1;
	}
}

public Action Command_GangMotd(int client, int args)
{
	if (!IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to be in a gang to use this \x07command!");
		return Plugin_Handled;
	}
	else if (!CheckGangAccess(client, ClientAccessMOTD[client]))
	{
		char RankName[32];
		GetRankName(ClientAccessMOTD[client], RankName, sizeof(RankName));
		RP_PrintToChat(client, "\x05You \x01have to be a gang \x07%s \x01to use this \x07command!", RankName);
		return Plugin_Handled;
	}

	char Args[100];
	GetCmdArgString(Args, sizeof(Args));
	StripQuotes(Args);

	if (StringHasInvalidCharacters(Args))
	{
		RP_PrintToChat(client, "Invalid motd! \x05You \x01can only use \x07SPACEBAR, \x07a-z, A-Z\x01, _, -, \x070-9");
		return Plugin_Handled;
	}
	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangMotd = '%s' WHERE GangTag = '%s'", Args, ClientTag[client]);

	SQL_TQuery(dbGangs, SQLCB_Error, sQuery, 6);

	RP_PrintToChat(client, "The gang's motd has been changed to \x07%s", Args);

	return Plugin_Handled;
}

public Action Command_GangTax(int client, int args)
{
	if (!IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to be in a gang to use this \x07command!");
		return Plugin_Handled;
	}

	else if (!CheckGangAccess(client, ClientAccessManageMoney[client]))
	{
		char RankName[32];
		GetRankName(ClientAccessManageMoney[client], RankName, sizeof(RankName));
		RP_PrintToChat(client, "\x05You \x01have to be a gang \x07%s \x01to use this \x07command!", RankName);
		return Plugin_Handled;
	}

	char Args[11];
	GetCmdArgString(Args, sizeof(Args));
	StripQuotes(Args);

	int tax = StringToInt(Args);

	if (tax < 0 || tax > 25)
	{
		RP_PrintToChat(client, "\x05Gang tax must be between 0 and 25%%");
		return Plugin_Handled;
	}

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangMemberTax = %i WHERE GangTag = '%s'", tax, ClientTag[client]);

	SQL_TQuery(dbGangs, SQLCB_Error, sQuery, 6);

	PrintToChatGang(ClientGang[client], "The gang's tax has been changed to \x07%i", tax);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (AreClientsSameGang(client, i))
			LoadClientGang(client, true);
	}

	return Plugin_Handled;
}

public Action Command_RenameGang(int client, int args)
{
	if (!IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to be in a \x07gang \x01to use this command!");
		return Plugin_Handled;
	}
	else if (!CheckGangAccess(client, RANK_LEADER))
	{
		RP_PrintToChat(client, "\x05You \x01have to be the gang's leader to use this \x07command!");
		return Plugin_Handled;
	}

	char Args[32];
	GetCmdArgString(Args, sizeof(Args));
	StripQuotes(Args);

	if (Args[0] == EOS)
	{
		RP_PrintToChat(client, "Invalid Usage! \x07!renamegang \x01<int name>");
		return Plugin_Handled;
	}
	else if (StringHasInvalidCharacters(Args))
	{
		RP_PrintToChat(client, "Invalid name! \x05You \x01can only use \x07a-z, A-Z\x01, _, -, \x070-9!");
		return Plugin_Handled;
	}
	Handle hMenu = CreateMenu(RenameGang_MenuHandler);

	AddMenuItem(hMenu, Args, "Yes");
	AddMenuItem(hMenu, "", "No");

	RP_SetMenuTitle(hMenu, "Gang Rename\n\nAre you sure you want to pay $%i to rename your gang?\nint Name: %s", GANG_RENAME_PRICE, Args);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public RenameGang_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Select)
	{
		if (!IsClientGang(client))
			return;

		else if (!CheckGangAccess(client, RANK_LEADER))
			return;

		if (item + 1 == 1)
		{
			if (ClientGangCash[client] < GANG_RENAME_PRICE)
			{
				char sPriceDifference[16];

				AddCommas(GANG_RENAME_PRICE - ClientGangCash[client], ",", sPriceDifference, sizeof(sPriceDifference));

				RP_PrintToChat(client, "\x05You \x01need \x07$%s more\x01 to rename your gang!", sPriceDifference);
				return;
			}

			char strName[32];
			GetMenuItem(hMenu, item, strName, sizeof(strName));

			Handle DP = CreateDataPack();
			WritePackCell(DP, GetClientUserId(client));
			WritePackString(DP, strName);

			char sQuery[256];
			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Gangs WHERE lower(GangName) = lower('%s')", strName);

			// Normal prio on check taken and high on change ensures if there is a check taken for anything else, it won't allow two gangs with same name.
			SQL_TQuery(dbGangs, SQLCB_RenameGang_CheckTakenName, sQuery, DP);
		}
	}
}

public SQLCB_RenameGang_CheckTakenName(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	ResetPack(DP);

	int client = GetClientOfUserId(ReadPackCell(DP));
	char GangName[32];

	ReadPackString(DP, GangName, sizeof(GangName));

	CloseHandle(DP);

	if (!IsValidPlayer(client))
	{
		return;
	}
	else
	{
		if (SQL_GetRowCount(hndl) == 0)
		{
			PrintToChatGang(ClientGang[client], "The gang was renamed to\x07 %s\x01!", GangName);

			DP = CreateDataPack();

			WritePackString(DP, ClientTag[client]);

			char sQuery[256];

			Transaction transaction = SQL_CreateTransaction();

			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangName = '%s' WHERE GangTag = '%s'", GangName, ClientTag[client]);
			SQL_AddQuery(transaction, sQuery);

			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = GangCash - %i WHERE GangTag = '%s'", GANG_RENAME_PRICE, ClientTag[client]);
			SQL_AddQuery(transaction, sQuery);

			SQL_ExecuteTransaction(dbGangs, transaction, SQLTrans_GangUpdated, INVALID_FUNCTION, DP, DBPrio_High);
		}
		else    // Gang name is taken.
		{
			RP_PrintToChat(client, "The selected gang name is \x07already \x01taken!");
		}
	}
}

public Action Command_PrefixGang(int client, int args)
{
	if (!IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to be in a \x07gang \x01to use this command!");
		return Plugin_Handled;
	}
	else if (!CheckGangAccess(client, RANK_LEADER))
	{
		RP_PrintToChat(client, "\x05You \x01have to be the gang's leader to use this \x07command!");
		return Plugin_Handled;
	}

	char Args[32];
	GetCmdArgString(Args, sizeof(Args));
	StripQuotes(Args);

	if (Args[0] == EOS)
	{
		RP_PrintToChat(client, "Invalid Usage! \x07!prefixgang \x01<new prefix>");
		return Plugin_Handled;
	}
	else if (StringHasInvalidCharacters(Args))
	{
		RP_PrintToChat(client, "Invalid prefix! \x05You \x01can only use \x07a-z, A-Z\x01, _, -, \x070-9!");
		return Plugin_Handled;
	}
	else if (strlen(Args) < 3 || strlen(Args) > 5)
	{
		RP_PrintToChat(client, "Invalid prefix! \x05You \x01can only use\x03\x01 to\x03 5\x01 characters!");

		return Plugin_Handled;
	}
	Handle hMenu = CreateMenu(PrefixGang_MenuHandler);

	AddMenuItem(hMenu, Args, "Yes");
	AddMenuItem(hMenu, "", "No");

	RP_SetMenuTitle(hMenu, "Gang Prefix Change\n\nAre you sure you want to pay $%i to change your gang's prefix?\nNew Prefix: %s", GANG_PREFIX_PRICE, Args);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public PrefixGang_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Select)
	{
		if (!IsClientGang(client))
			return;

		else if (!CheckGangAccess(client, RANK_LEADER))
			return;

		if (item + 1 == 1)
		{
			if (ClientGangCash[client] < GANG_PREFIX_PRICE)
			{
				char sPriceDifference[16];

				AddCommas(GANG_PREFIX_PRICE - ClientGangCash[client], ",", sPriceDifference, sizeof(sPriceDifference));

				RP_PrintToChat(client, "\x05You \x01need \x07$%s more\x01 to change your gang's prefix!", sPriceDifference);
				return;
			}

			char strName[32];
			GetMenuItem(hMenu, item, strName, sizeof(strName));

			Handle DP = CreateDataPack();
			WritePackCell(DP, GetClientUserId(client));
			WritePackString(DP, strName);

			char sQuery[256];
			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Gangs WHERE lower(GangPrefix) = lower('%s')", strName);

			// Normal prio on check taken and high on change ensures if there is a check taken for anything else, it won't allow two gangs with same name.
			SQL_TQuery(dbGangs, SQLCB_GangPrefix_CheckTakenPrefix, sQuery, DP);
		}
	}
}

public SQLCB_GangPrefix_CheckTakenPrefix(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	ResetPack(DP);

	int client = GetClientOfUserId(ReadPackCell(DP));
	char GangPrefix[32];

	ReadPackString(DP, GangPrefix, sizeof(GangPrefix));

	CloseHandle(DP);

	if (!IsValidPlayer(client))
	{
		return;
	}
	else
	{
		if (SQL_GetRowCount(hndl) == 0)
		{
			PrintToChatGang(ClientGang[client], "The gang's prefix was changed to\x07 %s\x01!", GangPrefix);

			DP = CreateDataPack();

			WritePackString(DP, ClientTag[client]);

			char sQuery[256];

			Transaction transaction = SQL_CreateTransaction();

			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangPrefix = '%s' WHERE GangTag = '%s'", GangPrefix, ClientTag[client]);
			SQL_AddQuery(transaction, sQuery);

			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = GangCash - %i WHERE GangTag = '%s'", GANG_PREFIX_PRICE, ClientTag[client]);
			SQL_AddQuery(transaction, sQuery);

			SQL_ExecuteTransaction(dbGangs, transaction, SQLTrans_GangUpdated, INVALID_FUNCTION, DP, DBPrio_High);
		}
		else    // Gang name is taken.
		{
			RP_PrintToChat(client, "The selected gang prefix is \x07already \x01taken!");
		}
	}
}

public Action Command_CreateGang(int client, int args)
{
	if (!ClientLoadedFromDb[client])
	{
		RP_PrintToChat(client, "\x05You \x01weren't loaded from the database \x07yet!");
		return Plugin_Handled;
	}
	else if (IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to leave your current \x07gang \x01to create a int \x07one!");
		return Plugin_Handled;
	}

	char Args[32];
	GetCmdArgString(Args, sizeof(Args));
	StripQuotes(Args);

	if (Args[0] == EOS)
	{
		RP_PrintToChat(client, "Invalid Usage! \x07!creategang \x01<name>");
		return Plugin_Handled;
	}
	else if (StringHasInvalidCharacters(Args))
	{
		RP_PrintToChat(client, "Invalid name! \x05You \x01can only use \x07a-z, A-Z\x01, _, -, \x070-9!");
		return Plugin_Handled;
	}

	GangCreateName[client] = Args;
	if (GangCreateTag[client][0] == EOS)
	{
		RP_PrintToChat(client, "Name selected! Please select your \x07gang \x01tag using \x07!gangtag.");
		return Plugin_Handled;
	}
	Handle hMenu = CreateMenu(CreateGang_MenuHandler);

	AddMenuItem(hMenu, "", "Yes");
	AddMenuItem(hMenu, "", "No");

	SetMenuExitButton(hMenu, false);

	char sPrice[16];

	AddCommas(GetConVarInt(hcv_CostCreate), ",", sPrice, sizeof(sPrice));

	RP_SetMenuTitle(hMenu, "Create Gang\nGang Name: %s\nGang Tag: %s\nCost: $%s", GangCreateName[client], GangCreateTag[client], sPrice);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Action Command_CreateGangTag(int client, int args)
{
	if (IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to leave your current gang to create a int \x07one!");
		return Plugin_Handled;
	}

	char Args[10];
	GetCmdArgString(Args, sizeof(Args));
	StripQuotes(Args);

	int len = strlen(Args);
	if (len < 4 || len > 8)
	{
		RP_PrintToChat(client, "The gang tag has to be \x07between 4 and 8 characters long");
		return Plugin_Handled;
	}
	GangCreateTag[client] = Args;
	if (GangCreateName[client][0] == EOS)
	{
		RP_PrintToChat(client, "Tag selected! Please select your gang name using \x07!creategang.");
		return Plugin_Handled;
	}

	else if (StringHasInvalidCharacters(Args))
	{
		RP_PrintToChat(client, "Invalid tag! \x05You \x01can only use \x07a-z, A-Z\x01, _, -, \x070-9!");
		return Plugin_Handled;
	}
	Handle hMenu = CreateMenu(CreateGang_MenuHandler);

	AddMenuItem(hMenu, "", "Yes");
	AddMenuItem(hMenu, "", "No");

	SetMenuExitButton(hMenu, false);

	char sPrice[16];

	AddCommas(GetConVarInt(hcv_CostCreate), ",", sPrice, sizeof(sPrice));

	RP_SetMenuTitle(hMenu, "Create Gang\nGang Name: %s\nGang Tag: %s\nCost: $%s", GangCreateName[client], GangCreateTag[client], sPrice);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Action Command_LeaveGang(int client, int args)
{
	if (!IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to be in a gang to use this \x07command!");
		return Plugin_Handled;
	}
	else if (!GangAttemptLeave[client])
	{
		RP_PrintToChat(client, "\x05You \x01have not made an attempt to leave your gang with \x07!gang.");
		return Plugin_Handled;
	}

	PrintToChatGang(ClientGang[client], "\x03%N \x09has left the gang!", client);
	KickClientFromGang(client, ClientTag[client]);

	GangAttemptLeave[client] = false;

	return Plugin_Handled;
}

public Action Command_DisbandGang(int client, int args)
{
	if (!IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to be in a gang to use this \x07command!");
		return Plugin_Handled;
	}
	else if (!CheckGangAccess(client, RANK_LEADER))
	{
		RP_PrintToChat(client, "\x05You \x01have to be the gang's leader to use this \x07command!");
		return Plugin_Handled;
	}
	else if (!GangAttemptDisband[client])
	{
		RP_PrintToChat(client, "\x05You \x01have not made an attempt to disband your gang with \x07!gang.");
		return Plugin_Handled;
	}

	RP_PrintToChatAll("\x05%N \x01has disbanded the gang \x07%s!", client, ClientGang[client]);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "DELETE FROM GangSystem_Gangs WHERE GangTag = '%s'", ClientTag[client]);

	Handle DP = CreateDataPack();

	WritePackString(DP, ClientTag[client]);

	SQL_TQuery(dbGangs, SQLCB_GangDisbanded, sQuery, DP);

	GangAttemptDisband[client] = false;
	return Plugin_Handled;
}

public Action Command_StepDown(int client, int args)
{
	if (!IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01have to be in a gang to use this \x07command!");
		return Plugin_Handled;
	}
	else if (!CheckGangAccess(client, RANK_LEADER))
	{
		RP_PrintToChat(client, "\x05You \x01have to be the gang's leader to use this \x07command!");
		return Plugin_Handled;
	}
	else if (!GangAttemptStepDown[client])
	{
		RP_PrintToChat(client, "\x05You \x01have not made an attempt to step down from your rank with \x07!gang.");
		return Plugin_Handled;
	}

	int NewLeader = GetClientOfUserId(GangStepDownTarget[client]);

	if (NewLeader == 0)
	{
		RP_PrintToChat(client, "The selected target has \x07disconnected.");
		return Plugin_Handled;
	}

	else if (!AreClientsSameGang(client, NewLeader))
	{
		RP_PrintToChat(client, "The selected target has left the \x07gang.");
		return Plugin_Handled;
	}

	PrintToChatGang(ClientGang[client], "\x05%N \x01has stepped down to \x07Co-Leader.", client);
	PrintToChatGang(ClientGang[client], "\x05%N \x01is now the gang \x07Leader.", NewLeader);

	char AuthId[35], AuthIdNewLeader[35];

	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	GetClientAuthId(NewLeader, AuthId_Engine, AuthIdNewLeader, sizeof(AuthIdNewLeader));

	SetAuthIdRank(AuthId, ClientTag[client], RANK_COLEADER);
	SetAuthIdRank(AuthIdNewLeader, ClientTag[NewLeader], RANK_LEADER);

	GangAttemptStepDown[client] = false;
	GangStepDownTarget[client]  = -1;
	return Plugin_Handled;
}

public SQLCB_GangDisbanded(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	char GangTag[32];
	ResetPack(DP);

	ReadPackString(DP, GangTag, sizeof(GangTag));

	CloseHandle(DP);

	Call_StartForward(fwGangDisbanded);

	Call_PushString(GangTag);

	Call_Finish();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (!StrEqual(GangTag, ClientTag[i], false))
			continue;

		OnClientConnected(i);
		OnClientPutInServer(i);

		OnClientPostAdminCheck(i);
	}
}

public CreateGang_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Select)
	{
		if (IsClientGang(client))
			return;

		if (item + 1 == 1)
		{
			if (GangCreateName[client][0] == EOS || GangCreateTag[client][0] == EOS || StringHasInvalidCharacters(GangCreateName[client]) || StringHasInvalidCharacters(GangCreateTag[client]))
				return;

			TryCreateGang(client, GangCreateName[client], GangCreateTag[client]);
		}
		else
		{
			GangCreateName[client] = GANG_NULL;
			GangCreateTag[client]  = GANG_NULL;
		}
	}
}

public Action Command_BreachGang(int client, int args)
{
	if (!IsHighManagement(client))
	{
		RP_PrintToChat(client, "\x05You \x01must be high management");
		return Plugin_Handled;
	}
	if (IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01must not be in a gang to move yourself into another \x07gang.");
		return Plugin_Handled;
	}

	if (args == 0)
	{
		PrintToChat(client, "Usage: \x07sm_breachgang \x01<gang tag>");
		return Plugin_Handled;
	}

	char GangTag[32];
	GetCmdArgString(GangTag, sizeof(GangTag));
	StripQuotes(GangTag);

	char AuthId[35];
	Handle DP = CreateDataPack();

	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	WritePackString(DP, AuthId);
	WritePackString(DP, AuthId);
	WritePackString(DP, GangTag);
	WritePackCell(DP, RANK_MEMBER);

	FinishAddAuthIdToGang(GangTag, AuthId, RANK_MEMBER, AuthId, DP);

	return Plugin_Handled;
}

public Action Command_BreachGangRank(int client, int args)
{
	if (!IsHighManagement(client))
	{
		RP_PrintToChat(client, "\x05You \x01must be high management");
		return Plugin_Handled;
	}
	else if (!IsClientGang(client))
	{
		RP_PrintToChat(client, "\x05You \x01must be in a gang to set your gang \x07rank.");
		return Plugin_Handled;
	}

	if (args == 0)
	{
		PrintToChat(client, "Usage: sm_breachgangrank <rank {0~%i}>", RANK_COLEADER + 1);
		return Plugin_Handled;
	}

	char RankToSet[11];
	GetCmdArg(1, RankToSet, sizeof(RankToSet));

	int Rank = StringToInt(RankToSet);

	if (Rank > RANK_COLEADER)
		Rank = RANK_LEADER;

	char AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	SetAuthIdRank(AuthId, ClientTag[client], Rank);

	return Plugin_Handled;
}

public Action Command_Testtt(int client, int args)
{
	CreateTimer(3.0, Timer_Test, client);
}

public Action Timer_Test(Handle hTimer, int client)
{
	DonateToGang(client, 10);
}
public Action Command_Gang(int client, int args)
{
	if (!ClientLoadedFromDb[client])
	{
		RP_PrintToChat(client, "\x05You \x01weren't loaded from the database \x07yet!");
		return Plugin_Handled;
	}

	GangAttemptLeave[client]   = false;
	GangAttemptDisband[client] = false;

	Handle hMenu = CreateMenu(Gang_MenuHandler);

	bool isGang = IsClientGang(client);

	bool isLeader = (IsClientGang(client) && CheckGangAccess(client, RANK_LEADER));

	char TempFormat[100];

	if (!isGang)
	{
		char sPrice[16];

		AddCommas(GetConVarInt(hcv_CostCreate), ",", sPrice, sizeof(sPrice));
		Format(TempFormat, sizeof(TempFormat), "Create Gang [ $%s ]", sPrice);
		AddMenuItem(hMenu, "Create", TempFormat, !isGang ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

		RP_SetMenuTitle(hMenu, "Gang Menu\n \n● Bank Cash: $%i\n ", GetClientCash(client, BANK_CASH));
	}
	else
	{
		AddMenuItem(hMenu, "Donate", "Donate To Gang", isGang ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(hMenu, "Member List", "Member List", isGang && ClientGangCash[client] >= 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		AddMenuItem(hMenu, "Perks", "Gang Perks", isGang && ClientGangCash[client] >= 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

		if (ClientGangCash[client] >= 0)
			AddMenuItem(hMenu, "Manage", "Manage Gang", CheckGangAccess(client, ClientAccessManage[client]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

		else
			AddMenuItem(hMenu, "Disband", "Disband Gang", isLeader ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

		AddMenuItem(hMenu, "Leave", "Leave Gang", !isLeader && isGang ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

		char sCash[16];

		AddCommas(Abs(ClientGangCash[client]), ",", sCash, sizeof(sCash));

		if (ClientGangCash[client] >= 0)
			RP_SetMenuTitle(hMenu, "Gang Menu\n \n● Current Gang: %s\n● Bank Cash: $%i\n● Gang's Bank Cash: $%s\n● Gang's Tax: %i%%\n ", ClientGang[client], GetClientCash(client, BANK_CASH), sCash, ClientGangTax[client]);

		else
			RP_SetMenuTitle(hMenu, "Gang Menu\n \n● Gang's Debt: $%s\n● Gang's Tax: %i%%\n Note: While your gang has a debt, you are not treated as a gang.", sCash, ClientGangTax[client]);
	}
	AddMenuItem(hMenu, "Top", "Top Gangs");

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Gang_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Select)
	{
		GangAttemptLeave[client]   = false;
		GangAttemptDisband[client] = false;

		char Info[32];
		GetMenuItem(hMenu, item, Info, sizeof(Info));

		if (StrEqual(Info, "Create"))
		{
			RP_PrintToChat(client, "Use \x07!creategang \x01<name> to create a \x07gang.");
		}
		else if (StrEqual(Info, "Donate"))
		{
			GangAttemptDonate[client] = true;
			RP_PrintToChat(client, "Type cash amount to donate or \x02-1\x01 to cancel!");
		}
		else if (StrEqual(Info, "Member List"))
		{
			if (IsClientGang(client))
				ShowMembersMenu(client);
		}
		else if (StrEqual(Info, "Perks"))
		{
			if (IsClientGang(client))
				ShowGangPerks(client)
		}
		else if (StrEqual(Info, "Manage"))
		{
			if (IsClientGang(client) && CheckGangAccess(client, ClientAccessManage[client]))
				ShowManageGangMenu(client);
		}
		else if (StrEqual(Info, "Disband"))
		{
			if (GetClientRank(client) != RANK_LEADER || !IsClientGang(client))
				return;

			StartDisbandSequence(client);
		}
		else if (StrEqual(Info, "Leave"))
		{
			if (GetClientRank(client) == RANK_LEADER || !IsClientGang(client))
				return;

			GangAttemptLeave[client] = true;
			RP_PrintToChat(client, "Write \x07!confirmleavegang \x01if you are absolutely sure you want to leave the \x07gang.");
			RP_PrintToChat(client, "Write anything else in the chat to \x07abort.");
		}
		else if (StrEqual(Info, "Top"))
		{
			ShowTopGangsMenu(client);
		}
	}
}

ShowTopGangsMenu(client)
{
	char sQuery[1024];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT GangName, GangTag, (%!s) as net_worth FROM GangSystem_Gangs WHERE GangCash >= 0 ORDER BY net_worth DESC", NET_WORTH_ORDER_BY_FORMULA);
	SQL_TQuery(dbGangs, SQLCB_ShowTopGangsMenu, sQuery, GetClientUserId(client));
}

public void SQLCB_ShowTopGangsMenu(Handle owner, Handle hndl, const char[] error, int UserId)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	int client = GetClientOfUserId(UserId);

	if (client == 0)
		return;

	else if (SQL_GetRowCount(hndl) == 0)
		return;

	Handle hMenu = CreateMenu(TopGangs_MenuHandler);

	int Rank = 1;
	while (SQL_FetchRow(hndl))
	{
		char GangName[32], GangTag[32];
		SQL_FetchString(hndl, 0, GangName, sizeof(GangName));
		SQL_FetchString(hndl, 1, GangTag, sizeof(GangTag));

		int NetWorth = SQL_FetchInt(hndl, 2);

		char sCash[16];

		AddCommas(NetWorth, ",", sCash, sizeof(sCash));

		char TempFormat[256];
		FormatEx(TempFormat, sizeof(TempFormat), "%s [$%s]", GangName, sCash);

		if (StrEqual(ClientGang[client], GangName))
			RP_PrintToChat(client, "\x01Your gang \x07%s \x01is ranked \x07[%i]. \x01Net Worth: \x07$%s", GangName, Rank, sCash);

		AddMenuItem(hMenu, GangTag, TempFormat);

		Rank++;
	}

	RP_SetMenuTitle(hMenu, "Top Gangs:");
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public TopGangs_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Select)
	{
		char GangTag[32];
		GetMenuItem(hMenu, item, GangTag, sizeof(GangTag));

		FindDonationsForGang(GangTag);

		char sQuery[256];
		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Gangs WHERE GangTag = '%s'", GangTag);

		SQL_TQuery(dbGangs, SQLCB_ShowGangInfo_LoadGang, sQuery, GetClientUserId(client));
	}
}

public SQLCB_ShowGangInfo_LoadGang(Handle owner, Handle hndl, const char[] error, int UserId)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}
	int client = GetClientOfUserId(UserId);

	if (client == 0)
	{
		return;
	}
	else
	{
		if (SQL_FetchRow(hndl))
		{
			char GangName[32], GangTag[32];

			DBResultSet query = view_as<DBResultSet>(hndl);

			SQL_FetchStringByName(query, "GangName", GangName, sizeof(GangName));
			SQL_FetchStringByName(query, "GangTag", GangTag, sizeof(GangTag));
			int GangCash = SQL_FetchIntByName(query, "GangCash");

			char sQuery[256];
			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Members WHERE GangTag = '%s'", GangTag);

			Handle DP = CreateDataPack();

			WritePackCell(DP, GetClientUserId(client));
			WritePackString(DP, GangName);
			WritePackString(DP, GangTag);
			WritePackCell(DP, GangCash);

			SQL_TQuery(dbGangs, SQLCB_ShowGangInfo_LoadMembers, sQuery, DP);
		}
	}
}

public SQLCB_ShowGangInfo_LoadMembers(Handle owner, Handle hndl, char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	ResetPack(DP);

	int client = GetClientOfUserId(ReadPackCell(DP));

	char GangName[32];
	char GangTag[32];

	ReadPackString(DP, GangName, sizeof(GangName));
	ReadPackString(DP, GangTag, sizeof(GangTag));

	int GangCash = ReadPackCell(DP);

	CloseHandle(DP);

	Handle hMenu = CreateMenu(GangTop_GangInfo_MenuHandler);

	char TempFormat[200], iAuthId[35], Name[64];

	while (SQL_FetchRow(hndl))
	{
		DBResultSet query = view_as<DBResultSet>(hndl);

		char strRank[32];
		int Rank = SQL_FetchIntByName(query, "GangRank");
		GetRankName(Rank, strRank, sizeof(strRank));
		SQL_FetchStringByName(query, "LastName", Name, sizeof(Name));
		SQL_FetchStringByName(query, "AuthId", iAuthId, sizeof(iAuthId));

		int amount;
		GetTrieValue(Trie_Donated, iAuthId, amount);

		char sCash[16];

		AddCommas(amount, ",", sCash, sizeof(sCash));

		Format(TempFormat, sizeof(TempFormat), "%s [%s] - %s [Donated: $%s]", Name, strRank, FindClientByAuthId(iAuthId) != 0 ? "ONLINE" : "OFFLINE", sCash);

		AddMenuItem(hMenu, iAuthId, TempFormat, ITEMDRAW_DISABLED);
	}

	char sCash[16];

	AddCommas(GangCash, ",", sCash, sizeof(sCash));

	RP_SetMenuTitle(hMenu, "Member List of %s:\nGang Tag: %s\nGang Cash: %s\n", GangName, GangTag, sCash);

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public GangTop_GangInfo_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowTopGangsMenu(client);
}

ShowGangPerks(client)
{
	Handle hMenu = CreateMenu(Perks_MenuHandler);

	char TempFormat[128];

	Format(TempFormat, sizeof(TempFormat), "Gang Size [ %i / %i ] Current Size: %i + %i", ClientGangSizePerk[client], GANG_SIZEMAX, ClientGangSizePerk[client] * GANG_SIZEINCREASE, GANG_INITSIZE);
	AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DISABLED);

	Format(TempFormat, sizeof(TempFormat), "Luck [ %i / %i ] Current Bonus: %i%%", ClientLuckPerk[client], GANG_LUCKMAX, ClientLuckPerk[client] * GANG_LUCKINCREASE);
	AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DISABLED);

	Format(TempFormat, sizeof(TempFormat), "House Shield [ %i / %i ] Current Bonus: -%i%%", ClientShieldPerk[client], GANG_SHIELDMAX, ClientShieldPerk[client] * GANG_SHIELDINCREASE);
	AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DISABLED);

	/*
	Format(TempFormat, sizeof(TempFormat), "Friendly Fire Decrease [ %i / %i ] Bonus: -%i%% [ %i%% per level ]\nNote: Friendly Fire decrease applies on Days only.", ClientFriendlyFirePerk[client], GANG_FRIENDLYFIREMAX, ClientFriendlyFirePerk[client] * GANG_FRIENDLYFIREINCREASE, GANG_FRIENDLYFIREINCREASE);
	AddMenuItem(hMenu, "", TempFormat, ITEMDRAW_DISABLED);
	*/
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public Perks_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		Command_Gang(client, 0);
}

ShowManageGangMenu(client)
{
	Handle hMenu = CreateMenu(ManageGang_MenuHandler);

	AddMenuItem(hMenu, "", "Invite To Gang", CheckGangAccess(client, ClientAccessInvite[client]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Kick From Gang", CheckGangAccess(client, ClientAccessKick[client]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Promote Member", CheckGangAccess(client, ClientAccessPromote[client]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Upgrade Perks", CheckGangAccess(client, ClientAccessUpgrade[client]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Set Gang MOTD", CheckGangAccess(client, ClientAccessMOTD[client]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Disband Gang", CheckGangAccess(client, RANK_LEADER) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Manage Actions Access", CheckGangAccess(client, RANK_LEADER) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Change Gang Tax", CheckGangAccess(client, ClientAccessManageMoney[client]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Rename Gang", CheckGangAccess(client, RANK_LEADER) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	AddMenuItem(hMenu, "", "Change Gang Prefix", CheckGangAccess(client, RANK_LEADER) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	char sPrice[16], sTime[32];

	AddCommas(GetConVarInt(hcv_WeeklyTax), ",", sPrice, sizeof(sPrice));

	FormatTime(sTime, sizeof(sTime), "%d/%m/%Y - %X", ClientGangNextWeekly[client]);

	RP_SetMenuTitle(hMenu, "Manage Gang\nWeekly tax: $%s\nDate of next Tax: %s", sPrice, sTime);

	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public ManageGang_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		Command_Gang(client, 0);

	else if (action == MenuAction_Select)
	{
		if (ClientGangCash[client] < 0)
			return;

		else if (!CheckGangAccess(client, ClientAccessManage[client]))
		{
			Command_Gang(client, 0);
			return;
		}
		switch (item + 1)
		{
			case 1:
			{
				if (!CheckGangAccess(client, ClientAccessInvite[client]))
					return;

				else if (ClientMembersCount[client] >= (GANG_INITSIZE + (ClientGangSizePerk[client] * GANG_SIZEINCREASE)))
				{
					RP_PrintToChat(client, "The gang is \x07full!");
					return;
				}
				ShowInviteMenu(client);
			}

			case 2:
			{
				if (!CheckGangAccess(client, ClientAccessKick[client]))
					return;

				ShowKickMenu(client);
			}
			case 3:
			{
				if (!CheckGangAccess(client, ClientAccessPromote[client]))
					return;

				ShowPromoteMenu(client);
			}

			case 4:
			{
				if (!CheckGangAccess(client, ClientAccessUpgrade[client]))
					return;

				ShowUpgradeMenu(client);
			}

			case 5:
			{
				if (!CheckGangAccess(client, ClientAccessMOTD[client]))
					return;

				RP_PrintToChat(client, "Use \x07!gangmotd \x01<int motd> to change the gang's \x07motd.");
			}

			case 6:
			{
				if (!CheckGangAccess(client, RANK_LEADER))
					return;

				StartDisbandSequence(client);
			}

			case 7:
			{
				if (!CheckGangAccess(client, RANK_LEADER))
					return;

				ShowActionAccessMenu(client);
			}

			case 8:
			{
				if (!CheckGangAccess(client, ClientAccessManageMoney[client]))
					return;

				RP_PrintToChat(client, "Use \x07!gangtax \x01<int tax> to change the gang's \x07tax.");

				ShowManageGangMenu(client);
			}
			case 9:
			{
				if (!CheckGangAccess(client, RANK_LEADER))
					return;

				RP_PrintToChat(client, "Use \x07!renamegang \x01<new name> to change the gang's \x07name.");

				ShowManageGangMenu(client);
			}

			case 10:
			{
				if (!CheckGangAccess(client, RANK_LEADER))
					return;

				RP_PrintToChat(client, "Use \x07!prefixgang \x01<new prefix> to change the gang's \x07prefix.");

				ShowManageGangMenu(client);
			}
		}
	}
}

StartDisbandSequence(client)
{
	GangAttemptDisband[client] = true;
	RP_PrintToChat(client, "Write \x07!confirmdisbandgang \x01to confirm DELETION of the \x05gang.");
	RP_PrintToChat(client, "Write anything else in the chat to abort deleting the \x05gang.");
	RP_PrintToChat(client, "ATTENTION! THIS ACTION WILL PERMANENTLY DELETE YOUR \x07GANG\x01, IT IS NOT UNDOABLE AND YOU WILL NOT BE \x07REFUNDED!!!");
}
ShowActionAccessMenu(client)
{
	Handle hMenu = CreateMenu(ActionAccess_MenuHandler);
	char RankName[32];
	char TempFormat[256];
	GetRankName(ClientAccessInvite[client], RankName, sizeof(RankName));
	Format(TempFormat, sizeof(TempFormat), "Invite to Gang - [%s]", RankName);
	AddMenuItem(hMenu, "", TempFormat);

	GetRankName(ClientAccessKick[client], RankName, sizeof(RankName));
	Format(TempFormat, sizeof(TempFormat), "Kick from Gang - [%s]", RankName);
	AddMenuItem(hMenu, "", TempFormat);

	GetRankName(ClientAccessPromote[client], RankName, sizeof(RankName));
	Format(TempFormat, sizeof(TempFormat), "Promote Member - [%s]", RankName);
	AddMenuItem(hMenu, "", TempFormat);

	GetRankName(ClientAccessUpgrade[client], RankName, sizeof(RankName));
	Format(TempFormat, sizeof(TempFormat), "Upgrade Perks - [%s]", RankName);
	AddMenuItem(hMenu, "", TempFormat);

	GetRankName(ClientAccessMOTD[client], RankName, sizeof(RankName));
	Format(TempFormat, sizeof(TempFormat), "Set Gang MOTD - [%s]", RankName);
	AddMenuItem(hMenu, "", TempFormat);

	GetRankName(ClientAccessManageMoney[client], RankName, sizeof(RankName));
	Format(TempFormat, sizeof(TempFormat), "Manage Money - [%s]", RankName);
	AddMenuItem(hMenu, "", TempFormat);

	GetRankName(ClientAccessGiveKeys[client], RankName, sizeof(RankName));
	Format(TempFormat, sizeof(TempFormat), "Give Door Keys - [%s]", RankName);
	AddMenuItem(hMenu, "", TempFormat);

	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public ActionAccess_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowManageGangMenu(client);

	else if (action == MenuAction_Select)
	{
		if (!CheckGangAccess(client, RANK_LEADER))
			return;

		ClientActionEdit[client] = item;

		ShowActionAccessSetRankMenu(client);
	}
}

ShowActionAccessSetRankMenu(client)
{
	Handle hMenu = CreateMenu(ActionAccessSetRank_MenuHandler);
	char RankName[32];

	for (int i = RANK_MEMBER; i <= GetClientRank(client); i++)
	{
		if (i == GetClientRank(client) && !CheckGangAccess(client, RANK_LEADER))
			break;

		else if (i > RANK_COLEADER)
			i = RANK_LEADER;

		GetRankName(i, RankName, sizeof(RankName));

		AddMenuItem(hMenu, "", RankName);
	}
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);

	char RightName[32];

	switch (ClientActionEdit[client])
	{
		case 0: RightName = "Invite";
		case 1: RightName = "Kick";
		case 2: RightName = "Promote";
		case 3: RightName = "Upgrade";
		case 4: RightName = "MOTD";
		case 5: RightName = "Manage Money";
		case 6: RightName = "Give Door Keys";
	}

	RP_SetMenuTitle(hMenu, "Choose which minimum rank will have right to %s", RightName);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public ActionAccessSetRank_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowActionAccessMenu(client);

	else if (action == MenuAction_Select)
	{
		if (!CheckGangAccess(client, RANK_LEADER))
			return;

		int TrueRank = item > RANK_COLEADER ? RANK_LEADER : item;

		char ColumnName[32];
		switch (ClientActionEdit[client])
		{
			case 0: ColumnName = "GangMinRankInvite";
			case 1: ColumnName = "GangMinRankKick";
			case 2: ColumnName = "GangMinRankPromote";
			case 3: ColumnName = "GangMinRankUpgrade";
			case 4: ColumnName = "GangMinRankMOTD";
			case 5: ColumnName = "GangMinRankManageMoney";
			case 6: ColumnName = "GangMinRankGiveKeys";
		}

		Handle DP = CreateDataPack();

		WritePackString(DP, ClientTag[client]);

		char sQuery[256];
		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET %s = %i WHERE GangTag = '%s'", ColumnName, TrueRank, ClientTag[client]);

		SQL_TQuery(dbGangs, SQLCB_GangUpdated, sQuery, DP);
	}
}
ShowUpgradeMenu(client)
{
	Handle hMenu = CreateMenu(Upgrade_MenuHandler);

	char TempFormat[100], strUpgradeCost[20];
	int upgradecost;

	/*
	upgradecost = GetUpgradeCost(ClientHealthPerkT[client], GANG_HEALTHCOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Health ( T ) [ %i / %i ] Cost: %i", ClientHealthPerkT[client], GANG_HEALTHMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangHonor[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	upgradecost = GetUpgradeCost(ClientSpeedPerkT[client], GANG_SPEEDCOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Speed ( T ) [ %i / %i ] Cost: %i", ClientSpeedPerkT[client], GANG_SPEEDMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangHonor[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	upgradecost = GetUpgradeCost(ClientNadePerkT[client], GANG_NADECOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Nade Chance ( T ) [ %i / %i ] Cost: %i", ClientNadePerkT[client], GANG_NADEMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangHonor[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	upgradecost = GetUpgradeCost(ClientHealthPerkCT[client], GANG_HEALTHCOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Health ( CT ) [ %i / %i ] Cost: %i", ClientHealthPerkCT[client], GANG_HEALTHMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangHonor[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	upgradecost = GetUpgradeCost(ClientSpeedPerkCT[client], GANG_SPEEDCOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Speed ( CT ) [ %i / %i ] Cost: %i", ClientSpeedPerkCT[client], GANG_SPEEDMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangHonor[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	upgradecost = GetUpgradeCost(ClientGetHonorPerk[client], GANG_GETCASHCOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Get Credits [ %i / %i ] Cost: %i", ClientGetHonorPerk[client], GANG_GETCASHMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangHonor[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	*/
	upgradecost = GetUpgradeCost(ClientGangSizePerk[client], GANG_SIZECOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Gang Size [ %i / %i ] Cost: $%i", ClientGangSizePerk[client], GANG_SIZEMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangCash[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	upgradecost = GetUpgradeCost(ClientLuckPerk[client], GANG_LUCKCOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Luck [ %i / %i ] Cost: $%i", ClientLuckPerk[client], GANG_LUCKMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangCash[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	upgradecost = GetUpgradeCost(ClientShieldPerk[client], GANG_SHIELDCOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "House Shield [ %i / %i ] Cost: $%i", ClientShieldPerk[client], GANG_SHIELDMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangCash[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	/*
	upgradecost = GetUpgradeCost(ClientFriendlyFirePerk[client], GANG_FRIENDLYFIRECOST);
	IntToString(upgradecost, strUpgradeCost, sizeof(strUpgradeCost));
	Format(TempFormat, sizeof(TempFormat), "Friendly Fire Decrease [ %i / %i ] Cost: %i", ClientFriendlyFirePerk[client], GANG_FRIENDLYFIREMAX, upgradecost);
	AddMenuItem(hMenu, strUpgradeCost, TempFormat, ClientGangHonor[client] >= upgradecost ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	*/
	RP_SetMenuTitle(hMenu, "Choose what perks to upgrade:");
	SetMenuPagination(hMenu, MENU_NO_PAGINATION);
	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public Upgrade_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowManageGangMenu(client);

	else if (action == MenuAction_Select)
	{
		if (!CheckGangAccess(client, RANK_MANAGER))
			return;

		char strUpgradeCost[20], strIgnoreable[1];
		int Ignoreable;

		GetMenuItem(hMenu, item, strUpgradeCost, sizeof(strUpgradeCost), Ignoreable, strIgnoreable, 0);
		LoadClientGang_TryUpgrade(client, item, StringToInt(strUpgradeCost));
	}
}

LoadClientGang_TryUpgrade(client, item, upgradecost)
{
	char AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Members WHERE AuthId = '%s'", AuthId);

	Handle DP = CreateDataPack();

	WritePackCell(DP, GetClientUserId(client));
	WritePackCell(DP, item);
	WritePackCell(DP, upgradecost);
	SQL_TQuery(dbGangs, SQLCB_LoadClientGang_TryUpgrade, sQuery, DP, DBPrio_High);
}

public SQLCB_LoadClientGang_TryUpgrade(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	ResetPack(DP);

	int client = GetClientOfUserId(ReadPackCell(DP));
	if (!IsValidPlayer(client))
	{
		CloseHandle(DP);
		return;
	}
	else
	{
		if (SQL_GetRowCount(hndl) != 0)
		{
			SQL_FetchRow(hndl);

			DBResultSet query = view_as<DBResultSet>(hndl);

			SQL_FetchStringByName(query, "GangTag", ClientTag[client], sizeof(ClientTag[]));
			ClientRank[client] = SQL_FetchIntByName(query, "GangRank");

			char sQuery[256];
			SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Gangs WHERE GangTag = '%s'", ClientTag[client]);
			SQL_TQuery(dbGangs, SQLCB_LoadGangByClient_TryUpgrade, sQuery, DP, DBPrio_High);
		}
		else
		{
			CloseHandle(DP);
			ClientLoadedFromDb[client] = true;
		}
	}
}

public SQLCB_LoadGangByClient_TryUpgrade(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	ResetPack(DP);

	int client      = GetClientOfUserId(ReadPackCell(DP));
	int item        = ReadPackCell(DP);
	int upgradecost = ReadPackCell(DP);

	CloseHandle(DP);
	if (!IsValidPlayer(client))
	{
		return;
	}
	else
	{
		if (SQL_GetRowCount(hndl) != 0)
		{
			SQL_FetchRow(hndl);

			SQL_FetchString(hndl, 0, ClientGang[client], sizeof(ClientGang[]));
			SQL_FetchString(hndl, 1, ClientTag[client], sizeof(ClientTag[]));
			SQL_FetchString(hndl, 2, ClientMotd[client], sizeof(ClientMotd[]));
			ClientGangCash[client] = SQL_FetchInt(hndl, 3);

			DBResultSet query = view_as<DBResultSet>(hndl);

			ClientGangSizePerk[client] = SQL_FetchIntByName(query, "GangSizePerk");
			ClientLuckPerk[client]     = SQL_FetchIntByName(query, "GangLuckPerk");
			ClientShieldPerk[client]   = SQL_FetchIntByName(query, "GangShieldPerk");

			TryUpgradePerk(client, item, upgradecost);
		}
	}
}

TryUpgradePerk(client, item, upgradecost)    // Safety accomplished.
{
	if (ClientGangCash[client] < upgradecost)
	{
		RP_PrintToChat(client, "Your gang doesn't have enough cash to \x07upgrade.");
		return;
	}
	int  PerkToUse, PerkMax, PerkInitCost;
	char PerkName[32], PerkNick[32];

	switch (item + 1)
	{
		case 1: PerkToUse = ClientGangSizePerk[client], PerkMax = GANG_SIZEMAX, PerkName = "GangSizePerk", PerkNick = "Gang Size", PerkInitCost = GANG_SIZECOST;
		case 2: PerkToUse = ClientLuckPerk[client], PerkMax = GANG_LUCKMAX, PerkName = "GangLuckPerk", PerkNick = "Luck", PerkInitCost = GANG_LUCKCOST;
		case 3: PerkToUse = ClientShieldPerk[client], PerkMax = GANG_SHIELDMAX, PerkName = "GangShieldPerk", PerkNick = "House Shield", PerkInitCost = GANG_SHIELDCOST;

		default: return;
	}

	if (upgradecost != GetUpgradeCost(PerkToUse, PerkInitCost))
	{
		RP_PrintToChat(client, "Couldn't compute price due to duplicate perk upgrade attempt.");
		return;
	}
	else if (PerkToUse >= PerkMax)
	{
		RP_PrintToChat(client, "Your gang has \x07already \x01maxed this perk!");
		return;
	}

	char sQuery[256];

	char steamid[32];
	GetClientAuthId(client, AuthId_Engine, steamid, sizeof(steamid));

	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "INSERT INTO GangSystem_upgradelogs (GangTag, AuthId, Perk, BValue, AValue, timestamp) VALUES ('%s', '%s', '%s', %i, %i, %i)", ClientTag[client], steamid, PerkName, PerkToUse, PerkToUse + 1, GetTime());
	SQL_TQuery(dbGangs, SQLCB_Error, sQuery, 7, DBPrio_High);

	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = GangCash - %i WHERE GangTag = '%s'", upgradecost, ClientTag[client]);

	Handle DP           = CreateDataPack();
	Handle DP2 = CreateDataPack();

	WritePackString(DP, ClientTag[client]);
	SQL_TQuery(dbGangs, SQLCB_GangUpdated, sQuery, DP);

	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET %s = %s + 1 WHERE GangTag = '%s'", PerkName, PerkName, ClientTag[client]);
	WritePackString(DP2, ClientTag[client]);
	SQL_TQuery(dbGangs, SQLCB_GangUpdated, sQuery, DP2, DBPrio_High);

	PrintToChatGang(ClientGang[client], "\x05%N \x01has upgraded the gang perk \x07%s!", client, PerkNick);
}

public SQLCB_GangUpdated(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}
	ResetPack(DP);

	char GangTag[32];
	ReadPackString(DP, GangTag, sizeof(GangTag));

	CloseHandle(DP);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		else if (!StrEqual(ClientTag[i], GangTag, true))
			continue;

		ResetVariables(i, false);

		LoadClientGang(i);
	}
}

public SQLTrans_GangUpdated(Database db, any DP, int numQueries, DBResultSet[] results, any[] queryData)
{
	ResetPack(DP);

	char GangTag[32];
	ReadPackString(DP, GangTag, sizeof(GangTag));

	CloseHandle(DP);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		else if (!StrEqual(ClientTag[i], GangTag, true))
			continue;

		ResetVariables(i, false);

		LoadClientGang(i);
	}
}

ShowPromoteMenu(client)
{
	FindDonationsForGang(ClientTag[client]);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Members WHERE GangTag = '%s' ORDER BY LastConnect DESC", ClientTag[client]);
	SQL_TQuery(dbGangs, SQLCB_ShowPromoteMenu, sQuery, GetClientUserId(client));
}

public SQLCB_ShowPromoteMenu(Handle owner, Handle hndl, const char[] error, int UserId)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}
	int client = GetClientOfUserId(UserId);

	if (!IsValidPlayer(client))
	{
		return;
	}
	else
	{
		Handle hMenu = CreateMenu(Promote_MenuHandler);

		char TempFormat[200], Info[250], iAuthId[35], Name[64];

		while (SQL_FetchRow(hndl))
		{
			DBResultSet query = view_as<DBResultSet>(hndl);

			char strRank[32];
			int Rank = SQL_FetchIntByName(query, "GangRank");
			GetRankName(Rank, strRank, sizeof(strRank));
			SQL_FetchStringByName(query, "LastName", Name, sizeof(Name));
			SQL_FetchStringByName(query, "AuthId", iAuthId, sizeof(iAuthId));

			int amount;
			GetTrieValue(Trie_Donated, iAuthId, amount);

			char sCash[16];

			AddCommas(amount, ",", sCash, sizeof(sCash));

			Format(TempFormat, sizeof(TempFormat), "%s [%s] - %s [Donated: $%s]", Name, strRank, FindClientByAuthId(iAuthId) != 0 ? "ONLINE" : "OFFLINE", sCash);

			FormatEx(Info, sizeof(Info), "\"%s\" \"%s\" %i %i", iAuthId, Name, Rank, SQL_FetchIntByName(query, "LastConnect"));

			AddMenuItem(hMenu, Info, TempFormat, Rank < GetClientRank(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		RP_SetMenuTitle(hMenu, "Choose who to promote:");

		SetMenuExitButton(hMenu, true);
		SetMenuExitBackButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
}

public Promote_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowManageGangMenu(client);

	else if (action == MenuAction_Select)
	{
		char Info[200], strIgnoreable[1];
		int Ignoreable;
		GetMenuItem(hMenu, item, Info, sizeof(Info), Ignoreable, strIgnoreable, 0);

		PromoteMenu_ChooseRank(client, Info);
	}
}

PromoteMenu_ChooseRank(int client, const char[] Info)
{
	Handle hMenu = CreateMenu(ChooseRank_MenuHandler);

	for (int i = RANK_MEMBER; i <= GetClientRank(client); i++)
	{
		if (i == GetClientRank(client) && !CheckGangAccess(client, RANK_LEADER))
			break;

		else if (i > RANK_COLEADER)
			i = RANK_LEADER;

		char RankName[20];
		GetRankName(i, RankName, sizeof(RankName));

		AddMenuItem(hMenu, Info, RankName);
	}

	char iAuthId[35], Name[64], strRank[11], strLastConnect[11];

	int len = BreakString(Info, iAuthId, sizeof(iAuthId));

	int len2 = BreakString(Info[len], Name, sizeof(Name));

	int len3 = BreakString(Info[len + len2], strRank, sizeof(strRank));

	BreakString(Info[len + len2 + len3], strLastConnect, sizeof(strLastConnect));

	char Date[64];
	FormatTime(Date, sizeof(Date), "%d/%m/%Y - %H:%M:%S", StringToInt(strLastConnect));

	RP_SetMenuTitle(hMenu, "Choose the rank you want to give to %s\nTarget's Last Connect: %s", Name, Date);

	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, client, 30);
}

public ChooseRank_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowPromoteMenu(client);

	else if (action == MenuAction_Select)
	{
		char Info[200], iAuthId[35], strRank[20], strLastConnect[11], Name[64], strIgnoreable[1];
		int Ignoreable;
		GetMenuItem(hMenu, item, Info, sizeof(Info), Ignoreable, strIgnoreable, 0);

		int len = BreakString(Info, iAuthId, sizeof(iAuthId));

		int len2 = BreakString(Info[len], Name, sizeof(Name));

		int len3 = BreakString(Info[len + len2], strRank, sizeof(strRank));

		BreakString(Info[len + len2 + len3], strLastConnect, sizeof(strLastConnect));

		if (item > RANK_COLEADER)
			item = RANK_LEADER;

		if (item < GetClientRank(client))
		{
			char NewRank[32];
			GetRankName(item, NewRank, sizeof(NewRank));
			PrintToChatGang(ClientGang[client], " %s has been \x07promoted \x01to \x05%s", Name, NewRank);
			SetAuthIdRank(iAuthId, ClientTag[client], item);
		}
		else
		{
			GangAttemptStepDown[client] = true;

			int target = FindClientByAuthId(iAuthId);

			if (target == 0)
			{
				RP_PrintToChat(client, "The target must be \x05connected \x01for a step-down action for security \x07reasons.");

				return;
			}

			GangStepDownTarget[client] = GetClientUserId(target);

			RP_PrintToChat(client, "Attention! \x05You are attempting to promote a player to be the \x07Leader.");
			RP_PrintToChat(client, "By doing so you will become a \x07Co-Leader \x01in the gang.");
			RP_PrintToChat(client, "This action is irreversible, the int \x07leader \x01can kick you if he wants.");
			RP_PrintToChat(client, "If you read all above and sure you want to continue, write \x07!confirmstepdowngang.");
			RP_PrintToChat(client, "Write anything else in the chat to abort the \x07action");
		}
	}
}

ShowKickMenu(client)
{
	FindDonationsForGang(ClientTag[client]);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Members WHERE GangTag = '%s' ORDER BY LastConnect DESC", ClientTag[client]);
	SQL_TQuery(dbGangs, SQLCB_ShowKickMenu, sQuery, GetClientUserId(client));
}

public SQLCB_ShowKickMenu(Handle owner, Handle hndl, const char[] error, int UserId)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}
	int client = GetClientOfUserId(UserId);

	if (!IsValidPlayer(client))
	{
		return;
	}
	else
	{
		Handle hMenu = CreateMenu(Kick_MenuHandler);

		char TempFormat[200], Info[250], iAuthId[35], Name[64];

		while (SQL_FetchRow(hndl))
		{
			DBResultSet query = view_as<DBResultSet>(hndl);

			char strRank[32];
			int Rank = SQL_FetchIntByName(query, "GangRank");
			GetRankName(Rank, strRank, sizeof(strRank));
			SQL_FetchStringByName(query, "LastName", Name, sizeof(Name));
			SQL_FetchStringByName(query, "AuthId", iAuthId, sizeof(iAuthId));

			int amount;
			GetTrieValue(Trie_Donated, iAuthId, amount);

			char sCash[16];

			AddCommas(amount, ",", sCash, sizeof(sCash));

			Format(TempFormat, sizeof(TempFormat), "%s [%s] - %s [Donated: $%s]", Name, strRank, FindClientByAuthId(iAuthId) != 0 ? "ONLINE" : "OFFLINE", sCash);

			FormatEx(Info, sizeof(Info), "\"%s\" \"%s\" %i %i", iAuthId, Name, Rank, SQL_FetchIntByName(query, "LastConnect"));

			AddMenuItem(hMenu, Info, TempFormat, Rank < GetClientRank(client) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}

		RP_SetMenuTitle(hMenu, "Choose who to kick:");

		SetMenuExitButton(hMenu, true);
		SetMenuExitBackButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
}

public Kick_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowManageGangMenu(client);

	else if (action == MenuAction_Select)
	{
		char Info[200], iAuthId[35], strRank[20], strLastConnect[11], Name[64], strIgnoreable[1];
		int Ignoreable;
		GetMenuItem(hMenu, item, Info, sizeof(Info), Ignoreable, strIgnoreable, 0);

		int len = BreakString(Info, iAuthId, sizeof(iAuthId));

		int len2 = BreakString(Info[len], Name, sizeof(Name));

		int len3 = BreakString(Info[len + len2], strRank, sizeof(strRank));

		BreakString(Info[len + len2 + len3], strLastConnect, sizeof(strLastConnect));

		if (StringToInt(strRank) >= GetClientRank(client))    // Should never return but better safe than sorry.
			return;

		ShowConfirmKickMenu(client, iAuthId, Name, StringToInt(strLastConnect));
	}
}

ShowConfirmKickMenu(int client, const char[] iAuthId, const char[] Name, int LastConnect)
{
	Handle hMenu = CreateMenu(ConfirmKick_MenuHandler);

	AddMenuItem(hMenu, iAuthId, "Yes");
	AddMenuItem(hMenu, Name, "No");    // This will also be used.

	char Date[64];
	FormatTime(Date, sizeof(Date), "%d/%m/%Y - %H:%M:%S", LastConnect);

	RP_SetMenuTitle(hMenu, "Gang Kick\nAre you sure you want to kick %s?\nSteam ID of target: %s\nTarget's last connect: %s", Name, iAuthId, Date);
	SetMenuExitButton(hMenu, true);
	DisplayMenu(hMenu, client, 60);
}

public ConfirmKick_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowKickMenu(client);

	else if (action == MenuAction_Select)
	{
		if (item + 1 == 1)
		{
			char iAuthId[35], Name[64], strIgnoreable[1];
			int Ignoreable;

			GetMenuItem(hMenu, 0, iAuthId, sizeof(iAuthId), Ignoreable, strIgnoreable, 0);
			GetMenuItem(hMenu, 1, Name, sizeof(Name), Ignoreable, strIgnoreable, 0);

			PrintToChatGang(ClientGang[client], "\x05%N \x01has kicked \x07%s \x01from the gang!", client, Name);

			KickAuthIdFromGang(iAuthId, ClientTag[client]);
		}
	}
}

ShowInviteMenu(client)
{
	Handle hMenu = CreateMenu(Invite_MenuHandler);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		else if (IsClientGang(i))
			continue;

		// else if(IsFakeClient(i))
		// continue;

		char strUserId[20], iName[64];
		IntToString(GetClientUserId(i), strUserId, sizeof(strUserId));
		GetClientName(i, iName, sizeof(iName));

		AddMenuItem(hMenu, strUserId, iName);
	}

	RP_SetMenuTitle(hMenu, "Choose who to invite:");

	SetMenuExitButton(hMenu, true);
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public Invite_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		ShowManageGangMenu(client);

	else if (action == MenuAction_Select)
	{
		char strUserId[20], strIgnoreable[1];
		int target;
		GetMenuItem(hMenu, item, strUserId, sizeof(strUserId), target, strIgnoreable, 0);

		target = GetClientOfUserId(StringToInt(strUserId));

		if (IsValidPlayer(target))
		{
			if (!IsClientGang(target))
			{
				if (!IsFakeClient(target))
				{
					char AuthId[35];
					GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
					ShowAcceptInviteMenu(target, AuthId, ClientGang[client]);
					RP_PrintToChat(client, "\x05You \x01have invited \x07%N \x01to join the gang!", target);
				}
				else
				{
					char AuthId[35];
					GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
					AddClientToGang(target, AuthId, ClientTag[client]);
				}
			}
		}
	}
}

ShowAcceptInviteMenu(int target, const char[] AuthIdInviter, const char[] GangName)
{
	if (!IsValidPlayer(target))
		return;

	Handle hMenu = CreateMenu(AcceptInvite_MenuHandler);

	AddMenuItem(hMenu, AuthIdInviter, "Yes");
	AddMenuItem(hMenu, GangName, "No");    // This info string will also be used.

	RP_SetMenuTitle(hMenu, "Gang Invite\nWould you like to join the gang %s?", GangName);
	DisplayMenu(hMenu, target, 10);
}

public AcceptInvite_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Select)
	{
		if (item + 1 == 1)
		{
			char AuthIdInviter[35], GangName[32], strIgnoreable[1];
			int Ignoreable;

			GetMenuItem(hMenu, 0, AuthIdInviter, sizeof(AuthIdInviter), Ignoreable, strIgnoreable, 0);
			GetMenuItem(hMenu, 1, GangName, sizeof(GangName), Ignoreable, strIgnoreable, 0);

			int inviter = FindClientByAuthId(AuthIdInviter);

			if (inviter == 0 || !IsClientGang(inviter) || !StrEqual(ClientGang[inviter], GangName, true))
				return;

			char LastGang[sizeof(ClientGang[])];
			LastGang = ClientGang[client];

			ClientGang[client] = GangName;
			PrintToChatGang(ClientGang[client], "\x05%N \x01has joined the \x07gang!", client);
			ClientGang[client] = LastGang;

			AddClientToGang(client, AuthIdInviter, ClientTag[inviter]);
		}
	}
}

ShowMembersMenu(client)
{
	FindDonationsForGang(ClientTag[client]);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Members WHERE GangTag = '%s' ORDER BY LastConnect DESC", ClientTag[client]);
	SQL_TQuery(dbGangs, SQLCB_ShowMembersMenu, sQuery, GetClientUserId(client));
}

public SQLCB_ShowMembersMenu(Handle owner, Handle hndl, const char[] error, int UserId)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}
	int client = GetClientOfUserId(UserId);

	if (!IsValidPlayer(client))
	{
		return;
	}
	else
	{
		Handle hMenu = CreateMenu(Members_MenuHandler);

		char TempFormat[200], iAuthId[35], Name[64];

		while (SQL_FetchRow(hndl))
		{
			DBResultSet query = view_as<DBResultSet>(hndl);

			char strRank[32];
			int Rank = SQL_FetchIntByName(query, "GangRank");
			GetRankName(Rank, strRank, sizeof(strRank));
			SQL_FetchStringByName(query, "LastName", Name, sizeof(Name));
			SQL_FetchStringByName(query, "AuthId", iAuthId, sizeof(iAuthId));

			int amount;
			GetTrieValue(Trie_Donated, iAuthId, amount);

			char sCash[16];

			AddCommas(amount, ",", sCash, sizeof(sCash));

			Format(TempFormat, sizeof(TempFormat), "%s [%s] - %s [Donated: $%s]", Name, strRank, FindClientByAuthId(iAuthId) != 0 ? "ONLINE" : "OFFLINE", sCash);

			AddMenuItem(hMenu, iAuthId, TempFormat);
		}

		RP_SetMenuTitle(hMenu, "Member List:\n Note: Weekly donations reset on Thursday");

		SetMenuExitBackButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
}

public Members_MenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
		CloseHandle(hMenu);

	else if (action == MenuAction_Cancel && item == MenuCancel_ExitBack)
		Command_Gang(client, 0);

	else if (action == MenuAction_Select)
	{
		char iAuthId[32];

		GetMenuItem(hMenu, item, iAuthId, sizeof(iAuthId));

		int amount, amountWeek;
		GetTrieValue(Trie_Donated, iAuthId, amount);
		GetTrieValue(Trie_DonatedWeek, iAuthId, amountWeek);

		char sCash[16], sCashWeek[16];

		AddCommas(amount, ",", sCash, sizeof(sCash));
		AddCommas(amountWeek, ",", sCashWeek, sizeof(sCashWeek));

		RP_PrintToChat(client, "Total donations: $%s. Weekly Donations: $%s", sCash, sCashWeek);

		ShowMembersMenu(client);
	}
}

TryCreateGang(int client, const char[] GangName, const char[] GangTag)
{
	if (GangName[0] == EOS)
	{
		GangCreateName[client] = GANG_NULL;
		GangCreateTag[client]  = GANG_NULL;
		RP_PrintToChat(client, "The selected gang name is \x07invalid.");
		return;
	}
	else if (GangTag[0] == EOS)
	{
		GangCreateName[client] = GANG_NULL;
		GangCreateTag[client]  = GANG_NULL;
		RP_PrintToChat(client, "The selected gang tag is \x07invalid.");
		return;
	}
	else if (GetClientCash(client, BANK_CASH) < GetConVarInt(hcv_CostCreate))
	{
		GangCreateName[client] = GANG_NULL;
		GangCreateTag[client]  = GANG_NULL;

		char sPriceDifference[16];

		AddCommas(GetConVarInt(hcv_CostCreate) - GetClientCash(client, BANK_CASH), ",", sPriceDifference, sizeof(sPriceDifference));

		RP_PrintToChat(client, "\x05You \x01need \x07$%s more\x01 to open a gang!", sPriceDifference);
		return;
	}
	Handle DP = CreateDataPack();
	WritePackCell(DP, GetClientUserId(client));
	WritePackString(DP, GangName);
	WritePackString(DP, GangTag);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Gangs WHERE lower(GangName) = lower('%s') OR lower(GangTag) = lower('%s')", GangName, GangTag);

	// Normal prio on check taken and high on change ensures if there is a check taken for anything else, it won't allow two gangs with same name.
	SQL_TQuery(dbGangs, SQLCB_CreateGang_CheckTakenNameOrTag, sQuery, DP);
}

public SQLCB_CreateGang_CheckTakenNameOrTag(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}
	ResetPack(DP);

	int client = GetClientOfUserId(ReadPackCell(DP));
	char GangName[32], GangTag[10];

	ReadPackString(DP, GangName, sizeof(GangName));
	ReadPackString(DP, GangTag, sizeof(GangTag));

	CloseHandle(DP);

	if (!IsValidPlayer(client))
	{
		return;
	}
	else
	{
		if (SQL_GetRowCount(hndl) == 0)
		{
			CreateGang(client, GangName, GangTag);
			RP_PrintToChat(client, "The gang was \x07created!")
		}
		else    // Gang name is taken.
		{
			bool NameTaken = false;
			bool TagTaken  = false;

			char iGangName[32], iGangTag[10];
			while (SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, iGangName, sizeof(iGangName));
				SQL_FetchString(hndl, 1, iGangTag, sizeof(iGangTag));

				if (StrEqual(iGangName, GangName, false))
					NameTaken = true;

				if (StrEqual(iGangTag, GangTag, false))
					TagTaken = true;
			}

			if (NameTaken)
			{
				GangCreateName[client] = GANG_NULL;
				RP_PrintToChat(client, "The selected gang name is \x07already \x01taken!");
			}
			if (TagTaken)
			{
				GangCreateTag[client] = GANG_NULL;
				RP_PrintToChat(client, "The selected gang tag is \x07already \x01taken!");
			}
		}
	}
}

CreateGang(int client, const char[] GangName, const char[] GangTag)
{
	if (GetClientCash(client, BANK_CASH) < GetConVarInt(hcv_CostCreate))
		return;

	char sQuery[256];

	char AuthId[35];

	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "DELETE FROM GangSystem_Members WHERE GangTag = '%s'", GangTag);    // Just in case.
	SQL_TQuery(dbGangs, SQLCB_Error, sQuery, 8, DBPrio_High);

	Handle DP = CreateDataPack();

	WritePackString(DP, AuthId);
	WritePackString(DP, GangName);
	WritePackString(DP, GangTag);

	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "INSERT INTO GangSystem_Gangs (GangName, GangTag, GangMotd, GangCash, GangSizePerk, GangNextWeekly) VALUES ('%s', '%s', '', 0, 0, %i)", GangName, GangTag, GetTime() + SECONDS_IN_A_WEEK);
	SQL_TQuery(dbGangs, SQLCB_GangCreated, sQuery, DP, DBPrio_High);

	GiveClientCash(client, BANK_CASH, -1 * GetConVarInt(hcv_CostCreate));
}

public SQLCB_GangCreated(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}
	ResetPack(DP);

	char AuthId[35], GangName[32], GangTag[32];

	ReadPackString(DP, AuthId, sizeof(AuthId));
	ReadPackString(DP, GangName, sizeof(GangName));
	ReadPackString(DP, GangTag, sizeof(GangTag));

	CloseHandle(DP);

	AddAuthIdToGang(AuthId, AuthId, GangTag, RANK_LEADER);
}

stock AddClientToGang(int client, const char[] AuthIdInviter, const char[] GangTag, int GangRank = RANK_MEMBER)
{
	char AuthId[35];

	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	AddAuthIdToGang(AuthId, AuthIdInviter, GangTag, GangRank);
}

stock AddAuthIdToGang(const char[] AuthId, const char[] AuthIdInviter, const char[] GangTag, int GangRank = RANK_MEMBER)
{
	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Gangs WHERE GangTag = '%s'", GangTag);

	Handle DP = CreateDataPack();

	WritePackString(DP, AuthId);
	WritePackString(DP, AuthIdInviter);
	WritePackString(DP, GangTag);
	WritePackCell(DP, GangRank);
	SQL_TQuery(dbGangs, SQLCB_AuthIdAddToGang_CheckSize, sQuery, DP);
}

public SQLCB_AuthIdAddToGang_CheckSize(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	if (SQL_GetRowCount(hndl) != 0)
	{
		SQL_FetchRow(hndl);

		int Size = GANG_INITSIZE + (SQL_FetchInt(hndl, 4) * GANG_SIZEINCREASE);

		WritePackCell(DP, Size);

		ResetPack(DP);
		char AuthId[1], GangTag[32];
		ReadPackString(DP, AuthId, 0);
		ReadPackString(DP, AuthId, 0);
		ReadPackString(DP, GangTag, sizeof(GangTag));

		char sQuery[256];
		SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Members WHERE GangTag = '%s'", GangTag);
		SQL_TQuery(dbGangs, SQLCB_AuthIdAddToGang_CheckMemberCount, sQuery, DP);
	}
	else
	{
		CloseHandle(DP);
		return;
	}
}

// This callback is used to get someone's member count
public SQLCB_CheckMemberCount(Handle owner, Handle hndl, const char[] error, int UserId)
{
	int MemberCount = SQL_GetRowCount(hndl);

	int client = GetClientOfUserId(UserId);

	if (client == 0)
		return;

	ClientMembersCount[client] = MemberCount;
}

public SQLCB_AuthIdAddToGang_CheckMemberCount(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	int MemberCount = SQL_GetRowCount(hndl);

	ResetPack(DP);
	char AuthId[35], AuthIdInviter[35], GangTag[32];
	int Size, GangRank;

	ReadPackString(DP, AuthId, sizeof(AuthId));
	ReadPackString(DP, AuthIdInviter, sizeof(AuthIdInviter));
	ReadPackString(DP, GangTag, sizeof(GangTag));
	GangRank = ReadPackCell(DP);
	Size     = ReadPackCell(DP);

	if (MemberCount >= Size)
	{
		CloseHandle(DP);

		int inviter = FindClientByAuthId(AuthIdInviter);

		if (inviter == 0)
			return;

		RP_PrintToChat(inviter, "\x03The gang is full!");
		return;
	}

	FinishAddAuthIdToGang(GangTag, AuthId, GangRank, AuthIdInviter, DP);
}

// The DataPack will contain the invited auth ID as the first thing to be added.
public FinishAddAuthIdToGang(char[] GangTag, char[] AuthId, int GangRank, char[] AuthIdInviter, Handle DP)	
{
	char sQuery[256];

	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "INSERT INTO GangSystem_Members (GangTag, AuthId, GangRank, GangInviter, LastName, GangJoinDate, LastConnect) VALUES ('%s', '%s', %i, '%s', '', %i, %i)", GangTag, AuthId, GangRank, AuthIdInviter, GetTime(), GetTime());

	SQL_TQuery(dbGangs, SQLCB_AuthIdAddedToGang, sQuery, DP);
}

public SQLCB_AuthIdAddedToGang(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	ResetPack(DP);

	char AuthId[35], AuthIdInviter[35], GangTag[32];

	ReadPackString(DP, AuthId, sizeof(AuthId));
	ReadPackString(DP, AuthIdInviter, sizeof(AuthIdInviter));
	ReadPackString(DP, GangTag, sizeof(GangTag));

	CloseHandle(DP);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		else if (!StrEqual(ClientTag[i], GangTag, true))
			continue;

		ResetVariables(i);

		LoadClientGang(i);
	}

	UpdateInGameAuthId(AuthId);
}

stock UpdateInGameAuthId(const char[] AuthId)
{
	char iAuthId[35];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		GetClientAuthId(i, AuthId_Engine, iAuthId, sizeof(iAuthId));

		if (StrEqual(AuthId, iAuthId, true))
		{
			ClientLoadedFromDb[i] = false;

			ResetVariables(i, true);
			LoadClientGang(i);
			break;
		}
	}
}

stock FindClientByAuthId(const char[] AuthId)
{
	char iAuthId[35];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		else if (!IsClientAuthorized(i))
			continue;

		GetClientAuthId(i, AuthId_Engine, iAuthId, sizeof(iAuthId));

		if (StrEqual(AuthId, iAuthId, true))
			return i;
	}

	return 0;
}
stock StoreClientLastInfo(client)
{
	char AuthId[35], Name[64];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	Format(Name, sizeof(Name), "%N", client);
	StoreAuthIdLastInfo(AuthId, Name);
}

stock StoreAuthIdLastInfo(const char[] AuthId, const char[] Name)
{
	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Members SET LastName = '%s', LastConnect = %i WHERE AuthId = '%s'", Name, GetTime(), AuthId);

	SQL_TQuery(dbGangs, SQLCB_Error, sQuery, 9, DBPrio_Low);
}

stock SetAuthIdRank(const char[] AuthId, const char[] GangTag, int Rank = RANK_MEMBER)
{
	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Members SET GangRank = %i WHERE AuthId = '%s' AND GangTag = '%s'", Rank, AuthId, GangTag);
	SQL_TQuery(dbGangs, SQLCB_Error, sQuery, 10);

	UpdateInGameAuthId(AuthId);
}

stock DonateToGang(client, amount)
{
	if (!IsValidPlayer(client))
		return;

	else if (!IsClientGang(client))
		return;

	char AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = GangCash + %i WHERE GangTag = '%s'", amount, ClientTag[client]);

	Handle DP = CreateDataPack();

	WritePackString(DP, ClientTag[client]);

	SQL_TQuery(dbGangs, SQLCB_GangDonated, sQuery, DP);

	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "INSERT INTO GangSystem_Donations (GangTag, AuthId, AmountDonated, timestamp) VALUES ('%s', '%s', %i, %i)", ClientTag[client], AuthId, amount, GetTime());

	SQL_TQuery(dbGangs, SQLCB_Error, sQuery, 11);

	GiveClientCash(client, BANK_CASH, -1 * amount);

	PrintToChatGang(ClientGang[client], "\x05%N \x01has donated \x07$%i \x01to the gang!", client, amount);
}

public SQLCB_GangDonated(Handle owner, Handle hndl, const char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	char GangTag[32];
	ResetPack(DP);

	ReadPackString(DP, GangTag, sizeof(GangTag));

	CloseHandle(DP);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		else if (!StrEqual(ClientTag[i], GangTag, true))
			continue;

		LoadClientGang(i);
	}
}
bool IsClientGang(client)
{
	return ClientGang[client][0] != EOS ? true : false;
}

stock GetClientRank(client)
{
	return ClientRank[client];
}

// returns true if the clients are in the same gang, or if checking the same client while he has a gang.
bool AreClientsSameGang(client, otherclient)
{
	if (!IsClientGang(client) || !IsClientGang(otherclient))
		return false;

	else if (ClientGangCash[client] < 0 || ClientGangCash[otherclient] < 0)
		return false;

	// If you wanna change case sensitive to true, check "ClientGang[inviter]" in the code

	return StrEqual(ClientGang[client], ClientGang[otherclient], true);
}

stock PrintToChatGang(const char[] GangName, const char[] format, any ...)
{
	char buffer[291];
	VFormat(buffer, sizeof(buffer), format, 3);

	char finalBuffer[291];
	finalBuffer = " \x01";
	StrCat(finalBuffer, sizeof(finalBuffer), buffer);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (IsFakeClient(i))
			continue;

		else if (!StrEqual(ClientGang[i], GangName, true))
			continue;

		PrintToChat(i, finalBuffer);
	}
}

bool IsValidPlayer(client)
{
	if (client <= 0)
		return false;

	else if (client > MaxClients)
		return false;

	return IsClientInGame(client);
}

stock GetRankName(int Rank, char[] buffer, int length)
{
	switch (Rank)
	{
		case RANK_MEMBER: Format(buffer, length, "Member");
		case RANK_OFFICER: Format(buffer, length, "Officer");
		case RANK_ADMIN: Format(buffer, length, "Admin");
		case RANK_MANAGER: Format(buffer, length, "Manager");
		case RANK_COLEADER: Format(buffer, length, "Co-Leader");
		case RANK_LEADER: Format(buffer, length, "Leader");
	}
}

bool CheckGangAccess(client, Rank)
{
	return (GetClientRank(client) >= Rank);
}

bool IsStringNumber(const char[] source)
{
	if (!IsCharNumeric(source[0]) && source[0] != '-')
		return false;

	for (int i = 1; i < strlen(source); i++)
	{
		if (!IsCharNumeric(source[i]))
			return false;
	}

	return true;
}

bool StringHasInvalidCharacters(const char[] source)
{
	for (int i = 0; i < strlen(source); i++)
	{
		if (!IsCharNumeric(source[i]) && !IsCharAlpha(source[i]) && source[i] != '-' && source[i] != '_' && source[i] != ' ')
			return true;
	}

	return false;
}

stock GetEntityHealth(entity)
{
	return GetEntProp(entity, Prop_Send, "m_iHealth");
}

stock GetUpgradeCost(CurrentPerkLevel, PerkCost)
{
	return (CurrentPerkLevel + 1) * PerkCost;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Get_User_Gang", Native_GetClientGangId);
	CreateNative("Get_User_Gang_Tax", Native_GetClientGangTax);
	CreateNative("Is_User_Gang", Native_GetClientGangRank);
	CreateNative("Are_Users_Same_Gang", Native_AreClientsSameGang);
	CreateNative("Get_User_Gang_Name", Native_GetGangName);
	CreateNative("Get_User_Gang_Tag", Native_GetGangTag);
	CreateNative("Get_User_GangBank", Native_GetClientGangBank);
	CreateNative("Set_User_GangBank", Native_SetClientGangBank);
	CreateNative("Add_User_GangBank", Native_AddClientGangBank);
	CreateNative("Add_GangBank", Native_AddGangBank);
	CreateNative("Add_User_Gang_Donations", Native_AddClientDonations);
	CreateNative("Is_User_Manage_Gang_Door", Native_CanClientManageGangDoor);
	CreateNative("Is_User_Gang_Give_Keys", Native_CanClientGiveDoorKeys);
	CreateNative("Get_User_Luck_Bonus", Native_GetClientLuckBonus);

	RegPluginLibrary("JB Gangs");

	return APLRes_Success;
}

public int Native_GetClientGangId(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (ClientGangCash[client] < 0)
		return -1;

	return GetClientGangId(client);
}

public int Native_GetClientGangTax(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	return ClientGangTax[client];
}

public int Native_GetClientGangRank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return ClientRank[client];
}

public int Native_AreClientsSameGang(Handle plugin, int numParams)
{
	int client      = GetNativeCell(1);
	int otherClient = GetNativeCell(2);

	return AreClientsSameGang(client, otherClient);
}

public int Native_GetGangName(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int len    = GetNativeCell(3);

	if (!IsClientGang(client))
	{
		return;
	}
	SetNativeString(2, ClientGang[client], len, false);
}

public int Native_GetGangTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int len    = GetNativeCell(3);

	if (!IsClientGang(client))
	{
		return;
	}
	SetNativeString(2, ClientTag[client], len, false);
}

public int Native_PrintToChatGang(Handle plugin, int numParams)
{
	char GangName[32];

	GetNativeString(1, GangName, sizeof(GangName));
	char buffer[192];

	FormatNativeString(0, 2, 3, sizeof(buffer), _, buffer);

	PrintToChatGang(GangName, buffer);
}

public int Native_GetClientGangBank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	return ClientGangCash[client];
}

public int Native_SetClientGangBank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = %i WHERE GangTag = '%s'", amount, ClientTag[client]);

	Handle DP = CreateDataPack();

	WritePackString(DP, ClientTag[client]);

	SQL_TQuery(dbGangs, SQLCB_GangDonated, sQuery, DP);
}

public int Native_AddClientGangBank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = GangCash + %i WHERE GangTag = '%s'", amount, ClientTag[client]);

	Handle DP = CreateDataPack();

	WritePackString(DP, ClientTag[client]);

	SQL_TQuery(dbGangs, SQLCB_GangDonated, sQuery, DP);
}

public int Native_AddGangBank(Handle plugin, int numParams)
{
	char GangTag[32];

	GetNativeString(1, GangTag, sizeof(GangTag));

	int amount = GetNativeCell(2);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = GangCash + %i WHERE GangTag = '%s'", amount, GangTag);

	Handle DP = CreateDataPack();

	WritePackString(DP, GangTag);

	SQL_TQuery(dbGangs, SQLCB_GangDonated, sQuery, DP);
}

public int Native_AddClientDonations(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int amount = GetNativeCell(2);

	if (amount < 100)
		return;

	char AuthId[35];
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "INSERT INTO GangSystem_Donations (GangTag, AuthId, AmountDonated, timestamp) VALUES ('%s', '%s', %i, %i)", ClientTag[client], AuthId, amount, GetTime());

	Handle DP = CreateDataPack();

	WritePackString(DP, ClientTag[client]);

	SQL_TQuery(dbGangs, SQLCB_GangDonated, sQuery, DP);
}

public int Native_GetUserGangBank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	return ClientGangCash[client];
}

public int Native_SetUserGangBank(Handle plugin, int numParams)
{
	char GangTag[32];

	GetNativeString(1, GangTag, sizeof(GangTag));
	int amount = GetNativeCell(2);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = %i WHERE GangTag = '%s'", amount, GangTag);

	Handle DP = CreateDataPack();

	WritePackString(DP, GangTag);

	SQL_TQuery(dbGangs, SQLCB_GiveGangHonor, sQuery, DP);
}

public int Native_AddUserGangBank(Handle plugin, int numParams)
{
	char GangTag[32];

	GetNativeString(1, GangTag, sizeof(GangTag));
	int amount = GetNativeCell(2);

	char sQuery[256];
	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "UPDATE GangSystem_Gangs SET GangCash = GangCash + %i WHERE GangTag = '%s'", amount, GangTag);

	Handle DP = CreateDataPack();

	WritePackString(DP, GangTag);

	SQL_TQuery(dbGangs, SQLCB_GiveGangHonor, sQuery, DP);
}

public int Native_CanClientManageGangDoor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientGang(client))
		return false;

	return CheckGangAccess(client, ClientAccessManageMoney[client]);
}

public int Native_CanClientGiveDoorKeys(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientGang(client))
		return false;

	return CheckGangAccess(client, ClientAccessGiveKeys[client]);
}

public int Native_GetClientLuckBonus(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientGang(client))
		return 0;

	if (g_iThiefJob == -1)
	{
		g_iThiefJob = RP_FindJobByShortName("TH");
	}

	int totalLuck = ClientLuckPerk[client] * GANG_LUCKINCREASE;

	if (RP_GetClientLevel(client, g_iThiefJob) >= 8)
		totalLuck += 10;

	else if (RP_GetClientLevel(client, g_iThiefJob) >= 5)
		totalLuck += 5;

	return totalLuck;
}

public SQLCB_GiveGangHonor(Handle owner, Handle hndl, char[] error, Handle DP)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	ResetPack(DP);

	char GangTag[32];
	ReadPackString(DP, GangTag, sizeof(GangTag));

	CloseHandle(DP);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidPlayer(i))
			continue;

		else if (!StrEqual(ClientTag[i], GangTag, true))
			continue;

		LoadClientGang(i);
	}
}

stock LogGangAction(const char[] format, any ...)
{
	char buffer[291], Path[256];
	VFormat(buffer, sizeof(buffer), format, 2);

	BuildPath(Path_SM, Path, sizeof(Path), "logs/JailBreakGangs.txt");
	LogToFile(Path, buffer);
}

bool IsKnifeClass(const char[] classname)
{
	if (StrContains(classname, "knife") != -1 || StrContains(classname, "bayonet") > -1)
		return true;

	return false;
}

stock GetAliveTeamCount(Team)
{
	int count = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		else if (GetClientTeam(i) != Team)
			continue;

		else if (!IsPlayerAlive(i))
			continue;

		count++;
	}

	return count;
}

stock GetClientGangId(client)
{
	return FindStringInArray(Array_GangIds, ClientTag[client]);
}

/*stock int SQL_FetchStringByName(Handle:hndl, const String:name[], String:buffer[], bufferLen)
{
    int field;

    if(!SQL_FieldNameToNum(hndl, name, field))
        return -1;

    return SQL_FetchString(hndl, field, buffer, bufferLen);
}
*/
AddCommas(int value, const char[] seperator, char[] buffer, int bufferLen)
{
	int divisor = 1000;
	while (value >= 1000 || value <= -1000)
	{
		int offcut = value % divisor;
		value      = RoundToFloor(float(value) / float(divisor));
		Format(buffer, bufferLen, "%c%03.d%s", seperator, offcut, buffer);
	}
	Format(buffer, bufferLen, "%d%s", value, buffer);
}

stock SetClientNameHidden(client, const char[] Name)
{
	HookUserMessage(GetUserMessageId("SayText2"), hook_alwaysBlock, true);
	HookUserMessage(GetUserMessageId("SayText"), hook_alwaysBlock, true);
	HookUserMessage(GetUserMessageId("TextMsg"), hook_alwaysBlock, true);

	SetClientName(client, Name);

	UnhookUserMessage(GetUserMessageId("SayText2"), hook_alwaysBlock, true);
	UnhookUserMessage(GetUserMessageId("SayText"), hook_alwaysBlock, true);
	UnhookUserMessage(GetUserMessageId("TextMsg"), hook_alwaysBlock, true);

}

public Action hook_alwaysBlock(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	return Plugin_Handled;
}

stock TryRemoveGangPrefix(client)
{
	char Name[64];

	GetClientName(client, Name, sizeof(Name));

	if (ClientPrefix[client][0] != EOS)
	{
		if (StrContains(Name, ClientPrefix[client]) == 0)    // Client's name starts with the prefix.
		{
			ReplaceStringEx(Name, sizeof(Name), ClientPrefix[client], "");

			SetClientNameHidden(client, Name);
		}
	}
}

stock FindDonationsForGang(const char[] GangTag)
{
	char sQuery[256];

	SQL_FormatQuery(dbGangs, sQuery, sizeof(sQuery), "SELECT * FROM GangSystem_Donations WHERE GangTag = '%s' ORDER BY AuthId", GangTag);

	SQL_TQuery(dbGangs, SQLCB_FindDonations, sQuery);
}

public SQLCB_FindDonations(Handle owner, Handle hndl, char[] error, any data)
{
	if (hndl == null)
	{
		LogError(error);

		return;
	}

	if (SQL_GetRowCount(hndl) != 0)
	{
		DBResultSet query = view_as<DBResultSet>(hndl);

		int amount;
		int amountWeek;

		char LastAuthId[35];

		char AuthId[35];

		while (SQL_FetchRow(hndl))
		{
			SQL_FetchStringByName(query, "AuthId", AuthId, sizeof(AuthId));

			if (LastAuthId[0] == EOS)
				strcopy(LastAuthId, sizeof(LastAuthId), AuthId);

			if (!StrEqual(AuthId, LastAuthId))
			{
				SetTrieValue(Trie_Donated, LastAuthId, amount);
				SetTrieValue(Trie_DonatedWeek, LastAuthId, amountWeek);

				amount     = 0;
				amountWeek = 0;
			}

			strcopy(LastAuthId, sizeof(LastAuthId), AuthId);

			int donated = SQL_FetchIntByName(query, "AmountDonated");

			amount += donated;

			if (RoundToFloor(float(GetTime()) / 604800.0) == RoundToFloor(float(SQL_FetchIntByName(query, "timestamp")) / 604800.0))
				amountWeek += donated;
		}

		SetTrieValue(Trie_Donated, LastAuthId, amount);
		SetTrieValue(Trie_DonatedWeek, LastAuthId, amountWeek);
	}
}

stock Abs(value)
{
	if (value < 0)
		return -1 * value;

	return value;
}
