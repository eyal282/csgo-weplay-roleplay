#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <Eyal-RP>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "RolePlay - Job of the Day.",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Each day per player a random job ( police excluded if can't choose it ) which grants 1.2x EXP for the first 100 EXP",
	version = PLUGIN_VERSION,
	url = "N/A"
}

new bool:dbFullConnected = false;

new bool:g_bBanCTLoaded = false;

new Handle:dbJOTD = INVALID_HANDLE;

new TimeOffset;

enum struct JOTD
{
	int job;
	int expLeft;
	
	void decreaseEXPLeft(int client, int amount)
	{
		this.expLeft -= amount;
		
		char AuthId[35];
		GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
		
		char sQuery[256];
		SQL_FormatQuery(dbJOTD, sQuery, sizeof(sQuery), "UPDATE RolePlay_JOTD SET EXPLeft = EXPLeft - %i WHERE AuthId = '%s'", amount, AuthId);
			
		SQL_TQuery(dbJOTD, SQLCB_Error, sQuery);
	}
	
	void increaseEXPLeft(int client, int amount)
	{
		this.expLeft += amount;
		
		char AuthId[35];
		GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
		
		char sQuery[256];
		SQL_FormatQuery(dbJOTD, sQuery, sizeof(sQuery), "UPDATE RolePlay_JOTD SET EXPLeft = EXPLeft + %i WHERE AuthId = '%s'", amount, AuthId);
			
		SQL_TQuery(dbJOTD, SQLCB_Error, sQuery);
	}
}

JOTD ClientJOTD[MAXPLAYERS+1];

public APLRes:AskPluginLoad2()
{
	CreateNative("RP_GetClientJOTD", Native_GetClientJOTD);
	CreateNative("RP_AddJOTDExp", Native_AddJOTDExp);
}

public Native_GetClientJOTD(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	SetNativeCellRef(2, ClientJOTD[client].job);
	SetNativeCellRef(3, ClientJOTD[client].expLeft);
}

public Native_AddJOTDExp(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	new exp = GetNativeCell(2);
	
	ClientJOTD[client].increaseEXPLeft(client, exp);
}
public OnPluginStart()
{
	ConnectDatabase();
	
	TimeOffset = GetTimeOffset();
	
	RegConsoleCmd("sm_jotd", Command_JOTD, "Shows your Job of the Day");
	
}

public Action:Command_JOTD(client, args)
{
	if(ClientJOTD[client].job == -1)
	{
		RP_PrintToChat(client, "Could not find your Job of the Day");
		return Plugin_Handled;
	}	
	new String:JobName[32];
	
	RP_GetJobName(ClientJOTD[client].job, JobName, sizeof(JobName));
	
	RP_PrintToChat(client, "Your Job of the Day is \x07%s. \x01You get \x041.2x \x01exp for the next \x10%i EXP", JobName, ClientJOTD[client].expLeft);
	
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
		
		dbJOTD = hndl;
		
		dbFullConnected = true;
		
		SQL_TQuery(dbJOTD, SQLCB_Error, "CREATE TABLE IF NOT EXISTS RolePlay_JOTD (AuthId VARCHAR(32) NOT NULL UNIQUE, Timestamp INT(20) NOT NULL, Job INT(11) NOT NULL, EXPLeft INT(11) NOT NULL)", 0, DBPrio_High);
		
		SQL_TQuery(dbJOTD, SQLCB_ErrorIgnore, sQuery, _, DBPrio_High);
		
		for(new i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
		
			else if(!IsClientAuthorized(i))
				continue;
			
			ClientJOTD[i].job = -1;
			
			LoadClientJOTD(i);
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

public void OnClientEarnJobEXP(int client, int job, int originalEXP, int &exp)
{
	if(ClientJOTD[client].job == job)
	{
		if(ClientJOTD[client].expLeft <= 0)
			return;
			
		new amount = RoundToCeil(float(originalEXP) * 1.2) - originalEXP;
		
		if(ClientJOTD[client].expLeft >= amount)
			exp += amount; // Like exp *= 2 but only for the original EXP.
			
		else
		{
			amount = ClientJOTD[client].expLeft;
			exp += amount;
		}	
		
		ClientJOTD[client].decreaseEXPLeft(client, amount);
	}
}

public OnClientConnected(client)
{
	ClientJOTD[client].job = -1;
}

public OnClientDisconnect(client)
{
	ClientJOTD[client].job = -1;
}

public OnClientPostAdminCheck(client)
{
	if(!dbFullConnected)
		return;
	
	LoadClientJOTD(client);
}

LoadClientJOTD(client, LowPrio=false)
{
	new String:AuthId[35]
	GetClientAuthId(client, AuthId_Engine, AuthId, sizeof(AuthId));
	
	new String:sQuery[256];
	SQL_FormatQuery(dbJOTD, sQuery, sizeof(sQuery), "SELECT * FROM RolePlay_JOTD WHERE AuthId = '%s'", AuthId);

	if(!LowPrio)
		SQL_TQuery(dbJOTD, SQLCB_LoadClientJOTD, sQuery, GetClientUserId(client));
	
	else
		SQL_TQuery(dbJOTD, SQLCB_LoadClientJOTD, sQuery, GetClientUserId(client), DBPrio_Low);
}

public SQLCB_LoadClientJOTD(Handle:owner, Handle:hndl, String:error[], any:data)
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
				
				RP_GetJobShortName(maxJob, JobShortName, sizeof(JobShortName))
				
				while(RP_GetJobShortName(maxJob, JobShortName, sizeof(JobShortName)))
				{
					if(StrEqual(JobShortName, "PM"))
					{
						if((!g_bBanCTLoaded || !IsPlayerBannedFromCT(client)) && GetTimePlayed(client) >= RP_GetMinutesToBecomePolice())
							JobList[pos++] = maxJob;
					}
					else
						JobList[pos++] = maxJob;
						
					maxJob++;
				}
				
				ClientJOTD[client].job = JobList[GetRandomInt(0, pos-1)];
				ClientJOTD[client].expLeft = 100;
				
				new String:sQuery[256];
				SQL_FormatQuery(dbJOTD, sQuery, sizeof(sQuery), "UPDATE RolePlay_JOTD SET job = %i, EXPLeft = %i, Timestamp = %i WHERE AuthId = '%s'", ClientJOTD[client].job, ClientJOTD[client].expLeft, GetTime(), AuthId);
			
				SQL_TQuery(dbJOTD, SQLCB_Error, sQuery);
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
			SQL_FormatQuery(dbJOTD, sQuery, sizeof(sQuery), "INSERT INTO RolePlay_JOTD (AuthId, Timestamp, Job, EXPLeft) VALUES ('%s', 0, -1, 0)", AuthId);
			
			SQL_TQuery(dbJOTD, SQLCB_Inserted, sQuery, GetClientUserId(client), DBPrio_High);
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