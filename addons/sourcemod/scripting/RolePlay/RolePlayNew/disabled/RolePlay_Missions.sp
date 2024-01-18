#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <Eyal-RP>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "RolePlay - Missions.",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Missions that expire by time.",
	version = PLUGIN_VERSION,
	url = "N/A"
}

new bool:dbFullConnected = false;

new bool:g_bBanCTLoaded = false;

new Handle:dbMissions = INVALID_HANDLE;

new TimeOffset;

enum MissionTypes
{
	MISSION_NULL,
	MISSION_COMPLETE_HITS
}

char MissionTypeNames[][] =
{
	"",
	"Finish hitman jobs"
}

enum MissionPrizes
{
	PRIZE_CASH,
	PRIZE_XPTOKEN,
	PRIZE_XP, // Random job.
	PRIZE_WEAPONS
}

enum struct Mission
{
	MissionTypes type;
	MissionPrizes prize;
	int progress;
	int targetProgress;
	bool completed;
	
	void gainProgress(int client, int amount)
	{
		if(this.completed)
			return;
			
		this.progress += amount;
		
		char AuthId[35];
		GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
		
		char sQuery[256];
		
		if(this.progress == this.targetProgress)
		{
			SQL_FormatQuery(dbMissions, sQuery, sizeof(sQuery), "UPDATE RolePlay_Missions SET Completed = 1 WHERE AuthId = '%s'", AuthId);
		}
		else
		{
			SQL_FormatQuery(dbMissions, sQuery, sizeof(sQuery), "UPDATE RolePlay_Missions SET Progress = Progress + %i WHERE AuthId = '%s'", amount, AuthId);
		}	
		SQL_TQuery(dbMissions, SQLCB_Error, sQuery);
	}
}

Mission ClientMissions[MAXPLAYERS+1][5];

public OnPluginStart()
{
	ConnectDatabase();
	
	TimeOffset = GetTimeOffset();
	
	RegConsoleCmd("sm_m", Command_Missions, "List of Missions");
	RegConsoleCmd("sm_missions", Command_Missions, "List of Missions");
	
}

public Action:Command_Missions(client, args)
{
	
	for(new i=0;i < sizeof(ClientMissions[]);i++)
	{
		new String:TempFormat[128];
		FormatEx(TempFormat, sizeof(TempFormat), MissionTypeNames[ClientMissions[client][i].type]);
		
		Format(TempFormat, sizeof(TempFormat), "%s [%i/%i]", MissionTypeNames[ClientMissions[client][i].type],
		ClientMissions[client][i].progress, ClientMissions[client][i].targetProgress);
	}
	
	return Plugin_Handled;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "Ban_CT", true))
	{
		PrintToChatAll("BANCT LOADED");
		g_bBanCTLoaded = true;
	}
}

public ConnectDatabase()
{
	new String:error[256];

	new Handle:hndl = SQL_Connect("eyal_rp", true, error, 255);
	
	if (hndl == INVALID_HANDLE)
	{
		PrintToServer("Could not connect [SQL]: %s", error);
		
		dbFullConnected = false;
	}
	else
	{
		new String:sQuery[256];
		
		dbMissions = hndl;
		
		dbFullConnected = true;
		
		SQL_TQuery(dbMissions, SQLCB_Error, "CREATE TABLE IF NOT EXISTS RolePlay_Missions (AuthId VARCHAR(32) NOT NULL, Timestamp INT(20) NOT NULL, Slot INT(2) NOT NULL, Type INT(11) NOT NULL, Progress INT(11) NOT NULL, UNIQUE(AuthId, Slot))", 0, DBPrio_High);
		
		SQL_TQuery(dbMissions, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);
		
		for(new i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
		
			else if(!IsClientAuthorized(i))
				continue;
			
			LoadClientMissions(i);
		}
	}
}

public SQLCB_Error(Handle:owner, Handle:hndl, const char[] Error, QueryUniqueID) 
{ 
    /* If something fucked up. */ 
	if (hndl == null) 
		LogError("%s --> %i", Error, QueryUniqueID); 
} 

public SQLCB_ErrorIgnore(Handle:owner, Handle:hndl, const char[] Error, Data) 
{ 
} 

public OnClientConnected(client)
{
	for(new i=0;i < sizeof(ClientMissions[]);i++)
		ClientMissions[client][i].completed = true;
}

public OnClientDisconnect(client)
{
	for(new i=0;i < sizeof(ClientMissions[]);i++)
		ClientMissions[client][i].completed = true;
}

public OnClientPostAdminCheck(client)
{
	if(!dbFullConnected)
		return;
	
	LoadClientMissions(client);
}

LoadClientMissions(client, LowPrio=false)
{
	new String:AuthId[35]
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	new String:sQuery[256];
	SQL_FormatQuery(dbMissions, sQuery, sizeof(sQuery), "SELECT * FROM RolePlay_Missions WHERE AuthId = '%s'", AuthId);

	if(!LowPrio)
		SQL_TQuery(dbMissions, SQLCB_LoadClientMissions, sQuery, GetClientUserId(client));
	
	else
		SQL_TQuery(dbMissions, SQLCB_LoadClientMissions, sQuery, GetClientUserId(client), DBPrio_Low);
}

public SQLCB_LoadClientMissions(Handle:owner, Handle:hndl, String:error[], any:data)
{
	if(hndl == null)
	{
		LogError(error);
		
		return;
	}

	new client = GetClientOfUserId(data);
	if(client == 0)
	{
		return;
	}
	else 
	{
		new String:AuthId[35]
		GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
		
		if(SQL_GetRowCount(hndl) != 0)
		{
			SQL_FetchRow(hndl);
			
			new timestamp = SQL_FetchInt(hndl, 1) + TimeOffset;
			new job = SQL_FetchInt(hndl, 2);
			
			new CurrentTime = GetTime() + TimeOffset;
			
			if(RoundToFloor(float(timestamp) / 86400.0) < RoundToFloor(float(CurrentTime) / 86400.0) || job == -1)
			{
				new maxJob = 0;
				
				new JobList[128], pos, String:JobShortName[32];
				
				RP_GetJobShortName(maxJob, JobShortName, sizeof(JobShortName))
				
				while(RP_GetJobShortName(maxJob, JobShortName, sizeof(JobShortName)))
				{
					if(StrEqual(JobShortName, "PM"))
					{
						if((!g_bBanCTLoaded || !IsPlayerBannedFromCT(client)) && GetTimePlayed(client) >= MINUTES_TO_BECOME_POLICE)
							JobList[pos++] = maxJob;
					}
					else
						JobList[pos++] = maxJob;
						
					maxJob++;
				}
				
				ClientJOTD[client].job = JobList[GetRandomInt(0, pos-1)];
				ClientJOTD[client].expLeft = 100;
				
				new String:sQuery[256];
				SQL_FormatQuery(dbMissions, sQuery, sizeof(sQuery), "UPDATE RolePlay_JOTD SET job = %i, EXPLeft = %i, Timestamp = %i WHERE AuthId = '%s'", ClientJOTD[client].job, ClientJOTD[client].expLeft, GetTime(), AuthId);
			
				SQL_TQuery(dbMissions, SQLCB_Error, sQuery);
			}
			else
			{
				ClientJOTD[client].job = job;
				ClientJOTD[client].expLeft = SQL_FetchInt(hndl, 3);
			}
		}
		else
		{
			new String:sQuery[256];
			SQL_FormatQuery(dbMissions, sQuery, sizeof(sQuery), "INSERT INTO RolePlay_JOTD (AuthId, Timestamp, Job, EXPLeft) VALUES ('%s', 0, -1, 0)", AuthId);
			
			SQL_TQuery(dbMissions, SQLCB_Inserted, sQuery, GetClientUserId(client), DBPrio_High);
		}
	}
}

public SQLCB_Inserted(Handle:owner, Handle:hndl, const char[] Error, UserId) 
{ 
    /* If something fucked up. */ 
	if (hndl == null) 
		LogError("%s", Error); 
		
	else
	{
		new client = GetClientOfUserId(UserId);
		
		if(client == 0)
			return;
			
		LoadClientJOTD(client);
	}
} 

stock int GetTimeOffset()
{
	bool Negate = false;
	char Time[11];

	FormatTime(Time, sizeof(Time), "%A", 86400);
	
	if(StrEqual(Time, "Thursday")) // 86400 in unix is Friday, meaning the timezone brought us back a bit.
		Negate = true;
		
	FormatTime(Time, sizeof(Time), "%H %M", 86400); // Can't use 0 because of negatives I think. I assume.
	
	char sHour[4], sMinute[4];
	
	int pos = BreakString(Time, sHour, sizeof(sHour));
	
	FormatEx(sMinute, sizeof(sMinute), Time[pos]);
	
	int secondstotal = StringToInt(sHour) * 3600 + StringToInt(sMinute) * 60;
	
	if(secondstotal == 0 || !Negate) // Server's time is positive or zero ( unix time )
		return secondstotal;
		
	else 
	{
		/*
		Suppose an hour negative, turns 00:00 into 23:00. The result should be -3600.
		-1 * (86400 - (23 * 3600 + 0 * 60)) = -3600
		*/
		return -1 * (86400 - secondstotal); 
	}
}