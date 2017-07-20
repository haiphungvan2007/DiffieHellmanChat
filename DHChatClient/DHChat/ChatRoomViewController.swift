//
//  ChatRoomViewController.swift
//  DHChat
//
//  Created by Phung Van Hai on 11/21/16.
//  Copyright © 2016 Phung Van Hai. All rights reserved.
//

import Foundation
import UIKit

class ChatRoomViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var msgTextField: UITextField!
    @IBOutlet weak var uiTableView: UITableView!
    
    var mainController: FriendListViewController? = nil
    var friendInfo:FriendInfo? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Init table view
        self.uiTableView.delegate = self
        self.uiTableView.dataSource = self
        self.uiTableView.backgroundColor = UIColor.white
        self.uiTableView.register(UITableViewCell.self, forCellReuseIdentifier: "FriendListTableCell")
        
        if (friendInfo != nil)
        {
            self.title = friendInfo?.name
        }
        
        //Register notification handler when need reload chat  table
        NotificationCenter.default.addObserver(forName: Notification.Name("NewMessageReceived"), object: nil, queue: nil, using: onRecievedNewMessage)
    }
    
    //Funtion handle new message recieved notification
    func onRecievedNewMessage(_ notification: Notification) {
        DispatchQueue.main.async {
            self.uiTableView.reloadData()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (mainController != nil)
        {
            return (self.mainController?.friendHash[(friendInfo?.client_id)!]?.messageList.count)!
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendListTableCell", for: indexPath)
        cell.textLabel?.text = self.mainController?.friendHash[(friendInfo?.client_id)!]?.messageList[indexPath.row]
        return cell
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        return true;
    }
    
    @IBAction func onSendButtonClicked(_ sender: UIButton) {
        if (!(self.msgTextField.text?.isEmpty)!)
        {
            //Encryot Message
            let secretKey = self.mainController?.friendHash[(friendInfo?.client_id)!]?.secretKey
            let encryptMessage = DHKeyManager.getInstance().encryptData(with: (self.msgTextField.text! as NSString).data(using: String.Encoding.ascii.rawValue), andSecretKey: secretKey as Data!)
            //Base64 encode encrypted message
            let base64Message = encryptMessage?.base64EncodedString()
            
            //Send message to server
            let jsonMessage = NSMutableDictionary()
            jsonMessage.setValue("", forKey: "from")
            jsonMessage.setValue(friendInfo?.client_id, forKey: "to")
            jsonMessage.setValue(true, forKey: "encypted")
            jsonMessage.setValue("send_message", forKey: "type")
            jsonMessage.setValue(base64Message, forKey: "message")
            self.mainController?.sendJSONData(dictionary: jsonMessage)
            self.mainController?.friendHash[(friendInfo?.client_id)!]?.messageList.append((self.mainController?.userName)! + ": " + self.msgTextField.text!)
            
            
            //Reset text field and reload table
            self.msgTextField.text = "";
            DispatchQueue.main.async {
                self.uiTableView.reloadData()
            }
        }
        self.view.endEditing(true)
    }
    
}
