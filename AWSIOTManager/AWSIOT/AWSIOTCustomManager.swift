//
//  AWSIOTCustomManager.swift
//  AWSIOTManager
//
//  Created by Magic-IOS on 07/05/21.
//

import Foundation
import UIKit
import AWSIoT

enum AWSUSERDEFAULTKEY : String {
    case certificateId = "certificateId"
    case certificateArn = "certificateArn"
    
}

private let p12Passphrase : String = ""

class AWSIOTCustomManager : NSObject {
    
    var status : AWSIoTMQTTStatus = .unknown
    
    // set below name as per format if need to generate certificate from application end. if you have .p12 file no need to change below param it will not use.
    private let CertificateSigningRequestCommonName = "IoTSampleSwift Application"
    private let CertificateSigningRequestCountryName = "Your Country"
    private let CertificateSigningRequestOrganizationName = "Your Organization"
    private let CertificateSigningRequestOrganizationalUnitName = "Your Organizational Unit"


    // This is the endpoint in your AWS IoT console. eg: https://xxxxxxxxxx.iot.<region>.amazonaws.com
    private let AWS_REGION = AWSRegionType.Unknown


    // below param change as per the values
    //For both connecting over websockets and cert, IOT_ENDPOINT should look like
    //https://xxxxxxx-ats.iot.REGION.amazonaws.com
    private let IOT_ENDPOINT = "https://xxxxxxxxxx.iot.<region>.amazonaws.com"
    private let IDENTITY_POOL_ID = "<REGION>:<UUID>"
    private let POLICY_NAME = "policy_name"


    // defaults no need to change below param
    //Used as keys to look up a reference of each manager
    private let AWS_IOT_DATA_MANAGER_KEY = "MyIotDataManager"
    private let AWS_IOT_MANAGER_KEY = "MyIotManager"
    
    // Variables
    @objc var iotDataManager: AWSIoTDataManager!
    @objc var iotManager: AWSIoTManager!
    @objc var iot: AWSIoT!
    
    public static var shared : AWSIOTCustomManager = AWSIOTCustomManager()
    
    override init() {
        super.init()
        self.configureAWSIOT()
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:AWS_REGION,
                                                                identityPoolId:IDENTITY_POOL_ID)
        initializeControlPlane(credentialsProvider: credentialsProvider)
        initializeDataPlane(credentialsProvider: credentialsProvider)
    }
    
    func configureAWSIOT() {
        
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USWest1,
           identityPoolId:IDENTITY_POOL_ID)

        let configuration = AWSServiceConfiguration(region:.USWest1, credentialsProvider:credentialsProvider)

        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
    }
    
    func initializeControlPlane(credentialsProvider: AWSCredentialsProvider) {
        //Initialize control plane
        // Initialize the Amazon Cognito credentials provider
        let controlPlaneServiceConfiguration = AWSServiceConfiguration(region:AWS_REGION, credentialsProvider:credentialsProvider)
        
        //IoT control plane seem to operate on iot.<region>.amazonaws.com
        //Set the defaultServiceConfiguration so that when we call AWSIoTManager.default(), it will get picked up
        AWSServiceManager.default().defaultServiceConfiguration = controlPlaneServiceConfiguration
        iotManager = AWSIoTManager.default()
        iot = AWSIoT.default()
    }
    
    func initializeDataPlane(credentialsProvider: AWSCredentialsProvider) {
        //Initialize Dataplane:
        // IoT Dataplane must use your account specific IoT endpoint
        let iotEndPoint = AWSEndpoint(urlString: IOT_ENDPOINT)
        
        // Configuration for AWSIoT data plane APIs
        let iotDataConfiguration = AWSServiceConfiguration(region: AWS_REGION,
                                                           endpoint: iotEndPoint,
                                                           credentialsProvider: credentialsProvider)
        //IoTData manager operates on xxxxxxx-iot.<region>.amazonaws.com
        AWSIoTDataManager.register(with: iotDataConfiguration!, forKey: AWS_IOT_DATA_MANAGER_KEY)
        iotDataManager = AWSIoTDataManager(forKey: AWS_IOT_DATA_MANAGER_KEY)
    }
    
    
    
    func mqttEventCallback( _ status: AWSIoTMQTTStatus ) {
        DispatchQueue.main.async {
            self.status = status
            print("connection status = \(status.rawValue)")

            switch status {
            case .connecting:
                break;
            case .connected:
                break;
            case .disconnected:
                break;
            case .connectionRefused:
                break;
            case .connectionError:
                break;
            case .protocolError:
                break;
            default:
                break;
            }
            
            NotificationCenter.default.post( name: .awsConnectionStatusChanged, object: status)
        }
    }
    
    func connectViaWebSocket() {
        iotDataManager.connectUsingWebSocket(withClientId: UUID().uuidString, cleanSession: true, statusCallback: self.mqttEventCallback)
    }
    
    func connectViaCert() {
        let defaults = UserDefaults.standard
        let certificateId = defaults.string( forKey: AWSUSERDEFAULTKEY.certificateId.rawValue)
        if (certificateId == nil) {
            
            let certificateIdInBundle = searchForExistingCertificateIdInBundle()
            
            if (certificateIdInBundle == nil) {
                
                createCertificateIdAndStoreinNSUserDefaults(onSuccess: {generatedCertificateId in
                    let uuid = UUID().uuidString
                    
                    self.iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:generatedCertificateId, statusCallback: self.mqttEventCallback)
                }, onFailure: {error in
                    print("Received error: \(error)")
                })
            }
        } else {
            let uuid = UUID().uuidString;
            // Connect to the AWS IoT data plane service w/ certificate
            iotDataManager.connect( withClientId: uuid, cleanSession:true, certificateId:certificateId!, statusCallback: self.mqttEventCallback)
        }
    }
    
    func searchForExistingCertificateIdInBundle() -> String? {
        let defaults = UserDefaults.standard
        // No certificate ID has been stored in the user defaults; check to see if any .p12 files
        // exist in the bundle.
        let myBundle = Bundle.main
        let myImages = myBundle.paths(forResourcesOfType: "p12" as String, inDirectory:nil)
        let uuid = UUID().uuidString

        guard let certId = myImages.first else {
            let certificateId = defaults.string(forKey: AWSUSERDEFAULTKEY.certificateId.rawValue)
            return certificateId
        }
        
        // A PKCS12 file may exist in the bundle.  Attempt to load the first one
        // into the keychain (the others are ignored), and set the certificate ID in the
        // user defaults as the filename.  If the PKCS12 file requires a passphrase,
        // you'll need to provide that here; this code is written to expect that the
        // PKCS12 file will not have a passphrase.
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: certId)) else {
            print("[ERROR] Found PKCS12 File in bundle, but unable to use it")
            let certificateId = defaults.string( forKey: AWSUSERDEFAULTKEY.certificateId.rawValue)
            return certificateId
        }
        
        
        // found identity \(certId), importing...
        
        if AWSIoTManager.importIdentity( fromPKCS12Data: data, passPhrase:p12Passphrase, certificateId:certId) {
            // Set the certificate ID and ARN values to indicate that we have imported
            // our identity from the PKCS12 file in the bundle.
            defaults.set(certId, forKey:AWSUSERDEFAULTKEY.certificateId.rawValue)
            defaults.set("from-bundle", forKey:AWSUSERDEFAULTKEY.certificateArn.rawValue)
            DispatchQueue.main.async {
                // Using certificate: \(certId))
                self.iotDataManager.connect( withClientId: uuid,
                                             cleanSession:true,
                                             certificateId:certId,
                                             statusCallback: self.mqttEventCallback)
            }
        }
        
        let certificateId = defaults.string( forKey: AWSUSERDEFAULTKEY.certificateId.rawValue)
        return certificateId
    }
    
    func createCertificateIdAndStoreinNSUserDefaults(onSuccess:  @escaping (String)->Void,
                                                     onFailure: @escaping (Error) -> Void) {
        let defaults = UserDefaults.standard
        // Now create and store the certificate ID in NSUserDefaults
        let csrDictionary = [ "commonName": CertificateSigningRequestCommonName,
                              "countryName": CertificateSigningRequestCountryName,
                              "organizationName": CertificateSigningRequestOrganizationName,
                              "organizationalUnitName": CertificateSigningRequestOrganizationalUnitName]
        
        self.iotManager.createKeysAndCertificate(fromCsr: csrDictionary) { (response) -> Void in
            guard let response = response else {
                // "Unable to create keys and/or certificate, check values in Constants.swift"
                onFailure(NSError(domain: "No response on iotManager.createKeysAndCertificate", code: -2, userInfo: nil))
                return
            }
            defaults.set(response.certificateId, forKey:AWSUSERDEFAULTKEY.certificateId.rawValue)
            defaults.set(response.certificateArn, forKey:AWSUSERDEFAULTKEY.certificateArn.rawValue)
            let certificateId = response.certificateId
            print("response: [\(String(describing: response))]")
            
            let attachPrincipalPolicyRequest = AWSIoTAttachPrincipalPolicyRequest()
            attachPrincipalPolicyRequest?.policyName = self.POLICY_NAME
            attachPrincipalPolicyRequest?.principal = response.certificateArn
            
            // Attach the policy to the certificate
            self.iot.attachPrincipalPolicy(attachPrincipalPolicyRequest!).continueWith (block: { (task) -> AnyObject? in
                if let error = task.error {
                    print("Failed: [\(error)]")
                    onFailure(error)
                } else  {
                    print("result: [\(String(describing: task.result))]")
                    DispatchQueue.main.asyncAfter(deadline: .now()+2, execute: {
                        if let certificateId = certificateId {
                            onSuccess(certificateId)
                        } else {
                            onFailure(NSError(domain: "Unable to generate certificate id", code: -1, userInfo: nil))
                        }
                    })
                }
                return nil
            })
        }
    }
    
    func handleDisconnect() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.iotDataManager.disconnect();
        }
    }
    
    func publishDataTomqtt(topic:String,data:Data,qos:AWSIoTMQTTQoS = .messageDeliveryAttemptedAtMostOnce) {
        iotDataManager.publishData(data, onTopic: topic, qoS: qos)
    }
    
}

extension Notification.Name {
    
    public static var awsConnectionStatusChanged = Notification.Name("awsConnectionStatusChanged")
    
}
