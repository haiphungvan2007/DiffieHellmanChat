//
//  FriendListViewController.swift
//  DHChat
//
//  Created by Phung Van Hai on 11/21/16.
//  Copyright © 2016 Phung Van Hai. All rights reserved.
//

import Foundation
import UIKit


struct FriendInfo {
    var client_id:String = ""
    var key:String = ""
    var name:String = ""
    var messageList:[String] = []
    var secretKey:NSData? = nil
};

class FriendListViewController: UITableViewController, StreamDelegate {
    
    private var isFirstLoad = false;
    private let CHAT_TEXT_ENCODING =  String.Encoding.ascii.rawValue
    
    //Server Info
    private let CHAT_SERVER_HOST:String = "127.0.0.1"
    private let CHAT_SERVER_PORT:Int = 8888
    private let CHAT_URL_WEBSERVICE:String = "http://127.0.0.1:9090/get_client_list"
    
    //Socket Properties
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    
    //User Profile
    var userName = ""
    var publicKey:NSData!
    
    var chatRoomTimer:Timer!
    
    //Friend Hash
    var friendHash:[String : FriendInfo] = [:]
    var friendArray:[FriendInfo] = []
    var selectedFriendInfo:FriendInfo? = nil;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Friend list"
        self.initNetworkCommunication()
        self.isFirstLoad = true;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //Display dialog to enter username
        if (self.isFirstLoad == true)
        {
            self.isFirstLoad = false
        }
        else
        {
           return
        }
        let alert = UIAlertController(title: "Login", message: "Enter your name:", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:
            {
                action in
                self.userName = (alert.textFields?[0].text!)!;
                //Send nick name
                let jsonMessage = NSMutableDictionary()
                jsonMessage.setValue("", forKey: "from")
                jsonMessage.setValue("", forKey: "to")
                jsonMessage.setValue(false, forKey: "encypted")
                jsonMessage.setValue("send_name", forKey: "type")
                jsonMessage.setValue(self.userName, forKey: "message")
                self.sendJSONData(dictionary: jsonMessage)
                
                if #available(iOS 10.0, *) {
                    self.chatRoomTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true)
                    {
                        timer in
                        self.reloadChatRom()
                        
                    }
                } else {
                    // Fallback on earlier versions
                }
                self.reloadChatRom()
                
        }
            
        ))
        alert.addTextField(configurationHandler: {(textField: UITextField!) in
            textField.placeholder = "Enter text:"
        })
        self.present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.friendHash.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendListTableCell", for: indexPath)
        cell.textLabel?.text = self.friendArray[indexPath.row].name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedFriendInfo = self.friendArray[indexPath.row]
        let chatRoomViewController = storyboard?.instantiateViewController(withIdentifier: "ChatRoomViewController") as! ChatRoomViewController
        chatRoomViewController.mainController = self
        chatRoomViewController.friendInfo = self.selectedFriendInfo
        self.navigationController?.pushViewController(chatRoomViewController, animated: true)
    }
    
    
    //Socket init and handlers
    func initNetworkCommunication(){
        if #available(iOS 8.0, *) {
            Stream.getStreamsToHost(withName: CHAT_SERVER_HOST, port: CHAT_SERVER_PORT, inputStream: &inputStream, outputStream: &outputStream)
        } else {
            var inStreamUnmanaged:Unmanaged<CFReadStream>?
            var outStreamUnmanaged:Unmanaged<CFWriteStream>?
            CFStreamCreatePairWithSocketToHost(nil, CHAT_SERVER_HOST as CFString!, UInt32(CHAT_SERVER_PORT), &inStreamUnmanaged, &outStreamUnmanaged)
            inputStream = inStreamUnmanaged?.takeRetainedValue()
            outputStream = outStreamUnmanaged?.takeRetainedValue()
        }
        
        self.inputStream?.delegate = self
        self.outputStream?.delegate = self
        
        self.inputStream?.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        self.outputStream?.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        
        self.inputStream?.open()
        self.outputStream?.open()
        
        //Send public key to server
        self.publicKey = DHKeyManager.getInstance().getPublicKey() as NSData!;
        let jsonMessage = NSMutableDictionary()
        jsonMessage.setValue("", forKey: "from")
        jsonMessage.setValue("", forKey: "to")
        jsonMessage.setValue(false, forKey: "encypted")
        jsonMessage.setValue("send_key", forKey: "type")
        jsonMessage.setValue(String(data: DHKeyManager.getInstance().getPublicKey(), encoding: String.Encoding.ascii), forKey: "message")
        self.sendJSONData(dictionary: jsonMessage)
        
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode{
        case Stream.Event.openCompleted:
            break
        case Stream.Event.hasSpaceAvailable:
            break
        case Stream.Event.hasBytesAvailable:
            if aStream == inputStream{
                var buffer = [UInt8](repeating: 0, count: 1024)
                var len: Int!
                len = inputStream?.read(&buffer, maxLength: 1024)
                if len > 0{
                    let output = NSString(bytes: &buffer, length: len, encoding: String.Encoding.ascii.rawValue)
                        
                    if nil != output{
                        let json = try! JSONSerialization.jsonObject(with: (output?.data(using: String.Encoding.ascii.rawValue))!, options: []) as! NSDictionary
                        let clientID = json.value(forKey: "from") as! String
                        let userName = self.friendHash[clientID]?.name;
                        let base64EncryptMessage = json.value(forKey: "message") as! String
                        let encryptMessage = NSData(base64Encoded: base64EncryptMessage)
                        
                        let secretKey = self.friendHash[clientID]?.secretKey
                        let plainMessage = DHKeyManager.getInstance().decryptData(with: encryptMessage as Data!, andSecretKey: secretKey as Data!)
        
                        self.friendHash[clientID]?.messageList.append(userName! + ": " + plainMessage!)
                
                        //Send notification for new message
                        NotificationCenter.default.post(name: Notification.Name("NewMessageReceived"), object: nil)
                    }
                }
            }
            break
        case Stream.Event.errorOccurred:
            break
        case Stream.Event.endEncountered:
            outputStream?.close()
            outputStream?.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            outputStream = nil
            break
        default:
            break
        }
    }
    
    func sendNSData(data:NSData){
        self.outputStream?.write(UnsafePointer<UInt8>(data.bytes.assumingMemoryBound(to: UInt8.self)) , maxLength: data.length)
        
    }
    
    func sendJSONData(dictionary:NSMutableDictionary){
        let jsonData = try! JSONSerialization.data(withJSONObject: dictionary, options: JSONSerialization.WritingOptions.prettyPrinted)
        
        jsonData.withUnsafeBytes {(bytes: UnsafePointer<UInt8>)->Void in
            self.outputStream?.write(bytes , maxLength: jsonData.count)
        }
        
    }
    
    
    func reloadChatRom() {
        let url = URL(string: self.CHAT_URL_WEBSERVICE)
        
        let task = URLSession.shared.dataTask(with: url!) { data, response, error in
            guard error == nil else {
                print(error!)
                return;
            }
            guard let data = data else {
                print("Data is empty")
                return
            }
            
            let json = try! JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
            
            //Check New Client Online
            for (clientID, friendInfo) in json
            {
                let friendInfoObject = friendInfo as! NSDictionary
                if (self.friendHash[clientID as! String] == nil)
                {
                    var newFriendInfo = FriendInfo()
                    newFriendInfo.client_id = friendInfoObject["client_id"] as! String
                    newFriendInfo.name = friendInfoObject["name"] as! String
                    newFriendInfo.key = friendInfoObject["key"] as! String
                    
                    if (!newFriendInfo.key.isEmpty)
                    {
                        newFriendInfo.secretKey = DHKeyManager.getInstance().getSecretKey(withPartnerKey: newFriendInfo.key.data(using: String.Encoding.ascii)) as NSData!
                        self.friendHash[clientID as! String] = newFriendInfo
                    }
                }
            }
            
            //Check Client Offline
            for (clientID, _) in self.friendHash
            {
                if (json[clientID] == nil)
                {
                    self.friendHash.removeValue(forKey: clientID)
                }
            }
            
            self.friendArray.removeAll();
            for (_, friendInfo) in self.friendHash
            {
                self.friendArray.append(friendInfo)
            }
            
            
            DispatchQueue.main.async {
               
                self.tableView.reloadData()
            }
            
        }
        
        task.resume()
    }

}
