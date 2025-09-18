import Foundation
import CryptoKit

// Purpose: 보안질문 답변을 안전하게 해시화하는 서비스
class SecurityService {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = SecurityService()

    // MARK: - Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - Hashing Methods

    // Purpose: 보안질문 답변을 Config의 pepper와 salt를 사용하여 SHA-512로 해시화
    func hashSecurityAnswer(_ answer: String) -> String {
        // Step 1: 답변을 소문자로 변환하여 대소문자 일관성 확보
        let normalizedAnswer = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 2: pepper와 salt를 결합한 문자열 생성
        let combinedString = normalizedAnswer + Config.pepper + Config.salt

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

    // Purpose: 보안질문 답변 검증 (로그인 시 사용)
    func verifySecurityAnswer(_ inputAnswer: String, hashedAnswer: String) -> Bool {
        // Step 1: 입력된 답변을 해시화
        let hashedInput = hashSecurityAnswer(inputAnswer)

        // Step 2: 저장된 해시와 비교
        return hashedInput == hashedAnswer
    }

    // Purpose: 해시화 과정에서 사용되는 정보 로깅 (디버깅용)
    private func logHashingProcess(_ answer: String) {
        print("SecurityService: 답변 해시화 시작")
        print("SecurityService: 원본 답변 길이: \(answer.count)")
        print("SecurityService: Pepper 길이: \(Config.pepper.count)")
        print("SecurityService: Salt 길이: \(Config.salt.count)")
    }
}