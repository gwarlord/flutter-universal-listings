import UIKit
import Flutter
import GoogleMaps
import GoogleMobileAds
import google_mobile_ads

class NativeAdFactoryExample: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: NativeAd,
                        customOptions: [AnyHashable: Any]? = nil) -> NativeAdView? {
        guard Bundle.main.path(forResource: "NativeAdView", ofType: "nib") != nil else {
            NSLog("[Runner] NativeAdView.xib is missing from app bundle.")
            return nil
        }

        guard let nibObjects = Bundle.main.loadNibNamed("NativeAdView", owner: nil, options: nil),
              let adView = nibObjects.first as? NativeAdView else {
            return nil
        }

        adView.nativeAd = nativeAd

        (adView.headlineView as? UILabel)?.text = nativeAd.headline

        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.bodyView?.isHidden = nativeAd.body == nil

        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.iconView?.isHidden = nativeAd.icon == nil

        (adView.storeView as? UILabel)?.text = nativeAd.store
        adView.storeView?.isHidden = nativeAd.store == nil

        (adView.priceView as? UILabel)?.text = nativeAd.price
        adView.priceView?.isHidden = nativeAd.price == nil

        (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        adView.advertiserView?.isHidden = nativeAd.advertiser == nil

        adView.callToActionView?.isUserInteractionEnabled = false

        return adView
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let nativeAdFactory = NativeAdFactoryExample()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if let mapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !mapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalizedKey = mapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedKey.hasPrefix("$(") {
                NSLog("[Runner] GMSApiKey is unresolved in Info.plist: %@", normalizedKey)
            } else {
                let didInitializeMaps = GMSServices.provideAPIKey(normalizedKey)
                NSLog("[Runner] Google Maps initialization result: %@", didInitializeMaps ? "success" : "failed")
            }
        } else {
            NSLog("[Runner] Missing or empty GMSApiKey in Info.plist; skipping Google Maps initialization.")
        }

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }

        GeneratedPluginRegistrant.register(with: self)
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self,
            factoryId: "adFactoryExample",
            nativeAdFactory: nativeAdFactory
        )

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(self, factoryId: "adFactoryExample")
        super.applicationWillTerminate(application)
    }
}
