#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <emitsoundany>
#include <Eyal-RP>

public Plugin:myinfo =
{
	name = "RolePlay Job Models",
	description = "",
	author = "Eyal282",
	version = "1.00",
	url = ""
}

public OnMapStart()
{	
		
	// Medic
	LoadDirOfModels("materials/models/player/kuristaja/tf2/medic");
	LoadDirOfModels("models/player/custom_player/kuristaja/tf2/medic");
	PrecacheModel("models/player/custom_player/kuristaja/tf2/medic/medic_redv2.mdl", true);

	// Weapon Crafter
	LoadDirOfModels("models/player/custom_player/kuristaja/l4d2/coach");
	LoadDirOfModels("materials/models/player/kuristaja/l4d2/coach");
	PrecacheModel("models/player/custom_player/kuristaja/l4d2/coach/coachv2.mdl", true);

	// Drug Dealer
	LoadDirOfModels("models/player/custom_player/hekut/maverick");
	LoadDirOfModels("materials/models/player/custom_player/hekut/maverick");
	PrecacheModel("models/player/custom_player/hekut/maverick/maverick_hekut.mdl", true);

	// Hitman
	LoadDirOfModels("materials/models/player/voikanaa/hitman/agent47");
	LoadDirOfModels("models/player/custom_player/voikanaa/hitman");
	PrecacheModel("models/player/custom_player/voikanaa/hitman/agent47.mdl", true);

	// Policeman
	LoadDirOfModels("models/player/custom_player/caleon1/nkpolice/");
	LoadDirOfModels("materials/models/player/custom_player/caleon1/nkpolice/");
	PrecacheModel("models/player/custom_player/caleon1/nkpolice/nkpolice.mdl", true);

	// Lawyer
	LoadDirOfModels("materials/models/player/kuristaja/agent_smith/");
	LoadDirOfModels("models/player/custom_player/kuristaja/agent_smith/");
	PrecacheModel("models/player/custom_player/kuristaja/agent_smith/smith.mdl", false);
}


public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "RolePlay_Jobs", true))
	{

		CreateTimer(0.2, Timer_SetJobModels);
	}
}

public Action Timer_SetJobModels(Handle hTimer)
{
	int job = RP_FindJobByShortName("MED");

	if(job != -1)
		RP_SetJobModel(job, "models/player/custom_player/kuristaja/tf2/medic/medic_redv2.mdl");

	job = RP_FindJobByShortName("WECR");

	if(job != -1)
		RP_SetJobModel(job, "models/player/custom_player/kuristaja/l4d2/coach/coachv2.mdl");
		
		
	job = RP_FindJobByShortName("DRUD");

	if(job != -1)
		RP_SetJobModel(job, "models/player/custom_player/hekut/maverick/maverick_hekut.mdl");
		
	job = RP_FindJobByShortName("HM");

	if(job != -1)
		RP_SetJobModel(job, "models/player/custom_player/voikanaa/hitman/agent47.mdl");

	job = RP_FindJobByShortName("PM");

	if(job != -1)
		RP_SetJobModel(job, "models/player/custom_player/caleon1/nkpolice/nkpolice.mdl");

	job = RP_FindJobByShortName("LAW");

	if(job != -1)
		RP_SetJobModel(job, "models/player/custom_player/kuristaja/agent_smith/smith.mdl");
}
