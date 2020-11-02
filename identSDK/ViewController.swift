//
//  ViewController.swift
//  identSDK
//
//  Created by Emir on 6.08.2020.
//  Copyright © 2020 Emir Beytekin. All rights reserved.
//

import UIKit

class ViewController: UIViewController, IdentifyListenerDelegate {
    
    @IBOutlet weak var buttonsStack: UIStackView!
    @IBOutlet weak var callButtonView: UIStackView!
    @IBOutlet weak var waitScreen: UIView!
    @IBOutlet weak var connectBtn: UIButton!
    @IBOutlet weak var responseCam: UIView!
    @IBOutlet weak var myCamView: UIView!
    var manager = IdentifyManager.shared
    @IBOutlet weak var smsViewScreen: UIView!
    @IBOutlet weak var smsCodeTxt: UITextField!
    @IBOutlet weak var smsSubmitBtn: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardBtn()
        manager.delegate = self

    }

    @IBAction func connectAct(_ sender: Any) {
        let _ = IdentifyManager.shared.getStats()
        let conn = manager.connectToSocket()
        manager.socket.onConnect = {
            print("socket connected")
        }
        if conn {
            setupUI()
            self.connectBtn.setTitle("connected", for: .normal)
        } else {
            self.connectBtn.setTitle("connect to server", for: .normal)
        }
    }
    
    func setupUI(_ isConnected:Bool = true) {
        if !isConnected {
            self.responseCam.isHidden = true
            self.myCamView.isHidden = true
            self.connectBtn.setTitle("reconnect to server", for: .normal)
        } else {
            setupWaitScreen()
        }
    }
    
    func setupWaitScreen() {
        let remoteVideoView = manager.webRTCClient.remoteVideoView()
        remoteVideoView.clipsToBounds = true
        manager.webRTCClient.setupRemoteViewFrame(frame: CGRect(x: 0, y: 0, width: responseCam.frame.width, height: responseCam.frame.height))
        self.responseCam.addSubview(remoteVideoView)
        responseCam.backgroundColor = .red
        let localVideoView = manager.webRTCClient.localVideoView()
        localVideoView.clipsToBounds = true
        manager.webRTCClient.setupLocalViewFrame(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
        self.myCamView.addSubview(localVideoView)
        myCamView.backgroundColor = .blue
        self.responseCam.isHidden = true
        self.myCamView.isHidden = true
        self.waitScreen.isHidden = false
        buttonsStack.isHidden = true
    }
    
    func setupKeyboardBtn() {
        let toolBar = UIToolbar(frame: CGRect(origin: .zero, size: .init(width: view.frame.size.width, height: 30)))
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneBtn = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneBtnAct))
        toolBar.setItems([flexSpace, doneBtn], animated: false)
        toolBar.sizeToFit()
        smsCodeTxt.inputAccessoryView = toolBar
    }
    
    @objc func doneBtnAct() {
        self.view.endEditing(true)
    }
    
    
    @IBAction func sendSmsCode(_ sender: UIButton) {
        if self.smsCodeTxt.text != "" {
            manager.sendSmsTan(tan: self.smsCodeTxt.text!)
            self.smsViewScreen.isHidden = true
            view.endEditing(true)
        }
    }
    
    // MARK: CALL METHODS
    
    @IBAction func acceptAct(_ sender: Any) {
        manager.acceptCall()
        self.responseCam.isHidden = false
        self.myCamView.isHidden = false
        self.waitScreen.isHidden = true
        buttonsStack.isHidden = true
    }
    
    @IBAction func rejectAct(_ sender: Any) {
        manager.rejectCall()
        self.setupUI()
    }
    
    // MARK: DELEGATE METHODS
    
    func comingSms() {
        smsCodeTxt.becomeFirstResponder()
        self.smsViewScreen.isHidden = false
    }
    
    func incomingCall() {
        buttonsStack.isHidden = false
    }
    
    func disconnected() {
        setupUI(false)
    }
    
}


