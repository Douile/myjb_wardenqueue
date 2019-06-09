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
#include <colors>
#include <autoexecconfig>
#include <myjailbreak>
#include <warden>
#include <mystocks>

/* Compiler options */
#pragma semicolon 1
#pragma newdecls required


/* ConVars */
ConVar gc_bPlugin;
ConVar gc_bRemoveTemp;
ConVar gc_bEmptyRandomWarden;
ConVar gc_bVIPSkip;
ConVar gc_sAdminFlag;
ConVar gc_sPrefix

/* Third-party ConVars */
ConVar gtc_bChooseRandom;
ConVar gtc_bWardenStay;
ConVar gtc_bWardenBecome;
ConVar gtc_bWadenChoice;

/* Handles */
Handle g_aWardenQueue;

/* Strings */
#define MAX_PREFIX_LENGTH 64
char gs_prefix[MAX_PREFIX_LENGTH] = "[{green}MyJB.Queue{default}]";

/* Booleans */
bool g_bRoundActive = false;

/* Plugin info */
#define PLUGIN_VERSION "0.6"

public Plugin myinfo = {
  name = "MyJailbreak - Warden Queue",
  author = "Douile",
  version = PLUGIN_VERSION
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


  /* Admin Commands */
  RegAdminCmd("sm_wrq", AdminCommand_RemoveFromQueue, ADMFLAG_GENERIC, "Remove a player from the warden queue");

  /* AutoExecConfig */
  AutoExecConfig_SetFile("Warden_Queue", "MyJailbreak");
  AutoExecConfig_SetCreateFile(true);

  /* ConVars */
  AutoExecConfig_CreateConVar("sm_wardenqueue_version", PLUGIN_VERSION, "Version of MyJB wardenqueue", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
  gc_bPlugin = AutoExecConfig_CreateConVar("sm_wardenqueue_enable","1","0 - disable, 1 - enable", _, true, 0.0, true, 1.0);
  gc_bRemoveTemp = AutoExecConfig_CreateConVar("sm_wardenqueue_removetemporary","1","0/1 - remove wardens set after a warden death from the queue", _, true, 0.0, true, 1.0);
  gc_bEmptyRandomWarden = AutoExecConfig_CreateConVar("sm_wardenqueue_emptyrandom","0","0/1 - choose a random warden if the queue is empty at the start of the round", _, true, 0.0, true, 1.0);
  gc_sAdminFlag = AutoExecConfig_CreateConVar("sm_wardenqueue_vipflag","a","Flag for VIP");
  gc_bVIPSkip = AutoExecConfig_CreateConVar("sm_wardenqueue_vipskip","1","0/1 - allow VIPs to skip to the front of warden queue", _, true, 0.0, true, 1.0);
  gc_sPrefix = AutoExecConfig_CreateConVar("sm_wardenqueue_prefix","MyJB.Queue","prefix for warden queue messages")

  /* AutoExecConfig finalize */
  AutoExecConfig_ExecuteFile();
  AutoExecConfig_CleanFile();

  /* Hooks */
  HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
  HookEvent("round_poststart", Event_RoundStartPost, EventHookMode_Post);
  HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);

  /* Arrays */
  g_aWardenQueue = CreateArray();
}

/* Force variables */
public void OnAllPluginsLoaded() {
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

  char prefix[MAX_PREFIX_LENGTH];
  GetConVarString(gc_sPrefix, prefix, MAX_PREFIX_LENGTH)
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


/* Command Listeners */

public Action CommandListener_JoinWardenQueue(int client, const char[] command, int argc) {
  Command_JoinWardenQueue(client, argc);
  return Plugin_Stop;
}

public Action CommandListener_LeaveWardenQueue(int client, const char[] command, int argc) {
  Command_LeaveWardenQueue(client, argc);
  return Plugin_Stop;
}

/* Commands */

public Action Command_LeaveWardenQueue(int client, int args) {
  if (!IsValidClient(client, true, true)) return Plugin_Handled;
  if (!gc_bPlugin.BoolValue) return Plugin_Handled;

  if (warden_iswarden(client)) {
    warden_removed(client); /* This checks whether client is warden and removes if he is */
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_retire");
  } else if (IsPlayerInWardenQueue(client)) {
    RemovePlayerFromWardenQueue(client);
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_left");
  } else {
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_not_left");
  }

  return Plugin_Handled;
}

public Action Command_JoinWardenQueue(int client, int args) {
  if (!IsValidClient(client, true, true)) return Plugin_Handled;
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
        CReplyToCommand(client, "%s %t", gs_prefix, "queue_joinqueue", pos);
      }
    }
  } else {
    CReplyToCommand(client, "%s %t", gs_prefix, "queue_notguard");
  }

  return Plugin_Handled;
}

public Action Command_ListQueue(int client, int args) {
  if (!IsValidClient(client, true, true)) return Plugin_Handled;
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

public Action AdminCommand_RemoveFromQueue(int client, int args) {
  if (!IsValidClient(client, true, true)) return Plugin_Handled;
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

/* Menus */
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

/* Events */

public Action Event_PlayerTeam_Post(Event event, const char[] szName, bool bDontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));

  /* If player switches from CT remove them from warden queue */
  if (event.GetInt("team") != CS_TEAM_CT) {
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

/* Functions */

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

void ChooseNextWarden(bool shouldRemove) {
  if (GetArraySize(g_aWardenQueue)) {
    int iWarden = ScanValidWarden();

    if (iWarden > -1) {
      int warden = GetArrayCell(g_aWardenQueue, 0);
      if (shouldRemove)
        RemoveFromArray(g_aWardenQueue, iWarden);

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

int GetRandomPlayerEx(int team, bool alive) {
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

void SetWarden(int target) {
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

/* Timers */
public Action Timer_SetWarden(Handle timer, Handle datapack) {
  ResetPack(datapack);
  int target = ReadPackCell(datapack);
  int limit = ReadPackCell(datapack);
  int current = ReadPackCell(datapack);

  if (!warden_exist()) {
    warden_set(target, target);
    return Plugin_Stop;
  } else {
    if (current < limit) {
      ResetPack(datapack);
      WritePackCell(datapack, target);
      WritePackCell(datapack, limit);
      WritePackCell(datapack, current + 1);
    } else {
      return Plugin_Stop;
    }
  }
  return Plugin_Continue;
}

/* Forwards */

public void OnClientDisconnect_Post(int client) {
  RemovePlayerFromWardenQueue(client);
}

public void warden_OnWardenRemoved(int client) {
 if (g_bRoundActive) {
   ChooseNextWarden(gc_bRemoveTemp.BoolValue);
 }
}

/* Stocks */

stock bool RemovePlayerFromWardenQueue(int client) {
  int iIndex = FindValueInArray(g_aWardenQueue, client);
  if (iIndex == -1) return;
  RemoveFromArray(g_aWardenQueue, iIndex);
}
