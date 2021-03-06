/*
 * MyJailbreak - Warden Queue Plugin.
 * by: Douile
 * https://github.com/douile/
 *
 * https://github.com/shanapu/MyJailbreak/
 *
 * This file is part of the MyJailbreak SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/* Includes */
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <colors>
#include <autoexecconfig>
#include <myjailbreak>
#include <warden>
#include <myjbwarden>
#include <mystocks>

/* Compiler options */
#pragma semicolon 1
#pragma newdecls required


/* ConVars */
ConVar gc_bPlugin;
ConVar gc_bRemoveTemp;
ConVar gc_bEmptyRandomWarden;
ConVar gc_bVIPSkip;
ConVar gc_bAutoQueue;
ConVar gc_sAdminFlag;
ConVar gc_sPrefix;

/* Third-party ConVars */
ConVar gtc_bChooseRandom;
ConVar gtc_bWardenStay;
ConVar gtc_bWardenBecome;
ConVar gtc_bWadenChoice;

/* Cookies */
Handle gC_autoQueue;
Handle gC_banQueue;

/* Handles */
Handle g_aWardenQueue;
Handle g_aMenuData;

/* Strings */
#define MAX_PREFIX_LENGTH 64
char gs_prefix[MAX_PREFIX_LENGTH] = "[{green}MyJB.Queue{default}]";
#define BOOL_STRING_LEN 8
char STRING_TRUE[BOOL_STRING_LEN] = "true";
char STRING_FALSE[BOOL_STRING_LEN] = "false";

/* Booleans */
bool g_bRoundActive = false;

/* Plugin info */
#define PLUGIN_VERSION "0.7"

public Plugin myinfo = {
  name = "MyJailbreak - Warden Queue",
  author = "Douile",
  version = PLUGIN_VERSION,
  url = "https://github.com/Douile/myjb_warden_queue"
};

/* Start */
public void OnPluginStart() {

  LoadTranslations("MyJailbreak.WardenQueue.phrases");

  /* Client Commands */
  RegConsoleCmd("sm_warden", Command_JoinWardenQueue, "Join the warden queue");
  RegConsoleCmd("sm_unwarden", Command_LeaveWardenQueue, "Step down as warden and leave the warden queue");
  AddCommandListener(CommandListener_JoinWardenQueue,"sm_warden");
  AddCommandListener(CommandListener_JoinWardenQueue,"sm_w");
  AddCommandListener(CommandListener_LeaveWardenQueue,"sm_unwarden");
  AddCommandListener(CommandListener_LeaveWardenQueue,"sm_uw");
  RegConsoleCmd("sm_lwq", Command_LeaveWardenQueue, "Step down as warden and leave the warden queue");
  RegConsoleCmd("sm_viewwardenqueue", Command_ListQueue, "Print out current queue for warden");
  RegConsoleCmd("sm_vwq", Command_ListQueue, "Print out current queue for warden");
  RegConsoleCmd("sm_aq", Command_AutoQueue, "Toggle auto warden queue prefence, if on guards will also join the queue when enabled");
  RegConsoleCmd("sm_autoqueue", Command_AutoQueue, "Toggle auto warden queue prefence, if on guards will also join the queue when enabled");


  /* Admin Commands */
  RegAdminCmd("sm_wrq", AdminCommand_RemoveFromQueue, ADMFLAG_GENERIC, "Remove a player from the warden queue");
  RegAdminCmd("sm_bwq", AdminCommand_BanFromQueue, ADMFLAG_GENERIC, "Ban a player from the warden queue");

  /* AutoExecConfig */
  AutoExecConfig_SetFile("Warden_Queue", "MyJailbreak");
  AutoExecConfig_SetCreateFile(true);

  /* ConVars */
  AutoExecConfig_CreateConVar("sm_wardenqueue_version", PLUGIN_VERSION, "Version of MyJB wardenqueue", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
  gc_bPlugin = AutoExecConfig_CreateConVar("sm_wardenqueue_enable","1","0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
  gc_bRemoveTemp = AutoExecConfig_CreateConVar("sm_wardenqueue_removetemporary","1","0/1 - remove wardens set after a warden death from the queue", _, true, 0.0, true, 1.0);
  gc_bEmptyRandomWarden = AutoExecConfig_CreateConVar("sm_wardenqueue_emptyrandom","0","0/1 - choose a random warden if the queue is empty at the start of the round", _, true, 0.0, true, 1.0);
  gc_bVIPSkip = AutoExecConfig_CreateConVar("sm_wardenqueue_vipskip","1","0/1 - allow VIPs to skip to the front of warden queue", _, true, 0.0, true, 1.0);
  gc_bAutoQueue = AutoExecConfig_CreateConVar("sm_wardenqueue_autoqueue","1","0/1 - enable autoqueuing for guards", _, true, 0.0, true, 1.0);
  gc_sPrefix = AutoExecConfig_CreateConVar("sm_wardenqueue_prefix","MyJB.Queue","prefix for warden queue messages");
  gc_sAdminFlag = AutoExecConfig_CreateConVar("sm_wardenqueue_vipflag","a","Flag for VIP");

  /* AutoExecConfig finalize */
  AutoExecConfig_ExecuteFile();
  AutoExecConfig_CleanFile();

  /* Cookies */
  gC_autoQueue = RegClientCookie("wardenqueue_autoqueue","Automatically join the warden queue when playing as a guard", CookieAccess_Protected);
  gC_banQueue = RegClientCookie("wardenqueue_banqueue", "Time left in queue ban", CookieAccess_Private);

  /* Hooks */
  HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
  HookEvent("round_poststart", Event_RoundStartPost, EventHookMode_Post);
  HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);

  /* Arrays */
  int max_clients = GetMaxClients();
  g_aWardenQueue = CreateArray(1, max_clients);
  g_aMenuData = CreateArray(max_clients+2, max_clients);
}

public void OnAllPluginsLoaded() {
  /* Force variables */
  gtc_bChooseRandom = FindConVar("sm_warden_choose_random");
  SetConVarString(gtc_bChooseRandom, "0", true, false);
  HookConVarChange(gtc_bChooseRandom, ConVarChangeFalse);
  gtc_bWardenStay = FindConVar("sm_warden_stay");
  SetConVarString(gtc_bWardenStay, "0", true, false);
  HookConVarChange(gtc_bWardenStay, ConVarChangeFalse);
  gtc_bWardenBecome = FindConVar("sm_warden_become");
  SetConVarString(gtc_bWardenBecome, "0", true, false);
  HookConVarChange(gtc_bWardenBecome, ConVarChangeFalse);
  gtc_bWadenChoice = FindConVar("sm_warden_choice");
  SetConVarString(gtc_bWadenChoice, "0", true, false);
  HookConVarChange(gtc_bWadenChoice, ConVarChangeFalse);

  /* Update prefix */
  char prefix[MAX_PREFIX_LENGTH];
  GetConVarString(gc_sPrefix, prefix, MAX_PREFIX_LENGTH);
  UpdatePrefix(prefix);
  HookConVarChange(gc_sPrefix, ConVarChangePrefix);
}

public void ConVarChangeFalse(ConVar cvar, const char[] oldValue, const char[] newValue) {
  if (!StrEqual(newValue, "0")) {
    SetConVarString(cvar, "0", true, false);
  }
}

public void ConVarChangePrefix(ConVar cvar, const char[] oldValue, const char[] newValue) {
  UpdatePrefix(newValue);
}


/*==============================================================================
   Command Listeners
==============================================================================*/

public Action CommandListener_JoinWardenQueue(int client, const char[] command, int argc) {
  Command_JoinWardenQueue(client, argc);
  return Plugin_Stop;
}

public Action CommandListener_LeaveWardenQueue(int client, const char[] command, int argc) {
  Command_LeaveWardenQueue(client, argc);
  return Plugin_Stop;
}

/*==============================================================================
   Commands
==============================================================================*/

public Action Command_LeaveWardenQueue(int client, int args) {
  if (!IsValidClient(client, false, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue) return Plugin_Handled;

  if (IsPlayerInWardenQueue(client)) {
    if (GetClientCookieBool(client, gC_autoQueue)) {
      SetClientCookie(client, gC_autoQueue, STRING_FALSE);
      CReplyToCommand(client, "%s %t", gs_prefix, "autoqueue_disabled");
    }
    RemovePlayerFromWardenQueue(client);
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_left");
  } else {
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_not_left");
  }

  if (warden_iswarden(client)) {
    warden_removed(client); /* This checks whether client is warden and removes if he is */
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_retire");
  }

  return Plugin_Handled;
}

public Action Command_JoinWardenQueue(int client, int args) {
  if (!IsValidClient(client, false, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue) return Plugin_Handled;

  if (GetClientTeam(client) == CS_TEAM_CT) {
    /* Must be CT to join warden queue */
    if (!warden_exist()) {
      /* No current warden so skip queue */
      warden_set(client, client);
      CReplyToCommand(client, "%s %t", gs_prefix, "queue_skipped");
    } else {
      /* Check VIP */
      int iIndex = FindValueInArray(g_aWardenQueue, client);
      if (iIndex > -1) {
        CReplyToCommand(client, "%s %t", gs_prefix, "queue_inqueue", iIndex+1);
      } else {
        int pos = AddPlayerToWardenQueue(client)+1;
        if (pos > -1) CReplyToCommand(client, "%s %t", gs_prefix, "queue_joinqueue", pos);
        else CReplyToCommand(client, "%s %t", gs_prefix, "queue_joinerror");
      }
    }
  } else {
    int iWarden = warden_get();
    if (IsValidClient(iWarden, true, true)) {
      char sWarden[MAX_NAME_LENGTH];
      GetClientName(iWarden, sWarden, MAX_NAME_LENGTH);
      CReplyToCommand(client, "%s %t", gs_prefix, "queue_currentwarden", sWarden);
    } else {
      CReplyToCommand(client, "%s %t", gs_prefix, "queue_nowarden");
    }
  }

  return Plugin_Handled;
}

public Action Command_ListQueue(int client, int args) {
  if (!IsValidClient(client, false, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue) return Plugin_Handled;

  int length = GetArraySize(g_aWardenQueue);

  if (length > 0) {
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_listqueue");

    for (int i=0;i<length;i++) {
      char name[MAX_NAME_LENGTH];

      int qClient = GetArrayCell(g_aWardenQueue, i);
      GetClientName(qClient, name, MAX_NAME_LENGTH);

      CReplyToCommand(client, "%d. {purple}%s{default}", i+1, name);
    }
  } else {
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_emptyqueue");
  }

  return Plugin_Handled;
}

public Action Command_AutoQueue(int client, int args) {
  if (!IsValidClient(client, false, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue || !gc_bAutoQueue.BoolValue) return Plugin_Handled;

  bool currentValue = GetClientCookieBool(client, gC_autoQueue);
  SetClientCookie(client, gC_autoQueue, currentValue ? STRING_FALSE : STRING_TRUE);

  if (GetClientTeam(client) == CS_TEAM_CT) {
    if (!currentValue) {
      int pos = AddPlayerToWardenQueue(client);
      if (pos > -1) CReplyToCommand(client, "%s %t", gs_prefix, "autoqueue_join", pos+1);
    }
  }

  char locMessage[32];
  locMessage = currentValue ? "autoqueue_disabled" : "autoqueue_enabled";
  CReplyToCommand(client, "%s %t", gs_prefix, locMessage);

  return Plugin_Handled;
}

public Action AdminCommand_RemoveFromQueue(int client, int args) {
  if (!IsValidClient(client, false, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue) return Plugin_Handled;

  int length = GetArraySize(g_aWardenQueue);

  if (length > 0) {
    Handle menu = CreateMenu(Menu_RemoveFromQueue);
    SetMenuTitle(menu, "Warden queue");

    if (length > 9) {
      SetMenuPagination(menu, 7);
    } else {
      SetMenuExitButton(menu, true);
    }
    for (int i=0;i<length;i++) {
      int qClient = GetArrayCell(g_aWardenQueue, i);
      char qName[MAX_NAME_LENGTH];
      GetClientName(qClient, qName, MAX_NAME_LENGTH);
      AddMenuItem(menu, qName, qName, ITEMDRAW_DEFAULT);
    }

    DisplayMenu(menu, client, 15);
  } else {
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_emptyqueue");
  }
  return Plugin_Handled;
}

public Action AdminCommand_BanFromQueue(int client, int args) {
  if (!IsValidClient(client, false, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue) return Plugin_Handled;

  return DisplayMenu_BanFromQueue(client);
}

/*==============================================================================
   Menu handlers
==============================================================================*/

public int Menu_RemoveFromQueue(Handle menu, MenuAction action, int client, int item) {
  if (IsValidClient(client, true, true)) {
    int target = GetArrayCell(g_aWardenQueue, item);
    RemoveFromArray(g_aWardenQueue, item);

    char targetName[MAX_NAME_LENGTH];
    GetClientName(target, targetName, MAX_NAME_LENGTH);

    char adminName[MAX_NAME_LENGTH];
    GetClientName(client, adminName, MAX_NAME_LENGTH);

    CPrintToChatAll("%s %t", gs_prefix, "queue_adminremove", adminName, targetName);
  }
}

public int Menu_BanFromQueue(Handle menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    int max_clients = GetMaxClients();
    int[] menuData = new int[max_clients];

    int size = GetArrayArray(g_aMenuData, client, menuData, max_clients);
    if (item >= 0 && item < size) {
      int target = menuData[item];

      DisplayMenu_BanFromQueue_Player(client, target);
    }
  } else if (action == MenuAction_Cancel) {
    SetArrayCell(g_aMenuData, client, 0);
  }
}

public int Menu_BanFromQueue_Player(Handle menu, MenuAction action, int client, int item) {
  if (action == MenuAction_Select) {
    /* TODO: add ban player action
       Unban or
       ban for selected time
       (Set cookie)
    */
  } else if (action == MenuAction_Cancel) {
    DisplayMenu_BanFromQueue(client);
  }
}

/*==============================================================================
   Menu generators
==============================================================================*/

Action DisplayMenu_BanFromQueue(int client) {
  if (!CheckCommandAccess(client, "sm_bwq", ADMFLAG_GENERIC, true)) return Plugin_Handled;

  int clients = GetClientCount(true);

  int[] menuData = new int[clients];

  Handle menu = CreateMenu(Menu_BanFromQueue);
  if (clients > 9) {
    SetMenuPagination(menu, 7);
  } else {
    SetMenuExitButton(menu, true);
  }

  int menuPos = 0;

  for (int i=1;i<=MaxClients;i++) {
    if (i != client && IsValidClient(i,false,true) && CanAdminTarget(client, i)) {
      char cName[MAX_NAME_LENGTH];
      GetClientName(i, cName, MAX_NAME_LENGTH);
      bool added = AddMenuItem(menu, cName, cName, ITEMDRAW_DEFAULT);
      if (added) {
        menuData[menuPos] = i;
        menuPos += 1;
      }
    }
  }

  SetArrayArray(g_aMenuData, client, menuData, menuPos);

  return Plugin_Handled;
}

Action DisplayMenu_BanFromQueue_Player(int client, int target) {
  if (!CheckCommandAccess(client, "sm_bwq", ADMFLAG_GENERIC, true)) return Plugin_Handled;
  /* Maybe check client can target the target here */

  /* TODO: Generate player info menu (name, currently banned, unban, ban for amount of time) */
}

/*==============================================================================
   Events
==============================================================================*/

public Action Event_PlayerTeam_Post(Event event, const char[] szName, bool bDontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));

  /* If player switches from CT remove them from warden queue */
  if (event.GetInt("team") == CS_TEAM_CT) {
    if (gc_bAutoQueue.BoolValue) {
      if (GetClientCookieBool(client, gC_autoQueue)) {
        int pos = AddPlayerToWardenQueue(client);
        if (pos > -1) CPrintToChat(client, "%s %t", gs_prefix, "autoqueue_join", pos+1);
      }
    }
  } else {
    RemovePlayerFromWardenQueue(client);
    CPrintToChat(client, "%s %t", gs_prefix, "queue_left");
  }
  return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] szName, bool bDontBroadcast) {
  g_bRoundActive = false;
  return Plugin_Continue;
}

public Action Event_RoundStartPost(Event event, const char[] szName, bool bDontBroadcast) {
  g_bRoundActive = true;
  ChooseNextWarden(true);
  return Plugin_Continue;
}

/*==============================================================================
   General functions
==============================================================================*/

 int AddPlayerToWardenQueue(int client) {
  int iIndex = FindValueInArray(g_aWardenQueue, client);

  if (iIndex == -1) {
    if (IsPlayerVIP(client) && gc_bVIPSkip.BoolValue) {
      CPrintToChat(client,"%s %t", gs_prefix, "queue_vip");
      int length = GetArraySize(g_aWardenQueue);
      if (length > 0) {
        for (int i=0;i<length;i++) {
          int iClient = GetArrayCell(g_aWardenQueue, i);
          if (!IsPlayerVIP(iClient)) {
            ShiftArrayUp(g_aWardenQueue, i);
            SetArrayCell(g_aWardenQueue, i, client);
            iIndex = i;
            break;
          }
        }
        if (iIndex == -1) {
          iIndex = PushArrayCell(g_aWardenQueue, client);
        }
      } else {
        iIndex = PushArrayCell(g_aWardenQueue, client);
      }
    } else {
      iIndex = PushArrayCell(g_aWardenQueue, client);
    }
  }

  return iIndex;
}

bool IsPlayerInWardenQueue(int client) {
  int iIndex = FindValueInArray(g_aWardenQueue, client);

  return iIndex != -1;
}

bool IsPlayerVIP(int client) {
  return MyJailbreak_CheckVIPFlags(client, "sm_wqueue_flag", gc_sAdminFlag, "sm_wqueue_flag");
}

int ScanValidWarden() {
  for (int i=0;i<GetArraySize(g_aWardenQueue);i++) {
    int client = GetArrayCell(g_aWardenQueue, i);
    if (IsValidClient(client, false, false))
      return i;
  }
  return -1;
}

bool RemovePlayerFromWardenQueue(int client) {
  int iIndex = FindValueInArray(g_aWardenQueue, client);
  if (iIndex == -1) return;
  RemoveFromArray(g_aWardenQueue, iIndex);
}

void ChooseNextWarden(bool shouldRemove) {
  if (GetArraySize(g_aWardenQueue)) {
    int iWarden = ScanValidWarden();

    if (iWarden > -1) {
      int warden = GetArrayCell(g_aWardenQueue, 0);
      if (shouldRemove) {
        RemoveFromArray(g_aWardenQueue, iWarden);
        if (gc_bAutoQueue.BoolValue) {
          if (GetClientCookieBool(warden, gC_autoQueue)) {
            int pos = AddPlayerToWardenQueue(warden);
            if (pos > -1) CPrintToChat(warden, "%s %t", gs_prefix, "autoqueue_join", pos+1);
          }
        }
      }

      char wardenName[MAX_NAME_LENGTH];
      GetClientName(warden, wardenName, MAX_NAME_LENGTH);

      CPrintToChatAll("%s %t", gs_prefix, "queue_next", wardenName, GetArraySize(g_aWardenQueue));
      SetWarden(warden);
      return;
    }
  }
  /* No wardens in queue, random ct will be chosen */
  if (gc_bEmptyRandomWarden.BoolValue) {
    int client = GetRandomPlayerEx(CS_TEAM_CT, true);
    if (client > -1) {
      char clientName[MAX_NAME_LENGTH];
      GetClientName(client, clientName, MAX_NAME_LENGTH);

      CPrintToChatAll("%s %t", gs_prefix, "queue_random", clientName);
      SetWarden(client);
    } else {
      /* No valid guards */
    }
  }
}

void SetWarden(int target) {
  if (!IsValidClient(target,true,false)) return;
  if (!warden_exist()) {
    warden_set(target,target);
  } else {
    int limit = 5;
    Handle datapack = CreateDataPack();
    WritePackCell(datapack, target);
    WritePackCell(datapack, limit);
    WritePackCell(datapack, 0);
    CreateTimer(0.2, Timer_SetWarden, datapack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
  }
}

void UpdatePrefix(const char[] prefix) {
  Format(gs_prefix,MAX_PREFIX_LENGTH,"[{green}%s{default}]",prefix);
}

/*==============================================================================
   Timers
==============================================================================*/

public Action Timer_SetWarden(Handle timer, Handle datapack) {
  ResetPack(datapack);
  int target = ReadPackCell(datapack);
  int limit = ReadPackCell(datapack);
  int current = ReadPackCell(datapack);

  if (!warden_exist()) {
    if (IsValidClient(target,true,false)) warden_set(target, target);
    return Plugin_Stop;
  } else if (current < limit && IsValidClient(target,true,false)) {
    ResetPack(datapack);
    WritePackCell(datapack, target);
    WritePackCell(datapack, limit);
    WritePackCell(datapack, current + 1);
    return Plugin_Continue;
  } else {
    return Plugin_Stop;
  }
}

/*==============================================================================
   Forwards
==============================================================================*/

public void OnClientDisconnect_Post(int client) {
  RemovePlayerFromWardenQueue(client);
}

public void warden_OnWardenRemoved(int client) {
 if (g_bRoundActive) {
   ChooseNextWarden(gc_bRemoveTemp.BoolValue);
 }
}

/*==============================================================================
   Stocks
==============================================================================*/

stock bool GetClientCookieBool(int client, Handle cookie) {
  char buf[BOOL_STRING_LEN];
  GetClientCookie(client, cookie, buf, BOOL_STRING_LEN);
  return StrContains(buf,"true",false) > -1 || strcmp(buf,"1") == 0;
}

stock int GetRandomPlayerEx(int team, bool alive) {
  int[] clients = new int[MaxClients];
  int clientCount;

  for (int i = 1; i <= MaxClients; i++)	{
    if (!IsValidClient(i, true, !alive))
      continue;

    if (GetClientTeam(i) != team)
      continue;

    clients[clientCount++] = i;
  }

  return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}
