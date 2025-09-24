import Foundation
import CryptoKit

// Purpose: 보안질문 답변을 안전하게 해시화하는 서비스
// MARK: - 함수 목록
/*
 * Security Answer Hashing Methods
 * - hashSecurityAnswer(): 보안질문 답변을 pepper와 함께 SHA-512로 해시화
 * - verifySecurityAnswer(): 입력된 답변과 저장된 해시값 비교 검증
 *
 * Data Hashing Methods
 * - hashEmail(): 이메일 전체를 pepper + salt와 함께 SHA-512로 해시화 (publicdata 저장용)
 * - hashPhoneNumber(): 전화번호를 salt와 함께 SHA-512로 해시화 (users 저장용)
 *
 * Private Methods
 * - logHashingProcess(): 해시화 과정 로깅 (디버깅용)
 */
class SecurityService {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = SecurityService()

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - Security Answer Hashing Methods

    // ═══════════════════════════════════════
    // PURPOSE: 보안질문 답변을 Config의 pepper를 사용하여 SHA-512로 해시화
    // ═══════════════════════════════════════
    func hashSecurityAnswer(_ answer: String) -> String {
        // Step 1: 답변을 소문자로 변환하여 대소문자 일관성 확보
        let normalizedAnswer = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 2: pepper를 결합한 문자열 생성
        let combinedString = normalizedAnswer + Config.pepper

        // Step 3: 문자열을 Data로 변환
        guard let data = combinedString.data(using: .utf8) else {
            print("SecurityService: 문자열을 Data로 변환 실패")
            return ""
        }

        // Step 4: SHA-512 해시 계산
        let hashedData = SHA512.hash(data: data)

        // Step 5: 해시 결과를 16진수 문자열로 변환
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()

        return hashString
    }

    // ═══════════════════════════════════════
    // PURPOSE: 보안질문 답변 검증
    // ═══════════════════════════════════════
    func verifySecurityAnswer(_ inputAnswer: String, hashedAnswer: String) -> Bool {
        // Step 1: 입력된 답변을 해시화
        let hashedInput = hashSecurityAnswer(inputAnswer)

        // Step 2: 저장된 해시와 비교
        return hashedInput == hashedAnswer
    }

    // MARK: - Data Hashing Methods

    // ═══════════════════════════════════════
    // PURPOSE: 이메일 전체를 해시화 (publicdata 컬렉션 저장용)
    // ═══════════════════════════════════════
    func hashEmail(_ email: String) -> String {
        // Step 1: 이메일을 소문자로 변환하여 일관성 확보
        let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 2: pepper와 salt를 결합한 문자열 생성
        let combinedString = normalizedEmail + Config.pepper + Config.salt

        // Step 3: 문자열을 Data로 변환
        guard let data = combinedString.data(using: .utf8) else {
            print("SecurityService: 이메일 문자열을 Data로 변환 실패")
            return ""
        }

        // Step 4: SHA-512 해시 계산
        let hashedData = SHA512.hash(data: data)

        // Step 5: 해시 결과를 16진수 문자열로 변환
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()

        print("SecurityService: 이메일 해시 생성 성공")
        return hashString
    }

    // ═══════════════════════════════════════
    // PURPOSE: 전화번호를 salt를 사용하여 SHA-512로 해시화 (users 컬렉션 저장용)
    // ═══════════════════════════════════════
    func hashPhoneNumber(_ phoneNumber: String) -> String {
        // Step 1: 하이픈 제거 및 트림 처리
        let normalizedNumber = phoneNumber.replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 2: salt를 결합한 문자엱 생성
        let combinedString = normalizedNumber + Config.salt

        // Step 3: 문자열을 Data로 변환
        guard let data = combinedString.data(using: .utf8) else {
            print("SecurityService: 전화번호 문자열을 Data로 변환 실패")
            return ""
        }

        // Step 4: SHA-512 해시 계산
        let hashedData = SHA512.hash(data: data)

        // Step 5: 해시 결과를 16진수 문자열로 변환
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()

        print("SecurityService: 전화번호 해시 생성 성공")
        return hashString
    }

    // MARK: - Private Methods

    // ═══════════════════════════════════════
    // PURPOSE: 해시화 과정에서 사용되는 정보 로깅 (디버깅용)
    // ═══════════════════════════════════════
    private func logHashingProcess(_ answer: String) {
        print("SecurityService: 답변 해시화 시작")
        print("SecurityService: 원본 답변 길이: \(answer.count)")
        print("SecurityService: Pepper 길이: \(Config.pepper.count)")
        print("SecurityService: Salt 길이: \(Config.salt.count)")
    }
}
