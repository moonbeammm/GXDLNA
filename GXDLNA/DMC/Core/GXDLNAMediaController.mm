#include "GXDLNAMediaController.h"
#import "GXDLNAResponseModel.h"
#import "GXDLNAPositionInfoModel.h"

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::PLT_MicroMediaController
 +---------------------------------------------------------------------*/
PLT_MicroMediaController::PLT_MicroMediaController(PLT_CtrlPointReference& ctrlPoint,GXDLNADMControl * delegateWrapper) :
PLT_SyncMediaBrowser(ctrlPoint),
PLT_MediaController(ctrlPoint),
m_Target(delegateWrapper)
{
    // create the stack that will be the directory where the
    // user is currently browsing.
    // push the root directory onto the directory stack.
    m_CurBrowseDirectoryStack.Push("0");
    
    PLT_MediaController::SetDelegate(this);
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::PLT_MicroMediaController
 +---------------------------------------------------------------------*/
PLT_MicroMediaController::~PLT_MicroMediaController()
{
}

/*
 *  Remove trailing white space from a string
 */
static void strchomp(char* str)
{
    if (!str) return;
    char* e = str+NPT_StringLength(str)-1;
    
    while (e >= str && *e) {
        if ((*e != ' ')  &&
            (*e != '\t') &&
            (*e != '\r') &&
            (*e != '\n'))
        {
            *(e+1) = '\0';
            break;
        }
        --e;
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::ChooseIDFromTable
 +---------------------------------------------------------------------*/
/*
 * Presents a list to the user, allows the user to choose one item.
 *
 * Parameters:
 *		PLT_StringMap: A map that contains the set of items from
 *                        which the user should choose.  The key should be a unique ID,
 *						 and the value should be a string describing the item.
 *       returns a NPT_String with the unique ID.
 */
const char*
PLT_MicroMediaController::ChooseIDFromTable(PLT_StringMap& table)
{
    printf("投屏GXDLNAMediaController:Select one of the following:\n");
    
    NPT_List<PLT_StringMapEntry*> entries = table.GetEntries();
    if (entries.GetItemCount() == 0) {
        printf("投屏GXDLNAMediaController:None available\n");
    } else {
        // display the list of entries
        NPT_List<PLT_StringMapEntry*>::Iterator entry = entries.GetFirstItem();
        int count = 0;
        while (entry) {
            printf("投屏GXDLNAMediaController:%d)\t%s (%s)\n", ++count, (const char*)(*entry)->GetValue(), (const char*)(*entry)->GetKey());
            ++entry;
        }
        
        int index = 0, watchdog = 3;
        char buffer[1024];
        
        // wait for input
        while (watchdog > 0) {
            fgets(buffer, 1024, stdin);
            strchomp(buffer);
            
            if (1 != sscanf(buffer, "%d", &index)) {
                printf("投屏GXDLNAMediaController:Please enter a number\n");
            } else if (index < 0 || index > count)	{
                printf("投屏GXDLNAMediaController:Please choose one of the above, or 0 for none\n");
                watchdog--;
                index = 0;
            } else {
                watchdog = 0;
            }
        }
        
        // find the entry back
        if (index != 0) {
            entry = entries.GetFirstItem();
            while (entry && --index) {
                ++entry;
            }
            if (entry) {
                return (*entry)->GetKey();
            }
        }
    }
    
    return NULL;
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::PopDirectoryStackToRoot
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::PopDirectoryStackToRoot(void)
{
    NPT_String val;
    while (NPT_SUCCEEDED(m_CurBrowseDirectoryStack.Peek(val)) && val.Compare("0")) {
        m_CurBrowseDirectoryStack.Pop(val);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::OnMSAdded
 +---------------------------------------------------------------------*/
bool
PLT_MicroMediaController::OnMSAdded(PLT_DeviceDataReference& device)
{
    // Issue special action upon discovering MediaConnect server
    PLT_Service* service;
    if (NPT_SUCCEEDED(device->FindServiceByType("urn:microsoft.com:service:X_MS_MediaReceiverRegistrar:*", service))) {
        PLT_ActionReference action;
        PLT_SyncMediaBrowser::m_CtrlPoint->CreateAction(
                                                        device,
                                                        "urn:microsoft.com:service:X_MS_MediaReceiverRegistrar:1",
                                                        "IsAuthorized",
                                                        action);
        if (!action.IsNull()) {
            action->SetArgumentValue("DeviceID", "");
            PLT_SyncMediaBrowser::m_CtrlPoint->InvokeAction(action, 0);
        }
        
        PLT_SyncMediaBrowser::m_CtrlPoint->CreateAction(
                                                        device,
                                                        "urn:microsoft.com:service:X_MS_MediaReceiverRegistrar:1",
                                                        "IsValidated",
                                                        action);
        if (!action.IsNull()) {
            action->SetArgumentValue("DeviceID", "");
            PLT_SyncMediaBrowser::m_CtrlPoint->InvokeAction(action, 0);
        }
    }
    
    return true;
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::OnMSRemoved +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::OnMSRemoved(PLT_DeviceDataReference& device)
{

}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::OnMRAdded
 +---------------------------------------------------------------------*/
bool
PLT_MicroMediaController::OnMRAdded(PLT_DeviceDataReference& device)
{
    NPT_String uuid = device->GetUUID();
    
    // test if it's a media renderer
    PLT_Service* service;
    if (NPT_SUCCEEDED(device->FindServiceByType("urn:schemas-upnp-org:service:AVTransport:*", service)))
    {
        NPT_AutoLock lock(m_MediaRenderers);
        m_MediaRenderers.Put(uuid, device);
    }
    
    if(m_Target && [m_Target respondsToSelector:@selector(onDMRAdded)])
    {
        [m_Target onDMRAdded];
    }
    
    return true;
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::OnMRRemoved
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::OnMRRemoved(PLT_DeviceDataReference& device)
{
    NPT_String uuid = device->GetUUID();
    
    {
        NPT_AutoLock lock(m_MediaRenderers);
        m_MediaRenderers.Erase(uuid);
    }
    
    {
        NPT_AutoLock lock(m_CurMediaRendererLock);
        
        // if it's the currently selected one, we have to get rid of it
        if (!m_CurMediaRenderer.IsNull() && m_CurMediaRenderer == device) {
            m_CurMediaRenderer = NULL;
        }
    }
    
    if(m_Target && [m_Target respondsToSelector:@selector(onDMRRemoved)])
    {
        [m_Target onDMRRemoved];
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::OnMRStateVariablesChanged
 |   获取到所有的action
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::OnMRStateVariablesChanged(PLT_Service*                  service,
                                                    NPT_List<PLT_StateVariable*>* vars)
{
    NSMutableArray<GXDLNAResponseModel *> *stateArray = [NSMutableArray array];
    
    NPT_String uuid = service->GetDevice()->GetUUID();
    NPT_List<PLT_StateVariable*>::Iterator var = vars->GetFirstItem();
    while (var) {
#if 0
        printf("投屏GXDLNAMediaController:Received state var \"%s:%s:%s\" changes: \"%s\"\n",
               (const char*)uuid,
               (const char*)service->GetServiceID(),
               (const char*)(*var)->GetName(),
               (const char*)(*var)->GetValue());
#endif
        NSString *deviceUUID = [NSString stringWithUTF8String:uuid];
        NSString *serviceID = [NSString stringWithUTF8String:service->GetServiceID()];
        NSString *eventName = [NSString stringWithUTF8String:(*var)->GetName()];
        NSString *eventValue = [NSString stringWithUTF8String:(*var)->GetValue()];
        
        GXDLNAResponseModel * state = [[GXDLNAResponseModel alloc] initWithDeviceUUID:deviceUUID ServiceID:serviceID EventName:eventName EventValue:eventValue];

        [stateArray addObject:state];
        
        ++var;
    }
    
    if(m_Target && [m_Target respondsToSelector:@selector(DMRStateViriablesChanged:)])
    {
        [m_Target DMRStateViriablesChanged:stateArray];
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::ChooseIDGetCurMediaServerFromTable
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::GetCurMediaServer(PLT_DeviceDataReference& server)
{
    NPT_AutoLock lock(m_CurMediaServerLock);
    
    if (m_CurMediaServer.IsNull()) {
        printf("投屏GXDLNAMediaController:No server selected.\n");
    } else {
        server = m_CurMediaServer;
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::GetCurMediaRenderer
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::GetCurMediaRenderer(PLT_DeviceDataReference& renderer)
{
    NPT_AutoLock lock(m_CurMediaRendererLock);
    
    if (m_CurMediaRenderer.IsNull()) {
        printf("投屏GXDLNAMediaController:No renderer selected, select one with setmr\n");
        if(m_Target && [m_Target respondsToSelector:@selector(noDMRBeSelected)])
        {
            [m_Target noDMRBeSelected];
        }
    } else {
        renderer = m_CurMediaRenderer;
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::DoBrowse
 +---------------------------------------------------------------------*/
NPT_Result
PLT_MicroMediaController::DoBrowse(const char* object_id, /* = NULL */
                                   bool        metadata  /* = false */)
{
    NPT_Result res = NPT_FAILURE;
    PLT_DeviceDataReference device;
    
    GetCurMediaServer(device);
    if (!device.IsNull()) {
        NPT_String cur_object_id;
        m_CurBrowseDirectoryStack.Peek(cur_object_id);
        
        // send off the browse packet and block
        res = BrowseSync(
                         device,
                         object_id?object_id:(const char*)cur_object_id,
                         m_MostRecentBrowseResults,
                         metadata);
    }
    
    return res;
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_getms
 +---------------------------------------------------------------------*/
//PLT_DeviceDataReference
//PLT_MicroMediaController::getCurrentMediaServer()
//{
//    PLT_DeviceDataReference device;
//    GetCurMediaServer(device);
//    return device;
//}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_getmr
 +---------------------------------------------------------------------*/
PLT_DeviceDataReference
PLT_MicroMediaController::getCurrentMediaRenderer()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    return device;
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::ChooseDevice
 +---------------------------------------------------------------------*/
PLT_DeviceDataReference
PLT_MicroMediaController::ChooseDevice(const NPT_Lock<PLT_DeviceMap>& deviceList, NPT_String chosenUUID)
{
    PLT_DeviceDataReference* result = NULL;

    if (chosenUUID.GetLength()) {
        deviceList.Get(chosenUUID, result);
    }
    
    return result?*result:PLT_DeviceDataReference(); // return empty reference if not device was selected
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_setms
 +---------------------------------------------------------------------*/
//void
//PLT_MicroMediaController::chooseMeidaServer(NPT_String chosenUUID)
//{
//    NPT_AutoLock lock(m_CurMediaServerLock);
//    
//    PopDirectoryStackToRoot();
//    m_CurMediaServer = ChooseDevice(GetMediaServersMap(),chosenUUID);
//}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_setmr
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::chooseMediaRenderer(NPT_String chosenUUID)
{
    NPT_AutoLock lock(m_CurMediaRendererLock);
    
    m_CurMediaRenderer = ChooseDevice(m_MediaRenderers, chosenUUID);
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_ls
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::HandleCmd_ls()
{
    DoBrowse();
    
    if (!m_MostRecentBrowseResults.IsNull()) {
        printf("投屏GXDLNAMediaController:There were %d results\n", m_MostRecentBrowseResults->GetItemCount());
        
        NPT_List<PLT_MediaObject*>::Iterator item = m_MostRecentBrowseResults->GetFirstItem();
        while (item) {
            if ((*item)->IsContainer()) {
                printf("投屏GXDLNAMediaController:Container: %s (%s)\n", (*item)->m_Title.GetChars(), (*item)->m_ObjectID.GetChars());
            } else {
                printf("投屏GXDLNAMediaController:Item: %s (%s)\n", (*item)->m_Title.GetChars(), (*item)->m_ObjectID.GetChars());
            }
            ++item;
        }
        
        m_MostRecentBrowseResults = NULL;
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_info
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::HandleCmd_info()
{
    NPT_String              object_id;
    PLT_StringMap           tracks;
    PLT_DeviceDataReference device;
    
    // issue a browse
    DoBrowse();
    
    if (!m_MostRecentBrowseResults.IsNull()) {
        // create a map item id -> item title
        NPT_List<PLT_MediaObject*>::Iterator item = m_MostRecentBrowseResults->GetFirstItem();
        while (item) {
            if (!(*item)->IsContainer()) {
                tracks.Put((*item)->m_ObjectID, (*item)->m_Title);
            }
            ++item;
        }
        
        // let the user choose which one
        object_id = ChooseIDFromTable(tracks);
        
        if (object_id.GetLength()) {
            // issue a browse with metadata
            DoBrowse(object_id, true);
            
            // look back for the PLT_MediaItem in the results
            PLT_MediaObject* track = NULL;
            if (!m_MostRecentBrowseResults.IsNull() &&
                NPT_SUCCEEDED(NPT_ContainerFind(*m_MostRecentBrowseResults, PLT_MediaItemIDFinder(object_id), track))) {
                
                // display info
                printf("投屏GXDLNAMediaController:Title: %s \n", track->m_Title.GetChars());
                printf("投屏GXDLNAMediaController:OjbectID: %s\n", track->m_ObjectID.GetChars());
                printf("投屏GXDLNAMediaController:Class: %s\n", track->m_ObjectClass.type.GetChars());
                printf("投屏GXDLNAMediaController:Creator: %s\n", track->m_Creator.GetChars());
                printf("投屏GXDLNAMediaController:Date: %s\n", track->m_Date.GetChars());
                for (NPT_List<PLT_AlbumArtInfo>::Iterator iter = track->m_ExtraInfo.album_arts.GetFirstItem();
                     iter;
                     iter++) {
                    printf("投屏GXDLNAMediaController:Art Uri: %s\n", (*iter).uri.GetChars());
                    printf("投屏GXDLNAMediaController:Art Uri DLNA Profile: %s\n", (*iter).dlna_profile.GetChars());
                }
                for (NPT_Cardinal i=0;i<track->m_Resources.GetItemCount(); i++) {
                    printf("投屏GXDLNAMediaController:\tResource[%d].uri: %s\n", i, track->m_Resources[i].m_Uri.GetChars());
                    printf("投屏GXDLNAMediaController:\tResource[%d].profile: %s\n", i, track->m_Resources[i].m_ProtocolInfo.ToString().GetChars());
                    printf("投屏GXDLNAMediaController:\tResource[%d].duration: %d\n", i, track->m_Resources[i].m_Duration);
                    printf("投屏GXDLNAMediaController:\tResource[%d].size: %d\n", i, (int)track->m_Resources[i].m_Size);
                }
                printf("投屏GXDLNAMediaController:Didl: %s\n", (const char*)track->m_Didl);
            } else {
                printf("投屏GXDLNAMediaController:Couldn't find the track\n");
            }
        }
        
        m_MostRecentBrowseResults = NULL;
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_download
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::HandleCmd_download()
{
    NPT_String              object_id;
    PLT_StringMap           tracks;
    PLT_DeviceDataReference device;
    
    // issue a browse
    DoBrowse();
    
    if (!m_MostRecentBrowseResults.IsNull()) {
        // create a map item id -> item title
        NPT_List<PLT_MediaObject*>::Iterator item = m_MostRecentBrowseResults->GetFirstItem();
        while (item) {
            if (!(*item)->IsContainer()) {
                tracks.Put((*item)->m_ObjectID, (*item)->m_Title);
            }
            ++item;
        }
        
        // let the user choose which one
        object_id = ChooseIDFromTable(tracks);
        
        if (object_id.GetLength()) {
            // issue a browse with metadata
            DoBrowse(object_id, true);
            
            // look back for the PLT_MediaItem in the results
            PLT_MediaObject* track = NULL;
            if (!m_MostRecentBrowseResults.IsNull() &&
                NPT_SUCCEEDED(NPT_ContainerFind(*m_MostRecentBrowseResults, PLT_MediaItemIDFinder(object_id), track))) {
                
                if (track->m_Resources.GetItemCount() > 0) {
                    printf("投屏GXDLNAMediaController:\tResource[0].uri: %s\n", track->m_Resources[0].m_Uri.GetChars());
                    NPT_HttpUrl url(track->m_Resources[0].m_Uri.GetChars());
                    if (url.IsValid()) {
                        // Extract filename from URL
                        NPT_String filename = NPT_FilePath::BaseName(url.GetPath(true).GetChars(), false);
                        NPT_String extension = NPT_FilePath::FileExtension(url.GetPath(true).GetChars());
                        printf("投屏GXDLNAMediaController:Downloading %s%s\n", filename.GetChars(), extension.GetChars());
                        
                        for (int i=0; i<3; i++) {
                            NPT_String filepath = NPT_String::Format("%s_%d%s", filename.GetChars(), i, extension.GetChars());
                            
                            // Open file for writing
                            NPT_File file(filepath);
                            file.Open(NPT_FILE_OPEN_MODE_WRITE | NPT_FILE_OPEN_MODE_CREATE | NPT_FILE_OPEN_MODE_TRUNCATE);
                            NPT_OutputStreamReference output;
                            file.GetOutputStream(output);
                            
                            // trigger 3 download
                            PLT_Downloader* downloader = new PLT_Downloader(url, output);
                            NPT_TimeInterval delay(5.);
                            m_DownloadTaskManager.StartTask(downloader, &delay);
                        }
                    }
                } else {
                    printf("投屏GXDLNAMediaController:No resources found");
                }
            } else {
                printf("投屏GXDLNAMediaController:Couldn't find the track\n");
            }
        }
        
        m_MostRecentBrowseResults = NULL;
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_cd
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::HandleCmd_cd(const char* command)
{
    NPT_String    newobject_id;
    PLT_StringMap containers;
    
    // if command has parameter, push it to stack and return
    NPT_String id = command;
    NPT_List<NPT_String> args = id.Split(" ");
    if (args.GetItemCount() >= 2) {
        args.Erase(args.GetFirstItem());
        id = NPT_String::Join(args, " ");
        m_CurBrowseDirectoryStack.Push(id);
        return;
    }
    
    // list current directory to let user choose
    DoBrowse();
    
    if (!m_MostRecentBrowseResults.IsNull()) {
        NPT_List<PLT_MediaObject*>::Iterator item = m_MostRecentBrowseResults->GetFirstItem();
        while (item) {
            if ((*item)->IsContainer()) {
                containers.Put((*item)->m_ObjectID, (*item)->m_Title);
            }
            ++item;
        }
        
        newobject_id = ChooseIDFromTable(containers);
        if (newobject_id.GetLength()) {
            m_CurBrowseDirectoryStack.Push(newobject_id);
        }
        
        m_MostRecentBrowseResults = NULL;
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_cdup
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::HandleCmd_cdup()
{
    // we don't want to pop the root off now....
    NPT_String val;
    m_CurBrowseDirectoryStack.Peek(val);
    if (val.Compare("0")) {
        m_CurBrowseDirectoryStack.Pop(val);
    } else {
        printf("投屏GXDLNAMediaController:Already at root\n");
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::HandleCmd_pwd
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::HandleCmd_pwd()
{
    NPT_Stack<NPT_String> tempStack;
    NPT_String val;
    
    while (NPT_SUCCEEDED(m_CurBrowseDirectoryStack.Peek(val))) {
        m_CurBrowseDirectoryStack.Pop(val);
        tempStack.Push(val);
    }
    
    while (NPT_SUCCEEDED(tempStack.Peek(val))) {
        tempStack.Pop(val);
        printf("投屏GXDLNAMediaController:%s/", (const char*)val);
        m_CurBrowseDirectoryStack.Push(val);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererAVTransportURI
 +---------------------------------------------------------------------*/

void
PLT_MicroMediaController::setRendererAVTransportURI(const char *uriStr, const char *metaData)
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    
    if (!device.IsNull()) {
        // get the protocol info to try to see in advance if a track would play on the device
        
        // invoke the setUri
        printf("投屏GXDLNAMediaController:Issuing SetAVTransportURI with url=%s & didl=%s",uriStr,(const char*)"");
        bool rel = NPT_FAILED(SetAVTransportURI(device, 0, uriStr, metaData == NULL ?"" : metaData, NULL));
        if(rel)
        {
            printf("投屏GXDLNAMediaController:Set uri failed!");
        }
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::canRendererSetNextURI
 +---------------------------------------------------------------------*/
bool
PLT_MicroMediaController::canRendererSetNextURI()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        return CanSetNextAVTransportURI(device);
    }
    return false;
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererNextAVTransportURI
 +---------------------------------------------------------------------*/

void
PLT_MicroMediaController::setRendererNextAVTransportURI(const char *nextUriStr)
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    
    if (!device.IsNull()) {
        // get the protocol info to try to see in advance if a track would play on the device
        
        // invoke the setUri
        printf("投屏GXDLNAMediaController:Issuing SetAVTransportURI with url=%s & didl=%s",nextUriStr,(const char*)"");
        if(NPT_FAILED(SetNextAVTransportURI(device, 0, nextUriStr, "", NULL)))
        {
            printf("投屏GXDLNAMediaController:Set next uri failed!");
        }
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererPlayMode
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererPlayMode(const char *new_play_mode)
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        SetPlayMode(device, 0, NPT_String(new_play_mode), NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererCurrentTransportActions
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererCurrentTransportActions()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetCurrentTransportActions(device, 0, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererDeviceCapabilities
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererDeviceCapabilities()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetDeviceCapabilities(device, 0, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererProtocolInfo
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererProtocolInfo()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetProtocolInfo(device, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererMediaInfo
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererMediaInfo()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetMediaInfo(device, 0, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererPositionInfo
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererPositionInfo()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetPositionInfo(device, 0, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererTransportInfo
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererTransportInfo()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetTransportInfo(device, 0, NULL);
    }
}


/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererTransportSettings
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererTransportSettings()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetTransportSettings(device, 0, NULL);
    }
}


/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererPlay
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererPlay()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        Play(device, 0, "1", NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererPause
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererPause()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        Pause(device, 0, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererStop
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererStop()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        Stop(device, 0, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererNext
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererNext()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        Next(device, 0, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererPrevious
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererPrevious()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        Previous(device, 0, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::sendSeekCommand
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::sendSeekCommand(NPT_UInt64 seek)
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        // remove first part of command ("seek")
        Seek(device, 0, "REL_TIME", PLT_Didl::FormatTimeStamp((NPT_UInt32) (seek)), NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRenderMute
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererMute()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        SetMute(device, 0, "Master", false, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererMute
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererMute()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetMute(device, 0, "Master", NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRenderUnMute
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererUnMute()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        SetMute(device, 0, "Master", true, NULL);
    }
}
/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::setRendererVolumn
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::setRendererVolume(int volume)
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        SetVolume(device, 0, "Master", volume, NULL);
    }
}

/*----------------------------------------------------------------------
 |   PLT_MicroMediaController::getRendererVolume
 +---------------------------------------------------------------------*/
void
PLT_MicroMediaController::getRendererVolume()
{
    PLT_DeviceDataReference device;
    GetCurMediaRenderer(device);
    if (!device.IsNull()) {
        GetVolume(device, 0, "Master", NULL);
    }
}

//const PLT_StringMap
//PLT_MicroMediaController:: getMediaServersNameTable()
//{
//    const NPT_Lock<PLT_DeviceMap>& deviceList = GetMediaServersMap();
//    
//    PLT_StringMap            namesTable;
//    NPT_AutoLock             lock(m_MediaServers);
//    
//    // create a map with the device UDN -> device Name
//    const NPT_List<PLT_DeviceMapEntry*>& entries = deviceList.GetEntries();
//    NPT_List<PLT_DeviceMapEntry*>::Iterator entry = entries.GetFirstItem();
//    while (entry) {
//        PLT_DeviceDataReference device = (*entry)->GetValue();
//        NPT_String              name   = device->GetFriendlyName();
//        namesTable.Put((*entry)->GetKey(), name);
//        
//        ++entry;
//    }
//    
//    return namesTable;
//}

const NPT_Lock<PLT_DeviceMap>
PLT_MicroMediaController:: getMediaRenderersNameTable()
{
    const NPT_Lock<PLT_DeviceMap>& deviceList = m_MediaRenderers;
    
    NPT_Lock<PLT_DeviceMap>            namesTable;
    NPT_AutoLock             lock(m_MediaServers);
    
    // create a map with the device UDN -> device Name
    const NPT_List<PLT_DeviceMapEntry*>& entries = deviceList.GetEntries();
    NPT_List<PLT_DeviceMapEntry*>::Iterator entry = entries.GetFirstItem();
    while (entry) {
        PLT_DeviceDataReference device = (*entry)->GetValue();
        NPT_String              name   = device->GetFriendlyName();
        namesTable.Put((*entry)->GetKey(), device);
        ++entry;
    }
    return namesTable;
}


/*----------------------------------------------------------------------
 |   PLT_MediaControllerDelegate
 +---------------------------------------------------------------------*/

// AVTransport
void PLT_MicroMediaController::
OnGetCurrentTransportActionsResult(
                                   NPT_Result               res ,
                                   PLT_DeviceDataReference& device ,
                                   PLT_StringList*          actions ,
                                   void*                    userdata)
{
    if(actions && m_Target && [m_Target respondsToSelector:@selector(getCurrentAVTransportActionResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        NSMutableArray<NSString*>*actionArr = [NSMutableArray array];
        PLT_StringList::Iterator iter = actions->GetFirstItem();
        while (iter) {
            NSString *action = [NSString stringWithUTF8String:(*iter).GetChars()];
            [actionArr addObject:action];
            iter++;
        }
        
        GXDLNACurTransportResponseModel *capsule = [[GXDLNACurTransportResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID Actions:actionArr UserData: (__bridge id)userdata];
        
        [m_Target getCurrentAVTransportActionResponse:capsule];

    }
}

/*
void PLT_MicroMediaController::
OnGetDeviceCapabilitiesResult(
                              NPT_Result               res ,
                              PLT_DeviceDataReference& device,
                              PLT_DeviceCapabilities*  capabilities,
                              void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(OnGetDeviceCapabilitiesResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        NSMutableArray<NSString*>*capabilitiesArr = [NSMutableArray array];
        PLT_StringList::Iterator iter = capabilities->play_media.GetFirstItem();
        while (iter) {
            NSString *capbility = [NSString stringWithUTF8String:(*iter).GetChars()];
            [capabilitiesArr addObject:capbility];
            iter++;
        }
        
        GetDeviceCapabilitiesResultCapsule *capsule = [[GetDeviceCapabilitiesResultCapsule alloc]initWithResult:result DeviceUUID:deviceUUID PlayMediaCapbilities:capabilitiesArr UserData: (__bridge id)userdata];
        
        [m_Target OnGetDeviceCapabilitiesResult:capsule];
        
    }
}
 */
/*
void PLT_MicroMediaController::
OnGetMediaInfoResult(
                     NPT_Result               res,
                     PLT_DeviceDataReference& device,
                     PLT_MediaInfo*           info,
                     void*                    userdata)
{
    
    if(m_Target && [m_Target respondsToSelector:@selector(OnGetMediaInfoResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        MediaInfoResultCapsule *capsule = [[MediaInfoResultCapsule alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        capsule.num_tracks = info->num_tracks;
        capsule.media_duration_in_seconds = info->media_duration;
        capsule.cur_uri = [NSString stringWithUTF8String:info->cur_uri];
        capsule.cur_metadata = [NSString stringWithUTF8String:info->cur_metadata];
        capsule.next_uri = [NSString stringWithUTF8String:info->next_uri];
        capsule.next_metadata = [NSString stringWithUTF8String:info->next_metadata];
        capsule.play_medium = [NSString stringWithUTF8String:info->play_medium];
        capsule.rec_medium = [NSString stringWithUTF8String:info->rec_medium];
        capsule.write_status = [NSString stringWithUTF8String:info->write_status];
        
        [m_Target OnGetMediaInfoResult:capsule];
        
    }
}
*/

void PLT_MicroMediaController::
OnGetPositionInfoResult(
                        NPT_Result               res,
                        PLT_DeviceDataReference& device,
                        PLT_PositionInfo*        info,
                        void*                    userdata)
{
    if(info && !device.IsNull() && m_Target && [m_Target respondsToSelector:@selector(delegateOnGetPositionInfoResult:)])
    {
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAPositionInfoModel *capsule = [[GXDLNAPositionInfoModel alloc] init];
        
        capsule.result = res;
        capsule.uuid = deviceUUID;
        capsule.track = info->track;
        capsule.duration = info->track_duration.ToSeconds();
        capsule.metadata = [NSString stringWithUTF8String:info->track_metadata];
        capsule.uri = [NSString stringWithUTF8String:info->track_uri];
        capsule.relTime = info->rel_time.ToSeconds();
        capsule.absTime = info->abs_time.ToSeconds();
        capsule.relCount = info->rel_count;
        capsule.absCount = info->abs_count;

        [m_Target delegateOnGetPositionInfoResult:capsule];
        
    }
}


void PLT_MicroMediaController::
OnGetTransportInfoResult(
                         NPT_Result               res,
                         PLT_DeviceDataReference& device,
                         PLT_TransportInfo*       info,
                         void*                    userdata)
{
    if(info && m_Target && [m_Target respondsToSelector:@selector(getTransportInfoResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNATransportInfoResponseModel *capsule = [[GXDLNATransportInfoResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        capsule.cur_transport_state = [NSString stringWithUTF8String:info->cur_transport_state];
        capsule.cur_transport_status = [NSString stringWithUTF8String:info->cur_transport_status];
        capsule.cur_speed = [NSString stringWithUTF8String:info->cur_speed];
        
        [m_Target getTransportInfoResponse:capsule];
        
    }
}

/*
void PLT_MicroMediaController::
OnGetTransportSettingsResult(
                             NPT_Result               res,
                             PLT_DeviceDataReference& device,
                             PLT_TransportSettings*   settings,
                             void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(OnGetTransportSettingsResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        TransportSettingsResultCapsule *capsule = [[TransportSettingsResultCapsule alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        capsule.play_mode = [NSString stringWithUTF8String:settings->play_mode];
        capsule.rec_quality_mode = [NSString stringWithUTF8String:settings->rec_quality_mode];
        
        [m_Target OnGetTransportSettingsResult:capsule];
        
    }
}
*/

void PLT_MicroMediaController::
OnNextResult(
             NPT_Result               res,
             PLT_DeviceDataReference& device,
             void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(nextResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target nextResponse:capsule];
        
    }
}

void PLT_MicroMediaController::
OnPauseResult(
              NPT_Result               res,
              PLT_DeviceDataReference& device,
              void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(pasuseResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target pasuseResponse:capsule];
        
    }
}

void PLT_MicroMediaController::
OnPlayResult(
             NPT_Result               res,
             PLT_DeviceDataReference& device,
             void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(playResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target playResponse:capsule];
        
    }
}
void PLT_MicroMediaController::
OnPreviousResult(
                 NPT_Result               res,
                 PLT_DeviceDataReference& device,
                 void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(previousResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target previousResponse:capsule];
    }
}

void PLT_MicroMediaController::
OnSeekResult(
             NPT_Result               res,
             PLT_DeviceDataReference& device,
             void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(OnSeekResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target OnSeekResult:capsule];
    }
}

void PLT_MicroMediaController::
OnSetAVTransportURIResult(
                          NPT_Result               res,
                          PLT_DeviceDataReference& device,
                          void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(setAVTransponrtResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target setAVTransponrtResponse:capsule];
        
    }
}
/*
void PLT_MicroMediaController::
OnSetPlayModeResult(
                    NPT_Result               res,
                    PLT_DeviceDataReference& device,
                    void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(OnSetPlayModeResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        EventCallbackResultBaseCapsule *capsule = [[EventCallbackResultBaseCapsule alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target OnSetPlayModeResult:capsule];
        
        
    }
}
*/

void PLT_MicroMediaController::
OnStopResult(
             NPT_Result               res,
             PLT_DeviceDataReference& device,
             void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(stopResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target stopResponse:capsule];
        
        
    }
}

// ConnectionManager
//void PLT_MicroMediaController::
//OnGetCurrentConnectionIDsResult(
//                                NPT_Result               /* res */,
//                                PLT_DeviceDataReference& /* device */,
//                                PLT_StringList*          /* ids */,
//                                void*                    /* userdata */)
//{
//    
//}

void PLT_MicroMediaController::
OnGetCurrentConnectionInfoResult(
                                 NPT_Result                res,
                                 PLT_DeviceDataReference&  device,
                                 PLT_ConnectionInfo*       info,
                                 void*                     userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(currentConnectionInfoResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target stopResponse:capsule];
        
        
    }
}
/*
void PLT_MicroMediaController::
OnGetProtocolInfoResult(
                        NPT_Result               res,
                        PLT_DeviceDataReference& device,
                        PLT_StringList*          sources,
                        PLT_StringList*          sinks,
                        void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(OnGetProtocolInfoResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        NSMutableArray<NSString *> *sourcesArr = [NSMutableArray array];
        PLT_StringList::Iterator iter = sources->GetFirstItem();
        while (iter) {
            NSString *source = [NSString stringWithUTF8String:(*iter).GetChars()];
            [sourcesArr addObject:source];
            iter++;
        }
        
        NSMutableArray<NSString *> *sinksArr = [NSMutableArray array];
        iter = sinks->GetFirstItem();
        while (iter) {
            NSString *sink = [NSString stringWithUTF8String:(*iter).GetChars()];
            [sinksArr addObject:sink];
            iter++;
        }
        
        ProtocolInfoResultCapsule *capsule = [[ProtocolInfoResultCapsule alloc]initWithResult:result DeviceUUID:deviceUUID  Sources:sourcesArr Sinks:sinksArr UserData: (__bridge id)userdata];
        
        [m_Target OnGetProtocolInfoResult:capsule];
        
        
    }
}
 */
// RenderingControl
/*
void PLT_MicroMediaController::
OnSetMuteResult(
                NPT_Result               res,
                PLT_DeviceDataReference& device,
                void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(OnSetMuteResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        EventCallbackResultBaseCapsule *capsule = [[EventCallbackResultBaseCapsule alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target OnSetMuteResult:capsule];
        
        
    }
}
*/
/*
void PLT_MicroMediaController::
OnGetMuteResult(
                NPT_Result              res ,
                PLT_DeviceDataReference&device,
                const char*             channel,
                bool                    mute,
                void*                   userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(OnGetMuteResult:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        NSString *cnl = [NSString stringWithUTF8String:channel];
        
        MuteResultCapsule *capsule = [[MuteResultCapsule alloc]initWithResult:result DeviceUUID:deviceUUID Channel:cnl Mute:mute UserData: (__bridge id)userdata];
        
        [m_Target OnGetMuteResult:capsule];
        
    }
}
*/

void PLT_MicroMediaController::
OnSetVolumeResult(
                  NPT_Result               res,
                  PLT_DeviceDataReference& device,
                  void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(setVolumeResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        GXDLNAResultResponseModel *capsule = [[GXDLNAResultResponseModel alloc]initWithResult:result DeviceUUID:deviceUUID UserData: (__bridge id)userdata];
        
        [m_Target setVolumeResponse:capsule];
        
        
    }
}
void PLT_MicroMediaController::
OnGetVolumeResult(
                  NPT_Result               res,
                  PLT_DeviceDataReference& device,
                  const char*              channel,
                  NPT_UInt32               volume,
                  void*                    userdata)
{
    if(m_Target && [m_Target respondsToSelector:@selector(getVolumeResponse:)])
    {
        NSInteger result = res;
        NSString *deviceUUID = [NSString stringWithUTF8String:device->GetUUID()];
        
        NSString *cnl = [NSString stringWithUTF8String:channel];
        
        GXDLNAVolumResponseModel * capsule = [[GXDLNAVolumResponseModel alloc] initWithResult:result DeviceUUID:deviceUUID UserData:(__bridge id)userdata Channel:cnl Volume:volume];
        [m_Target getVolumeResponse:capsule];
        
    
    }
}
