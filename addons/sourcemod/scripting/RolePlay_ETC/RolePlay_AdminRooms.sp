#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <Eyal-RP>

#include <cstrike>

new EngineVersion:g_Game;

new LastCommand;
 
public Plugin:myinfo =
{
	name = "",
	description = "",
	author = "Author was lost, heavy edit by Eyal282",
	version = "0.00",
	url = ""
};

new Float:fNextReport[MAXPLAYERS + 1];
// This is the last thing to be added to eco.

new ReportSerialCount = 1;

new Handle:Trie_AdminRoomsEco;

enum struct enReport
{
	int ReportSerial; // Use report serial when accessing a report so if you press a report in the menu, you don't get another one.
	int ReportUnix;
	int UserId;
	char Reason[64];
	int KillerUserId;
	char KillerName[64];
	char KillerAuthId[35];
	int KillUnix;
}

new Handle:Array_Reports;

new adminRoomsSize;

new Float:g_fAdminRooms[64][3];
new Float:g_fAdminRoomsArrange[64][16][3]; // [room][player slot][vector]
new g_AdminRoomsArrangeSize[64]; // [room][player slot][vector]
new String:g_sAdminRoomsCCA[64][64];

new g_iAdminRoom[MAXPLAYERS+1] = -1;
new bool:g_bTeleportPlayer[MAXPLAYERS+1];
new Float:g_fClientLastOrigin[MAXPLAYERS+1][3];

new ClientKillerUserId[MAXPLAYERS + 1], String:ClientKillerName[MAXPLAYERS + 1][64], String:ClientKillerAuthId[MAXPLAYERS + 1][64];

new Handle:hcv_showActivity = INVALID_HANDLE;

public OnAllPluginsLoaded()
{
	hcv_showActivity = FindConVar("sm_show_activity");
}
public OnPluginStart()
{
	// Also on Command_FreeKill.
	_NO_PREFIX = true;

	g_Game = GetEngineVersion();
	
	if (g_Game != EngineVersion:12 && g_Game != EngineVersion:13)
	{
		SetFailState("This plugin is for CSGO/CSS only.");
	}
	
	LoadTranslations("common.phrases");

	Array_Reports = CreateArray(sizeof(enReport));
	
	RegConsoleCmd("sm_fk", Command_FreeKill, "sm_fk [reason]");
	RegConsoleCmd("sm_freekill", Command_FreeKill, "sm_freekill [reason]");
	
	RegAdminCmd("sm_fklist", Command_FKList, ADMFLAG_GENERIC, "Opens a list of free kill reports.");
	
	RegAdminCmd("sm_ars", Command_AdminRooms, ADMFLAG_GENERIC, "Opens up the admin rooms menu.", "", 0);
	RegAdminCmd("sm_arrangears", Command_ArrangeAdminRooms, ADMFLAG_GENERIC, "Arrange every player to a corner.", "", 0);
	
	AddMultiTargetFilter("@ars", TargetFilter_AdminRoom, "all players in Admin room", false);

	HookEvent("player_spawn", Event_OnPlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
	
	if(RP_GetEcoTrie("Admin Rooms") != INVALID_HANDLE)
		RP_OnEcoLoaded();
}


public RP_OnEcoLoaded()
{
	adminRoomsSize = 0;
	
	for (new i = 0; i < sizeof(g_AdminRoomsArrangeSize);i++)
		g_AdminRoomsArrangeSize[i] = 0;
		
	Trie_AdminRoomsEco = RP_GetEcoTrie("Admin Rooms");
	
	if(Trie_AdminRoomsEco == INVALID_HANDLE)
		SetFailState("Could not find eco for Admin Rooms");
		
	new String:TempFormat[64];
	
	new i=0;
	while(i > -1)
	{
		new String:Key[64];
		
		FormatEx(Key, sizeof(Key), "ADMIN_ROOM_XYZ_#%i", i);
		
		if(!GetTrieString(Trie_AdminRoomsEco, Key, TempFormat, sizeof(TempFormat)))
			break;
		
		StringToVector(TempFormat, g_fAdminRooms[adminRoomsSize]);
		
		FormatEx(Key, sizeof(Key), "ADMIN_ROOM_CCA_#%i", i);
		
		if(GetTrieString(Trie_AdminRoomsEco, Key, TempFormat, sizeof(TempFormat)))
			FormatEx(g_sAdminRoomsCCA[adminRoomsSize], sizeof(g_sAdminRoomsCCA[]), TempFormat);
			
		else
			FormatEx(g_sAdminRoomsCCA[adminRoomsSize], sizeof(g_sAdminRoomsCCA[]), "sm_admin");
			
		new a=0;
		while(a > -1)
		{
			FormatEx(Key, sizeof(Key), "ADMIN_ROOM_XYZ_#%i_ARRANGE_#%i", i, a);
			
			if(!GetTrieString(Trie_AdminRoomsEco, Key, TempFormat, sizeof(TempFormat)))
				break;
			
			StringToVector(TempFormat, g_fAdminRoomsArrange[adminRoomsSize][g_AdminRoomsArrangeSize[adminRoomsSize]]);
			
			g_AdminRoomsArrangeSize[adminRoomsSize]++;
			
			
			a++;
		}
			
		adminRoomsSize++;
		
		i++;
	}
}
public void RP_OnClientJailStatusPost(client)
{
	if(g_iAdminRoom[client] != -1)
		g_fClientLastOrigin[client] = Float:{0.0, 0.0, 0.0};
}
public void RP_OnClientTeleportToJail(client)
{
	if(g_iAdminRoom[client] != -1)
	{
		TeleportToAdminRoom(client, g_iAdminRoom[client]);
	}
}

public Action:RP_OnPlayerSuiciding(client)
{
	if(g_iAdminRoom[client] != -1)
	{
		return Plugin_Handled;
	}	
	return Plugin_Continue;
}

public OnPluginEnd()
{
	RemoveMultiTargetFilter("@ars", TargetFilter_AdminRoom);
}

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], err_max)
{
	RegPluginLibrary("RolePlay_AdminRooms");
	CreateNative("IsPlayerInAdminRoom", _IsPlayerInAdminRoom);
	CreateNative("GetPlayerAdminRoom", _GetPlayerAdminRoom);
	return APLRes:0;
}

public _IsPlayerInAdminRoom(Handle:plugin, numParams)
{
	return g_iAdminRoom[GetNativeCell(1)] != -1;
}

public _GetPlayerAdminRoom(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if(!IsClientObserver(client))
		return g_iAdminRoom[client];
		
	new target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	
	if(target == -1)
		return g_iAdminRoom[client];
		
	return g_iAdminRoom[target];
}

public Action:OnClientCommand(client, args)
 {
    LastCommand = client;
}

public bool:TargetFilter_AdminRoom(const char[] pattern, Handle clients)
{
	if(g_iAdminRoom[LastCommand] == -1)
		return false;
		
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(g_iAdminRoom[i] == g_iAdminRoom[LastCommand] && !IsPlayerAdmin(i))
		{
			PushArrayCell(clients, i);
		}
	}
	
	return true;
}


public Action:Event_OnPlayerSpawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(g_iAdminRoom[client] != -1)
	{
		
		RequestFrame(Frame_TeleportToAdminRoom, client);
	}
	return Plugin_Continue;
}

public Action:Event_OnPlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(victim == 0 || attacker == 0 || attacker == victim)
		return;
		
	new String:AuthId[35];
	GetClientAuthId(attacker, AuthId_Engine, AuthId, sizeof(AuthId));
	
	ClientKillerUserId[victim] = GetClientUserId(attacker);
	
	FormatEx(ClientKillerName[victim], sizeof(ClientKillerName[]), "%N", attacker);
	FormatEx(ClientKillerAuthId[victim], sizeof(ClientKillerAuthId[]), AuthId);
}

public MoveClientToAdminRoom(client, room)
{
	new oldRoom = g_iAdminRoom[client];
	
	TeleportToAdminRoom(client, room);
	
	g_iAdminRoom[client] = room;
	
	RP_StopPlayerSuiciding(client);
	
	UpdateRoomMenu(room);
	
	if(oldRoom != -1 && CheckForEmptyAdminRoom(oldRoom))
	{
		PrintToAdminChatRoom(oldRoom, "\x02%N\x01 has left the admin room so everyone was kicked.", client);
		
		for(new i=1;i <= MaxClients;i++)
		{
			if(!IsClientInGame(i))
				continue;
			
			else if(g_iAdminRoom[i] != oldRoom)
				continue;
				
			KickFromAdminRoom(i);
		}
	}
}

TeleportToAdminRoom(client, room)
{
	if (!IsPlayerAlive(client))
		return;
	
	if(g_iAdminRoom[client] == -1)
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", g_fClientLastOrigin[client]);
		
	TeleportEntity(client, g_fAdminRooms[room], NULL_VECTOR, NULL_VECTOR);
	
}

public Frame_TeleportToAdminRoom(client)
{
	if(!IsClientInGame(client)) // In one frame no player replacement can be made, only a client can leave.
		return;
		
	TeleportToAdminRoom(client, g_iAdminRoom[client]);
}



public Action:Command_FreeKill(client, args)
{
	if(fNextReport[client] > GetGameTime())
	{
		RP_PrintToChat(client, "You can send another report in %.1f seconds!", fNextReport[client] - GetGameTime());
		
		return Plugin_Handled;
	}
	new String:Arg[64];
	
	GetCmdArgString(Arg, sizeof(Arg));
	
	if(args == 0)
	{
		FormatEx(Arg, sizeof(Arg), "No Reason from Player");
	}

	_NO_PREFIX = false;

	new bool:bAdmins = false;
	
	for (new i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(!CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC))
			continue;
			
		bAdmins = true;
		
		RP_PrintToChat(i, "%N sent a freekill report! Reason: %s", client, Arg);
	}
	
	if(bAdmins)
	{
		RP_PrintToChat(client, "!הדיווח שלך נשלח בהצלחה");
	}
	else
	{
		RP_PrintToChat(client, "אין צוות מחובר לשרת");
	}

	_NO_PREFIX = true;

	fNextReport[client] = GetGameTime() + 45.0;
	enReport newReport;
	
	newReport.ReportSerial = ReportSerialCount++;
	newReport.ReportUnix = GetTime();
	newReport.UserId = GetClientUserId(client);
	newReport.KillerUserId = ClientKillerUserId[client];
	FormatEx(newReport.KillerName, sizeof(enReport::KillerName), ClientKillerName[client]);
	FormatEx(newReport.KillerAuthId, sizeof(enReport::KillerAuthId), ClientKillerAuthId[client]);
	FormatEx(newReport.Reason, sizeof(enReport::Reason), Arg);
	newReport.KillUnix = GetTime();
	
	PushArrayArray(Array_Reports, newReport);
	
	return Plugin_Handled;
	
}


public Action:Command_FKList(client, args)
{
	RemoveDisconnectedFromArray();
	
	new String:sReportSerial[11], String:TempFormat[128];
	
	enReport report;
	
	new size = GetArraySize(Array_Reports);
	
	if(size == 0)
	{
		RP_PrintToChat(client, "There are no waiting reports");
		
		return Plugin_Handled;
	}
		
	new Handle:hMenu = CreateMenu(MenuHandler_FKList);
	
	for (new i = 0; i < size;i++)
	{
		GetArrayArray(Array_Reports, i, report, sizeof(enReport));
		
		IntToString(report.ReportSerial, sReportSerial, sizeof(sReportSerial));
		
		int UserId = view_as<int>(report.UserId);
	
		int reporter = GetClientOfUserId(UserId);
		
		if(g_iAdminRoom[reporter] != -1 && g_iAdminRoom[reporter] != g_iAdminRoom[client])
			continue;
			
		FormatEx(TempFormat, sizeof(TempFormat), "Report #%i by %N (%s) [%i Seconds ago]", report.ReportSerial, reporter, report.Reason, GetTime() - report.ReportUnix);
		
		AddMenuItem(hMenu, sReportSerial, TempFormat);
	}
	
	RP_SetMenuTitle(hMenu, "Free Kill List:\n ");
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public MenuHandler_FKList(Handle:menu, MenuAction:action, client, item)
{
	if(action == MenuAction_End)
		CloseHandle(menu);
		
	if (action == MenuAction_Select)
	{
		RemoveDisconnectedFromArray();
		
		new String:sReportSerial[11];
		GetMenuItem(menu, item, sReportSerial, sizeof(sReportSerial));
		
		new serial = StringToInt(sReportSerial);
		
		new i = FindReportBySerial(serial);
		
		if(i == -1)
		{
			RP_PrintToChat(client, "Reporting player left the server or report was marked as resolved.");
		}
		else
		{
			ShowResolvingReportMenu(client, i, serial);
		}
	}
}

public Action:ShowResolvingReportMenu(client, i, serial)
{
	enReport report;
	GetArrayArray(Array_Reports, i, report, sizeof(enReport));
	
	new Handle:hMenu = CreateMenu(MenuHandler_ResolvingReport);
	
	new reporter = GetClientOfUserId(report.UserId);
	
	new reported = GetClientOfUserId(report.KillerUserId);
	
	if(g_iAdminRoom[reporter] != -1 && g_iAdminRoom[reporter] != g_iAdminRoom[client])
	{
		RP_PrintToChat(client, "%N's report is already being investigated by another admin.", reporter);
		
		return;
	}
	
	new String:TempFormat[128];
	IntToString(serial, TempFormat, sizeof(TempFormat));
	
	AddMenuItem(hMenu, TempFormat, "Teleport reporter to available Admin Room\n ", reporter != client ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	AddMenuItem(hMenu, TempFormat, "Teleport both to available Admin Room\n ", reported != 0 && reported != client && reporter != client ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	
	AddMenuItem(hMenu, "", "Resolve Report");
	
	FormatEx(TempFormat, sizeof(TempFormat), "Resolve All %N's Reports", reporter)
	AddMenuItem(hMenu, "", TempFormat);
	
	FormatTime(TempFormat, sizeof(TempFormat), "%H:%M:%S", report.ReportUnix);
	
	if(reported == 0)
	{
		if(report.KillerAuthId[0] == EOS)
			RP_SetMenuTitle(hMenu, "Report Info - %N's Report\n\n ◉ Report Time: %s\n \n ◉ Reporter: %N\n ◉ Reason: %s\n \n ◉ No Last Killer This Session.\n ", reporter, TempFormat, reporter, report.Reason);
			
		else
			RP_SetMenuTitle(hMenu, "Report Info - %N's Report\n\n ◉ Report Time: %s\n \n ◉ Reporter: %N\n ◉ Reason: %s\n \n ◉ Last Killer Disconnected: %s [%s]\n ", reporter, TempFormat, reporter, report.Reason, report.KillerName, report.KillerAuthId);
	}
	else
	{
		new String:KillTime[16];
		
		FormatTime(KillTime, sizeof(KillTime), "%H:%M:%S", report.KillUnix);
		RP_SetMenuTitle(hMenu, "Report Info - %N's Report\n\n ◉ Report Time: %s\n \n ◉ Reporter: %N\n ◉ Reason: %s\n \n ◉ Last Killer: %N at %s\n ", reporter, TempFormat, reporter, report.Reason, reported, KillTime);
	}
	
	DisplayMenu(hMenu, client, 0);
}

public MenuHandler_ResolvingReport(Menu:menu, MenuAction:action, client, item)
{
	if (action == MenuAction_Select)
	{
		RemoveDisconnectedFromArray();
		
		new String:sReportSerial[11];
		GetMenuItem(menu, 0, sReportSerial, sizeof(sReportSerial));
		
		new serial = StringToInt(sReportSerial);

		enReport report;
		
		new pos = FindReportBySerial(serial);
		
		if(pos == -1)
		{
			RP_PrintToChat(client, "Reporting player left the server or report was marked as resolved.");
			
			return;
		}

		GetArrayArray(Array_Reports, pos, report, sizeof(enReport));
		
		new reporter = GetClientOfUserId(report.UserId); // The remove disconnected function guarantees reporter is in game and fully valid.
		new reported = GetClientOfUserId(report.KillerUserId); // NOT GUARANTEED TO BE IN-GAME, CAREFUL
		
		if(g_iAdminRoom[reporter] != -1 && g_iAdminRoom[reporter] != g_iAdminRoom[client])
		{
			RP_PrintToChat(client, "%N's report is already being investigated by another admin.", reporter);
			
			return;
		}
		switch(item)
		{
			case 0, 1:
			{
				bool[] bOccupied = new bool[adminRoomsSize];
				
				for (new i = 0; i < adminRoomsSize;i++)
				{
					bOccupied[i] = false;
				}
				
				for (new i = 1; i <= MaxClients;i++)
				{
					if(!IsClientInGame(i))
						continue;
						
					else if(g_iAdminRoom[i] == -1)
						continue;
						
					// Don't care if the room is occupied by the client, the reporter or the reported.
					// Also don't care if the reported is not in-game ( YET! )
					else if(i == client || i == reporter || i == reported)
						continue;
						
					bOccupied[g_iAdminRoom[i]] = true;
				}
				
				int targetRoom = -1;
				
				for (new i = 0; i < sizeof(g_fAdminRooms);i++)
				{
					if(IsEmptyVector(g_fAdminRooms[i]))
						break;
						
					else if(bOccupied[i])
						continue;
						
					targetRoom = i;
					break;
				}
				
				if(targetRoom == -1)
				{
					RP_PrintToChat(client, "Could not find an unoccupied admin room.");
					
					return;
				}
				
				MoveClientToAdminRoom(client, targetRoom);
				
				if(RP_GetKarma(reporter) >= BOUNTY_KARMA)
				{
					RP_PrintToChat(client, "%s \x02%N\x01 is bounty. Cannot teleport.", " \x04[Admins Rooms]\x01", reporter);
					
					return;
				}
				else if(RP_IsUserInDuel(reporter) || RP_IsUserInArena(reporter))
				{
					RP_PrintToChat(client, "%s \x02%N\x01 is dueling / ja. Cannot teleport.", " \x04[Admins Rooms]\x01", reporter);
					
					return;
				}
				
				MoveClientToAdminRoom(reporter, targetRoom);
				
				if(item != 0 && reported != 0 && reported != reporter)
				{
					if(RP_GetKarma(reported) >= BOUNTY_KARMA)
					{
						PrintToAdminChatRoom(targetRoom, "\x02%N\x01 is bounty. Cannot teleport.", reported);
	
					}
					else if(RP_IsUserInDuel(reported) || RP_IsUserInArena(reported))
					{
						PrintToAdminChatRoom(targetRoom, "\x02%N\x01 is dueling / ja. Cannot teleport.", reported);
					}
					else
					{
						MoveClientToAdminRoom(reported, targetRoom);
						
						PrintToAdminChatRoom(targetRoom, "All players involved in report #%i were teleported Admin Room #%i",  serial, targetRoom + 1);
						PrintToAdmins("All players involved in report #%i were teleported Admin Room #%i",  serial, targetRoom + 1);
					}
				}
			}
			
			case 2:
			{
				RemoveFromArray(Array_Reports, pos);
				
				RP_PrintToChat(client, "Successfully marked report #%i as solved.", serial);
				RP_PrintToChat(reporter, "%N marked your report as solved! (Report #%i, Reason: %s)", client, serial, report.Reason);
			}
			
			case 3:
			{
				RemoveClientReports(reporter);
				
				RP_PrintToChat(client, "Successfully marked all reports of %N as solved.", reporter);
				RP_PrintToChat(reporter, "%N marked all your reports as solved!", client);				
			}
		}
	}
}


public Action:Command_ArrangeAdminRooms(client, args)
{
	new room = g_iAdminRoom[client];
	if (room == -1)
	{
		RP_PrintToChat(client, "Command must be used inside admin room.");
		return Plugin_Handled;
	}
	
	new slot = 0;
	
	for (new i = 1; i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(slot == g_AdminRoomsArrangeSize[room])
			break;
		
		else if(g_iAdminRoom[i] != room)
			continue;
		
		else if(CheckCommandAccess(i, "sm_admin", ADMFLAG_GENERIC))
			continue;
		
		TeleportEntity(i, g_fAdminRoomsArrange[room][slot]);
		
		slot++;
	}
	
	FakeClientCommand(client, "sm_freeze @ars -1");
	
	RP_PrintToChat(client, "Successfully arranged %i players in corners.", slot);
		
	return Plugin_Handled;
}

public Action:Command_AdminRooms(client, args)
{
	if (g_iAdminRoom[client] != -1)
	{
		Menu_ShowAdminRoomInside(client);
	}
	else
	{
		Menu_ShowAdminRoomMain(client);
	}
	return Plugin_Handled;
}

Menu_ShowAdminRoomInside(client)
{
	new String:szItemFormat[64];
	new String:szItemData[11];

	new Menu:menu = CreateMenu(MenuCallBack_ShowAdminRoomInside, MenuAction:28);

	AddMenuItem(menu, "", "Leave Room (Everyone will be kicked if you are the only admin)\n ", 0);
	AddMenuItem(menu, "", "Teleport Player by Name", 0);
	AddMenuItem(menu, "", "Teleport Player by Menu\n ", 0);
	
	IntToString(GetClientUserId(client), szItemData, sizeof(szItemData));

	FormatEx(szItemFormat, 64, "%N [Kick]", client);
	
	AddMenuItem(menu, szItemData, szItemFormat, ITEMDRAW_DISABLED);
	
	new count;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(g_iAdminRoom[client] != g_iAdminRoom[i])
			continue;
		
		count++;
		
		if(client == i)
			continue;
			
		IntToString(GetClientUserId(i), szItemData, sizeof(szItemData));
		FormatEx(szItemFormat, 64, "%N [Kick]", i);

		AddMenuItem(menu, szItemData, szItemFormat, ITEMDRAW_DEFAULT);
	}
	
	RP_SetMenuTitle(menu, "Menu - Room Menu\n ◉ Players in room: %i.\n ", count);
	DisplayMenu(menu, client, 0);
}

public MenuCallBack_ShowAdminRoomInside(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Select)
	{
		if (key)
		{
			if (key == 1)
			{
				g_bTeleportPlayer[client] = true;
				RP_PrintToChat(client, "%s Type \x02player name\x01 in the chat or \x04-1\x01 to cancel.", " \x04[Admins Rooms]\x01");
			}
			else if(key == 2)
			{
				Menu_ShowAdminRoomInsideAddPlayer(client);
			}
			
			new String:szItemData[11];
			GetMenuItem(menu, key, szItemData, sizeof(szItemData));
			new iTargetTemp = GetClientOfUserId(StringToInt(szItemData));
			
			if(iTargetTemp != 0)
			{
				if (g_iAdminRoom[client] == g_iAdminRoom[iTargetTemp])
				{
					PrintToAdminChatRoom(g_iAdminRoom[client], "\x02%N\x01 has kicked \x04%N\x01 from the admin room.", client, iTargetTemp);
					KickFromAdminRoom(iTargetTemp);
					UpdateRoomMenu(g_iAdminRoom[client]);
				}
				else
				{
					RP_PrintToChat(client, "%s Error occured.", " \x04[Admins Rooms]\x01");
				}
			}
		}
		else
		{
			new oldRoom = g_iAdminRoom[client];
			
			KickFromAdminRoom(client);
			
			if(oldRoom != -1)
				PrintToAdmins("\x02%N\x01 has left \x04Admin Room #%i\x01", client, oldRoom + 1);
				
			if(CheckForEmptyAdminRoom(oldRoom))
			{
				PrintToAdminChatRoom(oldRoom, "\x02%N\x01 has left the admin room so everyone was kicked.", client);
				
				for(new i=1;i <= MaxClients;i++)
				{
					if(!IsClientInGame(i))
						continue;
					
					else if(g_iAdminRoom[i] != oldRoom)
						continue;
						
					KickFromAdminRoom(i);
				}
			}
			else
			{
				if(oldRoom != -1)
					PrintToAdminChatRoom(oldRoom, "\x02%N\x01 has left the admin room.", client);
				
				KickFromAdminRoom(client);
				UpdateRoomMenu(oldRoom);
			}
		}
	}
	else
	{
		if (action == MenuAction_End)
		{
			CloseHandle(menu);
			menu = null;
		}
	}
}


Menu_ShowAdminRoomInsideAddPlayer(client)
{
	new String:szItemFormat[64];
	new String:szItemData[11];

	new Menu:menu = CreateMenu(MenuCallBack_ShowAdminRoomInsideAddPlayer, MenuAction:28);
	
	new count;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(g_iAdminRoom[i] != -1)
			continue;
			
		IntToString(GetClientUserId(i), szItemData, 11);
		FormatEx(szItemFormat, 64, "%N", i);

		AddMenuItem(menu, szItemData, szItemFormat, client != i ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		
		count++;
	}
	
	if(count == 0)
	{
		AddMenuItem(menu, "0", "No players to add.");
	}
	RP_SetMenuTitle(menu, "Menu - Room Menu\n ◉ Choose a player to bring here:\n ", count);
	
	SetMenuExitBackButton(menu, true);
	
	DisplayMenu(menu, client, 0);

}

public MenuCallBack_ShowAdminRoomInsideAddPlayer(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_Cancel && key == MenuCancel_ExitBack)
	{
		Command_AdminRooms(client, 0);
	}
	if (action == MenuAction_Select)
	{

		new String:szItemData[11];
		GetMenuItem(menu, key, szItemData, sizeof(szItemData));
		new iTargetTemp = GetClientOfUserId(StringToInt(szItemData));
		
		if(iTargetTemp != 0)
		{
			if (g_iAdminRoom[iTargetTemp] != -1)
			{
				RP_PrintToChat(client, "%s \x02%N\x01 is already in a admin room.", " \x04[Admins Rooms]\x01", iTargetTemp);
			}
			else if(RP_GetKarma(iTargetTemp) >= BOUNTY_KARMA)
			{
				RP_PrintToChat(client, "%s \x02%N\x01 is bounty. Cannot teleport.", " \x04[Admins Rooms]\x01", iTargetTemp);
			}
			else if(RP_IsUserInDuel(iTargetTemp) || RP_IsUserInArena(iTargetTemp))
			{
				RP_PrintToChat(client, "%s \x02%N\x01 is dueling / ja. Cannot teleport.", " \x04[Admins Rooms]\x01", iTargetTemp);
			}
			else if((CheckCommandAccess(iTargetTemp, "sm_cca_root", ADMFLAG_ROOT) && !CheckCommandAccess(client, "sm_cca_root", ADMFLAG_ROOT)) || !CanAdminTarget(GetUserAdmin(client), GetUserAdmin(iTargetTemp)))
			{
				RP_PrintToChat(client, "%s \x02%N\x01 is an higher admin than you. Cannot teleport", " \x04[Admins Rooms]\x01", iTargetTemp);
				
				RP_PrintToChat(iTargetTemp, "\x02%N\x01 tried to teleport you to \x02Admin Room #%i", client, g_iAdminRoom[client] + 1);
			}
			else
			{
				MoveClientToAdminRoom(iTargetTemp, g_iAdminRoom[client]);
				
				PrintToAdminChatRoom(g_iAdminRoom[client], "\x02%N\x01 has teleported \x04%N\x01 to the admin room!", client, iTargetTemp);
				RP_PrintToChat(iTargetTemp, "%s You were teleported to \x02Admin Room #%i\x01 by \x04%N", " \x04[Admins Rooms]\x01", g_iAdminRoom[client] + 1, client);
				PrintToAdmins("\x02%N\x01 has teleported \x04%N\x01 to \x02Admin Room #%i\x01", client, iTargetTemp, g_iAdminRoom[client] + 1);
			}
		}
		
		Command_AdminRooms(client, 0);
	}
	else
	{
		if (action == MenuAction_End)
		{
			CloseHandle(menu);
			menu = null;
		}
	}
}
Menu_ShowAdminRoomMain(client)
{
	new Menu:menu = CreateMenu(MenuCallBack_ShowAdminRoomMain, MenuAction:28);
	RP_SetMenuTitle(menu, "Menu - Main Menu\n ");

	char[][] szMenuItem = new char[adminRoomsSize][256];
	
	new bool:bEmptyRoom[MAXPLAYERS+1] = true;
	
	for(new i=0;i < sizeof(bEmptyRoom);i++)
	{
		bEmptyRoom[i] = true;
	}
		
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		else if(g_iAdminRoom[i] == -1)
			continue;
			
		Format(szMenuItem[g_iAdminRoom[i]], 256, "%s%N, ", szMenuItem[g_iAdminRoom[i]], i);
		
		bEmptyRoom[g_iAdminRoom[i]] = false;
		
		//PrintToAdmins("fearless [%N] %i", i, g_iAdminRoom[i])
	}
	
	for(new i=0;i < adminRoomsSize;i++)
	{
		if(!CheckCommandAccess(client, g_sAdminRoomsCCA[i], ADMFLAG_ROOT))
		{
			new bool:Found = false;
			
			for (new a = 1; a <= MaxClients;a++)
			{
				if(IsClientInGame(a) && CheckCommandAccess(a, g_sAdminRoomsCCA[i], ADMFLAG_ROOT))
					Found = true;
				
			}
			
			if(Found)
				continue;
		}	
		//PrintToAdmins("fearless222 [%i] %i", i, bEmptyRoom[i])
		if(bEmptyRoom[i])
			FormatEx(szMenuItem[i], 256, "Admin Room #%i [Empty]", i + 1);
			
		else
		{
			new len = strlen(szMenuItem[i]);
			szMenuItem[i][len - 2] = EOS;
			Format(szMenuItem[i], 256, "Admin Room #%i [%s]", i + 1, szMenuItem[i]);
		}
		
		AddMenuItem(menu, "", szMenuItem[i], 0);
	}
		
	DisplayMenu(menu, client, 0);
}

public MenuCallBack_ShowAdminRoomMain(Menu:menu, MenuAction:action, client, key)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		menu = null;
	}
	else if (action == MenuAction_Select)
	{
		if(!IsPlayerAlive(client))
			return;
			
		MoveClientToAdminRoom(client, key);

		PrintToAdmins("\x02%N\x01 has teleported himself to \x04Admin Room #%i\x01", client, key + 1);
	}
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	if (!client || g_iAdminRoom[client] == -1)
	{
		return Plugin_Continue;
	}
	if (sArgs[0] == '@' || sArgs[0] == '!' || sArgs[0] == '/')
	{
		return Plugin_Continue;
	}

	if (IsPlayerAdmin(client) && g_bTeleportPlayer[client])
	{
		if (!StrEqual(sArgs, "-1", true))
		{
			char target_name[MAX_TARGET_LENGTH];
			int[] target_list = new int[MaxClients+1];
			int target_count;
			bool tn_is_ml;

			target_count = ProcessTargetString(
							sArgs,
							client,
							target_list,
							MaxClients,
							COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_ALIVE|COMMAND_FILTER_NO_IMMUNITY,
							target_name,
							sizeof(target_name),
							tn_is_ml);


			if(target_count <= COMMAND_TARGET_NONE)
			{
				g_bTeleportPlayer[client] = false;
				ReplyToTargetError(client, target_count);
				Menu_ShowAdminRoomInside(client);
				return Plugin_Handled;
			}
			
			int iTarget = target_list[0];
			
			if (g_iAdminRoom[iTarget] != -1)
			{
				RP_PrintToChat(client, "%s \x02%N\x01 is already in a admin room.", " \x04[Admins Rooms]\x01", iTarget);
			}
			else if(RP_GetKarma(iTarget) >= BOUNTY_KARMA)
			{
				RP_PrintToChat(client, "%s \x02%N\x01 is bounty. Cannot teleport.", " \x04[Admins Rooms]\x01", iTarget);
			}
			else if(RP_IsUserInDuel(iTarget) || RP_IsUserInArena(iTarget))
			{
				RP_PrintToChat(client, "%s \x02%N\x01 is dueling / ja. Cannot teleport.", " \x04[Admins Rooms]\x01", iTarget);
			}
			else if((CheckCommandAccess(iTarget, "sm_cca_root", ADMFLAG_ROOT) && !CheckCommandAccess(client, "sm_cca_root", ADMFLAG_ROOT)) || !CanAdminTarget(GetUserAdmin(client), GetUserAdmin(iTarget)))
			{
				
				RP_PrintToChat(client, "%s \x02%N\x01 is an higher admin than you. Cannot teleport", " \x04[Admins Rooms]\x01", iTarget);
				
				RP_PrintToChat(iTarget, "%s \x02%N\x01 tried to teleport you to \x02Admin Room #%i", " \x04[Admins Rooms]\x01", client, g_iAdminRoom[client] + 1);
			}
			else
			{
				MoveClientToAdminRoom(iTarget, g_iAdminRoom[client]);
				
				PrintToAdminChatRoom(g_iAdminRoom[client], "\x02%N\x01 has teleported \x04%N\x01 to the admin room!", client, iTarget);
				
				RP_PrintToChat(iTarget, "%s You were teleported to \x02Admin Room #%i\x01 by \x04%N", " \x04[Admins Rooms]\x01", g_iAdminRoom[client] + 1, client);
				
				PrintToAdmins("\x02%N\x01 has teleported \x04%N\x01 to \x02Admin Room #%i\x01", client, iTarget, g_iAdminRoom[client] + 1);
			}
		}
		g_bTeleportPlayer[client] = false;
		return Plugin_Stop;
	}
	PrintToAdminChatRoom(g_iAdminRoom[client], "\x02%N: \x01%s", client, sArgs);
	
	return Plugin_Stop;
}

public OnClientDisconnect(client)
{
	if (g_iAdminRoom[client] != -1)
	{		
		PrintToAdmins("\x02%N\x01 has left \x04Admin Room #%i\x01 by a disconnection", client, g_iAdminRoom[client] + 1);
		
		RP_StopPlayerSuiciding(client);
		
		new oldRoom = g_iAdminRoom[client];
		
		KickFromAdminRoom(client)
		
		if (CheckForEmptyAdminRoom(oldRoom))
		{
			PrintToAdminChatRoom(oldRoom, "\x02%N\x01 has left the admin room so everyone was kicked.", client);
			
			for(new i=1;i <= MaxClients;i++)
			{
				if(!IsClientInGame(i))
					continue;
				
				else if(g_iAdminRoom[i] != oldRoom)
					continue;
					
				KickFromAdminRoom(i);
			}
		}
		else
		{
			PrintToAdminChatRoom(oldRoom, "\x02%N\x01 has left the admin room.", client);
			
			UpdateRoomMenu(oldRoom);
		}
	}
}

public OnClientPutInServer(client)
{
	g_iAdminRoom[client] = -1;
	g_bTeleportPlayer[client] = false;
	
	fNextReport[client] = 0.0;
}

UpdateRoomMenu(room)
{
	if(room == -1)
		return;
		
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(g_iAdminRoom[i] != room)
			continue;
			
		else if(!IsPlayerAdmin(i))
			continue;
			
		Menu_ShowAdminRoomInside(i);
	}
}

KickFromAdminRoom(client)
{	
	if (g_iAdminRoom[client] != -1)
	{
		g_iAdminRoom[client] = -1;
		
		if(IsVectorZero(g_fClientLastOrigin[client]))
			CS_RespawnPlayer(client);
			
		else
			TeleportEntity(client, g_fClientLastOrigin[client], NULL_VECTOR, NULL_VECTOR);
		
		RP_TryTeleportToJail(client);
		
		RP_StopPlayerSuiciding(client);
		
		if(GetEntityMoveType(client) == MOVETYPE_NONE)
		{ 
			
			new value = GetConVarInt(hcv_showActivity);
			
			SetConVarInt(hcv_showActivity, 0);
			
			ServerCommand("sm_freeze #%i 0", GetClientUserId(client));
				
			SetConVarInt(hcv_showActivity, value);
		}
	}
}

// Returns true if room should be emptied due to 0 admins left.

stock bool:CheckForEmptyAdminRoom(room)
{
	new bool:bAdmin;
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(room != g_iAdminRoom[i])
			continue;
		
		else if(IsPlayerAdmin(i))
		{
			bAdmin = true;
			
			break;
		}
	}
	
	return !bAdmin;
}
bool:IsPlayerAdmin(client)
{
	return CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC);
}

PrintToAdminChatRoom(room, String:message[], any:...)
{
	new String:szFormattedMessage[256];
	VFormat(szFormattedMessage, 256, message, 3);
	Format(szFormattedMessage, 256, "%s %s", " \x04[Admins Rooms]\x01", szFormattedMessage);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if(!IsClientInGame(i))
			continue;
		
		else if(g_iAdminRoom[i] != room)
			continue;
			
		RP_PrintToChat(i, "%s", szFormattedMessage);
	}
}

PrintToAdmins(String:message[], any:...)
{
	new String:szFormattedMessage[256];
	VFormat(szFormattedMessage, 256, message, 2);
	Format(szFormattedMessage, 256, "%s %s", " \x04[Admins Rooms]\x01", szFormattedMessage);
	
	for(new i=1;i <= MaxClients;i++)
	{
		if (IsClientInGame(i) && IsPlayerAdmin(i))
		{
			RP_PrintToChat(i, "%s", szFormattedMessage);
		}
	}
}

RemoveDisconnectedFromArray()
{
	int size = GetArraySize(Array_Reports);
	
	enReport report;
	for (int i = 0; i < size;i++)
	{
		GetArrayArray(Array_Reports, i, report, sizeof(enReport));
		
		int UserId = report.UserId;
		
		int client = GetClientOfUserId(UserId);
		
		if(client == 0)
		{
			RemoveFromArray(Array_Reports, i);

			RemoveDisconnectedFromArray();

			break; // Go backwards because we deleted an entry from the array.
		}
	}
}

RemoveClientReports(client)
{
	int size = GetArraySize(Array_Reports);
				
	enReport report;
	for (int i = 0; i < size;i++)
	{
		GetArrayArray(Array_Reports, i, report, sizeof(enReport));
		
		int UserId = report.UserId;
		
		int reporter = GetClientOfUserId(UserId);
		
		if(client == reporter)
		{
			RemoveFromArray(Array_Reports, i);

			RemoveClientReports(client);

			break; // Go backwards because we deleted an entry from the array.
		}
	}
}

FindReportBySerial(serial)
{
	new size = GetArraySize(Array_Reports);
	
	enReport report;
	
	for (new i = 0; i < size;i++)
	{
		GetArrayArray(Array_Reports, i, report, sizeof(enReport));
		
		if(report.ReportSerial == serial)
		{
			return i;
		}
	}
	
	return -1;
}

stock bool:IsVectorZero(Float:Vector[3])
{
	return Vector[0] == 0.0 && Vector[1] == 0.0 && Vector[2] == 0.0;
}
 