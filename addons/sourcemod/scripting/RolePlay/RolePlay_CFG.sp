#include <sourcemod>

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

public OnMapStart()
{
	ServerCommand("bot_quota 0;bot_join_after_player 0;bot_kick;mp_ignore_round_win_conditions 1;mp_respawn_on_death_ct 1;mp_respawn_on_death_t 1;mp_do_warmup_period 0;mp_warmuptime 0;mp_freezetime 0;mp_autoteambalance 0;ammo_grenade_limit_flashbang 2;mp_free_armor 0;mp_teamcashawards 0;mp_playercashawards 0;sv_teamid_overhead_always_prohibit 1;sv_show_team_equipment_prohibit 1;sv_airaccelerate 10000;mp_teammates_are_enemies 1;sv_enablebunnyhopping 1;sv_ignoregrenaderadio 1;mp_autokick 0;sv_allow_votes 0 ");
	ServerCommand("mp_ct_default_primary \"\"; mp_ct_default_secondary \"\"; mp_t_default_primary \"\"; mp_t_default_secondary \"\";");
	ServerCommand("sm_flashlight_return 1");
	
	// This cvar does the following: when you aim at an enemy player, it instantly shows his name rather than having to "snipe" him with your mouse.
	ServerCommand("mp_playerid_delay 0");
}

 