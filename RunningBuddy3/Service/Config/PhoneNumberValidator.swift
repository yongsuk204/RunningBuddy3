import Foundation

// Purpose: 전화번호 유효성 검증 및 포맷팅 서비스
// MARK: - 함수 목록
/*
 * Validation Methods
 * - validatePhoneNumber(): 전화번호 형식 검증 (010, 011, 016, 017, 018, 019)
 * - isBasicValidFormat(): 기본 형식 검증 (실시간 입력용)
 *
 * Formatting Methods
 * - formatPhoneNumber(): 하이픈 자동 추가 (010-1234-5678)
 * - extractNumbers(): 숫자만 추출
 */
class PhoneNumberValidator {

    // MARK: - Singleton Instance

    // Purpose: 앱 전체에서 사용할 단일 인스턴스
    static let shared = PhoneNumberValidator()

    // MARK: - Private Initialization

    // Purpose: 싱글톤 패턴을 위한 private 생성자
    private init() {}

    // MARK: - Validation Methods

    // Purpose: 전화번호 완전 검증 (형식 + 길이)
    func validatePhoneNumber(_ phoneNumber: String) -> (isValid: Bool, errorMessage: String) {
        // Step 1: 숫자만 추출
        let numbers = extractNumbers(from: phoneNumber)

        // Step 2: 길이 체크 (10자리 또는 11자리)
        guard numbers.count == 10 || numbers.count == 11 else {
            return (false, "전화번호는 10자리 또는 11자리여야 합니다")
        }

        // Step 3: 한국 전화번호 형식 체크
        let validPrefixes = ["010", "011", "016", "017", "018", "019"]
        let prefix = String(numbers.prefix(3))

        guard validPrefixes.contains(prefix) else {
            return (false, "유효한 전화번호 형식이 아닙니다")
        }

        // Step 4: 010이면 11자리, 나머지는 10자리
        if prefix == "010" && numbers.count != 11 {
            return (false, "010 번호는 11자리여야 합니다")
        }

        if prefix != "010" && numbers.count != 10 {
            return (false, "\(prefix) 번호는 10자리여야 합니다")
        }

        return (true, "")
    }

    // Purpose: 기본 형식 검증 (실시간 입력 체크용)
    func isBasicValidFormat(_ phoneNumber: String) -> Bool {
        let numbers = extractNumbers(from: phoneNumber)

        // 최소 3자리 이상이어야 함 (prefix 확인용)
        guard numbers.count >= 3 else { return false }

        // 유효한 prefix로 시작하는지 확인
        let validPrefixes = ["010", "011", "016", "017", "018", "019"]
        let prefix = String(numbers.prefix(3))

        return validPrefixes.contains(prefix)
    }

    // MARK: - Formatting Methods

    // Purpose: 전화번호 자동 포맷팅 (하이픈 추가)
    func formatPhoneNumber(_ phoneNumber: String) -> String {
        let numbers = extractNumbers(from: phoneNumber)

        // 길이에 따른 포맷팅
        if numbers.count <= 3 {
            return numbers
        } else if numbers.count <= 7 {
            let prefix = String(numbers.prefix(3))
            let middle = String(numbers.dropFirst(3))
            return "\(prefix)-\(middle)"
        } else if numbers.count <= 11 {
            let prefix = String(numbers.prefix(3))

            // 010은 4-4 형식, 나머지는 3-4 형식
            if prefix == "010" {
                let middle = String(numbers.dropFirst(3).prefix(4))
                let suffix = String(numbers.dropFirst(7))
                if suffix.isEmpty {
                    return "\(prefix)-\(middle)"
                }
                return "\(prefix)-\(middle)-\(suffix)"
            } else {
                let middle = String(numbers.dropFirst(3).prefix(3))
                let suffix = String(numbers.dropFirst(6))
                if suffix.isEmpty {
                    return "\(prefix)-\(middle)"
                }
                return "\(prefix)-\(middle)-\(suffix)"
            }
        } else {
            // 11자리 초과는 11자리까지만 포맷팅
            return formatPhoneNumber(String(numbers.prefix(11)))
        }
    }

    // Purpose: 문자열에서 숫자만 추출
    func extractNumbers(from string: String) -> String {
        return string.filter { $0.isNumber }
    }
}