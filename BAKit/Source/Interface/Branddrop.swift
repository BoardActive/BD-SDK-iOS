//
//  Branddrop.swift
//  Branddrop.framework
//
//  Created by Hunter Brennick on 7/23/18.
//  Copyright © 2018 Branddrop. All rights reserved.
//
import CoreLocation
import Foundation
import os.log
import UIKit

public enum NetworkError: Error {
    case BadJSON
    case NSError
}

/**
 Dev and prod base urls plus their associated endpoints.
 */
public enum EndPoints {
    static let DevEndpoint = "https://api.branddrop.us/mobile/v1"
    static let ProdEndpoint = "https://api.branddrop.us/mobile/v1"
    static let Events = "/events"
    static let Me = "/me"
    static let Locations = "/locations"
    static let Login = "/login"
    static let Attributes = "/attributes"
    static let GeoFenceLocation = "/geofenceLocation"
}

/**
 A succinct means of denoting which `CLLocationManager` permission the app will request from the user.
 */
public enum AuthorizationMode: String {
    case always
    case whenInUse
}

/**
These are all the general errors which may occur in the SDK.
 */
enum BAKitError: Error {
    case appDisable
}

public class Branddrop: NSObject, CLLocationManagerDelegate {
    /**
     A property returning the Branddrop singleton.
     */
    public static let client = Branddrop()
    public var userDefaults = UserDefaults(suiteName: "BAKit")
    public var isDevEnv = true
    public var geofenceRadius = 100
    public var recordLocationAfterMeters: Double = 1000
    
    public var isAppEnable = true
    
    private let locationManager = CLLocationManager()
    private let geofenceNotifyTimeLimit: Double = 86400
    
    public var currentLocation = CLLocation()
    private var isGeoLocationCalled = false
    
//    public var previousUserLocation: CLLocation?
//    public var distanceBetweenLocations: CLLocationDistance?
    
    public let categoryIdentifier = "PreviewNotification"
    public let downloadActionIdentifier = "download"

    private override init() {}

    /**
     Sets the `appID`, `appKey`, and `fcmToken` in the `UserDefaults` to those of the parameters before calling `FirebaseApp.configure()`.

     - parameter appID: The app's ID.
     - parameter appKey: The app's key.
     - parameter fcmToken: The FCM token for this device.
     */
    public func setupEnvironment(appID: String, appKey: String) {
        userDefaults?.set(appID, forKey: String.ConfigKeys.AppId)
        userDefaults?.set(appKey, forKey: String.ConfigKeys.AppKey)
        userDefaults?.synchronize()
    }

    deinit {
        stopUpdatingLocation()
    }
    
    /**
     If error occurs, block will execute with status other than `INTULocationStatusSuccess` and subscription will be kept alive.
     */
    public func monitorLocation() {
        Branddrop.client.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        Branddrop.client.locationManager.distanceFilter = kCLDistanceFilterNone
        Branddrop.client.locationManager.delegate = self
        Branddrop.client.locationManager.requestAlwaysAuthorization()
        Branddrop.client.locationManager.startUpdatingLocation()
        Branddrop.client.locationManager.startMonitoringSignificantLocationChanges()
        Branddrop.client.locationManager.pausesLocationUpdatesAutomatically = false
        Branddrop.client.locationManager.allowsBackgroundLocationUpdates=true
        Branddrop.client.locationManager.activityType = .otherNavigation
    }
    
      /**
       Calls `stopUpdatingLocation` on Branddrop's private CLLocationManager property.
       */
      public func stopUpdatingLocationandReinitialize() {
            Branddrop.client.locationManager.stopUpdatingLocation()
            Branddrop.client.locationManager.startMonitoringSignificantLocationChanges()
      }

    //MARK: - Core Location
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            os_log("\n[Branddrop] didUpdateLocations :: Error: Last location of locations = nil.\n")
            return
        }
        Branddrop.client.currentLocation = location
        
        if UserDefaults.standard.value(forKey: String.ConfigKeys.traveledDistance) == nil {
            UserDefaults.standard.set([location.coordinate.latitude, location.coordinate.longitude], forKey: String.ConfigKeys.traveledDistance)
        } else {
            let previous = UserDefaults.standard.value(forKey: String.ConfigKeys.traveledDistance) as! NSArray
            let previousLocation = CLLocation(latitude: previous[0] as! CLLocationDegrees, longitude: previous[1] as! CLLocationDegrees)
            let distanceInMeters = previousLocation.distance(from: location)
            if distanceInMeters >= recordLocationAfterMeters {
                UserDefaults.standard.set([location.coordinate.latitude, location.coordinate.longitude], forKey: String.ConfigKeys.traveledDistance)
                UserDefaults(suiteName: "BAKit")?.set(nil, forKey: String.ConfigKeys.geoFenceLocations)
                Branddrop.client.storeAppLocations()
            }
        }
        let flag: Bool = Branddrop.client.userDefaults?.value(forKey: String.ConfigKeys.silentPushReceived) as? Bool ?? false
        if flag {
            Branddrop.client.userDefaults?.set(false, forKey: String.ConfigKeys.silentPushReceived)
            UserDefaults(suiteName: "BAKit")?.set(nil, forKey: String.ConfigKeys.geoFenceLocations)
            Branddrop.client.storeAppLocations()
        }
        
        if !isGeoLocationCalled {
            self.isGeoLocationCalled = true
            Branddrop.client.storeAppLocations()
        }

       /* if let locationList = userDefaults?.value(forKey: String.ConfigKeys.userLocations) as? [[String: Double]] {
            Branddrop.client.previousUserLocation = CLLocation(latitude: locationList.last?[String.NetworkCallRelated.Latitude] ?? 0.0, longitude: locationList.last?[String.NetworkCallRelated.Longitude] ?? 0.0)
        }
        
        if (Branddrop.client.previousUserLocation == nil) {
            Branddrop.client.previousUserLocation = location
            saveLocationLocally(location: location)
            
        } else if let previousLocation = Branddrop.client.previousUserLocation, location.distance(from: previousLocation) > recordLocationAfterMeters {
            Branddrop.client.previousUserLocation = location
            saveLocationLocally(location: location)
        } */
        
//        if CLLocationManager.locationServicesEnabled() {
//            switch CLLocationManager.authorizationStatus() {
//            case .notDetermined, .restricted, .denied, .authorizedWhenInUse:
//                Branddrop.client.userDefaults?.set(false, forKey: String.Attribute.LocationPermission)
//            case .authorizedAlways:
//                Branddrop.client.userDefaults?.set(true, forKey: String.Attribute.LocationPermission)
//            }
//            Branddrop.client.userDefaults?.synchronize()
//        }
//
//        if Branddrop.client.userDefaults?.object(forKey: String.Attribute.DateLocationRequested) == nil {
//            let date = Date().iso8601
//            Branddrop.client.userDefaults?.set(date, forKey: String.Attribute.DateLocationRequested)
//            Branddrop.client.userDefaults?.synchronize()
////            Branddrop.client.editUser(attributes: Attributes(fromDictionary: ["dateLocationRequested": date]), httpMethod: String.HTTPMethod.PUT)
//        }
//
//        if Branddrop.client.currentLocation == nil {
//            Branddrop.client.currentLocation = location
//            postLocation(location: location)
//        }
//
//        if let currentLocation = Branddrop.client.currentLocation, location.distance(from: currentLocation) < 10.0 {
//            Branddrop.client.distanceBetweenLocations = (Branddrop.client.distanceBetweenLocations ?? 0.0) + location.distance(from: currentLocation)
//        } else {
//            postLocation(location: location)
//            Branddrop.client.distanceBetweenLocations = 0.0
//        }

//        Branddrop.client.currentLocation = location
    }
    
    public func getAttributes(completionHandler: @escaping([[String: Any]]?, Error?) -> Void) {
        let path = EndPoints.Attributes
        callServer(forList: path, httpMethod: String.HTTPMethod.GET, body: [:]) { (parsedJson, error) in
            if error != nil {
                completionHandler(nil, error)
            } else {
                completionHandler(parsedJson, nil)
            }
        }
    }
      
      
      public func updateUserData(body: [String: Any], completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
          let path = "\(EndPoints.Me)"

          callServer(path: path, httpMethod: String.HTTPMethod.PUT, body: body) { parsedJSON, err in
              guard err == nil else {
                  completionHandler(nil, err)
                  return
              }

              completionHandler(parsedJSON, nil)
              return
          }
      }
      
      public func getMe(completionHandler: @escaping([String: Any]?, Error?) -> Void) {
          let path = "\(EndPoints.Me)"

          callServer(path: path, httpMethod: String.HTTPMethod.GET, body: [:]) { parsedJSON, err in
                       guard err == nil else {
                           completionHandler(nil, err)
                           return
                       }
                  os_log("[Branddrop] :: login: %s", parsedJSON.debugDescription)
                       completionHandler(parsedJSON, nil)
                       return
                   }
      }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let clError = error as? CLError else {
            os_log("\n[Branddrop] didFailWithError :: %s \n", error.localizedDescription)
            return
        }
        
        switch clError.errorCode {
        case 0:
            os_log("\n[Branddrop] didFailWithError :: Error: Location Unknown \n")
            break
        case 1:
            // Access to the location service was denied by the user.
            stopUpdatingLocation()
            break
        case 2:
            // Network error
            break
        default:
            os_log("\n[Branddrop] didFailWithError :: Error: %s \n", clError.errorUserInfo.debugDescription)
            break
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        var isAppAuthorized = false
        switch status {
        case .notDetermined, .restricted, .denied, .authorizedWhenInUse:
            os_log("\n[Branddrop] didChangeAuthorization :: status: Always\n")
            userDefaults?.set(false, forKey: String.Attribute.LocationPermission)
        case .authorizedAlways:
            os_log("\n[Branddrop] didChangeAuthorization :: status: Always\n")
            userDefaults?.set(true, forKey: String.Attribute.LocationPermission)
            isAppAuthorized = true
        }
        userDefaults?.synchronize()
        Branddrop.client.updatePermissionStates()
    }
    
    /**
     Functions as an as needed means of procuring the user's current location.
     - Returns: `CLLocation?` An optional `CLLocation` obtained by `CLLocationManager's` `requestLocation()` function.
     */
  /*  public func getCurrentLocations() -> Dictionary<String, String>? {
        if let latitude = previousUserLocation?.coordinate.latitude, let longitude = previousUserLocation?.coordinate.longitude {
            return [String.NetworkCallRelated.Latitude: "\(latitude)", String.NetworkCallRelated.Longitude: "\(longitude)"]
        }
        return nil
    } */

    /**
     Calls `stopUpdatingLocation` on Branddrop's private CLLocationManager property.
     */
    public func stopUpdatingLocation() {
        Branddrop.client.locationManager.stopUpdatingLocation()
    }

    // MARK: SDK Functions

    public func getHeaders() -> [String: String]? {
        guard let tokenString = userDefaults?.object(forKey: String.HeaderValues.FCMToken) as? String else {
            return nil
        }

        let hostKey: String
        if isDevEnv {
            hostKey = String.HeaderValues.DevHostKey
        } else {
            hostKey = String.HeaderValues.ProdHostKey
        }

        let headers: [String: String] = [
            String.HeaderKeys.AcceptEncodingHeader: String.HeaderValues.GzipDeflate,
            String.HeaderKeys.AcceptHeader: String.HeaderValues.WildCards,
            String.HeaderKeys.AppKeyHeader: Branddrop.client.userDefaults?.string(forKey: String.ConfigKeys.AppKey) ?? "",
            String.HeaderKeys.AppIdHeader: Branddrop.client.userDefaults?.string(forKey: String.ConfigKeys.AppId) ?? "",
            String.HeaderKeys.AppVersionHeader: String.HeaderValues.AppVersion,
            String.HeaderKeys.CacheControlHeader: String.HeaderValues.NoCache,
            String.HeaderKeys.ConnectionHeader: String.HeaderValues.KeepAlive,
            String.HeaderKeys.ContentTypeHeader: String.HeaderValues.ApplicationJSON,
            String.HeaderKeys.DeviceOSHeader: String.HeaderValues.iOS,
            String.HeaderKeys.DeviceOSVersionHeader: String.HeaderValues.DeviceOSVersion,
            String.HeaderKeys.DeviceTokenHeader: tokenString,
            String.HeaderKeys.DeviceTypeHeader: String.HeaderValues.DeviceType,
            String.HeaderKeys.HostHeader: hostKey,
            String.HeaderKeys.IsTestApp: isDevEnv ? "1" : "0",
            String.HeaderKeys.UUIDHeader: UIDevice.current.identifierForVendor!.uuidString,
        ]
        return headers
    }

    private func retrievePath(isDev: Bool) -> String {
        if isDevEnv {
            return EndPoints.DevEndpoint
        } else {
            return EndPoints.ProdEndpoint
        }
    }

    /**
     Retrieves a user attributes and affiliated apps.
     - Returns: Closure containing client/user information.
     */
    public func postLogin(email: String, password: String, completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        let path = "\(EndPoints.Login)"
        let body: [String: Any] = [
            String.ConfigKeys.Email: email,
            String.ConfigKeys.Password: password,
        ]
      
        callServer(path: path, httpMethod: String.HTTPMethod.POST, body: body as Dictionary<String, AnyObject>, verifyAppEnable: false) { parsedJSON, err in
            guard err == nil else {
                completionHandler(nil, err)
                return
            }

            os_log("[Branddrop] :: login: %s", parsedJSON.debugDescription)
            completionHandler(parsedJSON, nil)
            // since login requires email, update user after email is given
            DispatchQueue.main.async {
                Branddrop.client.editUser(attributes: Attributes(fromDictionary: ["stock": ["email": email]]), httpMethod: String.HTTPMethod.PUT)
            }
          
            return
        }
    }

    /**
     Associates a particular device with a user's account.
     - Returns: Closure containing a user's attributes.
     */
    public func registerDevice(completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        let path = "\(EndPoints.Me)"

        let body: [String: Any] = [
            String.ConfigKeys.Email: Branddrop.client.userDefaults?.object(forKey: String.ConfigKeys.Email) as Any,
            String.HeaderKeys.DeviceOSHeader: String.HeaderValues.iOS,
            String.HeaderKeys.DeviceOSVersionHeader: String.HeaderValues.DeviceOSVersion,
        ]

        callServer(path: path, httpMethod: String.HTTPMethod.PUT, body: body, verifyAppEnable: false) { parsedJSON, err in
            guard err == nil else {
                completionHandler(nil, err)
                return
            }

            Branddrop.client.userDefaults?.set(true, forKey: String.ConfigKeys.DeviceRegistered)
            completionHandler(parsedJSON, nil)
            return
        }
    }

    /**
     Creates an Event using the information provided and then logs said Event to the Branddrop server.

     - Parameter name: `String`
     - Parameter messageId: `String` The value associated with the key "messageId" in notifications.
     - Parameter firebaseNotificationId: `String` The value associated with key "gcm.message_id" in notifications.
     */
    public func postEvent(name: String, messageId: String, firebaseNotificationId: String, notificationId: String, completionHandler: (() -> Void)? = nil) {
        let path = "\(EndPoints.Events)"

        let body: [String: Any] = [
            String.EventKeys.EventName: name,
            String.EventKeys.MessageId: messageId,
            String.EventKeys.FirebaseNotificationId: firebaseNotificationId,
            String.EventKeys.NotificationId: notificationId
//            String.EventKeys.Inbox: ["": ""],
        ]
        
        print("body: \(body)")

        callServer(path: path, httpMethod: String.HTTPMethod.POST, body: body) { _, err in
            guard err == nil else {
                if completionHandler != nil {
                    completionHandler!()
                }
                return
            }
            if completionHandler != nil {
                completionHandler!()
            }
        }
    }

    /**
     Derives a latitude and longitude from the location parameter, couples the coordinate with an iso8601 formatted date, and then updates the server and database with user's timestamped location.

     - Parameter location: `CLLocation`
     */
    public func postLocation(location: CLLocation) {
        let body: [String: Any] = [
            String.NetworkCallRelated.Latitude: location.coordinate.latitude,
            String.NetworkCallRelated.Longitude: location.coordinate.longitude,
            String.NetworkCallRelated.DeviceTime: Date().iso8601 as AnyObject,
        ]
        print("calling post location................................")
        callServer(path: EndPoints.Locations, httpMethod: String.HTTPMethod.POST, body: body) { parsedJSON, err in
            guard err == nil else {
                return
            }
        }
    }

    /**
     A means of updating the user's associated attributes.

     - Parameter attributes: `Attributes` An instance of the `Attributes` class. Include only those keys whose values you intend to edit.
     - Parameter httpMethod: `String` Either `String.HTTPMethod.POST` ("POST") or `String.HTTPMethod.PUT` ("PUT").
      */
    public func editUser(attributes: Attributes, httpMethod: String) {
      
        let path = "\(EndPoints.Me)"

        let body: [String: Any] = [
            String.Attribute.Attrs: [
                String.Attribute.Stock: attributes.toDictionary()[String.Attribute.Stock],
                String.Attribute.Custom: attributes.toDictionary()[String.Attribute.Custom],
            ] as AnyObject,
        ]

        callServer(path: path, httpMethod: httpMethod, body: body) { parsedJSON, err in
            guard err == nil else {
                // Handle Error
                return
            }
          
            os_log("\n[Branddrop] :: editUser: %s\n", parsedJSON.debugDescription)
        }
    }
    
    /**
        A method to get the list of geofence location.
     */
    public func downloadGeofenceLocation(completionHandler: @escaping ([String: Any]?, Error?) -> Void) {
        if Branddrop.client.currentLocation.coordinate.latitude != 0 && Branddrop.client.currentLocation.coordinate.longitude != 0 {
            print("Branddrop.client.currentLocation: \(Branddrop.client.currentLocation.coordinate.latitude), \(Branddrop.client.currentLocation.coordinate.longitude)")
            //        let path = "\(EndPoints.GeoFenceLocation)?limit=10"
            let path = "\(EndPoints.GeoFenceLocation)"
            let body: [String: Any] = [
                String.NetworkCallRelated.Latitude: "\(Branddrop.client.currentLocation.coordinate.latitude)",
                String.NetworkCallRelated.Longitude: "\(Branddrop.client.currentLocation.coordinate.longitude)",
                String.NetworkCallRelated.Radius: recordLocationAfterMeters*2,
            ]
            callServer(path: path, httpMethod: String.HTTPMethod.POST, body: body as Dictionary<String, AnyObject>, verifyAppEnable: false) { parsedJSON, err in
                guard err == nil else {
                    completionHandler(nil, err)
                    return
                }
                completionHandler(parsedJSON, nil)
                print(parsedJSON)
            }
        }
    }

    /**
     Creates a `URLSession` given the parameters provided and returns a completion handler containing either a `Dictionary` of the parsed, returned JSON, or an error.

     - Parameter path:  String The path the `URLSession` calls.
     - Parameter httpMethod: String Corresponding `HTTPMethod`
     - Parameter body: [String:Any] Dictionary of what will become the `URLRequest`'s body.
     - Parameter completionHandler: [String: Any]?
     */
    public func callServer(path: String, httpMethod: String, body: [String: Any], verifyAppEnable: Bool = true, completionHandler:
        @escaping ([String: Any]?, Error?) -> Void) {
        if (verifyAppEnable && !isAppEnable) {
            print("App is disable")
            completionHandler(nil, BAKitError.appDisable)
            return
        }
        
        let destination = retrievePath(isDev: isDevEnv) + path
        let parameters = body as [String: Any]
        var bodyData = Data()

        do {
            try bodyData = JSONSerialization.data(withJSONObject: parameters, options: [])
        } catch {
            print("[Branddrop] :: callServer :: bodyData serialization error.")
        }

        let request = NSMutableURLRequest(url: NSURL(string: destination)! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)

        guard let headers = getHeaders(), !headers.isEmpty else {
            os_log("[BA:client:callServer] :: NSMutableURLRequest:headers :: %s", getHeaders()?.debugDescription ?? "Empty Headers")
            return
        }

        request.allHTTPHeaderFields = headers
        request.httpMethod = httpMethod

        if path == EndPoints.Me && httpMethod == String.HTTPMethod.GET {
            request.httpBody = nil
        } else {
            request.httpBody = bodyData as Data
        }

        let session = URLSession.shared

        let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
            guard error == nil, let _ = response as? HTTPURLResponse else {
                os_log("[BA:client:callServer] :: dataTask:error : %s", error!.localizedDescription)
                return
            }

            if let data = data, (try? JSONSerialization.jsonObject(with: data)) != nil {
                if let dataString = String(data: data, encoding: .utf8) {
                    os_log("[BA:client:callServer] :: dataString : %@", dataString)

                    completionHandler(Branddrop.client.convertToDictionary(text: dataString), nil)
                    return
                }
            }
        })
        dataTask.resume()
    }

    public func callServer(forList path: String, httpMethod: String, body: [String: Any], verifAppEnable: Bool = true, completionHandler:@escaping ([[String: Any]]?, Error?) -> Void) {
        if (verifAppEnable && !isAppEnable) {
            print("App is disable")
            completionHandler(nil, BAKitError.appDisable)
            return
        }
        
          let destination = retrievePath(isDev: isDevEnv) + path
          let parameters = body as [String: Any]

          let request = NSMutableURLRequest(url: NSURL(string: destination)! as URL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60.0)

          guard let headers = getHeaders(), !headers.isEmpty else {
              os_log("[BA:client:callServer] :: NSMutableURLRequest:headers :: %s", getHeaders()?.debugDescription ?? "Empty Headers")
              return
          }
          request.allHTTPHeaderFields = headers
          request.httpMethod = httpMethod
          let session = URLSession.shared

          let dataTask = session.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) -> Void in
              guard error == nil, let _ = response as? HTTPURLResponse else {
                  os_log("[BA:client:callServer] :: dataTask:error : %s", error!.localizedDescription)
                  return
              }

              if let data = data, (try? JSONSerialization.jsonObject(with: data)) != nil {
                  if let dataString = String(data: data, encoding: .utf8) {
                      os_log("[BA:client:callServer] :: dataString : %@", dataString)

                      completionHandler(Branddrop.client.convertToDictionary(ofArray: dataString), nil)
                      return
                  }
              }
          })
          dataTask.resume()
      }
      
    func convertToDictionary(ofArray text: String) -> [[String: Any]]? {
           if let data = text.data(using: .utf8) {
               do {
                   return try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
               } catch {
                   print(error.localizedDescription)
               }
           }
           return nil
       }
    
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    //Find and update the location permission and notification permission in the backend.
       @objc public func updatePermissionStates() {
           var locationSharingEnable = false
           let center = UNUserNotificationCenter.current()

           if CLLocationManager.locationServicesEnabled() {
                switch CLLocationManager.authorizationStatus() {
                   case .notDetermined, .restricted, .denied:
                       locationSharingEnable = false

                   case .authorizedAlways, .authorizedWhenInUse:
                       locationSharingEnable = true
                   default:
                       locationSharingEnable = false
               }
           }

           center.getNotificationSettings { (settings) in
               var notificationPermission = false
               if(settings.authorizationStatus == .authorized) {
                   notificationPermission = true

               } else {
                   notificationPermission = false
               }
               let dictPara: [String: Any] = ["notificationPermission": notificationPermission,
                                              "locationPermission": locationSharingEnable]
               let body =  ["attributes" : ["stock": dictPara]]
               Branddrop.client.updateUserData(body: body) { (response, error) in
                 print(response as Any)
               }
           }
       }
    
    /**
     Function remove save user locations.
     */
    public func removeSaveUserLocations() {
        userDefaults?.set(nil, forKey: String.ConfigKeys.userLocations)
    }
    
    public func removeTraveledDistance() {
        userDefaults?.set(nil, forKey: String.ConfigKeys.traveledDistance)
    }
    
    /**
     Function save device location locally.
     */
    private func saveLocationLocally(location: CLLocation) {
        if let locationList = userDefaults?.value(forKey: String.ConfigKeys.userLocations) as? [[String: Double]] {
            var arrLocations = locationList
            arrLocations.append(formatLocation(location: location)!)
            userDefaults?.set(arrLocations, forKey: String.ConfigKeys.userLocations)
        } else {
            let arrLocation = [formatLocation(location: location)]
            userDefaults?.set(arrLocation, forKey: String.ConfigKeys.userLocations)
        }
    }
    
    /**
     Function formats the location and returns the dictionary.
     - Returns: Dictionary which contains latitued and longitude in dictionary format.
     */
    private func formatLocation(location: CLLocation) -> Dictionary<String, Double>? {
        return [String.NetworkCallRelated.Latitude: location.coordinate.latitude, String.NetworkCallRelated.Longitude: location.coordinate.longitude]
    }
    
    /**
     Function download and save image in Photo Gallery.
     */
    public func downloadAndSaveImageDownloadFromPush(_ vc: UIViewController, _ strUrl: String) {
        let alert = UIAlertController(title: "Do you want to download the image?", message:"", preferredStyle: UIAlertController.Style.alert)
        // add an action (button)
        alert.addAction(UIAlertAction(title: "Yes", style: UIAlertAction.Style.default) { (action) in
//            let strUrl = (userInfo["imageUrl"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            if let url = URL(string: strUrl) {
                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    guard let data = data, error == nil else { return }
                        UIImageWriteToSavedPhotosAlbum(UIImage(data: data)!, nil, nil, nil)
                }
                task.resume()
            } else {
                print(strUrl + " is invalid")
            }
        })
        alert.addAction(UIAlertAction(title: "No", style: .destructive))
        // show the alert
        vc.present(alert, animated: true, completion: nil)
    }
}

//Method to handle geofence feature
extension Branddrop {
    public func storeAppLocations() {
        if (userDefaults?.value(forKey: String.ConfigKeys.geoFenceLocations) == nil) {
            downloadGeofenceLocation { [self] response, error in
                if let arrLocations = response?["data"] as? [[String : Any]], error == nil {
                    var locationList: [[String: Any]] = []
                    /*
//                    for location in arrLocations {
//                        let geoFenceLocation = ["longitude":(location["coordinates"] as? [[String: Any]])?.first?["longitude"] ?? "", "latitude":(location["coordinates"] as? [[String: Any]])?.first?["latitude"] ?? "", "locationId": location["id"]!, "radius": location["radius"] as? Int ?? 100, "lastNotificationDate":""] as [String: Any]
//                        locationList.append(geoFenceLocation)
//                    }
                    for location in arrLocations {
                        let coordinatesArr: [[String: Any]] = location["coordinates"] as? [[String: Any]] ?? []
                        for coord in coordinatesArr {
                            let geoFenceLocation = ["longitude":coord["longitude"] ?? "", "latitude":coord["latitude"] ?? "", "locationId": location["id"]!, "radius": location["radius"] as? Int ?? 100, "lastNotificationDate":"", "placeName":location["placeName"] ?? ""] as [String: Any]
                            locationList.append(geoFenceLocation)
                        }
                    } */
                    self.removeGeofenceLocations()
                    for location in arrLocations {
                        let coordinatesArr: [[String: Any]] = location["coordinates"] as? [[String: Any]] ?? []
                        if coordinatesArr.count > 1 {
                            var polygon = [CGPoint]()
                            for coord in coordinatesArr {
                                let lat = coord["latitude"] is String ? (coord["latitude"] as! NSString).doubleValue : Double(truncating: coord["latitude"] as! NSNumber)
                                let long = coord["longitude"] is String ? (coord["longitude"] as! NSString).doubleValue : Double(truncating: coord["longitude"] as! NSNumber)
                                let point = CGPoint(x: lat, y: long)
                                polygon.append(point)
                            }
                            let center = polygonCenterOfMass(polygon: polygon)
                            var disArr = [CGFloat]()
                            for coord in coordinatesArr {
                                let lat = coord["latitude"] is String ? (coord["latitude"] as! NSString).doubleValue : Double(truncating: coord["latitude"] as! NSNumber)
                                let long = coord["longitude"] is String ? (coord["longitude"] as! NSString).doubleValue : Double(truncating: coord["longitude"] as! NSNumber)
                                disArr.append(CLLocation(latitude: lat, longitude: long).distance(from: CLLocation(latitude: center.x, longitude: center.y)))
                            }
                            let geoFenceLocation = ["latitude":"\(center.x)", "longitude":"\(center.y)", "locationId": location["id"]!, "radius": disArr.max() ?? 100, "lastNotificationDate":"", "placeName":location["placeName"] ?? ""] as [String: Any]
                            locationList.append(geoFenceLocation)
                        } else {
                            let coord = coordinatesArr.first
                            let geoFenceLocation = ["longitude":coord?["longitude"] ?? "", "latitude":coord?["latitude"] ?? "", "locationId": location["id"]!, "radius": location["radius"] as? Int ?? 100, "lastNotificationDate":"", "placeName":location["placeName"] ?? ""] as [String: Any]
                            locationList.append(geoFenceLocation)
                        }
                    }
                    print("\n------------\nlocationList\n-----------\n\(locationList)\n------------\n")
                    self.userDefaults?.set(locationList, forKey: String.ConfigKeys.geoFenceLocations)
                    self.setupRegion()
                } else {
                    os_log("\n[Branddrop] downloadGeofenceLocation :: Error: Not able to fetch geofence location = %s.\n", error?.localizedDescription ?? "")
                    return
                }
            }
        } else {
            setupRegion()
        }
    }
    
    func signedPolygonArea(polygon: [CGPoint]) -> CGFloat {
        let nr = polygon.count
        var area: CGFloat = 0
        for i in 0 ..< nr {
            let j = (i + 1) % nr
            area = area + polygon[i].x * polygon[j].y
            area = area - polygon[i].y * polygon[j].x
        }
        area = area/2.0
        return area
    }

    func polygonCenterOfMass(polygon: [CGPoint]) -> CGPoint {
        let nr = polygon.count
        var centerX: CGFloat = 0
        var centerY: CGFloat = 0
        var area = signedPolygonArea(polygon: polygon)
        for i in 0 ..< nr {
            let j = (i + 1) % nr
            let factor1 = polygon[i].x * polygon[j].y - polygon[j].x * polygon[i].y
            centerX = centerX + (polygon[i].x + polygon[j].x) * factor1
            centerY = centerY + (polygon[i].y + polygon[j].y) * factor1
        }
        area = area * 6.0
        let factor2 = 1.0/area
        centerX = centerX * factor2
        centerY = centerY * factor2
        let center = CGPoint.init(x: centerX, y: centerY)
        return center
    }
    
    private func setupRegion() {
        if let geofenceLocations = userDefaults?.value(forKey: String.ConfigKeys.geoFenceLocations) as? [[String: Any]] {
            let arrFilterLocation = geofenceLocations.filter { location in
                if let notifyDate = location["lastNotificationDate"] as? Date {
                    return (Date().timeIntervalSince(notifyDate) > geofenceNotifyTimeLimit)
                } else {
                    return true
                }
            }
            
            for (index, geoFenceLocation) in arrFilterLocation.enumerated() {
                let location = Location.init(fromDictionary: geoFenceLocation)
                if (index>=20) {
                    break
                }
                createGeoFence(location: location)
            }
            print(geofenceLocations)
        }
    }
    
    func createGeoFence(location: Location) {
        if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            print("Geofence not supported.")
            return
         }
        let region = CLCircularRegion(
            center: CLLocationCoordinate2DMake(location.latitude ?? 0.0, location.longitude ?? 0.0),
            radius: CLLocationDistance(location.radius ?? geofenceRadius),
            identifier: location.locationId!)

        region.notifyOnEntry = true
        region.notifyOnExit = false
        locationManager.requestAlwaysAuthorization()
        locationManager.startMonitoring(for: region)
    }
    
    public func stopMonitoring(region: CLRegion) {
        guard
          let circularRegion = region as? CLCircularRegion
        else { return }
        locationManager.stopMonitoring(for: circularRegion)
        print("geoFenceLocations: ", userDefaults?.value(forKey: String.ConfigKeys.geoFenceLocations) as? [[String: Any]])
        if let geofenceLocations = userDefaults?.value(forKey: String.ConfigKeys.geoFenceLocations) as? [[String: Any]] {
            var arrLocations = geofenceLocations
            for (index, geoFenceLocation) in arrLocations.enumerated() {
                var location = Location.init(fromDictionary: geoFenceLocation)
                if (location.locationId == circularRegion.identifier) {
                    location.lastNotificationDate = Date()
                    arrLocations[index] = location.toDictionary()
                    userDefaults?.set(arrLocations, forKey: String.ConfigKeys.geoFenceLocations)
                    break
                }
            }
            storeAppLocations()
            postLocation(location: CLLocation(latitude: circularRegion.center.latitude, longitude: circularRegion.center.longitude))
            print("geofenceLocations: ", geofenceLocations)
        }
    }
    
    public func removeGeofenceLocations() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        userDefaults?.set(nil, forKey: String.ConfigKeys.geoFenceLocations)
    }
}
