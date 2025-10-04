//
//  RunningBuddy3App.swift
//  RunningBuddy3
//
//  Created by 배용석 on 9/18/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import UserNotifications

// Purpose: SwiftUI 앱 진입점 및 Firebase 초기화 관리
// MARK: - 함수 목록
/*
 * AppDelegate Methods
 * - application(_:didFinishLaunchingWithOptions:): Firebase 초기화 및 Push Notification 권한 요청
 * - application(_:didRegisterForRemoteNotificationsWithDeviceToken:): APNs 토큰 등록 성공 시 Firebase에 토큰 전달
 * - application(_:didFailToRegisterForRemoteNotificationsWithError:): APNs 토큰 등록 실패 처리
 * - application(_:didReceiveRemoteNotification:fetchCompletionHandler:): Remote Notification 수신 처리
 *
 * App Structure
 * - body: SwiftUI 앱의 UI 계층 구조 정의
 */

// MARK: - AppDelegate

// Purpose: Firebase 초기화 및 APNs(Apple Push Notification service) 설정을 위한 AppDelegate
// Note: SwiftUI 앱에서 UIApplicationDelegate를 사용하기 위해 NSObject와 UIApplicationDelegate 프로토콜 채택
class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - App Lifecycle

    // Purpose: 앱 시작 시 호출되는 메서드
    // Note: Firebase 초기화 및 Push Notification 권한 요청을 여기서 처리
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Step 1: Firebase 초기화
        // GoogleService-Info.plist 파일을 읽어 Firebase 서비스를 설정
        FirebaseApp.configure()
        print("🔥 Firebase 초기화 완료")

        // Step 2: Push Notification 권한 요청 및 APNs 등록
        // Firebase Phone Authentication을 위해서는 APNs 토큰이 필수
        // 사용자에게 알림 권한 요청 (알림, 소리, 뱃지)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("🔔 Notification 권한: \(granted ? "승인" : "거부")")

            if granted {
                // 권한이 승인되면 APNs 토큰 등록 시작
                // Main 스레드에서 실행해야 함
                /*
                  APNs 토큰이 필요한 이유
                  Firebase Phone Authentication은 **사일런트 푸시알림(Silent Push)**을 사용하여 기기검증을 수행합니다.

                  1. 사용자가 전화번호 입력
                           ↓
                  2. Firebase가 해당 번호로 SMS 발송
                           ↓
                  3. 동시에 APNs를 통해 기기에 사일런트 푸시 전송
                           ↓
                  4. 앱이 사일런트 푸시 수신 (사용자는 모름)
                           ↓
                  5. Firebase가 "이 번호 요청이 실제 기기에서 온 것" 확인
                           ↓
                  6. SMS 인증 코드 전송 허용

                  사일런트 푸시의 역할:
                  - ✅ 봇/스팸 방지: 실제 iOS 기기에서만 작동
                  - ✅ 어뷰징 방지: 무분별한 SMS 발송 차단
                  - ✅ 빠른 검증: 네트워크 왕복 시간 단축
                 */
                DispatchQueue.main.async {
                    // APNs에 기기 등록 요청
                    // 성공 시: didRegisterForRemoteNotificationsWithDeviceToken 콜백 호출
                    // 실패 시: didFailToRegisterForRemoteNotificationsWithError 콜백 호출
                    application.registerForRemoteNotifications()
                }
            } else if let error = error {
                // 권한 요청 중 에러 발생
                print("❌ Notification 권한 에러: \(error.localizedDescription)")
            }
        }

        return true
    }

    // MARK: - APNs Token Handling

    // Purpose: APNs 토큰 등록 성공 시 호출되는 콜백 메서드
    // Note: Firebase Phone Authentication이 작동하려면 이 토큰을 Firebase에 등록해야 함
    // Parameters:
    //   - deviceToken: Apple이 발급한 고유한 기기 토큰 (32 bytes)
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        print("✅ APNs 토큰 등록 성공!")

        // Firebase Auth에 APNs 토큰 등록
        // Firebase Phone Auth는 이 토큰을 사용하여 사일런트 푸시 알림으로 기기 검증
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        print("🔧 Firebase: .sandbox 타입으로 토큰 등록")
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        print("🚀 Firebase: .prod 타입으로 토큰 등록")
        #endif
    }

    // Purpose: APNs 토큰 등록 실패 시 호출되는 콜백 메서드
    // Note: 실제 기기에서만 APNs가 작동하므로 시뮬레이터에서는 항상 실패
    // Parameters:
    //   - error: 등록 실패 원인 (네트워크 오류, 권한 문제 등)
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Remote Notifications 등록 실패: \(error.localizedDescription)")
        print("❌ Error 상세: \(error)")
        print("❌ Error Code: \((error as NSError).code)")
        print("❌ Error Domain: \((error as NSError).domain)")
    }

    // MARK: - Remote Notification Handling

    // Purpose: 앱이 백그라운드/포그라운드에서 Remote Notification을 수신했을 때 호출
    // Note: Firebase Phone Auth는 사일런트 푸시 알림을 사용하여 기기 검증
    // Parameters:
    //   - userInfo: 알림 데이터 (Firebase가 보낸 검증 데이터 포함)
    //   - completionHandler: 시스템에 알림 처리 결과를 전달하는 핸들러
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        // Firebase Auth가 처리할 수 있는 알림인지 확인
        // Phone Auth 검증용 사일런트 푸시인 경우 Firebase가 자동 처리
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }

        // Firebase와 관련 없는 일반 알림 처리
        completionHandler(.noData)
    }
}

// MARK: - SwiftUI App

// Purpose: SwiftUI 앱의 진입점
// Note: @main 어트리뷰트로 앱의 시작점을 표시
@main
struct RunningBuddy3App: App {

    // Purpose: UIKit의 AppDelegate를 SwiftUI 앱에 연결
    // Note: @UIApplicationDelegateAdaptor를 사용하여 Firebase 초기화 및 APNs 설정 처리
    // Why: SwiftUI는 기본적으로 AppDelegate가 없으므로 이 방식으로 연결
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Purpose: 앱의 UI 계층 구조 정의
    var body: some Scene {
        WindowGroup {
            // NavigationView로 감싸서 화면 전환 기능 제공
            NavigationView {
                ContentView()
            }
        }
    }
}
