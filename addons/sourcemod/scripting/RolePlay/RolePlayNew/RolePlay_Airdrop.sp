#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Totenfluch"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <multicolors>
#include <smlib>
#include <emitsoundany>
#include <sdkhooks>
#include <map_workshop_functions>
#include <autoexecconfig>
#include <Eyal-RP>

#define MAX_AIRDROPS 1024

#define DOLLARS_PER_EXP_LOST 100 // Amount of $ to multiply the EXP gained if the player has no job at the moment

enum PrizeTypes
{
	PRIZE_NULL=0,
	PRIZE_CASH,
	PRIZE_EXP,
	PRIZE_WEAPON,
}	

enum struct enPrizes
{
	char PrizeName[32];
	int PrizeCount;
	PrizeTypes PrizeType;
	int PrizeWeight; // Prize weight is how likely it is to win relative to others. When you spin the wheel, the actual chance of you getting an item is PrizeWeight divided by the prize weight of all other prizes.
}

enPrizes Prizes[] =
{ 
	{ "Negev", 1, PRIZE_WEAPON,    200 },
    { "250 EXP", 250, PRIZE_EXP,    1 },
    { "Scar-20", 1, PRIZE_WEAPON,    200 },
    { "$15,000", 15000, PRIZE_CASH,    50 },
    { "150 EXP", 150, PRIZE_EXP,     9 },
    { "$12,500", 12500, PRIZE_CASH,     40 },
    { "Shield", 1, PRIZE_WEAPON,     100 },
    { "Breach Charge", 1, PRIZE_WEAPON,     100 },
    { "AK47", 1, PRIZE_WEAPON,         300 }
};

EngineVersion g_Game;

// Airdrop
int AirdropHeight = 650;
int HelicoAllowToSound[MAXPLAYERS + 1];

// LOOOOT
//bool g_bChestLooted[MAXPLAYERS + 1];

// Plane
int AirPlaneOne = -1;
float AirPlaneOnePos[3];
float AirPlaneOneStartPos;
bool AirPlaneFlying = false;

// Buttons for the Pickup with E
int g_iPlayerPrevButtons[MAXPLAYERS + 1];

int g_iSpawnCounter = 0;

enum struct Airdrop {
	float gXPos;
	float gYPos;
	float gZPos;
	bool gIsActive;
	int gAirdropRef;
}
/*
new const String:WeaponList[][] = 
{
	"weapon_deagle",
	"weapon_usp_silencer",
	"weapon_tec9",
	"weapon_m4a1",
	"weapon_ak47",
	"weapon_awp",
	"weapon_ssg08"
};

new const String:WeaponNames[][] = 
{
	"Desert-Eagle",
	"USP-S",
	"Tec-9",
	"M4A4",
	"AK-47",
	"AWP",
	"SSG-08"
	
};

*/
Airdrop g_eAirdropSpawnPoints[MAX_AIRDROPS];
int g_iLoadedAirdrops = 0;

int g_iBlueGlow;

Handle g_hTimeToAirdrop;
int g_iTimeToAirdrop;

Handle g_hMaxLootable;
int g_iMaxLootable;

Handle g_hCreditAmount;
int g_iCreditAmount;

Handle g_hTickRate;
int g_iTickRate;

public Plugin myinfo = 
{
	name = "T-Airdrop", 
	author = PLUGIN_AUTHOR, 
	description = "Spawns an Airdrop", 
	version = PLUGIN_VERSION, 
	url = "http://ggc-base.de"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if (g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	//HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_RoundStart);
	RegAdminCmd("sm_airdrop", cmd_SpawnAirdrop, ADMFLAG_ROOT, "Spawn an Airdrop");
	RegAdminCmd("sm_airdropspawns", addSpawnPointsMenu, ADMFLAG_ROOT, "Opens the Airdrop spawn menu");
	
	AutoExecConfig_SetFile("Airdrop");
	AutoExecConfig_SetCreateFile(true);
	
	g_hTimeToAirdrop = AutoExecConfig_CreateConVar("airdrop_timeToSpawn", "2147483647", "Seconds after Roundstart to spawn the drop");
	g_hMaxLootable = AutoExecConfig_CreateConVar("airdrop_maxLootable", "1", "How many people can loot the chest before it disappears");
	g_hCreditAmount = AutoExecConfig_CreateConVar("airdrop_credits", "1500", "Credits to give on chest looted");
	g_hTickRate = AutoExecConfig_CreateConVar("airdrop_tickrate", "1", "1 -> 64 Ticks | 2 -> 128 Ticks");
	
	AutoExecConfig_CleanFile();
	AutoExecConfig_ExecuteFile();
}

public OnPluginEnd()
{
	new entity = -1;
	
	while((entity = FindEntityByTargetname(entity, "AirDrop_", false, true)) != -1)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public OnMapStart() {	
	CreateTimer(2700.0, Timer_SummonAirDrop, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	
	//CreateTimer(1.0, RefreshTimer, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	AddFileToDownloadsTable("materials/models/parachute/pack.vmt");
	AddFileToDownloadsTable("materials/models/parachute/pack.vtf");
	AddFileToDownloadsTable("materials/models/parachute/pack_carbon.vmt");
	AddFileToDownloadsTable("materials/models/parachute/pack_carbon.vtf");
	AddFileToDownloadsTable("materials/models/parachute/parachute_carbon.vmt");
	AddFileToDownloadsTable("materials/models/parachute/parachute_carbon.vtf");
	
	AddFileToDownloadsTable("models/parachute/parachute_carbon.dx80.vtx");
	AddFileToDownloadsTable("models/parachute/parachute_carbon.dx90.vtx");
	AddFileToDownloadsTable("models/parachute/parachute_carbon.mdl");
	AddFileToDownloadsTable("models/parachute/parachute_carbon.sw.vtx");
	AddFileToDownloadsTable("models/parachute/parachute_carbon.vvd");
	AddFileToDownloadsTable("models/parachute/parachute_carbon.xbox.vtx");
	
	// PLANE FOR AIRDROP
	PrecacheModel("models/prop_vehicles/helicopter_rescue.mdl");
	// BOX
	PrecacheModel("models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_96_e.mdl");
	PrecacheModel("models/parachute/parachute_carbon.mdl", true);
	PrecacheSoundAny("vehicles/loud_helicopter_lp_01.wav", true);
	
	forceReload();
}

public Action Timer_SummonAirDrop(Handle hTimer)
{
	CreateTimer(1.0, Timer_CountDownAirDrop, 11, TIMER_FLAG_NO_MAPCHANGE);
		
	// BAR COLOR
	RP_PrintToChatAll("Server Drop \x07Started");
}

public Action Timer_CountDownAirDrop(Handle hTimer, int TimeLeft)
{	
	TimeLeft--;

	if(TimeLeft == 0)
	{
		TriggerRoundDrop();
	}
	else
	{
		SetHudMessage(-1.0, -1.0, 0.9, 0, 50, 255);
		ShowHudMessage(0, 3, "Airdrop will arrive in\n%i Second%s\n", TimeLeft, TimeLeft > 1 ? "s" : "");
		
		CreateTimer(1.0, Timer_CountDownAirDrop, TimeLeft, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public void forceReload() {
	for (int i = 0; i < MAX_AIRDROPS; i++) {
		g_eAirdropSpawnPoints[i].gXPos = -1.0;
		g_eAirdropSpawnPoints[i].gYPos = -1.0;
		g_eAirdropSpawnPoints[i].gZPos = -1.0;
		g_eAirdropSpawnPoints[i].gIsActive = false;
	}
	g_iLoadedAirdrops = 0;
	g_iBlueGlow = PrecacheModel("sprites/blueglow1.vmt");
	loadAirdropSpawnPoints();
}

public void OnConfigsExecuted() {
	g_iTimeToAirdrop = GetConVarInt(g_hTimeToAirdrop);
	g_iMaxLootable = GetConVarInt(g_hMaxLootable);
	g_iCreditAmount = GetConVarInt(g_hCreditAmount);
	g_iTickRate = GetConVarInt(g_hTickRate);
}

public Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_iSpawnCounter = 0;
}

public Action RefreshTimer(Handle Timer) {
	g_iSpawnCounter++;
	if (g_iSpawnCounter == g_iTimeToAirdrop) {
		PrintHintTextToAll("Airdrop Incoming!");
		TriggerRoundDrop();
	}
}

public void TriggerRoundDrop() {
	if (g_iLoadedAirdrops == 0)
	{
		PrintToChatEyal("g_iLoadedAirdrops = false");
		return;
	}	
	int selected = GetRandomInt(0, g_iLoadedAirdrops - 1);
	float pos[3];
	pos[0] = g_eAirdropSpawnPoints[selected].gXPos;
	pos[1] = g_eAirdropSpawnPoints[selected].gYPos;
	pos[2] = g_eAirdropSpawnPoints[selected].gZPos;
	SetupAirDrop(pos, 1);
}

public Action cmd_SpawnAirdrop(int client, int args) {

	if(!IsPlayerAlive(client))
	{
		RP_PrintToChat(client, "You cannot do !airdrop when dead.");
		
		return Plugin_Handled;
	}
	
	else if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		RP_PrintToChat(client, "You cannot do !airdrop when not standing still.");
		
		return Plugin_Handled;
	}
	float vecPosition[3];
	float vecAngle[3];
	GetClientAbsAngles(client, vecAngle);
	GetClientAbsOrigin(client, vecPosition);
	RP_PrintToChatAll("Player \x07%N \x01index \x04%i \x01origin %0.2f  %0.2f %0.2f", client, client, vecPosition[0], vecPosition[1], vecPosition[2]);
	SetupAirDrop(vecPosition, 1);
	return Plugin_Handled;
}
/*
public Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_bChestLooted[client] = false;
}
*/
// Looting
public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon, int &tickcount) {
	if (!(g_iPlayerPrevButtons[client] & IN_USE) && iButtons & IN_USE)
	{
		if (IsPlayerAlive(client)/* && !g_bChestLooted[client]*/)
		{
			int TargetObject = GetTargetBlock(client);
			if (IsValidEntity(TargetObject))
			{
				float ObjectOrigin[3];
				float PlayerOrigin[3];
				
				GetEntPropVector(TargetObject, Prop_Send, "m_vecOrigin", ObjectOrigin);
				GetClientAbsOrigin(client, PlayerOrigin);
				
				float distance = GetVectorDistance(ObjectOrigin, PlayerOrigin);
				
				if (distance < 128.0) {
					char ObjectName[120];
					Entity_GetGlobalName(TargetObject, ObjectName, sizeof(ObjectName));
					if (StrContains(ObjectName, "AirdropBox") != -1)
					{
						Entity_SetGlobalName(TargetObject, "AcceptEntityInput Kill");
						
						AcceptEntityInput(TargetObject, "Kill");
						
						int TotalWeight;
						for(int i=0;i < sizeof(Prizes);i++)
						{
							TotalWeight += Prizes[i].PrizeWeight;
						}
						
						int LuckyNumber = GetRandomInt(1, TotalWeight);
						
						int LuckyItem;
						
						int RelativeTotalWeight = 0;
						
						for(int i=0;i < sizeof(Prizes);i++)
						{
							if(LuckyNumber <= RelativeTotalWeight + Prizes[i].PrizeWeight)
							{
								LuckyItem = i;
								
								break;
							}	
							
							RelativeTotalWeight += Prizes[i].PrizeWeight;
							
						}
						
						switch(Prizes[LuckyItem].PrizeType)
						{
							case PRIZE_CASH:
							{
								GiveClientCash(client, BANK_CASH, Prizes[LuckyItem].PrizeCount);
							}
							
							case PRIZE_EXP:
							{
								new job = RP_GetClientJob(client);
								
								if(job == -1)
								{
									new cash = Prizes[LuckyItem].PrizeCount * DOLLARS_PER_EXP_LOST;
									GiveClientCash(client, BANK_CASH, cash);
									
									// BAR COLOR
									RP_PrintToChat(client, "You have no job and therefore you gained \x07$%i", cash);
								}
								else
								{
									RP_AddClientEXP(client, job, Prizes[LuckyItem].PrizeCount);
								}
							}
							
							case PRIZE_WEAPON:
							{
								new String:Classname[64];
								
								FormatEx(Classname, sizeof(Classname), "weapon_%s", Prizes[LuckyItem].PrizeName);
								
								ReplaceString(Classname, sizeof(Classname), "-", "");
								ReplaceString(Classname, sizeof(Classname), " ", "");
								StringToLower(Classname);
								
								GivePlayerItem(client, Classname);
							}
						}	
						
						RP_PrintToChatAll("\x02%N \x01got the helicopter drop \x07%s! ( %.2f%% )", client, Prizes[LuckyItem].PrizeName, float(Prizes[LuckyItem].PrizeWeight) / float(TotalWeight) * 100.0);
						/*
						g_bChestLooted[client] = true;	
								
						if (getPeopleLootedChest() >= g_iMaxLootable)
						{
							AcceptEntityInput(TargetObject, "kill");
						}
						*/
					}
				}
			}
		}
	}
	
	g_iPlayerPrevButtons[client] = iButtons;
}
/*
public int getPeopleLootedChest() {
	int looted = 0;
	for (int i = 1; i < MAXPLAYERS; i++) {
		if (g_bChestLooted[i])
			looted++;
	}
	return looted;
}
*/
stock int GetTargetBlock(int client)
{
	int entity = GetClientAimTarget(client, false);
	if (IsValidEntity(entity))
	{
		char classname[32];
		GetEdictClassname(entity, classname, 32);
		
		if (StrContains(classname, "prop_physics_multiplayer") != -1 || StrContains(classname, "prop_physics") != -1)
			return entity;
	}
	return -1;
}

// AIRDROP /////////////////
public void SetupAirDrop(float fPos[3], int which) {
	/*
	for (int i = 1; i < MAXPLAYERS; i++) {
		g_bChestLooted[i] = false;
	}
	*/
	int entity = CreateFlair(fPos);
	
	DataPack pack = new DataPack();
	pack.WriteCell(entity);
	pack.WriteCell(which);
	pack.WriteFloat(fPos[0]);
	pack.WriteFloat(fPos[1]);
	pack.WriteFloat(fPos[2]);
	StartPlane(fPos);
	CreateTimer(5.0, TriggerDrop, pack);
}

public void StartPlane(float fPos[3]) {
	fPos[2] += 700.0;
	fPos[0] -= 3550.0;
	
	if(AirPlaneOne != -1)
	{
		AcceptEntityInput(AirPlaneOne, "Kill");
	}
	AirPlaneOne = CreateEntityByName("prop_dynamic");
	if (AirPlaneOne != -1)
	{
		SetEntProp(AirPlaneOne, Prop_Send, "m_hOwnerEntity", 0);
		//DispatchKeyValue(AirPlaneOne, "model", "models/f18/f18.mdl");
		DispatchKeyValue(AirPlaneOne, "model", "models/props_vehicles/helicopter_rescue.mdl");
		SetEntPropFloat(AirPlaneOne, Prop_Send, "m_flModelScale", 1.3);
		DispatchSpawn(AirPlaneOne);
		SetEntityMoveType(AirPlaneOne, MOVETYPE_NOCLIP);
		TeleportEntity(AirPlaneOne, fPos, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(0.1, SetAnimation, AirPlaneOne);
	}
	
	AirPlaneOnePos[0] = fPos[0];
	AirPlaneOnePos[1] = fPos[1];
	AirPlaneOnePos[2] = fPos[2];
	AirPlaneOneStartPos = fPos[0];
	AirPlaneFlying = true;
}

public Action SetAnimation(Handle Timer, any entity) {
	// The animation actually is named "3ready" and not "ready"
	SetVariantString("3ready");
	AcceptEntityInput(entity, "SetAnimation");
}

public void OnGameFrame() {
	AirPlaneOnePos[0] += (11.5 / g_iTickRate);
	if (AirPlaneFlying && AirPlaneOne != -1) {
		if (IsValidEntity(AirPlaneOne)) {
			TeleportEntity(AirPlaneOne, AirPlaneOnePos, NULL_VECTOR, NULL_VECTOR);
			if (AirPlaneOnePos[0] > (AirPlaneOneStartPos + 8000.0)) {
				AcceptEntityInput(AirPlaneOne, "kill");
				AirPlaneFlying = false;
				
			}
			
			CreateSound(AirPlaneOne, "vehicles/loud_helicopter_lp_01.wav");
			
			if(!AirPlaneFlying)
				AirPlaneOne = -1;
		}
	}
}

public void CreateSound(int edict, char[] sound)
{
	if(!AirPlaneFlying)
	{
		RemoveSound(edict, sound);
		return;
	}
	int CHANNEL = 100 + 24;
	int LEVEL = SNDLEVEL_HELICOPTER;
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			float target[3];
			GetClientAbsOrigin(i, target);
			float distance = GetVectorDistance(AirPlaneOnePos, target);
			
			if (distance > 0 && distance < 500)
			{
				if (HelicoAllowToSound[i] != 1)
				{
					EmitSoundToClientAny(i, sound, edict, CHANNEL, LEVEL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, _, _, _, _, _);
					HelicoAllowToSound[i] = 1;
				}
			} else if (distance > 501 && distance < 1500) {
				if (HelicoAllowToSound[i] != 2)
				{
					EmitSoundToClientAny(i, sound, edict, CHANNEL, LEVEL, SND_NOFLAGS, 0.8, SNDPITCH_NORMAL, _, _, _, _, _);
					HelicoAllowToSound[i] = 2;
				}
			} else if (distance > 1501 && distance < 2500) {
				if (HelicoAllowToSound[i] != 3)
				{
					EmitSoundToClientAny(i, sound, edict, CHANNEL, LEVEL, SND_NOFLAGS, 0.6, SNDPITCH_NORMAL, _, _, _, _, _);
					HelicoAllowToSound[i] = 3;
				}
			} else if (distance > 2501 && distance < 4000) {
				if (HelicoAllowToSound[i] != 4)
				{
					EmitSoundToClientAny(i, sound, edict, CHANNEL, LEVEL, SND_NOFLAGS, 0.4, SNDPITCH_NORMAL, _, _, _, _, _);
					HelicoAllowToSound[i] = 4;
				}
			} else if(distance > 4001) {
				if (HelicoAllowToSound[i] != 0)
				{
					RemoveSound(edict, sound);
				}
			}
		}
	}
}

void RemoveSound(int edict, char[] sound)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			EmitSoundToClientAny(i, sound, edict, 100 + 24, SNDLEVEL_NORMAL, SND_STOPLOOPING, SNDVOL_NORMAL, SNDPITCH_NORMAL, _, _, _, _, 0.0);
			HelicoAllowToSound[i] = 0;
		}
	}
}


public int CreateFlair(float pos[3]) {
	pos[2] += 5.0;
	
	int GLOW_ENTITY = CreateEntityByName("env_glow");
	SetEntProp(GLOW_ENTITY, Prop_Data, "m_nBrightness", 70, 4);
	DispatchKeyValue(GLOW_ENTITY, "model", "sprites/ledglow.vmt");
	DispatchKeyValue(GLOW_ENTITY, "rendermode", "3");
	DispatchKeyValue(GLOW_ENTITY, "renderfx", "14");
	DispatchKeyValue(GLOW_ENTITY, "scale", "5.0");
	DispatchKeyValue(GLOW_ENTITY, "renderamt", "255");
	DispatchKeyValue(GLOW_ENTITY, "rendercolor", "255 255 255 255");
	DispatchSpawn(GLOW_ENTITY);
	AcceptEntityInput(GLOW_ENTITY, "ShowSprite");
	TeleportEntity(GLOW_ENTITY, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(GLOW_ENTITY, "TurnOn");
	return GLOW_ENTITY;
}

public Action TriggerDrop(Handle Timer, any data) {
	float pos[3];
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int entity = pack.ReadCell();
	int which = pack.ReadCell();
	pos[0] = pack.ReadFloat();
	pos[1] = pack.ReadFloat();
	pos[2] = pack.ReadFloat();
	SpawnAirDrop(pos, which);
	CreateTimer(10.0, KillEntity, entity);
}

public Action KillEntity(Handle Timer, int entity) {
	AcceptEntityInput(entity, "kill");
}

public int SpawnAirDrop(float fPos[3], int which) {
	fPos[2] += AirdropHeight;
	int iEntity = CreateEntityByName("prop_physics_override");
	if (iEntity == -1)
		return -1;
	
	char AirBoxName[64];
	Format(AirBoxName, sizeof(AirBoxName), "AirdropBox_%i", which);
	SetEntityModel(iEntity, "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_96_e.mdl");
	DispatchKeyValue(iEntity, "disablereceiveshadows", "1");
	DispatchKeyValue(iEntity, "disableshadows", "1");
	SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", COLLISION_GROUP_PUSHAWAY);
	DispatchSpawn(iEntity);
	SetEntityMoveType(iEntity, MOVETYPE_VPHYSICS);
	float fAngle[3];
	fAngle[1] = GetRandomFloat(0.0, 360.0);
	TeleportEntity(iEntity, fPos, fAngle, NULL_VECTOR);
	Entity_SetGlobalName(iEntity, AirBoxName);
	
	CreateTimer(600.0, Timer_ExpireDrop, EntIndexToEntRef(iEntity), TIMER_FLAG_NO_MAPCHANGE);
	
	SDKHook(iEntity, SDKHook_OnTakeDamage, SDKEvent_NeverTakeDamage);
	//makeLightDynamic(iEntity, fPos);
	
	fPos[2] += 60.0;
	
	int ParaIndex = CreateEntityByName("prop_dynamic_override");
	if (ParaIndex != -1)
	{
		SetEntProp(ParaIndex, Prop_Send, "m_hOwnerEntity", 0);
		DispatchKeyValue(ParaIndex, "model", "models/parachute/parachute_carbon.mdl");
		DispatchSpawn(ParaIndex);
		TeleportEntity(ParaIndex, fPos, NULL_VECTOR, NULL_VECTOR);
		SetVariantString("!activator");
		AcceptEntityInput(ParaIndex, "SetParent", iEntity, ParaIndex, 0);
	}
	
	DataPack pack = new DataPack();
	pack.WriteCell(EntIndexToEntRef(iEntity));
	pack.WriteCell(EntIndexToEntRef(ParaIndex));
	pack.WriteFloat(fPos[2]);
	pack.WriteFloat(fPos[2]);
	CreateTimer(0.01, AnimateAirDrop, pack);
	//SetVariantString("deploy");
	//AcceptEntityInput(ParaIndex, "SetAnimation");
	return iEntity;
}

public Action:Timer_ExpireDrop(Handle:hTimer, Ref)
{
	new entity = EntRefToEntIndex(Ref);
	
	if(entity != INVALID_ENT_REFERENCE)
		AcceptEntityInput(entity, "Kill");
}

public Action:SDKEvent_NeverTakeDamage(victimEntity)
{
	return Plugin_Handled;
}	
public Action AnimateAirDrop(Handle Timer, any data) {
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	
	int iEntity = EntRefToEntIndex(pack.ReadCell());
	int ParaIndex = EntRefToEntIndex(pack.ReadCell());
	float startpos = pack.ReadFloat();
	float endpos = pack.ReadFloat();
	
	CloseHandle(pack);
	
	if(iEntity == INVALID_ENT_REFERENCE)
	{
		if(ParaIndex != INVALID_ENT_REFERENCE)
			AcceptEntityInput(ParaIndex, "kill");
			
		return;
	}	
	if (startpos - endpos < AirdropHeight) {
		DataPack npack = new DataPack();
		npack.WriteCell(EntIndexToEntRef(iEntity));
		npack.WriteCell(EntIndexToEntRef(ParaIndex));
		npack.WriteFloat(startpos);
		float position[3];
		GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", position);
		float velocity[3];
		velocity[0] = 0.0;
		velocity[1] = 0.0;
		velocity[2] = 6.0;
		float angles[3];
		GetEntPropVector(iEntity, Prop_Data, "m_angRotation", angles);
		TeleportEntity(iEntity, position, NULL_VECTOR, velocity);
		npack.WriteFloat(position[2]);
		position[2] += 55;
		//TeleportEntity(ParaIndex, position, NULL_VECTOR, velocity);
		CreateTimer(0.01, AnimateAirDrop, npack);
	} else {
		//SetVariantString("detach");
		//AcceptEntityInput(ParaIndex, "SetAnimation");
		// CreateTimer(1.5, KillEntity, ParaIndex);
		
		if(ParaIndex != INVALID_ENT_REFERENCE)
			AcceptEntityInput(ParaIndex, "kill");
	}
	
}

int makeLightDynamic(int entity, float pos[3])
{
	pos[2] += 50.0;
	int Ent = CreateEntityByName("light_dynamic");
	DispatchKeyValue(Ent, "_light", "150 50 200 255");
	DispatchKeyValue(Ent, "brightness", "2");
	DispatchKeyValueFloat(Ent, "spotlight_radius", 64.0);
	DispatchKeyValueFloat(Ent, "distance", 3500.0);
	DispatchKeyValue(Ent, "style", "0");
	DispatchKeyValue(Ent, "rendercolor", "150 50 200");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, pos, NULL_VECTOR, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(Ent, "SetParent", entity, Ent, 0);
	
	return Ent;
}


public void loadAirdropSpawnPoints()
{
	char sRawMap[PLATFORM_MAX_PATH];
	char sMap[64];
	GetCurrentMap(sRawMap, sizeof(sRawMap));
	RemoveMapPath(sRawMap, sMap, sizeof(sMap));
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/event_Airdrop/%s.txt", sMap);
	
	Handle hFile = OpenFile(sPath, "r");
	
	char sBuffer[512];
	char sDatas[3][32];
	
	if (hFile != INVALID_HANDLE)
	{
		while (ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
		{
			ExplodeString(sBuffer, ";", sDatas, 3, 32);
			
			g_eAirdropSpawnPoints[g_iLoadedAirdrops].gXPos = StringToFloat(sDatas[0]);
			g_eAirdropSpawnPoints[g_iLoadedAirdrops].gYPos = StringToFloat(sDatas[1]);
			g_eAirdropSpawnPoints[g_iLoadedAirdrops].gZPos = StringToFloat(sDatas[2]);
			
			g_iLoadedAirdrops++;
		}
		
		CloseHandle(hFile);
	}
	PrintToServer("Loaded %i Airdrop Spawn Points", g_iLoadedAirdrops);
}

public void saveAirdropSpawnPoints()
{
	char sRawMap[PLATFORM_MAX_PATH];
	char sMap[64];
	GetCurrentMap(sRawMap, sizeof(sRawMap));
	RemoveMapPath(sRawMap, sMap, sizeof(sMap));
	
	CreateDirectory("configs/event_Airdrop", 511);
	
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/event_Airdrop/%s.txt", sMap);
	
	
	
	Handle hFile = OpenFile(sPath, "w");
	
	if (hFile != INVALID_HANDLE)
	{
		for (int i = 0; i < g_iLoadedAirdrops; i++) {
			WriteFileLine(hFile, "%.2f;%.2f;%.2f;", g_eAirdropSpawnPoints[i].gXPos, g_eAirdropSpawnPoints[i].gYPos, g_eAirdropSpawnPoints[i].gZPos);
		}
		
		CloseHandle(hFile);
	}
	
	if (!FileExists(sPath))
		LogError("Couldn't save Airdrop spawns to  file: \"%s\".", sPath);
}

public void AddLootSpawn(int client, bool vision)
{
	float pos[3];
	if (vision) {
		float ang[3];
		GetClientEyePosition(client, pos);
		GetClientEyeAngles(client, ang);
		TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
		TR_GetEndPosition(pos);
	} else
		GetClientAbsOrigin(client, pos);
	
	TE_SetupGlowSprite(pos, g_iBlueGlow, 10.0, 1.0, 235);
	TE_SendToAll();
	
	g_eAirdropSpawnPoints[g_iLoadedAirdrops].gXPos = pos[0];
	g_eAirdropSpawnPoints[g_iLoadedAirdrops].gYPos = pos[1];
	g_eAirdropSpawnPoints[g_iLoadedAirdrops].gZPos = pos[2];
	g_iLoadedAirdrops++;
	
	RP_PrintToChat(client, "Added new loot spawn at %.2f:%.2f:%.2f, for type: event_Airdrop", pos[0], pos[1], pos[2]);
	saveAirdropSpawnPoints();
}


public Action addSpawnPoints(int client, int args) {
	addSpawnPointsMenu(client, args);
	return Plugin_Handled;
}

public Action addSpawnPointsMenu(int client, int args)
{
	char AirdropText[64];
	char AirdropAim[64];
	
	Format(AirdropText, sizeof(AirdropText), "Spawn: Airdrop (%i)", g_iLoadedAirdrops);
	Format(AirdropAim, sizeof(AirdropAim), "Spawn: Airdrop (%i) [AIM]", g_iLoadedAirdrops);
	
	Handle panel = CreatePanel();
	SetPanelTitle(panel, "Add a Spawnpoint");
	DrawPanelText(panel, "x-x-x-x-x-x-x-x-x-x");
	DrawPanelItem(panel, AirdropText);
	DrawPanelItem(panel, AirdropAim);
	DrawPanelText(panel, "-------------");
	DrawPanelItem(panel, "Show Spawns");
	DrawPanelItem(panel, "Close");
	DrawPanelText(panel, "x-x-x-x-x-x-x-x-x-x");
	
	
	SendPanelToClient(panel, client, addSpawnPointsMenuHandler, 30);
	
	CloseHandle(panel);
	return Plugin_Handled;
}

public int addSpawnPointsMenuHandler(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		if (item == 1) {
			AddLootSpawn(client, false);
			addSpawnPointsMenu(client, 0);
		} else if (item == 2) {
			AddLootSpawn(client, true);
			addSpawnPointsMenu(client, 0);
		} else if (item == 3) {
			ShowSpawns();
			addSpawnPointsMenu(client, 0);
		}
	}
}

public void ShowSpawns() {
	for (int i = 0; i < g_iLoadedAirdrops; i++) {
		float pos[3];
		pos[0] = g_eAirdropSpawnPoints[i].gXPos;
		pos[1] = g_eAirdropSpawnPoints[i].gYPos;
		pos[2] = g_eAirdropSpawnPoints[i].gZPos;
		TE_SetupGlowSprite(pos, g_iBlueGlow, 10.0, 1.0, 235);
		TE_SendToAll();
	}
}

public int getActiveAirdrop() {
	int count = 0;
	for (int i = 0; i < g_iLoadedAirdrops; i++) {
		if (g_eAirdropSpawnPoints[i].gIsActive)
			count++;
	}
	return count;
}

public bool TraceRayDontHitSelf(int entity, int mask, any data) {
	if (entity == data)
		return false;
	return true;
}


stock SetHudMessage(Float:x=-1.0, Float:y=-1.0, Float:HoldTime=6.0, r=255, g=0, b=0, a=255, effects=0, Float:fxTime=12.0, Float:fadeIn=0.0, Float:fadeOut=0.0)
{
	SetHudTextParams(x, y, HoldTime, r, g, b, a, effects, fxTime, fadeIn, fadeOut);
}

stock ShowHudMessage(client, channel = -1, String:Message[], any:...)
{
	new String:VMessage[300];
	VFormat(VMessage, sizeof(VMessage), Message, 4);
	
	if(client != 0)
		ShowHudText(client, channel, VMessage);
	
	else
	{
		for(new i=1;i <= MaxClients;i++)
		{
			if(IsClientInGame(i))
				ShowHudText(i, channel, VMessage);
		}
	}
}