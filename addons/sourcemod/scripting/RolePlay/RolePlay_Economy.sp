#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>
#include <updater>
#undef REQUIRE_PLUGIN
#include <Eyal-RP>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0"

new Handle:fwEconomyLoaded = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "RolePlay Economy",
	author = "Author was lost, heavy edit by Eyal282",
	description = "Allows to manage the roleplay's economy into key values.",
	version = PLUGIN_VERSION,
	url = ""
}

new Handle:Trie_TrieList;

new String:EcoPath[PLATFORM_MAX_PATH];

#define FPERM_ULTIMATE (FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC|FPERM_G_READ|FPERM_G_WRITE|FPERM_G_EXEC|FPERM_O_READ|FPERM_O_WRITE|FPERM_O_EXEC)


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("RP_GetEcoTrie", Native_GetEcoTrie);
	 
	RegPluginLibrary("RP Economy");
	
	return APLRes_Success;
}

public any:Native_GetEcoTrie(Handle:plugin, numParams)
{
	if(Trie_TrieList == INVALID_HANDLE)
		return INVALID_HANDLE;
		
	new String:Key[64];
	
	GetNativeString(1, Key, sizeof(Key));
	
	new Handle:Trie;
	
	if(GetTrieValue(Trie_TrieList, Key, Trie))
		return Trie;
		
	else
		return INVALID_HANDLE;
}

Handle hcv_URL;

public OnPluginStart()
{
	Trie_TrieList = CreateTrie();
	
	fwEconomyLoaded = CreateGlobalForward("RP_OnEcoLoaded", ET_Ignore);
	
	BuildPath(Path_SM, EcoPath, sizeof(EcoPath), "configs/RolePlay_Economy");
	
	CreateDirectory(EcoPath, FPERM_ULTIMATE);
	
	RegAdminCmd("sm_eco", Command_Eco, ADMFLAG_ROOT, "Loads the economy file");

	CreateProtectedConVar("community_prefix", " {NORMAL}[{RED}RolePlay{NORMAL}] {NORMAL}");
	CreateProtectedConVar("community_menu_prefix", "[RolePlay] ");
	hcv_URL = CreateProtectedConVar("rp_economy_url", "https://raw.githubusercontent.com/eyal282/WePlayRP-Economy/master/Economy/updatefile.txt");
}

public OnAllPluginsLoaded()
{
	ReadEcoFile();
}

public OnLibraryAdded(const String:name[])
{
	if(LibraryExists("RolePlay_Jobs") && LibraryExists("RolePlay_NPC") && LibraryExists("RolePlay_Cash"))
		ReadEcoFile();
}

public Action:Command_Eco(client, args)
{
	char UPDATE_URL[512];
	GetConVarString(hcv_URL, UPDATE_URL, sizeof(UPDATE_URL));
	
	Updater_AddPlugin(UPDATE_URL);
	
	Updater_ForceUpdate();
	
	Updater_RemovePlugin();
	
	return Plugin_Handled;
}

public Updater_OnPluginUpdated()
{
	ReadEcoFile();
}

ReadEcoFile()
{
	new Handle:TrieSnapshot = CreateTrieSnapshot(Trie_TrieList);
	
	for(new i=0;i < TrieSnapshotLength(TrieSnapshot);i++)
	{
		new String:Key[64];
		GetTrieSnapshotKey(TrieSnapshot, i, Key, sizeof(Key));
		
		new Handle:Trie;
		GetTrieValue(Trie_TrieList, Key, Trie);
		
		CloseHandle(Trie);
	}
	
	CloseHandle(TrieSnapshot);
	ClearTrie(Trie_TrieList);
	
	new Handle:dir = OpenDirectory(EcoPath);
	
	new String:FileName[64], String:FullPath[PLATFORM_MAX_PATH], FileType:type;
	while(ReadDirEntry(dir, FileName, sizeof(FileName), type))
	{
		if(type != FileType_File)
			continue;
			
		// While the previous condition would filter out directories, it's still a good practice.
		else if(StrEqual(FileName, ".") || StrEqual(FileName, ".."))
			continue;
			
		FormatEx(FullPath, sizeof(FullPath), "%s/%s", EcoPath, FileName);
		
		new Handle:keyValues = CreateKeyValues("DUMMY_VALUE");
		
		if(!FileToKeyValues(keyValues, FullPath))
		{
			SetFailState("%s is not a keyvalue file", FullPath);
			
			return;
		}
		
		new String:SectionName[64];
		KvGetSectionName(keyValues, SectionName, sizeof(SectionName));
		
		new Handle:Trie;
		
		if(GetTrieValue(Trie_TrieList, SectionName, Trie))
		{	
			SetFailState("Duplicate key value found: %s", SectionName);
			
			return;
		}
		
		else if(!KvGotoFirstSubKey(keyValues, false))
		{
			SetFailState("%s is invalid keyvalue file", FullPath);
			
			return;
		}
		
		Trie = CreateTrie();
		
		SetTrieValue(Trie_TrieList, SectionName, Trie);
		
		do
		{
			KvSavePosition(keyValues);
			
			KvGotoFirstSubKey(keyValues, false);
			
			
			new String:Key[64];
			KvGetSectionName(keyValues, Key, sizeof(Key));
		
			KvGoBack(keyValues);	
			
			SetTrieString(Trie, Key, "DUMMY_VALUE");
			
		}
		while(KvGotoNextKey(keyValues, false))
		
		KvGoBack(keyValues);
		
		TrieSnapshot = CreateTrieSnapshot(Trie);
		
		for(new i=0;i < TrieSnapshotLength(TrieSnapshot);i++)
		{
			new String:Key[64], String:Value[64];
			GetTrieSnapshotKey(TrieSnapshot, i, Key, sizeof(Key));
			
			KvGetString(keyValues, Key, Value, sizeof(Value), "");
			
			SetTrieString(Trie, Key, Value);
		}
		
		CloseHandle(TrieSnapshot);
		
		CloseHandle(keyValues);
	}
	
	Call_StartForward(fwEconomyLoaded);
	
	Call_Finish();
}
