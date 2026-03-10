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
@objc class AppDelegate: FlutterAppDelegate {
    #if canImport(GoogleMobileAds) && canImport(google_mobile_ads)
    private let nativeAdFactory = NativeAdFactoryExample()
    #endif

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // App Check provider factory must be configured before FirebaseApp.configure().
        // Use debug provider in debug builds or when a debug token is passed via scheme env.
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

        // Initialize Firebase first if proxy is disabled
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

#if canImport(GoogleMaps)
        if let mapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !mapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalizedKey = mapsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            GMSServices.provideAPIKey(normalizedKey)
        }
#endif

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }

        // Manual setup for Messaging
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()

        GeneratedPluginRegistrant.register(with: self)

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
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NSLog("DEBUG_IOS: APNs Device Token: %@", apnsToken)

        // MANUAL FORWARDING (Required when Proxy is disabled)
        Messaging.messaging().apnsToken = deviceToken

        #if DEBUG
        Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
        NSLog("DEBUG_IOS: Firebase APNs token type: sandbox")
        #else
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
        NSLog("DEBUG_IOS: Firebase APNs token type: prod")
        #endif

        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("DEBUG_IOS: CRITICAL: Failed to register for APNs: %@", error.localizedDescription)
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NSLog("DEBUG_IOS: didReceiveRemoteNotification: %@", userInfo as NSDictionary)

        // MANUAL FORWARDING
        Messaging.messaging().appDidReceiveMessage(userInfo)

        super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        NSLog("DEBUG_IOS: willPresent notification userInfo: %@", userInfo as NSDictionary)
        completionHandler([.banner, .sound, .badge])
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NSLog("DEBUG_IOS: didReceive notification response userInfo: %@", userInfo as NSDictionary)
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken = fcmToken {
            NSLog("DEBUG_IOS: FCM Token from MessagingDelegate: %@", fcmToken)
            // Notify Flutter/Native listeners if needed
            let dataDict: [String: String] = ["token": fcmToken]
            NotificationCenter.default.post(
                name: Notification.Name("FCMToken"),
                object: nil,
                userInfo: dataDict
            )
        }
    }
}
