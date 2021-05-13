//
//  ViewController.swift
//  AWSIOTManager
//
//  Created by Magic-IOS on 07/05/21.
//

import UIKit
import AWSIoT

class ViewController: UIViewController {

    var isFirstTimeConnect : Bool = false
    var count : Int = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.connectionStatus(notification:)), name: .awsConnectionStatusChanged, object: nil)
        AWSIOTCustomManager.shared.connectViaWebSocket()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .awsConnectionStatusChanged, object: nil)
    }
    
    @objc func connectionStatus(notification:NSNotification) {
        guard let status = notification.object as? AWSIoTMQTTStatus else {
            return
        }
        print(status.rawValue)
        if status == .connected {
            print("Connected")
            self.subscribeTopic()
        }
    }
    
    func subscribeTopic() {
        AWSIOTCustomManager.shared.iotDataManager.subscribe(toTopic: "slider", qoS: .messageDeliveryAttemptedAtMostOnce, messageCallback: {
            (payload) ->Void in
            print(" payload data " ,payload)
            guard let stringValue = NSString(data: payload, encoding: String.Encoding.utf8.rawValue) else {
                return;
            }
            print("received: \(stringValue)")
        } )
    }

    func unSubscribeTopic() {
        AWSIOTCustomManager.shared.iotDataManager.unsubscribeTopic("slider")
    }
    
    
    @IBAction func btnTempAction(_ sender: UIButton) {
        let str = "\(count)"
        count += 1
        guard let data = str.data(using: .utf8) else {
            return
        }
        print("publish")
        AWSIOTCustomManager.shared.publishDataTomqtt(topic: "slider", data: data)
    }
    
}

