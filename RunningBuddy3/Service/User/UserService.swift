import Foundation
import FirebaseFirestore
import FirebaseAuth

// Purpose: Firestore에서 사용자 데이터를 관리하는 서비스
// MARK: - 함수 목록
/*
 * User Data Management
 * - saveUserData(): 회원가입 시 사용자 정보를 Firestore users 컬렉션에 저장 (해시화된 이메일로 저장)
 * - getUserData(): 사용자 ID로 사용자 정보 조회
 * - verifySecurityAnswer(): 보안질문 답변 검증
 * - updateUserData(): 사용자 데이터 업데이트
 * - deleteUserData(): 사용자 데이터 삭제
 *
 * Email Public Data Methods (중복 가입 방지용)
 * - checkEmailInPublicData(): publicdata 컬렉션에서 해시된 이메일 문서 ID로 중복 체크
 * - saveEmailToPublicData(): publicdata 컬렉션에 해시된 이메일을 문서 ID로 저장
 *
 * Email Recovery Methods
 * - findEmailByPhoneNumber(): 전화번호로 사용자 이메일 찾기 (이메일 찾기 기능용)
 */
class UserService {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = UserService()

    // MARK: - Properties

    // Purpose: Firestore 데이터베이스 참조
    private let firestore = FirebaseManager.shared.firestore

    // Purpose: SecurityService 인스턴스
    private let securityService = SecurityService.shared

    // Purpose: 컬렉션 이름들
    private let usersCollection = "users"
    private let publicDataCollection = "publicdata"

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - User Data Management

    // ═══════════════════════════════════════
    // PURPOSE: 회원가입 시 사용자 정보를 Firestore에 저장 👈
    // ═══════════════════════════════════════
    func saveUserData(userId: String, email: String, phoneNumber: String, securityQuestion: String, securityAnswer: String) async throws {
        // Step 1: 이메일과 전화번호 해시화
        let hashedEmail = securityService.hashEmail(email)
        let hashedPhoneNumber = securityService.hashPhoneNumber(phoneNumber)

        // Step 2: 보안질문 답변 해시화
        let hashedAnswer = securityService.hashSecurityAnswer(securityAnswer)

        // Step 3: UserData 객체 생성 👈 UserData() init!!
        let userData = UserData(
            userId: userId,
            email: hashedEmail,
            phoneNumber: hashedPhoneNumber,
            securityQuestion: securityQuestion,
            hashedSecurityAnswer: hashedAnswer
        )

        // Step 4: Firestore에 저장 👈 userData.toDictionary() 상태로 저장!!
        do {
            try await firestore.collection(usersCollection).document(userId).setData(userData.toDictionary())
            print("UserService: 사용자 데이터 저장 성공 - \(hashedEmail)")
        } catch {
            print("UserService: 사용자 데이터 저장 실패 - \(error.localizedDescription)")
            throw UserServiceError.saveFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 ID로 사용자 정보 조회
    // ═══════════════════════════════════════
    func getUserData(userId: String) async throws -> UserData? {
        do {
            // Step 1: Firestore에서 문서 조회
            let document = try await firestore.collection(usersCollection).document(userId).getDocument()

            // Step 2: 문서 존재 여부 확인 let data = document.data() 👈 firestore에 저장된 원본
            guard document.exists, let data = document.data() else {
                print("UserService: 사용자 데이터 없음 - \(userId)")
                return nil
            }

            // Step 3: UserData 객체로 변환 👈 UserData.fromDictionary(data) 상태로 가져옴!!
            guard let userData = UserData.fromDictionary(data) else {
                print("UserService: 데이터 변환 실패 - \(userId)")
                throw UserServiceError.dataConversionFailed
            }

            print("UserService: 사용자 데이터 조회 성공 - \(userData.email)")
            return userData

        } catch {
            print("UserService: 사용자 데이터 조회 실패 - \(error.localizedDescription)")
            throw UserServiceError.fetchFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 보안질문 답변 검증
    // ═══════════════════════════════════════
    func verifySecurityAnswer(userId: String, inputAnswer: String) async throws -> Bool {
        // Step 1: 사용자 데이터 조회
        guard let userData = try await getUserData(userId: userId) else {
            throw UserServiceError.userNotFound
        }

        // Step 2: 보안질문 답변 검증
        let isValid = securityService.verifySecurityAnswer(inputAnswer, hashedAnswer: userData.hashedSecurityAnswer)

        print("UserService: 보안질문 답변 검증 결과 - \(isValid)")
        return isValid
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 데이터 업데이트
    // ═══════════════════════════════════════
    func updateUserData(userId: String, updates: [String: Any]) async throws {
        do {
            try await firestore.collection(usersCollection).document(userId).updateData(updates)
            print("UserService: 사용자 데이터 업데이트 성공 - \(userId)")
        } catch {
            print("UserService: 사용자 데이터 업데이트 실패 - \(error.localizedDescription)")
            throw UserServiceError.updateFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 사용자 데이터 삭제 (users 컬렉션 + publicdata 컬렉션)
    // ═══════════════════════════════════════
    func deleteUserData(userId: String) async throws {
        do {
            // Step 1: 사용자 데이터 조회 (이메일 정보 필요)
            guard let userData = try await getUserData(userId: userId) else {
                throw UserServiceError.userNotFound
            }

            // Step 2: publicdata 컬렉션에서 해시된 이메일 문서 삭제
            let documentRef = firestore.collection(publicDataCollection).document(userData.email)
            try await documentRef.delete()
            print("UserService: PublicData 이메일 삭제 성공")

            // Step 3: users 컬렉션에서 사용자 문서 삭제
            try await firestore.collection(usersCollection).document(userId).delete()
            print("UserService: 사용자 데이터 삭제 성공 - \(userId)")

        } catch {
            print("UserService: 사용자 데이터 삭제 실패 - \(error.localizedDescription)")
            throw UserServiceError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Email Public Data Methods (중복 가입 방지용)

    // ═══════════════════════════════════════
    // PURPOSE: publicdata 컬렉션에서 해시된 이메일로 중복 체크 (문서 ID로 조회)
    // ═══════════════════════════════════════
    func checkEmailInPublicData(_ email: String) async throws -> Bool {
        do {
            // Step 1: 이메일 해시화
            let hashedEmail = securityService.hashEmail(email)

            // Step 2: 해시값을 문서 ID로 사용하여 문서 존재 여부 확인
            let documentRef = firestore.collection(publicDataCollection).document(hashedEmail)
            let document = try await documentRef.getDocument()

            // Step 3: 문서가 존재하면 true (중복), 없으면 false
            if document.exists {
                print("UserService: PublicData 이메일 중복 확인 - 이미 존재하는 이메일")
                return true
            } else {
                print("UserService: PublicData 이메일 중복 확인 - 사용 가능한 이메일")
                return false
            }
        } catch {
            print("UserService: PublicData 이메일 중복 확인 실패 - \(error.localizedDescription)")
            throw UserServiceError.searchFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: publicdata 컬렉션에 해시된 이메일을 문서 ID로 저장
    // ═══════════════════════════════════════
    func saveEmailToPublicData(_ email: String) async throws {
        do {
            // Step 1: 이메일 해시화
            let hashedEmail = securityService.hashEmail(email)

            // Step 2: 해시값을 문서 ID로 사용하여 publicdata 컬렉션에 저장
            let documentRef = firestore.collection(publicDataCollection).document(hashedEmail)

            let data: [String: Any] = [
                "createdAt": Timestamp(date: Date())
            ]

            // Step 3: 문서 저장
            try await documentRef.setData(data)
            print("UserService: PublicData 이메일 저장 성공 - 문서 ID: \(hashedEmail)")

        } catch {
            print("UserService: PublicData 이메일 저장 실패 - \(error.localizedDescription)")
            throw UserServiceError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Email Recovery Methods

    // ═══════════════════════════════════════
    // PURPOSE: 전화번호로 사용자 이메일 찾기 (이메일 찾기 기능용)
    // ═══════════════════════════════════════
    func findEmailByPhoneNumber(_ phoneNumber: String) async throws -> String? {
        do {
            // Step 1: 전화번호 해시화
            let hashedPhoneNumber = securityService.hashPhoneNumber(phoneNumber)

            // Step 2: users 컬렉션에서 해당 전화번호를 가진 사용자 찾기
            let querySnapshot = try await firestore.collection(usersCollection).getDocuments()

            for document in querySnapshot.documents {
                if let userData = UserData.fromDictionary(document.data()),
                   userData.phoneNumber == hashedPhoneNumber {
                    print("UserService: 전화번호로 사용자 찾기 성공")
                    return userData.email
                }
            }

            print("UserService: 해당 전화번호의 사용자를 찾을 수 없음")
            return nil

        } catch {
            print("UserService: 전화번호로 이메일 찾기 실패 - \(error.localizedDescription)")
            throw UserServiceError.searchFailed(error.localizedDescription)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 전화번호로 모든 이메일 찾기 (복수 계정 지원)
    // ═══════════════════════════════════════
    func findEmailsByPhoneNumber(_ phoneNumber: String) async throws -> [String] {
        do {
            // Step 1: 전화번호 해시화
            let hashedPhoneNumber = securityService.hashPhoneNumber(phoneNumber)

            // Step 2: users 컬렉션에서 해당 전화번호를 가진 모든 사용자 찾기
            let querySnapshot = try await firestore.collection(usersCollection).getDocuments()

            var foundEmails: [String] = []

            for document in querySnapshot.documents {
                if let userData = UserData.fromDictionary(document.data()),
                   userData.phoneNumber == hashedPhoneNumber {
                    foundEmails.append(userData.email)
                }
            }

            print("UserService: 전화번호로 \(foundEmails.count)개의 이메일 찾기 완료")
            return foundEmails

        } catch {
            print("UserService: 전화번호로 이메일 찾기 실패 - \(error.localizedDescription)")
            throw UserServiceError.searchFailed(error.localizedDescription)
        }
    }

}

// MARK: - Error Types

// Purpose: UserService에서 발생할 수 있는 에러 타입 정의
enum UserServiceError: LocalizedError {
    case saveFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case searchFailed(String)
    case dataConversionFailed
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "사용자 데이터 저장 실패: \(message)"
        case .fetchFailed(let message):
            return "사용자 데이터 조회 실패: \(message)"
        case .updateFailed(let message):
            return "사용자 데이터 업데이트 실패: \(message)"
        case .deleteFailed(let message):
            return "사용자 데이터 삭제 실패: \(message)"
        case .searchFailed(let message):
            return "사용자 검색 실패: \(message)"
        case .dataConversionFailed:
            return "데이터 변환 실패"
        case .userNotFound:
            return "사용자를 찾을 수 없습니다"
        }
    }
}
