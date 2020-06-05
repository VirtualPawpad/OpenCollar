  
/*
This file is a part of OpenCollar.
Copyright ©2020


: Contributors :

Aria (Tashia Redrose)
    *June 2020       -       Created oc_api
      * This implements some auth features, and acts as a API Bridge for addons and plugins
    
    
et al.
Licensed under the GPLv2. See LICENSE for full details.
https://github.com/OpenCollarTeam/OpenCollar

*/
list g_lOwner;
list g_lTrust;
list g_lBlock;

integer g_iMode;

integer ACTION_ADD = 1;
integer ACTION_REM = 2;
integer ACTION_SCANNER = 4;
integer ACTION_OWNER = 8;
integer ACTION_TRUST = 16;
integer ACTION_BLOCK = 32;

//MESSAGE MAP
integer CMD_ZERO = 0;
integer CMD_OWNER = 500;
integer CMD_TRUSTED = 501;
integer CMD_GROUP = 502;
integer CMD_WEARER = 503;
integer CMD_EVERYONE = 504;
integer CMD_RLV_RELAY = 507;
integer CMD_SAFEWORD = 510;
integer CMD_RELAY_SAFEWORD = 511;
integer CMD_NOACCESS=599;


string UPMENU = "BACK";
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved
//str must be in form of "token=value"
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the settings script sends responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from settings
integer LM_SETTING_EMPTY = 2004;//sent when a token has no value

Dialog(key kID, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string sName) {
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);

    integer iIndex = llListFindList(g_lMenuIDs, [kID]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, sName], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, sName];
}
string SLURL(key kID){
    return "secondlife:///app/agent/"+(string)kID+"/about";
}

key g_kWearer;
key g_kTry;
integer g_iCurrentAuth;
key g_kMenuUser;
integer CalcAuth(key kID){
    string sID = (string)kID;
    // First check
    if(llGetListLength(g_lOwner) == 0 && llGetListLength(g_lTrust)==0 && kID==g_kWearer)
        return CMD_OWNER;
    else{
        if(llListFindList(g_lBlock,[sID])!=-1)return CMD_NOACCESS;
        if(llListFindList(g_lOwner, [sID])!=-1)return CMD_OWNER;
        if(llListFindList(g_lTrust,[sID])!=-1)return CMD_TRUSTED;
        
        if(g_iPublic)return CMD_EVERYONE;
        
    }
        
    
    
    return CMD_NOACCESS;
}

list g_lMenuIDs;
integer g_iMenuStride;

integer NOTIFY = 1002;
integer REBOOT = -1000;
integer g_iPublic;
string g_sPrefix;
integer g_iChannel=1;
integer g_iListenHandle;
integer g_iListenHandlePrivate;

PrintAccess(key kID){
    string sFinal = "\n \nAccess List:\nOwners:";
    integer i=0;
    integer end = llGetListLength(g_lOwner);
    for(i=0;i<end;i++){
        sFinal += "\n   "+SLURL(llList2String(g_lOwner,i));
    }
    end=llGetListLength(g_lTrust);
    sFinal+="\nTrusted:";
    for(i=0;i<end;i++){
        sFinal+="\n   "+SLURL(llList2String(g_lTrust,i));
    }
    end = llGetListLength(g_lBlock);
    sFinal += "\nBlock:";
    for(i=0;i<end;i++){
        sFinal += "\n   "+SLURL(llList2String(g_lBlock,i));
    }
    sFinal+="\n";
    llMessageLinked(LINK_SET,NOTIFY, "0"+sFinal,kID);
    llSay(0, sFinal);
}

DoListeners(){
    llListenRemove(g_iListenHandlePrivate);
    g_iListenHandlePrivate = llListen(g_iChannel, "", "", "");
    llListenRemove(g_iListenHandle);
    g_iListenHandle = llListen(0, "", "", "");
}
UpdateLists(key kID){
    integer iMode = g_iMode;
    if(iMode&ACTION_ADD){
        if(iMode&ACTION_OWNER){
            if(llListFindList(g_lOwner, [(string)kID])==-1){
                g_lOwner+=kID;
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been added as owner", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_owner="+llDumpList2String(g_lOwner,","), kID);
                g_iMode = ACTION_REM | ACTION_TRUST | ACTION_BLOCK;
                UpdateLists(kID);
            }
        }
        if(iMode & ACTION_TRUST){
            if(llListFindList(g_lTrust, [(string)kID])==-1){
                g_lTrust+=kID;
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been added to the trusted user list", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_trust="+llDumpList2String(g_lTrust, ","),kID);
                g_iMode = ACTION_REM | ACTION_OWNER | ACTION_BLOCK;
                UpdateLists(kID);
            }
        }
        if(iMode & ACTION_BLOCK){
            if(llListFindList(g_lBlock, [(string)kID])==-1){
                g_lBlock+=kID;
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been blocked", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_block="+llDumpList2String(g_lBlock,","),"");
                g_iMode=ACTION_REM|ACTION_OWNER|ACTION_TRUST;
                UpdateLists(kID);
            }
        }
    } else if(iMode&ACTION_REM){
        if(iMode&ACTION_OWNER){
            if(llListFindList(g_lOwner, [(string)kID])!=-1){
                integer iPos = llListFindList(g_lOwner, [(string)kID]);
                g_lOwner = llDeleteSubList(g_lOwner, iPos, iPos);
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been removed from the owner role", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_owner="+llDumpList2String(g_lOwner,","),"");
            }
        } 
        if(iMode&ACTION_TRUST){
            if(llListFindList(g_lTrust, [(string)kID])!=-1){
                integer iPos = llListFindList(g_lTrust, [(string)kID]);
                g_lTrust = llDeleteSubList(g_lTrust, iPos, iPos);
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been removed from the trusted role", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_trust="+llDumpList2String(g_lTrust, ","),"");
            }
        }
        if(iMode & ACTION_BLOCK){
            if(llListFindList(g_lBlock, [(string)kID])!=-1){
                integer iPos = llListFindList(g_lBlock, [(string)kID]);
                g_lBlock = llDeleteSubList(g_lBlock, iPos, iPos);
                llMessageLinked(LINK_SET, NOTIFY, "1"+SLURL(kID)+" has been removed from the blocked list", kID);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "auth_block="+llDumpList2String(g_lBlock,","),"");
            }
        }
    }
}
default
{
    state_entry(){
        g_kWearer = llGetOwner();
        g_sPrefix = llToLower(llGetSubString(llKey2Name(llGetOwner()),0,1));
        DoListeners();
    }
    listen(integer c,string n,key i,string m){
        if(llToLower(llGetSubString(m,0,1))==g_sPrefix){
            string CMD=llGetSubString(m,2,-1);
            if(llGetSubString(CMD,0,0)==" ")CMD=llDumpList2String(llParseString2List(CMD,[" "],[]), " ");
            llMessageLinked(LINK_SET, CMD_ZERO, CMD, i);
        }
    }
    link_message(integer iSender, integer iNum, string sStr, key kID){
        if(iNum == CMD_ZERO){
            integer iAuth = CalcAuth(kID);
            llSay(0, "{API} Calculate auth for "+(string)kID+"="+(string)iAuth);
            llMessageLinked(LINK_SET, iAuth, sStr, kID);
        } else if(iNum == LM_SETTING_RESPONSE){
            list lPar = llParseString2List(sStr, ["_","="],[]);
            string sToken = llList2String(lPar,0);
            string sVar = llList2String(lPar,1);
            string sVal = llList2String(lPar,2);
            
            if(sToken == "auth"){
                if(sVar == "owner"){
                    g_lOwner=llParseString2List(sVal, [","],[]);
                } else if(sVar == "trust"){
                    g_lTrust = llParseString2List(sVal,[","],[]);
                } else if(sVar == "block"){
                    g_lBlock = llParseString2List(sVal,[","],[]);
                } else if(sVar == "public"){
                    g_iPublic=(integer)sVal;
                }
            } else if(sToken == "global"){
                if(sVar == "channel"){
                    g_iChannel = (integer)sVal;
                    DoListeners();
                } else if(sVar == "prefix"){
                    g_sPrefix = sVal;
                }
            }
        } else if(iNum == CMD_OWNER){
            list lCmd = llParseString2List(sStr, [" "],[]);
            string sCmd = llToLower(llList2String(lCmd,0));
            
            if(sCmd == "channel"){
                g_iChannel = (integer)llList2String(lCmd,1);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "global_channel="+(string)g_iChannel, kID);
            } else if(sCmd == "prefix"){
                g_sPrefix = llList2String(lCmd,1);
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "global_prefix="+g_sPrefix,kID);
            } else if(sCmd == "add" || sCmd == "rem"){
                string sType = llToLower(llList2String(lCmd,1));
                string sID;
                if(llGetListLength(lCmd)==3) sID = llList2String(lCmd,2);
                
                g_kMenuUser=kID;
                g_iCurrentAuth = iNum;
                if(sCmd=="add")
                    g_iMode = ACTION_ADD;
                else g_iMode=ACTION_REM;
                if(sType == "owner")g_iMode = g_iMode|ACTION_OWNER;
                else if(sType == "trust")g_iMode = g_iMode|ACTION_TRUST;
                else if(sType == "block")g_iMode=g_iMode|ACTION_BLOCK;
                else return; // Invalid, don't continue
                
                if(sID == ""){
                    // Open Scanner Menu to add
                    if(g_iMode&ACTION_ADD){
                        g_iMode = g_iMode|ACTION_SCANNER;
                        llSensor("", "", AGENT, 20, PI);
                    } else {
                        list lOpts;
                        if(sType == "owner")lOpts=g_lOwner;
                        else if(sType == "trust")lOpts=g_lTrust;
                        else if(sType == "block")lOpts=g_lBlock;
                        Dialog(kID, "OpenCollar\n\nRemove "+sType, lOpts, [UPMENU],0,iNum,"removeUser");
                    }
                }else {
                    UpdateLists((key)sID);
                }
            } else if(sStr == "print auth"){
                PrintAccess(kID);
            }
        }
        else if(iNum == DIALOG_RESPONSE){
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if(iMenuIndex!=-1){
                string sMenu = llList2String(g_lMenuIDs, iMenuIndex+1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex-1, iMenuIndex-2+g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"],[]);
                key kAv = llList2Key(lMenuParams,0);
                string sMsg = llList2String(lMenuParams,1);
                integer iAuth = llList2Integer(lMenuParams,3);
                integer iRespring=TRUE;
                
                if(sMenu == "scan~add"){
                    if(sMsg == UPMENU){
                        llMessageLinked(LINK_SET, iAuth, "menu Access", kAv);
                        return;
                    } else if(sMsg == ">Wearer<"){
                        UpdateLists(llGetOwner());
                        llMessageLinked(LINK_SET, 0, "menu Access", kAv);
                    }else {
                        //UpdateLists((key)sMsg);
                        g_kTry = (key)sMsg;
                        if(!(g_iMode&ACTION_BLOCK))
                            Dialog(g_kTry, "OpenCollar\n\n"+SLURL(g_kTry)+" is trying to add you to an access list, do you agree?", ["Yes", "No"], [], 0, CMD_NOACCESS, "scan~confirm");
                        else UpdateLists((key)sMsg);
                    }
                } else if(sMenu == "scan~confirm"){
                    if(sMsg == "No"){
                        g_iMode = 0;
                        llMessageLinked(LINK_SET, 0, "menu Access", kAv);
                    } else if(sMsg == "Yes"){
                        UpdateLists(g_kTry);
                        llSleep(1);
                        llMessageLinked(LINK_SET, 0, "menu Access", kAv);
                    }
                } else if(sMenu == "removeUser"){
                    if(sMsg == UPMENU){
                        llMessageLinked(LINK_SET,0, "menu Access", kAv);
                    }else{
                        UpdateLists(sMsg);
                    }
                }
            }
        }
    }
    sensor(integer iNum){
        if(!(g_iMode&ACTION_SCANNER))return;
        list lPeople = [];
        integer i=0;
        for(i=0;i<iNum;i++){
            if(llGetListLength(lPeople)<10){
                //llSay(0, "scan: "+(string)i+";"+(string)llGetListLength(lPeople)+";"+(string)g_iMode);
                if(llDetectedKey(i)!=llGetOwner())
                    lPeople += llDetectedKey(i);
                
            } else {
                //llSay(0, "scan: invalid list length: "+(string)llGetListLength(lPeople)+";"+(string)g_iMode);
            }
        }
        
        Dialog(g_kMenuUser, "OpenCollar\nAdd Menu", lPeople, [">Wearer<",UPMENU], 0, g_iCurrentAuth, "scan~add");
    }
}
