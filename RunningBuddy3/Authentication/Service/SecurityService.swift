import Foundation
import CryptoKit

// Purpose: 보안질문 답변을 안전하게 해시화하는 서비스
// MARK: - 함수 목록
/*
 * - hash(): 보안질문 답변을 해시화
 * - verify(): 입력값과 해시값 검증
 */
class SecurityService {

    // MARK: - Security Constants

    // Purpose: 해시 암호화에 사용할 pepper 값 (⚠️ 배포 후 절대 변경 금지)
    private static let pepper = "K7mN9pQr2sT4vW6xY8zA1bC3dE5fG7hI9jK1lM3nO5pQ7rS9tU1vW3xY5zA7bC9dE1fG3hI5jK7lM9nO1pQ3rS5tU7vW9xY1zA3bC5dE7fG9hI1jK3lM5nO7pQ9rS1tU3vW5xY7zA9bC1dE3fG5hI7jK9lM1nO3pQ5rS7tU9vW1xY3zA"


    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = SecurityService()

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - Core Methods

    // ═══════════════════════════════════════
    // PURPOSE: 보안질문 답변을 해시화
    // ═══════════════════════════════════════
    func hash(_ data: String) -> String {
        // Step 1: 정규화 (소문자 + 공백 제거)
        let normalizedData = data.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 2: pepper를 결합한 문자열 생성
        let combinedString = normalizedData + SecurityService.pepper

        // Step 4: 문자열을 Data로 변환
        guard let dataToHash = combinedString.data(using: .utf8) else {
            print("SecurityService: 문자열을 Data로 변환 실패")
            return ""
        }

        // Step 5: 해시 계산
        let hashedData = SHA512.hash(data: dataToHash)

        // Step 6: 해시 결과를 16진수 문자열로 변환
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()

        return hashString
    }

    // ═══════════════════════════════════════
    // PURPOSE: 입력값과 해시값 검증
    // ═══════════════════════════════════════
    func verify(_ input: String, hashedValue: String) -> Bool {
        return hash(input) == hashedValue
    }
}
