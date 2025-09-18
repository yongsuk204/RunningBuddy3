import Foundation
import Firebase
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase

// Firebase 서비스들을 중앙 집중식으로 관리하는 싱글톤 클래스
class FirebaseManager {

    // MARK: - Singleton Instance

    // 앱 전체에서 사용할 단일 인스턴스
    static let shared = FirebaseManager()

    // MARK: - Service Properties

    // Firebase Authentication 인스턴스 접근
    var auth: Auth {
        return Auth.auth()
    }

    // Firestore 데이터베이스 인스턴스 접근
    var firestore: Firestore {
        return Firestore.firestore()
    }

    // Firebase Realtime Database 인스턴스 접근
    var realtime: DatabaseReference {
        return Database.database().reference()
    }

    // MARK: - Initialization

    // 싱글톤 패턴을 위한 private 생성자
    private init() {
    }

    // MARK: - Configuration

    // 앱 시작 시 Firebase 초기화
    static func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }
}