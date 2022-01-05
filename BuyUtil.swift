import StoreKit
class BuyUtil:NSObject, ObservableObject,SKProductsRequestDelegate, SKPaymentTransactionObserver{
    class BuyLister {
        var getList:(([SKProduct])->Void)!
        var onComplete:(()->Void)!
        var onRestore:(()->Void)!
        var onError:((String)->Void)!
    }
    var productIDs: [String] = [String]() // 產品ID(Consumable_Product、Not_Consumable_Product)
    var productsArray: [SKProduct] = [SKProduct]() //  存放 server 回應的產品項目
    var selectedProductIndex: Int! // 點擊到的購買項目
    var isProgress: Bool = false // 是否有交易正在進行中
    var vc:UIViewController? = nil
    var lister:BuyLister? = nil
    init(_ pIDs:[String],_ vc:UIViewController){
        self.productIDs = pIDs
        self.vc = vc
    }
    func setLister(_ lister:BuyLister){
        self.lister = lister
    }
    // 發送請求以用來取得內購的產品資訊
    func requestProductInfo() {
        if SKPaymentQueue.canMakePayments() {
            // 取得所有在 iTunes Connect 所建立的內購項目
            let productIdentifiers: Set<String> = NSSet(array: self.productIDs) as! Set<String>
            let productRequest: SKProductsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
            
            productRequest.delegate = self
            productRequest.start() // 開始請求內購產品
        } else {
            lister?.onError("取不到任何內購的商品...")
        }
    }
    
    // 取消按鈕
    @IBAction func goCancel(_ sender: Any) {
        lister?.onError("取消交易")
    }
    
    // 回復購買
    @IBAction func goRestore(_ sender: Any) {
        //self.showActionSheet(.restore)
        debugPrint("goRestore")
    }
    
    // 接收到產品請求的回應
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        // invalidProductIdentifiers.description 會印出不合法的內購項目，例如：沒有設定價錢、已停用的等等
        debugPrint("invalidProductIdentifiers： \(response.invalidProductIdentifiers.description)")
        // 產品陣列(SKProduct)，裡面包含著在iTunes Connect所建立的該 APP 的所有內購項目
        if response.products.count != 0 {
            // 將取得的 IAP 產品放入 tableView 裡
            for product in response.products {
                self.productsArray.append(product)
            }
            lister?.getList(self.productsArray)
        }
        else {
            lister?.onError("取不到任何商品...")
        }
    }
    
    // 購買、復原成功與否的 protocol
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // 送出購買則會 update 一次，購買成功 server 又會回傳一次 update
        for transaction in transactions {
            switch transaction.transactionState {
            case SKPaymentTransactionState.purchased:
                debugPrint("交易成功...")
                // 必要的機制
                SKPaymentQueue.default().finishTransaction(transaction)
                self.isProgress = false
                
                // 移除觀查者
                SKPaymentQueue.default().remove(self)
                
                hideloading()
                lister?.onComplete()
            case SKPaymentTransactionState.failed:
                debugPrint("交易失敗...")
                
                if let error = transaction.error as? SKError {
                    switch error.code {
                    case .paymentCancelled:
                        // 輸入 Apple ID 密碼時取消
                        lister?.onError("交易取消: \(error.localizedDescription)")
                    case .paymentInvalid:
                        lister?.onError("交易付款無效: \(error.localizedDescription)")
                    case .paymentNotAllowed:
                        lister?.onError("交易付款不允許: \(error.localizedDescription)")
                    default:
                        lister?.onError("交易: \(error.localizedDescription)")
                    }
                }
                
                SKPaymentQueue.default().finishTransaction(transaction)
                self.isProgress = false
            case SKPaymentTransactionState.restored:
                debugPrint("復原成功...")
                // 必要的機制
                SKPaymentQueue.default().finishTransaction(transaction)
                self.isProgress = false
                hideloading()
                lister?.onRestore()
            default:
                debugPrint(transaction.transactionState.rawValue)
            }
        }
    }
    
    // 詢問是否購買或回復的 Action Sheet
    func showActionSheet(_ product: SKProduct,_ isrestore:Bool) {
        // 代表有購買項目正在處理中
        if self.isProgress {
            return
        }
        
        var message: String!
        var buyAction: UIAlertAction?
        var restoreAction: UIAlertAction?
        
        if(isrestore){
            message = "確定訂閱商品？"
            buyAction = UIAlertAction(title: "訂閱", style: UIAlertAction.Style.default) { (action) -> Void in
                                
                if SKPaymentQueue.canMakePayments() {
                    // 設定交易流程觀察者，會在背景一直檢查交易的狀態，成功與否會透過 protocol 得知
                    SKPaymentQueue.default().add(self)
                    
                    // 取得內購產品
                    let payment = SKPayment(product: product)
                    
                    // 購買消耗性、非消耗性動作將會開始在背景執行(updatedTransactions delegate 會接收到兩次)
                    SKPaymentQueue.default().add(payment)
                    self.isProgress = true
                    
                    // 開始執行購買產品的動作
                    self.showloading()
                }
            }
        }else{
            // 復原購買產品
            message = "是否回復？"
            restoreAction = UIAlertAction(title: "回復", style: UIAlertAction.Style.default) { (action) -> Void in
                if SKPaymentQueue.canMakePayments() {
                    SKPaymentQueue.default().restoreCompletedTransactions()
                    self.isProgress = true
                    
                    // 開始執行回復購買的動作
                    self.showloading()
                }
            }
        }
        
        // 產生 Action Sheet
        let actionSheetController = UIAlertController(title: product.localizedTitle, message: message, preferredStyle: UIAlertController.Style.actionSheet)
        
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertAction.Style.cancel, handler: nil)
        
        actionSheetController.addAction(buyAction != nil ? buyAction! : restoreAction!)
        actionSheetController.addAction(cancelAction)
        
        vc!.present(actionSheetController, animated: true, completion: nil)
    }
    
    // 復原購買失敗
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        debugPrint("復原購買失敗...")
        lister?.onError(error.localizedDescription)
    }

    // 回復購買成功(若沒實作該 delegate 會有問題產生)
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        debugPrint("復原購買成功...")
    }
    
    func showloading(){
        DispatchQueue.main.async {
            let indicator = UIActivityIndicatorView(frame: self.vc!.view.bounds)
            indicator.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            indicator.tag = 11223344

            self.vc!.view.addSubview(indicator)
            indicator.isUserInteractionEnabled = false
            indicator.startAnimating()
        }
    }
    
    func hideloading(){
        DispatchQueue.main.async {
            let existingView = self.vc!.view.viewWithTag(11223344)
            existingView?.removeFromSuperview()
        }
    }
}
