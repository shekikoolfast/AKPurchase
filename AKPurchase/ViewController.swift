//
//  ViewController.swift
//  AKPurchase
//
//  Created by AbhishekKumar on 02/02/16.
//  Copyright © 2016 Abhishek. All rights reserved.
//

import UIKit
import StoreKit

class ViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
//    "org.vidya.inapp.item1"
    IAPManager.sharedInstance.purchaseProducts(["org.vidya.inapp.item1"]) { (success, message) -> () in
      print(success)
      print(message)
    }
  }

  func useStore() {
    let storeVC = SKStoreProductViewController()
    storeVC.delegate = self
    let numberFormatter = NSNumberFormatter()
    numberFormatter.numberStyle = .DecimalStyle
//    364709193 for iBooks
//    1084276368 for the app
    if let number = numberFormatter.numberFromString("364709193") {
      storeVC.loadProductWithParameters([SKStoreProductParameterITunesItemIdentifier: number], completionBlock: { [weak self] (success, error) -> Void in
        self?.presentViewController(storeVC, animated: true, completion: nil)
      })
    }
  }
}

extension ViewController: SKStoreProductViewControllerDelegate {
  func productViewControllerDidFinish(viewController: SKStoreProductViewController) {
    viewController.dismissViewControllerAnimated(true, completion: nil)
  }
}