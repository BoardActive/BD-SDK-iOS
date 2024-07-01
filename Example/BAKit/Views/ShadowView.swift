//
//  ShadowView.swift
//  BrandDrop
//
//  Created by Ed Salter on 8/2/19.
//  Copyright © 2019 BoardActive. All rights reserved.
//

import UIKit
import MaterialComponents

class ShadowView: UIView {
    override class var layerClass: AnyClass {
        return MDCShadowLayer.self
    }
    
    var shadowLayer: MDCShadowLayer {
        return self.layer as! MDCShadowLayer
    }
    
    func setDefaultElevation() {
        self.shadowLayer.elevation = .cardResting
    }
    /*
     // Only override draw() if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func draw(_ rect: CGRect) {
     // Drawing code
     }
     */
    
}

