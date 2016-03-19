//
//  IAPManager.swift
//  AKPurchase
//
//  Created by AbhishekKumar on 02/02/16.
//  Copyright © 2016 Abhishek. All rights reserved.
//

import UIKit
import StoreKit

typealias FetchCompletionHandler = (Bool, [SKProduct]?) -> ()
typealias PurchaseCompletionHandler = (Bool, String?) -> ()

class IAPManager: NSObject {

  static let sharedInstance: IAPManager = {
    let instance = IAPManager()
    return instance
  }()

  lazy var fetchHandler: FetchCompletionHandler = { success, products in
    if !success {
      self.purchaseHandler?(false, "fetch not successful")
    } else if let products = products where products.count > 0 {
      let payment = SKPayment(product: products[0])
      SKPaymentQueue.defaultQueue().addPayment(payment)
    } else {
      self.purchaseHandler?(false, "No products to purchase")
    }
  }
  private var purchaseHandler: PurchaseCompletionHandler?
}

//MARK: - Notification Methods
extension IAPManager {
  func appDidAddPaymentObserver(notif: NSNotification) {
    SKPaymentQueue.defaultQueue().addTransactionObserver(self)
  }

  func appWillRemovePaymentObserver(notif: NSNotification) {
    SKPaymentQueue.defaultQueue().removeTransactionObserver(self)
  }
}

//MARK: - Public Methods
extension IAPManager {
  /**
   Call this method on IAPManager sharedInstance to make an In App Purchase.
   
   - parameter products: Set of products which have to be purchased. Configured in iTunes Connect portal.
   - parameter purchaseCompletionHandler: Completion handler which will be called in case of success and failure as applicable with a reason.
   */
  func purchaseProducts(products: Set<String>, purchaseCompletionHandler: PurchaseCompletionHandler) {
    if SKPaymentQueue.canMakePayments() {
      let productsRequest = SKProductsRequest(productIdentifiers: products)
      purchaseHandler = purchaseCompletionHandler
      productsRequest.delegate = self
      productsRequest.start()
    } else {
      purchaseCompletionHandler(false, "User is not authorised")
    }
  }
  
  /**
   Call this method on IAPManager sharedInstance to restore an In App Purchase.
   
   - parameter purchaseCompletionHandler: Completion handler which will be called in case of success and failure as applicable with a reason.
   */
  func restorePurchasedTransaction(purchaseCompletionHandler: PurchaseCompletionHandler)  {
    purchaseHandler = purchaseCompletionHandler
    SKPaymentQueue.defaultQueue().restoreCompletedTransactions()
  }
}

//MARK: - SKRequestDelegate Methods
extension IAPManager: SKRequestDelegate {
  func requestDidFinish(request: SKRequest) {
    print("Finished loading Products")
  }

  func request(request: SKRequest, didFailWithError error: NSError) {
    fetchHandler(false, nil)
  }
}

//MARK: - SKProductsRequestDelegate Methods
extension IAPManager: SKProductsRequestDelegate {
  func productsRequest(request: SKProductsRequest, didReceiveResponse response: SKProductsResponse) {
    fetchHandler(true, response.products)
  }
}

//MARK: - SKPaymentTransactionObserver Methods
extension IAPManager: SKPaymentTransactionObserver {
  func paymentQueue(queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .Deferred:
        print("Waiting for user action")
      case .Purchasing:
        print("Purchasing")
      case .Purchased:
        print("Purchased")
        completeTransaction(transaction)
      case .Restored:
        print("Restored")
        restoreTransaction(transaction)
      case .Failed:
        print("Failed")
        failedTransaction(transaction)
      }
    }
  }

  func paymentQueueRestoreCompletedTransactionsFinished(queue: SKPaymentQueue) {
    if queue.transactions.count > 0 {
      let transaction = queue.transactions[0] // When handling only 1 product
      purchaseHandler?(true, transaction.payment.productIdentifier)
      finishTransaction(transaction)
    } else {
      purchaseHandler?(false, nil)
    }
  }

  func paymentQueue(queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: NSError) {
    purchaseHandler?(false, nil)
    if queue.transactions.count > 0 {
      let transaction = queue.transactions[0]
      finishTransaction(transaction)
    }
  }
}

//MARK: - Helper Methods
extension IAPManager {
  /**
   This method is called when the transaction results in a success
   
   - parameter transaction: Transaction which resulted in success.
   */
  private func completeTransaction(transaction: SKPaymentTransaction) {
    purchaseHandler?(true, transaction.payment.productIdentifier)
    finishTransaction(transaction)
  }

  /**
   This method is called when the transaction results in a failure.
   
   - parameter transaction: Transaction which resulted in Failure.
   */
  private func failedTransaction(transaction: SKPaymentTransaction) {
    purchaseHandler?(false, transaction.error?.localizedDescription)
    finishTransaction(transaction)
  }

  /**
   This method is called when the transaction is restored.
   
   - parameter transaction: Transaction which was restored.
   */
  private func restoreTransaction(transaction: SKPaymentTransaction) {
    purchaseHandler?(true, transaction.payment.productIdentifier)
    finishTransaction(transaction)
  }

  
  private func finishTransaction(transaction: SKPaymentTransaction) {
    SKPaymentQueue.defaultQueue().finishTransaction(transaction)
    purchaseHandler = nil
  }
  
  /**
   Fetch the receipt Data which was saved locally on the device.
   
   - returns: Data in raw format for the in app purchase receipt.
   */
  private func receiptData() -> NSData? {
    if let appStoreReceiptURL = NSBundle.mainBundle().appStoreReceiptURL {
      let data = NSData(contentsOfURL: appStoreReceiptURL)
      return data
    }
    return nil
  }
  
  /**
   Call this method to validate the In App Purchase from Apple Server.
   
   - returns: Block which resulted in success or failure.
   */
//  func locallyValidateReceipt() {
//    if let receiptData = receiptData() {
//      if let appleRootURL = NSBundle.mainBundle().URLForResource("AppleIncRootCertificate", withExtension: "cer"), let appleRootData = NSData(contentsOfURL: appleRootURL) {
//        
//      }
//    }
//  }
  
  private func receiptData(appStoreReceiptURL : NSURL?) -> NSData? {
    guard let receiptURL = appStoreReceiptURL, receipt = NSData(contentsOfURL: receiptURL)
      else {
        return nil
    }
    do {
      let receiptData = receipt.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
      let requestContents = ["receipt-data" : receiptData]
      let requestData = try NSJSONSerialization.dataWithJSONObject(requestContents, options: [])
      return requestData
    }
    catch let error as NSError {
      print(error)
    }
    return nil
  }
  
  private func validateReceiptInternal(appStoreReceiptURL : NSURL?, isProd: Bool , onCompletion: (Int?) -> Void) {
    
    let serverURL = isProd ? "https://buy.itunes.apple.com/verifyReceipt" : "https://sandbox.itunes.apple.com/verifyReceipt"
    
    guard let receiptData = receiptData(appStoreReceiptURL),
      url = NSURL(string: serverURL)  else {
        onCompletion(nil)
        return
    }
    
    let request = NSMutableURLRequest(URL: url)
    request.HTTPMethod = "POST"
    request.HTTPBody = receiptData
    
    let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: {data, response, error -> Void in
      guard let data = data where error == nil else {
        onCompletion(nil)
        return
      }
      do {
        let json = try NSJSONSerialization.JSONObjectWithData(data, options:[])
        print(json)
        guard let statusCode = json["status"] as? Int else {
          onCompletion(nil)
          return
        }
        onCompletion(statusCode)
      }
      catch let error as NSError {
        print(error)
        onCompletion(nil)
      }
    })
    task.resume()
  }
  
  internal func validateReceipt(appStoreReceiptURL : NSURL?, onCompletion: (Bool) -> Void) {
    
    validateReceiptInternal(appStoreReceiptURL, isProd: true) { (statusCode: Int?) -> Void in
      guard let status = statusCode else {
        onCompletion(false)
        return
      }
      
      // This receipt is from the test environment, but it was sent to the production environment for verification.
      if status == 21007 {
        self.validateReceiptInternal(appStoreReceiptURL, isProd: false) { (statusCode: Int?) -> Void in
          guard let statusValue = statusCode else {
            onCompletion(false)
            return
          }
          
          // 0 if the receipt is valid
          if statusValue == 0 {
            onCompletion(true)
          } else {
            onCompletion(false)
          }
        }
        // 0 if the receipt is valid
      } else if status == 0 {
        onCompletion(true)
      } else {
        onCompletion(false)
      }
    }
  }
}

extension IAPManager {
  func initiateRefresh () {
    if let _ = receiptData() {
      
    } else {
      let refreshReceiptRequest = SKReceiptRefreshRequest(receiptProperties: nil)
      refreshReceiptRequest.delegate = self
      refreshReceiptRequest.start()
    }
  }
}
