//
//  ContentController.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 11/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI
import Then
import SwiftMatrixSDK

struct ContentController: View {
    
    var contentLogic = ContentLogic()
    
    var loggedInUserId: String = ""
    var chatsFetchRequest: FetchRequest<Chat>
    var userFetchRequest: FetchRequest<UserDetails>
    
    var userName: String
    
    @State private var refreshing = false
    @State var deviceName: String = ""
    @State var inviteUser: String = ""
    @State var inviteDevice: String = ""
    @State var userDetails: UserDetails?
    @State var newChatModalVisible: Bool = false
    @State private(set) var viewError: IdentifiableError?
    @State var showingLogOutActionSheet: Bool = false
    @State var showingPasswordModal: Bool = false
    @State var syncInProgress: Bool = false
    @State var startChatInProgress: Bool = false
    
    @Environment(\.managedObjectContext) var context
    @EnvironmentObject var sessionData: SessionData
    
    private var didSave =  NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
    
    init(_ loggedInUserId: String) {
        //Note init runs each time loggedInUserId changes in the parent view
        self.loggedInUserId = loggedInUserId
        chatsFetchRequest = FetchRequest<Chat>(
            entity: Chat.entity(),
            sortDescriptors: [],
            predicate: NSPredicate(format: "ownerUser.userId == %@", loggedInUserId))
        userFetchRequest = FetchRequest<UserDetails>(
            entity: UserDetails.entity(),
            sortDescriptors: [],
            predicate: NSPredicate(format: "userId == %@", loggedInUserId))
        self.userName = loggedInUserId
    }
    
    /// Sync
    /// Performs sychronisation with server
    /// - Returns: A Promise
    func sync() {
        DispatchQueue.global(qos:.userInitiated).async {
            async {
                self.syncInProgress = true
                try await(self.contentLogic.sync(
                    mxRestClient: self.sessionData.mxRestClient!,
                    context: self.context,
                    ownerUser: self.userDetails!,
                    encryptionHandler: self.sessionData.encryptionHandler!))
                DispatchQueue.main.sync {
                    self.syncInProgress = false
                }
            }.onError {error in
                DispatchQueue.main.sync {
                    self.viewError = IdentifiableError(error)
                    self.syncInProgress = false
                }
            }
        }
    }
    
    /// startChat
    /// Adds a new chat to the user's record
    /// - Returns: Void
    func startChat() {
        DispatchQueue.global(qos: .userInitiated).async {
            async {
                self.startChatInProgress = true
                try await(self.contentLogic.startChat(
                    invitedUser: self.inviteUser,
                    invitedDevice: self.inviteDevice,
                    userDetails: self.userDetails!,
                    context: self.context,
                    encryptionHandler: self.sessionData.encryptionHandler!,
                    locationLogic: self.sessionData.locationLogic
                ))
                try await(self.sessionData.locationLogic.startTrackingLocation())
                self.startChatInProgress = false
                self.newChatModalVisible = false
            }.onError() {error in
                DispatchQueue.main.sync {
                    // The order in which these occure is vital, as we cannot present twice in swift UI
                    self.startChatInProgress = false
                    self.newChatModalVisible = false
                    // Wait for the animation closing the modal to complete, otherwise fatalerror occurs
                    sleep(1)
                    self.viewError = IdentifiableError(error)
                }
            }
        }
    }
    
    
    /// logout
    /// Logs the signed in user user out
    /// - Returns: Void
    func logout() {contentLogic.logout(sessionData: self.sessionData)}
    
    
    /// handleClickedLogoutAndDeleteData
    /// Handles closure of alert and opening of modal when user wishes to delete all data
    /// - Returns: Void
    func handleClickedLogoutAndDeleteData() {
        self.showingLogOutActionSheet = false
        self.showingPasswordModal = true
    }
    
    
    /// logoutAndDeleteData
    /// Perfoms deletion of all data related to the user and logs the user out
    /// - Parameter password: A string containing the user's password, required for deletion of server-side data
    /// - Returns: A Promise.
    func logoutAndDeleteData(password: String) -> Promise<Void> {
        async {
            try await(self.contentLogic.logoutAndDeleteData(
                sessionData: self.sessionData,
                context: self.context,
                password: password))
        }.onError {error in
            self.showingPasswordModal = false
            self.viewError = IdentifiableError(error)
        }
    }
    
    /// handleOnAppear
    /// Handles data manipulation on view loading
    /// - Returns: Void
    func handleOnAppear() -> Void {
        let userFetchedResults = self.userFetchRequest.wrappedValue
        guard userFetchedResults.count > 0 else {
            print("Unable to find owner user")
            return
        }
        self.userDetails = userFetchedResults.first!
        self.sync()
    }
    
    /// handleNewRestClient
    ///  Handles updating state when a new rest client is createed
    /// - Parameter newMXRestClient: The new rest client
    /// - Returns: Void
    func handleNewRestClient(_ newMXRestClient: MXRestClient?) -> Void {
        if (newMXRestClient != nil && newMXRestClient!.credentials.deviceId != nil) {
            self.deviceName = newMXRestClient!.credentials.deviceId!
        }
    }
    
    /// Handles the creation of an action sheet presenting the user with logout options
    /// - Returns: an ActionSheet
    private func LogOutActionSheet() -> ActionSheet {
        return ActionSheet(
            title: Text("Logout"),
            message: Text("Do you wish to delete all the local data as you logout?"),
            buttons: [
                .default(Text("Retain local data")) {self.logout()},
                .destructive(Text("Delete all device data")) {self.handleClickedLogoutAndDeleteData()},
                .cancel()
            ])
    }
    
    var body: some View {
        ZStack {
            ContentView(
                chatArray: self.chatsFetchRequest.wrappedValue.sorted(by: {$0.lastSeen < $1.lastSeen}),
                sync: sync,
                userName: userName,
                deviceName: $deviceName,
                newChatModalVisible: $newChatModalVisible,
                refreshing: $refreshing,
                showingLogOutActionSheet: $showingLogOutActionSheet,
                syncInProgress: $syncInProgress
            )
            .onAppear() { self.handleOnAppear() }
            .onReceive(self.didSave) { _ in  self.refreshing.toggle() }
            .onReceive(self.sessionData.$mxRestClient) { (newMXRestClient) in self.handleNewRestClient(newMXRestClient) }
            Text("").hidden().alert(item: self.$viewError) { viewError -> Alert in
                return ErrorAlert(viewError: viewError)
            }
            Text("").hidden().actionSheet(isPresented: self.$showingLogOutActionSheet) {
                LogOutActionSheet()
            }
            Text("").hidden().sheet(isPresented: $showingPasswordModal) {
                LogoutAndDeleteDataModal(logoutAndDeleteData: self.logoutAndDeleteData)
            }
            Text("").hidden().sheet(isPresented: $newChatModalVisible) {
                NewChatModal(
                    startChat: self.startChat,
                    inviteUser: self.$inviteUser,
                    inviteDevice: self.$inviteDevice,
                    startChatInProgress: self.$startChatInProgress)
            }
        }
        
    }
}
