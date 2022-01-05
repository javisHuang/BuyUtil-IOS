# BuyUtil-IOS
IOS In-app Billing Class

```Swift
var productIDs: [String] = [String]() //商品資料
productIDs.append("product1")
productIDs.append("product2")
productIDs.append("product3")
productIDs.append("product4")
productIDs.append("product5")
let b = BuyUtil.init(productIDs,self )
let buylister = BuyUtil.BuyLister()
//取得所有商品資料
buylister.getList = {sks in
    b.hideloading()
    DispatchQueue.main.async {
        //自訂顯示在UI上的所有商品
        self.ShowOrder2CCVC.setPd(sks)
    }
}
//購買流程結束後
buylister.onComplete = {
    DispatchQueue.main.async {
        UIApplication.shared.keyWindow?.showToast(text: "訂閱成功")
    }
}
//購買回復時
buylister.onRestore = {

}
//購買流程發生異常時
buylister.onError = {msg in
    b.hideloading()
    DispatchQueue.main.async {
        UIApplication.shared.keyWindow?.showToast(text: msg)
    }
}
b.setLister(buylister)
b.showloading()
//都準備好後執行
b.requestProductInfo()
self.ShowOrder2CCVC.buy = {p in
    //選擇商品購買
    b.showActionSheet(p,true)
}
```
