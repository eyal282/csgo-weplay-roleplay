#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <Eyal-RP>

#define JOB_DRUG_DEALER 	"DRUD"
#define JOB_HITMAN 			"HM"
#define JOB_THIEF 			"TH"
#define JOB_POLICE 			"PM"
#define JOB_WEAPON_CRAFTER	"WECR"
#define JOB_MEDIC 			"MED"
#define JOB_LAWYER			"LAW"
#define JOB_HOUSE_BREAKER	"HBREAKER"

new SalariesByJob[][] =
{
	{0, 0, 0, 0, 0, 0}, // Drug Dealer
	{0, 0, 0, 0, 0, 0}, // Hitman
	{0, 0, 0, 0, 0, 0}, // Thief
	{400, 600, 800, 1000, 1500, 2500 }, // Policeman
	{0, 0, 0, 0, 0, 0}, // Weapon Crafter
	{0, 0, 0, 0, 0, 0}, // Medic
	{0, 0, 0, 0, 0, 0}, // Lawyer
	{0, 0, 0, 0, 0, 0} // House Breaker
}

new Handle:hTimer_EachQuarterHour[MAXPLAYERS+1];

new EngineVersion:g_Game;

public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "1.00",
	url = ""
};

public OnPluginStart()
{
	g_Game = GetEngineVersion();

	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
}

public OnClientDisconnect(client)
{
	if(hTimer_EachQuarterHour[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_EachQuarterHour[client]);
		hTimer_EachQuarterHour[client] = INVALID_HANDLE;
	}
}

public bool UpdateJobStats(int client, int job)
{
	if(hTimer_EachQuarterHour[client] != INVALID_HANDLE)
	{
		CloseHandle(hTimer_EachQuarterHour[client]);
		hTimer_EachQuarterHour[client] = INVALID_HANDLE;
	}
	
	hTimer_EachQuarterHour[client] = CreateTimer(3600.0, Timer_EachHour, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_EachHour(Handle:hTimer, UserId)
{
	new client = GetClientOfUserId(UserId);
	
	if(client == 0)
		return Plugin_Stop;
		
	new job = RP_GetClientJob(client);
	
	new String:JobShortName[32], String:JobName[32];
	
	new jobStatus = -1;
	
	RP_GetJobShortName(job, JobShortName, sizeof(JobShortName));
	RP_GetJobName(job, JobName, sizeof(JobName));

	if(StrEqual(JobShortName, JOB_DRUG_DEALER))
		jobStatus = 0;
		
	else if(StrEqual(JobShortName, JOB_HITMAN))
		jobStatus = 1;
		
	else if(StrEqual(JobShortName, JOB_THIEF))
		jobStatus = 2;
		
	else if(StrEqual(JobShortName, JOB_POLICE))
		jobStatus = 3;
		
	else if(StrEqual(JobShortName, JOB_WEAPON_CRAFTER))
		jobStatus = 4;
		
	else if(StrEqual(JobShortName, JOB_MEDIC))
		jobStatus = 5;
		
	else if(StrEqual(JobShortName, JOB_LAWYER))
		jobStatus = 6;
		
	else if(StrEqual(JobShortName, JOB_HOUSE_BREAKER))
		jobStatus = 7;
	
	if(jobStatus != -1)
	{
		new reward = SalariesByJob[jobStatus][RP_GetClientLevel(client, job)];
		
		if(reward > 0)
		{
			reward = GiveClientCash(client, BANK_CASH, reward);
			
			RP_PrintToChat(client, "You got $%i for playing as %s for 15 minutes.", reward, JobName);
		}
	}	
	
	return Plugin_Continue;
}
 