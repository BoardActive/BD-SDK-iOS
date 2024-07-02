//
//  NotificationViewController.swift
//  Content Extension
//
//  Created by Ed Salter on 8/5/19.
//  Copyright © 2019 Branddrop. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var mainNotificationImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
    }
    
    func didReceive(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo as! [String:Any]
        if let urlString = userInfo["imageUrl"] as? String, !urlString.isEmpty {
//            DispatchQueue.main.async {
                self.mainNotificationImageView.loadImageUsingCache(withUrl: urlString)
//            }
        }
    }
}

public let imageCache = NSCache<NSString, AnyObject>()

public extension UIImageView {
    func loadImageUsingCache(withUrl urlString: String) {
        let url = URL(string: urlString)
        image = nil
        
        // check cached image
        if let cachedImage = imageCache.object(forKey: urlString as NSString) as? UIImage {
            image = cachedImage
            return
        }
        
        // if not, download image from url
        URLSession.shared.dataTask(with: url!, completionHandler: { data, _, error in
            if error != nil {
                return
            }
            
            DispatchQueue.main.async {
                if let image = UIImage(data: data!) {
                    imageCache.setObject(image, forKey: urlString as NSString)
                    self.image = image
                }
            }
            
        }).resume()
    }
}
