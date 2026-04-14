import UIKit
import Flutter
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import FirebaseAppCheck

#if canImport(GoogleMaps)
import GoogleMaps
#endif

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

#if canImport(google_mobile_ads)
import google_mobile_ads
#endif

#if canImport(GoogleMobileAds) && canImport(google_mobile_ads)
class NativeAdFactoryExample: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: NativeAd,
                        customOptions: [AnyHashable: Any]? = nil) -> NativeAdView? {
        guard Bundle.main.path(forResource: "NativeAdView", ofType: "nib") != nil else {
            NSLog("[Runner] NativeAdView.xib is missing from app bundle.")
            return nil
        }

        guard let nibObjects = Bundle.main.loadNibNamed("NativeAdView", owner: nil, options: nil),
              let adView = nibObjects.first as? NativeAdView else {
            NSLog("[Runner] Failed to load NativeAdView from NativeAdView.xib.")
            return nil
        }

        
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        adView.headlineView?.isHidden = nativeAd.headline == nil

        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.bodyView?.isHidden = nativeAd.body == nil

        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (adView.mediaView as? MediaView)?.mediaContent = nativeAd.mediaContent
        adView.mediaView?.isHidden = nativeAd.mediaContent.aspectRatio <= 0

        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.iconView?.isHidden = nativeAd.icon == nil

        (adView.storeView as? UILabel)?.text = nativeAd.store
        adView.storeView?.isHidden = nativeAd.store == nil

        (adView.priceView as? UILabel)?.text = nativeAd.price
        adView.priceView?.isHidden = nativeAd.price == nil

        (adView.advertiserView as? UILabel)?.text = nativeAd.advertiser
        adView.advertiserView?.isHidden = nativeAd.advertiser == nil

        adView.callToActionView?.isUserInteractionEnabled = false
        adView.nativeAd = nativeAd

        return adView
    }
}
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
    #if canImport(GoogleMobileAds) && canImport(google_mobile_ads)
    private let nativeAdFactory = NativeAdFactoryExample()
    #endif
    private var envChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // App Check provider factory must be configured before FirebaseApp.configure().
        let env = ProcessInfo.processInfo.environment
        let appCheckDebugToken = env["FIRAAppCheckDebugToken"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let forceDebugAppCheck = (env["APPCHECK_FORCE_DEBUG_PROVIDER"] ?? "").lowercased() == "true"

        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        NSLog("DEBUG_IOS: App Check debug provider enabled (DEBUG build)")
        #else
        if forceDebugAppCheck || !appCheckDebugToken.isEmpty {
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            NSLog("DEBUG_IOS: App Check debug provider enabled (env override)")
        }
        #endif

        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()

#if canImport(GoogleMaps)
        if let mapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !mapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalizedKey = mapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            GMSServices.provideAPIKey(normalizedKey)
        }
#endif

        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "caribtap/app_env", binaryMessenger: controller.binaryMessenger)
            channel.setMethodCallHandler { [weak self] call, result in
                guard let self = self else {
                    result("")
                    return
                }
                switch call.method {
                case "getGoogleMapsApiKey":
                    result(self.readGoogleMapsApiKey())
                case "getGooglePlacesApiKey":
                    result(self.readGooglePlacesApiKey())
                case "getGeminiApiKey":
                    result(self.readGeminiApiKey())
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
            envChannel = channel
        }

        #if canImport(GoogleMobileAds) && canImport(google_mobile_ads)
        FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
            self,
            factoryId: "adFactoryExample",
            nativeAdFactory: nativeAdFactory
        )
        #endif

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("DEBUG_IOS: Failed to register for remote notifications: \(error.localizedDescription)")
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        NSLog("DEBUG_IOS: Firebase registration token refreshed: \(fcmToken ?? "nil")")
    }

    private func readGoogleMapsApiKey() -> String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String else {
            return ""
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func readGooglePlacesApiKey() -> String {
        if let placesKey = Bundle.main.object(forInfoDictionaryKey: "GMSPlacesApiKey") as? String {
            let trimmedPlaces = placesKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPlaces.isEmpty {
                return trimmedPlaces
            }
        }
        return readGoogleMapsApiKey()
    }

    private func readGeminiApiKey() -> String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GeminiApiKey") as? String else {
            return ""
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
