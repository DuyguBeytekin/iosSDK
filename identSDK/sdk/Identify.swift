//
//  Identify.swift
//  identSDK
//
//  Created by Emir on 6.08.2020.
//  Copyright © 2020 Emir Beytekin. All rights reserved.
//

import UIKit
import Alamofire
import Starscream
import WebRTC

protocol IdentifyListenerDelegate:class {
    func incomingCall()
    func disconnected()
    func comingSms()
    
}

open class IdentifyManager: WebSocketDelegate, WebRTCClientDelegate, CameraSessionDelegate {
    
    private init() {
        socket = WebSocket(url: URL(string: "wss://ws.identify24.de:8887/")!)
        self.microphoneReq()
        self.wantCameraRequest()
    }
    
    public var socket: WebSocket!
    static let shared = IdentifyManager.init()
    public var userToken = ""
    var netw = Network()
    var tempResp: RoomResponse = RoomResponse()
    weak var delegate: IdentifyListenerDelegate?
    var torchOn = false
    var isFront = true
    var webRTCClient: WebRTCClient!
    var tryToConnectWebSocket: Timer?
    var cameraSession: CameraSession?
    var userId = ""
    var isConnected = false
    var tid = 0
    
    public func remoteCam() -> UIView {
        let remoteVideoView = self.webRTCClient.remoteVideoView()
        self.webRTCClient.setupRemoteViewFrame(frame: CGRect(x: 0, y: 0, width: 125, height:165))
        return remoteVideoView
    }
    
    public func myCam() -> UIView {
        let myCam = self.webRTCClient.localVideoView()
        return myCam
    }
    
    func connectToServer() -> Bool {
        var connected = false
        netw.connectToRoom(identId: self.userToken) { (resp) in
            self.tempResp = resp
            self.userId = resp.data?.customer_id ?? ""
            connected = true
        }
        return connected
    }
    
    func sendSmsTan(tan:String) {
        netw.verifySms(tid: "\(tid)", tan: tan) { (resp) in
            self.sendSmsStatus(tanCode: tan)
        }
    }
    
    func getStats() -> RoomResponse {
        let _ = self.connectToServer()
        if self.tempResp.data?.customer_id != "" {
            let _ = self.connectToSocket()
        }
        return self.tempResp
    }
    
    func connectToSocket() -> Bool {
        socket.delegate = self
        socket.pongDelegate = self as? WebSocketPongDelegate
        self.socket.enableCompression = true
        self.socket.desiredTrustHostname = "identify24"
        self.socket.disableSSLCertValidation = true
        socket.connect()
        webRTCClient = WebRTCClient()
        webRTCClient.delegate = self
        webRTCClient.setup(videoTrack: true, audioTrack: true, dataChannel: true, customFrameCapturer: false, isFront: true)
        isConnected = true
        tryToConnectWebSocket = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
            if self.webRTCClient.isConnected || self.socket.isConnected {
                self.socket.enableCompression = true
                self.socket.desiredTrustHostname = "identify24"
                self.socket.disableSSLCertValidation = true
                return
            }
        })
        
        return true
    }
    
    func sendImOnline(socket: WebSocketClient) {
        
        let newSignal2 = ConnectSocketResp.init(location: "conf", room: tempResp.data?.customer_uid ?? "", action: "imOnline")
        do {
            let data = try JSONEncoder().encode(newSignal2)
            let message = String(data: data, encoding: String.Encoding.utf8)!
            if self.socket.isConnected {
                print(#function)
                print("giden data::")
                print(message)
                print("-----------")
                self.socket.write(string: message)
            }
            
        } catch {
            print(error)
        }
    }
    
    func sendSmsStatus(tanCode: String) {
        let signal = sendSmsStr.init(action: "tan_entered", room: tempResp.data?.customer_uid ?? "", tid: "\(self.tid)", tan: tanCode)
        do {
            let data = try JSONEncoder().encode(signal)
            let message = String(data: data, encoding: String.Encoding.utf8)!
            if self.socket.isConnected {
                self.socket.write(string: message)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func sendFirstSubscribe(socket: WebSocketClient) {
        let newSignal = ConnectSocketResp.init(location: "conf", room: tempResp.data?.customer_uid ?? "", action: "subscribe")
        do {
            let data = try JSONEncoder().encode(newSignal)
            let message = String(data: data, encoding: String.Encoding.utf8)!
            print(#function)
            print("giden data::")
            print(message)
            print("-----------")
            if self.socket.isConnected {
                self.socket.write(string: message)
            }
        } catch {
            print(error)
        }
    }
    
    /// socket functions
    
    public func websocketDidConnect(socket: WebSocketClient) {
        self.sendFirstSubscribe(socket: self.socket!)
    }
        
    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        isConnected = false
        if let error = error as? WSError {
            print(error)
        }
        
        print("-- websocket is disconnected: \(error?.localizedDescription) --")
    }
    
    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        do {
            let signalingMessage = try JSONDecoder().decode(SendCandidate.self, from: text.data(using: .utf8)!)
            let cominCan = try JSONDecoder().decode(GetCandidate.self, from: text.data(using: .utf8)!)
//            let firstConnect = try JSONDecoder().decode(connectStr.self, from: text.data(using: .utf8)!)
            let smsCan = try JSONDecoder().decode(SMSCandidate.self, from: text.data(using: .utf8)!)
            print("sinyal mesajı:", text)
            
//            if firstConnect.action == "sysMsg" {
//
//            }
//            if cominCan.action == "smsMsg" {
//                self.sendFirstSubscribe(socket: self.socket)
//            } else
            if cominCan.action == "candidate" {
                let x = signalingMessage.candidate!
                let can = RTCIceCandidate(sdp: x.candidate, sdpMLineIndex: x.sdpMLineIndex, sdpMid: x.sdpMid)
                webRTCClient.receiveCandidate(candidate: can)
            }
            if signalingMessage.action == "initCall" {
                delegate?.incomingCall()
//                let next = CallViewController()
//                next.delegate = self
//                next.modalPresentationStyle = .overCurrentContext
//                let nc = UINavigationController(rootViewController: next)
//                self.present(nc, animated: false, completion: nil)
//                vibrate(type: .oldSchool)
            } else if signalingMessage.action == "newSub" {
                sendImOnline(socket: self.socket!)
            } else if signalingMessage.action == "imOnline" {
                sendImOnline(socket: self.socket!)
            } else if signalingMessage.action == "startCall" {
                
            } else if signalingMessage.action == "terminateCall" || signalingMessage.action == "endCall" {
                delegate?.disconnected()
            } else if signalingMessage.action == "requestTan" {
                self.tid = smsCan.tid ?? 0
                delegate?.comingSms()
//                goSms()
            } else if signalingMessage.action == "sdp" {
                let sm = try JSONDecoder().decode(SDPSender.self, from: text.data(using: .utf8)!)
                webRTCClient.receiveAnswer(answerSDP: RTCSessionDescription(type: .answer, sdp: sm.sdp!.sdp))
            }
            else if signalingMessage.action == "toggleFlash" {
                torchOn = !torchOn
                if !isFront {
                    self.sendTorchPositionSocket(isOpened: torchOn)
                    self.toggleTorch(on: torchOn)
                }
            } else if signalingMessage.action == "toggleCamera" {
                self.isFront = !isFront
                self.sendCameraPositionSocket(isFront: isFront)
                webRTCClient.switchCameraPosition()
            }
        } catch {
            print(error)
        }
    }
    
    func sendTorchPositionSocket(isOpened: Bool) {
        let signal = ToogleTorch.init(action: "toggleFlash",result:isOpened)
        do {
            let data = try JSONEncoder().encode(signal)
            let message = String(data: data, encoding: String.Encoding.utf8)!
            if self.socket.isConnected {
                self.socket.write(string: message)
            }
        } catch {
            print(error)
        }
    }
    
    func sendCameraPositionSocket(isFront: Bool) {
        let signal = ToogleCamera.init(action: "toggleCamera", result:isFront)
        do {
            let data = try JSONEncoder().encode(signal)
            let message = String(data: data, encoding: String.Encoding.utf8)!
            if self.socket.isConnected {
                self.socket.write(string: message)
            }
        } catch {
            print(error)
        }
    }
    
    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("gelen data::")
        print(data)
    }
    
    func didGenerateCandidate(iceCandidate: RTCIceCandidate) {
        self.sendCandidate(iceCandidate: iceCandidate)
    }
    
    func didIceConnectionStateChanged(iceConnectionState: RTCIceConnectionState) {
        
    }
    
    func didOpenDataChannel() {
        print("did open data channel")
    }
    
    func didReceiveData(data: Data) {
        print(data)
    }
    
    func didReceiveMessage(message: String) {
        print(message)
    }
    
    func didConnectWebRTC() {
        self.webRTCClient.speakerOn()
    }
    
    func didDisconnectWebRTC() {
        rejectCall()
    }
    
    func didOutput(_ sampleBuffer: CMSampleBuffer) {
        print("")
    }
    
    func acceptCall() {
        webRTCClient.connect { (desc) in
            let msg = CallSocketResp(action: "startCall", room: self.tempResp.data?.customer_uid ?? "")
            do {
                let data = try JSONEncoder().encode(msg)
                let message = String(data: data, encoding: String.Encoding.utf8)!
                if self.socket.isConnected {
                    print(#function)
                    print("giden data::")
                    print(message)
                    print("-----------")
                    self.socket.write(string: message)
                    self.sendSDP(sessionDescription: RTCSessionDescription(type: .offer, sdp: desc.sdp))
                }
            } catch {
                print(error)
            }
        }
    }
    
    func rejectCall() {
        self.socket.disconnect()
        self.webRTCClient.disconnect()
    }
    
    
    
    private func sendSDP(sessionDescription: RTCSessionDescription) {
        let sdpp = SDP2.init(type: "offer", sdp: sessionDescription.sdp)
        let sm2 = SDPSender.init(action: "sdp", room: self.tempResp.data?.customer_uid ?? "", sdp: sdpp)
        do {
            let data = try JSONEncoder().encode(sm2)
            let message = String(data: data, encoding: String.Encoding.utf8)!
            if self.socket.isConnected {
                print(#function)
                print("giden data::")
                print(message)
                print("-----------")
                self.socket.write(string: message)
            }
        } catch {
            print(error)
        }
    }
    
    private func sendCandidate(iceCandidate: RTCIceCandidate){
        let candidate = Candidate.init(candidate: iceCandidate.sdp, sdpMLineIndex: iceCandidate.sdpMLineIndex, sdpMid: iceCandidate.sdpMid == "audio" ? "audio" : "video")
        let newSignal = SendCandidate.init(action: "candidate", candidate: candidate, room: self.tempResp.data?.customer_uid ?? "", sessionDescription: nil)
        do {
            let data = try JSONEncoder().encode(newSignal)
            let message = String(data: data, encoding: String.Encoding.utf8)!
            print(#function)
            print("giden candidate data::")
            print(message)
            print("-----------")
            if self.socket.isConnected {
                self.socket.write(string: message)
            }
        } catch {
            print(error)
        }
    }
    
    func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        if device.hasTorch {
            do {
                try device.lockForConfiguration()

                if on == true {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }

                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
    
    public func microphoneReq() {
            var microphoneAccessGranted = false
            let microPhoneStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)
            
            switch microPhoneStatus {
            case .authorized:
                microphoneAccessGranted = true
            case .denied, .restricted, .notDetermined:
                microphoneAccessGranted = false
                AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (alowedAccess) -> Void in
                    if !alowedAccess {
    //                    weakSelf?.showMicrophonePermisionPopUp()
                    }
                })
            }
        }
        
    public func wantCameraRequest() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        let userAgreedToUseIt = authorizationStatus == .authorized
        if userAgreedToUseIt {
           
            //Do whatever you want to do with camera.
            
        } else if authorizationStatus == .denied
            || authorizationStatus == .restricted
            || authorizationStatus == .notDetermined {
            
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (alowedAccess) -> Void in
                if alowedAccess {
                    self.microphoneReq()
                } else {
                    self.microphoneReq()
                }
            })
        }
    }

}


public class Network: NSObject {
    
    var BASE_URL = "https://api.identify24.de/"
    
    func connectToRoom(identId: String, callback: @escaping((_ results: RoomResponse) -> Void)) {
        let urlStr = BASE_URL + "mobile/getIdentDetails/" + IdentifyManager.shared.userToken
        var jsonHeaders = [String : String]()
        jsonHeaders["Content-Type"] = "application/json"
        Alamofire.request(urlStr, method: .get, parameters:nil, encoding: URLEncoding.default , headers:jsonHeaders).validate(contentType: ["application/json"]).responseJSON { response in
            guard let data = response.data else { return }
            do {
                let decoder = JSONDecoder()
                let forceResp = try decoder.decode(RoomResponse.self, from: data)
                DispatchQueue.main.async {
                    callback(forceResp)
                }
            } catch let error {
                print(error)
            }
        }
    }
    
    func verifySms(tid: String, tan: String, callback: @escaping ((_ results: EmptyResponse) -> Void)) {
        let urlStr = BASE_URL + "mobile/verifyTan"
        var jsonHeaders = [String : String]()
        jsonHeaders["Content-Type"] = "application/json"
        let papara = SmsJson.init(tid: tid, tan: tan)
        Alamofire.request(urlStr, method: .post, parameters:papara.asDictionary(), encoding: JSONEncoding.default , headers:jsonHeaders).responseJSON { response in

            print("Request: \(String(describing: response.request))")   // original url request
            print("Parameters: \(papara.asDictionary())")
            print("Response: \(String(describing: response.response))") // http url response
            print("Result: \(response.result)")
            
            
            if let  JSON = response.result.value,
                let JSONData = try? JSONSerialization.data(withJSONObject: JSON, options: .prettyPrinted),
                let prettyString = NSString(data: JSONData, encoding: String.Encoding.utf8.rawValue) {
                print(prettyString)
            }
            
            guard let data = response.data else { return }
            do {
                print(data)
                let decoder = JSONDecoder()
                let forceResp = try decoder.decode(EmptyResponse.self, from: data)
                DispatchQueue.main.async {
                    callback(forceResp)
                }
                
            } catch let error {
                print(error)
            }
        }
    }
    
    class SmsJson: Codable {
        var tid: String?
        var tan: String?

        init(tid: String?, tan: String?) {
            self.tid = tid
            self.tan = tan
        }
    }
}

extension Encodable {
    func asDictionary() -> [String: Any] {
        
        do{
            let data = try JSONEncoder().encode(self)
            
            guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
                print("Request Object dictionary ' e çevrilirken hata oluştu.")
                return [:]
            }
            return dictionary
            
        }catch {
            
            print("AsDictionary hatası :  \(error)")
            return [:]
        }
    }
}



extension UIViewController {
    
    func goSms() {
//        let next = SmsVerificationViewController()
//        next.customerId = self.tid
//        next.modalPresentationStyle = .overCurrentContext
//        next.delegate = self
//        self.present(next, animated: true, completion: nil)
    }
    
    
}
