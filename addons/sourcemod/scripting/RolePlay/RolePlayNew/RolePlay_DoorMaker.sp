#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>


// This define prevents RP_PrintToChat from making prefixes
#include <Eyal-RP>

#define MENU_ACTION_OFFSET -3

#define KV_ROOT_NAME "Spawns"
#define MENU_ITEM_BACK 7
#define MENU_ITEM_DELETE_RULE 6

#define MENU_SELECT_SOUND	"buttons/button14.wav"
#define MENU_EXIT_SOUND	"buttons/combine_button7.wav"

#define PLUGIN_VERSION "1.0"

new ClientDoorID[MAXPLAYERS+1], ClientDoorPrice[MAXPLAYERS+1];
new ClientRentDoorID[MAXPLAYERS+1], ClientRentDoorPrice[MAXPLAYERS+1];

new Handle:Array_ConnectedDoors[MAXPLAYERS+1];

new String:DoorsPath[1024];

public Plugin:myinfo = 
{
	name = "RolePlay Door Maker",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Create and Delete RolePlay Doors",
	version = PLUGIN_VERSION,
	url = ""
}


public OnPluginStart()
{
	_NO_PREFIX = true;
	
	BuildPath(Path_SM, DoorsPath, sizeof(DoorsPath), "configs/doors.ini");
	
	RegAdminCmd("sm_invertinsidedoor", Command_InvertInsideDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_changepricedoor", Command_ChangePriceDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_adddoor", Command_AddDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_addrentdoor", Command_AddRentDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_addconnecteddoor", Command_AddConnectedDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_resetconnecteddoors", Command_ResetConnectedDoors, ADMFLAG_ROOT);
	RegAdminCmd("sm_deletedoor", Command_DeleteDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_confirmdoor", Command_ConfirmAddDoor, ADMFLAG_ROOT);
	RegAdminCmd("sm_confirmrentdoor", Command_ConfirmAddRentDoor, ADMFLAG_ROOT);
	
	for(new i=1;i <= MaxClients;i++)
	{
		Array_ConnectedDoors[i] = CreateArray(1);
	}
}

public OnClientConnected(client)
{
	ClearArray(Array_ConnectedDoors[client]);
}
public OnClientPostAdminCheck(client)
{

}

public OnMapStart()
{
	PrecacheSound(MENU_SELECT_SOUND);
	PrecacheSound(MENU_EXIT_SOUND);
}

public Action:Command_ConfirmAddDoor(client, args)
{
	if(ClientDoorID[client] == -1)
	{
		ReplyToCommand(client, "[SM] Use sm_adddoor <price> before confirming door creation");
		return Plugin_Handled;
	}
	AddNewDoor(ClientDoorID[client], ClientDoorPrice[client], Array_ConnectedDoors[client]);
					
	ClientDoorID[client] = -1;
	ClientDoorPrice[client] = 0;
				
	ClearArray(Array_ConnectedDoors[client]);
	
	RP_PrintToChat(client, "Door was successfully added.");
	
	return Plugin_Handled;
}


public Action:Command_ConfirmAddRentDoor(client, args)
{
	if(ClientRentDoorID[client] == -1)
	{
		ReplyToCommand(client, "[SM] Use sm_addrentdoor <price> before confirming door creation");
		return Plugin_Handled;
	}
	AddNewRentDoor(ClientRentDoorID[client], ClientRentDoorPrice[client]);
					
	ClientRentDoorID[client] = -1;
	ClientRentDoorPrice[client] = 0;
	
	RP_PrintToChat(client, "Rent Door was successfully added.");
	
	return Plugin_Handled;
}

public Action:Command_InvertInsideDoor(client, args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_invertinsidedoor <1/0>");
		return Plugin_Handled;
	}
	
	new String:Arg[11];
	GetCmdArg(1, Arg, sizeof(Arg));
	
	new invert = StringToInt(Arg);
	
	if(invert != 0 && invert != 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_invertinsidedoor <1/0>");
		return Plugin_Handled;
	}
	
	new target = GetClientAimTarget(client, false);
	
	if(target != -1)
	{
		if(!HasEntProp(target, Prop_Data, "m_iHammerID"))
			target = -1;
	}
	
	if(target == -1)
	{
		ReplyToCommand(client, "[SM] Error: couldn't find a valid door at your aim.");
		return Plugin_Handled;
	}
	
	new HammerID = GetEntProp(target, Prop_Data, "m_iHammerID");
	
	if(SetInvertInsideDoor(HammerID, view_as<bool>(invert)))
	{
		RP_PrintToChat(client, "Door was successfully set invert inside to %i.", invert);
	}
	else
	{
		RP_PrintToChat(client, "Door does not exist.");
	}
	
	return Plugin_Handled;
}


public Action:Command_ChangePriceDoor(client, args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_changepricedoor <price>");
		return Plugin_Handled;
	}
	
	new String:Arg[11];
	GetCmdArg(1, Arg, sizeof(Arg));
	
	new price = StringToInt(Arg);
	
	if(price <= 0)
	{
		ReplyToCommand(client, "[SM] Error: price cannot be lower than 1.");
		return Plugin_Handled;
	}
	
	new target = GetClientAimTarget(client, false);
	
	if(target != -1)
	{
		if(!HasEntProp(target, Prop_Data, "m_iHammerID"))
			target = -1;
	}
	
	if(target == -1)
	{
		ReplyToCommand(client, "[SM] Error: couldn't find a valid door at your aim.");
		return Plugin_Handled;
	}
	
	new HammerID = GetEntProp(target, Prop_Data, "m_iHammerID");
	
	if(ChangeDoorPrice(HammerID, price))
	{
		RP_PrintToChat(client, "Changed price of the door to %i [ HID: %i ]", price, HammerID);
	}
	else
	{
		RP_PrintToChat(client, "Door does not exist.");
	}
	
	return Plugin_Handled;
}


public Action:Command_AddDoor(client, args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_adddoor <price>");
		return Plugin_Handled;
	}
	
	new String:Arg[11];
	GetCmdArg(1, Arg, sizeof(Arg));
	
	new price = StringToInt(Arg);
	
	if(price <= 0)
	{
		ReplyToCommand(client, "[SM] Error: price cannot be lower than 1.");
		return Plugin_Handled;
	}
	
	new target = GetClientAimTarget(client, false);
	
	if(target != -1)
	{
		if(!HasEntProp(target, Prop_Data, "m_iHammerID"))
			target = -1;
	}
	
	if(target == -1)
	{
		ReplyToCommand(client, "[SM] Error: couldn't find a valid door at your aim.");
		return Plugin_Handled;
	}
	
	new HammerID = GetEntProp(target, Prop_Data, "m_iHammerID");
	
	ClientDoorID[client] = HammerID;
	ClientDoorPrice[client] = price;
	
	new String:Classname[64];
	
	GetEdictClassname(target, Classname, sizeof(Classname));
	
	RP_PrintToChat(client, "Preparing to set up a %s [ HID: %i ] as a door priced at %i", Classname, HammerID, price);
	RP_PrintToChat(client, "Use sm_confirmdoor if you're certain you want to add the door.");

	return Plugin_Handled;
}


public Action:Command_AddRentDoor(client, args)
{
	if(args == 0)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addrentdoor <price>");
		return Plugin_Handled;
	}
	
	new String:Arg[11];
	GetCmdArg(1, Arg, sizeof(Arg));
	
	new price = StringToInt(Arg);
	
	if(price <= 0)
	{
		ReplyToCommand(client, "[SM] Error: price cannot be lower than 1.");
		return Plugin_Handled;
	}
	
	new target = GetClientAimTarget(client, false);
	
	if(target != -1)
	{
		if(!HasEntProp(target, Prop_Data, "m_iHammerID"))
			target = -1;
	}
	
	if(target == -1)
	{
		ReplyToCommand(client, "[SM] Error: couldn't find a valid door at your aim.");
		return Plugin_Handled;
	}
	
	new HammerID = GetEntProp(target, Prop_Data, "m_iHammerID");
	
	ClientRentDoorID[client] = HammerID;
	ClientRentDoorPrice[client] = price;
	
	new String:Classname[64];
	
	GetEdictClassname(target, Classname, sizeof(Classname));
	
	RP_PrintToChat(client, "Preparing to set up a %s [ HID: %i ] as a rented door priced at %i", Classname, HammerID, price);
	RP_PrintToChat(client, "Use sm_confirmrentdoor if you're certain you want to add the door.");
	
	return Plugin_Handled;
}


public Action:Command_AddConnectedDoor(client, args)
{	
	new target = GetClientAimTarget(client, false);
	
	if(target != -1)
	{
		if(!HasEntProp(target, Prop_Data, "m_iHammerID"))
			target = -1;
	}
	
	if(target == -1)
	{
		ReplyToCommand(client, "[SM] Error: couldn't find a valid door at your aim.");
		return Plugin_Handled;
	}
	
	new HammerID = GetEntProp(target, Prop_Data, "m_iHammerID");
	
	new String:Classname[64];
	
	GetEdictClassname(target, Classname, sizeof(Classname));
	
	if(FindValueInArray(Array_ConnectedDoors[client], HammerID) != -1)
	{
		ReplyToCommand(client, "[SM] Error: couldn't find a valid door at your aim.");
		return Plugin_Handled;
	}
	PushArrayCell(Array_ConnectedDoors[client], HammerID);
	
	RP_PrintToChat(client, "Attached a %s [ HID: %i ] as a connected door [Σ%i]", Classname, HammerID, GetArraySize(Array_ConnectedDoors[client]));
	RP_PrintToChat(client, "Use sm_resetconnecteddoors if you added the wrong door.");
	
	return Plugin_Handled;
}

public Action:Command_ResetConnectedDoors(client, args)
{	
	ClearArray(Array_ConnectedDoors[client]);
	
	RP_PrintToChat(client, "Deattached all selected connected doors");
	
	return Plugin_Handled;
}

public Action:Command_DeleteDoor(client, args)
{
	new target = GetClientAimTarget(client, false);
	
	if(target != -1)
	{
		if(!HasEntProp(target, Prop_Data, "m_iHammerID"))
			target = -1;
	}
	
	if(target == -1)
	{
		ReplyToCommand(client, "[SM] Error: couldn't find a valid door at your aim.");
		return Plugin_Handled;
	}
	
	new HammerID = GetEntProp(target, Prop_Data, "m_iHammerID");
	
	new String:Classname[64];
	
	GetEdictClassname(target, Classname, sizeof(Classname));
	
	if(!DeleteExistingDoor(HammerID)) 
	{
		RP_PrintToChat(client, "Target %s is not added as a buyable door", Classname);
		return Plugin_Handled;
	}
	
	RP_PrintToChat(client, "Target %s, Hammer ID %i was successfully deleted", Classname, HammerID);
	return Plugin_Handled;
}

stock AddNewDoor(HammerID, price, Handle:ConnectedDoorsArray)
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, DoorsPath))
	{
		CreateEmptyKvFile(DoorsPath);
		
		if(!FileToKeyValues(keyValues, DoorsPath))
			SetFailState("Something that should never happen has happened.");
	}
	
	KvJumpToKey(keyValues, "Doors", true);
	
	new String:sHammerID[11];
	
	IntToString(HammerID, sHammerID, sizeof(sHammerID));
	
	KvJumpToKey(keyValues, sHammerID, true);
	
	KvSetNum(keyValues, "price", price);
	
	for(new i=0;i < GetArraySize(ConnectedDoorsArray);i++)
	{
		new String:Key[32];
		
		FormatEx(Key, sizeof(Key), "connected_door_%i", i + 1);
		
		KvSetNum(keyValues, Key, GetArrayCell(ConnectedDoorsArray, i));
	}
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, DoorsPath);
	CloseHandle(keyValues);
	
	return true;
}

stock AddNewRentDoor(HammerID, price)
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, DoorsPath))
	{
		CreateEmptyKvFile(DoorsPath);
		
		if(!FileToKeyValues(keyValues, DoorsPath))
			SetFailState("Something that should never happen has happened.");
	}
	
	KvJumpToKey(keyValues, "Rented Doors", true);
	
	new String:sHammerID[11];
	
	IntToString(HammerID, sHammerID, sizeof(sHammerID));
	
	KvJumpToKey(keyValues, sHammerID, true);
	
	KvSetNum(keyValues, "price", price);
	
	KvRewind(keyValues);
	
	KeyValuesToFile(keyValues, DoorsPath);
	CloseHandle(keyValues);
	
	return true;
}

stock bool:DeleteExistingDoor(HammerID)
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, DoorsPath))
	{
		CloseHandle(keyValues);
		return false;
	}
	
	KvJumpToKey(keyValues, "Doors");
	
	if(!KvGotoFirstSubKey(keyValues, false))
	{
		CloseHandle(keyValues);
		return false;
	}	
	
	new bool:Deleted, String:SectionName[11];
	
	do
	{
		KvGetSectionName(keyValues, SectionName, sizeof(SectionName));
		
		if(StringToInt(SectionName) == HammerID)
		{
			Deleted = true;
			KvDeleteThis(keyValues);
			break;
		}
	}
	while(KvGotoNextKey(keyValues))
	
	KvRewind(keyValues);
	
	if(Deleted)
	{
		KeyValuesToFile(keyValues, DoorsPath);
		CloseHandle(keyValues);
		
		return Deleted;
	}
	KvJumpToKey(keyValues, "Rented Doors");
	
	if(!KvGotoFirstSubKey(keyValues, false))
	{
		CloseHandle(keyValues);
		return false;
	}	
	
	do
	{
		KvGetSectionName(keyValues, SectionName, sizeof(SectionName));
		
		if(StringToInt(SectionName) == HammerID)
		{
			Deleted = true;
			KvDeleteThis(keyValues);
			break;
		}
	}
	while(KvGotoNextKey(keyValues))
	
	KvRewind(keyValues);
	
	KeyValuesToFile(keyValues, DoorsPath);
	CloseHandle(keyValues);
	
	return Deleted;
}


stock bool:SetInvertInsideDoor(HammerID, bool:invertInside)
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, DoorsPath))
	{
		CloseHandle(keyValues);
		return false;
	}
	else if(!KvGotoFirstSubKey(keyValues, false))
	{
		CloseHandle(keyValues);
		return false;
	}
	
	KvJumpToKey(keyValues, "Doors");
	
	if(!KvGotoFirstSubKey(keyValues, false))
	{
		CloseHandle(keyValues);
		return false;
	}
	
	new bool:Inverted, String:SectionName[11];
	
	do
	{
		KvGetSectionName(keyValues, SectionName, sizeof(SectionName));
		
		if(StringToInt(SectionName) == HammerID)
		{
			Inverted = true;
			KvSetNum(keyValues, "invertInside", invertInside);
			break;
		}
	}
	while(KvGotoNextKey(keyValues))
	
	KvRewind(keyValues);
	
	if(Inverted)
	{
		KeyValuesToFile(keyValues, DoorsPath);
		CloseHandle(keyValues);
		
		return Inverted;
	}
	
	KvJumpToKey(keyValues, "Rented Doors")
	
	if(!KvGotoFirstSubKey(keyValues, false))
	{

		CloseHandle(keyValues);
		return false;
	}	
	
	do
	{
		KvGetSectionName(keyValues, SectionName, sizeof(SectionName));
		
		if(StringToInt(SectionName) == HammerID)
		{
			Inverted = true;
			KvSetNum(keyValues, "invertInside", invertInside);
			break;
		}
	}
	while(KvGotoNextKey(keyValues))
	
	KvRewind(keyValues);
	
	KeyValuesToFile(keyValues, DoorsPath);
	CloseHandle(keyValues);
	
	return Inverted;
}


stock ChangeDoorPrice(HammerID, price)
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	if(!FileToKeyValues(keyValues, DoorsPath))
	{
		CreateEmptyKvFile(DoorsPath);
		
		if(!FileToKeyValues(keyValues, DoorsPath))
			SetFailState("Something that should never happen has happened.");
	}
	
	else if(!KvGotoFirstSubKey(keyValues, false))
	{
		CloseHandle(keyValues);
		return false;
	}
	
	KvJumpToKey(keyValues, "Doors");
	
	new String:sHammerID[11];
	
	IntToString(HammerID, sHammerID, sizeof(sHammerID));
	
	if(!KvJumpToKey(keyValues, sHammerID, false))
	{
		CloseHandle(keyValues);
		return false;
	}
	KvSetNum(keyValues, "price", price);
	
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, DoorsPath);
	CloseHandle(keyValues);
	
	return true;
}

stock CreateEmptyKvFile(const String:Path[])
{
	new Handle:keyValues = CreateKeyValues(KV_ROOT_NAME);
	
	KvRewind(keyValues);
	KeyValuesToFile(keyValues, Path);
	
	CloseHandle(keyValues);
}