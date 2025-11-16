import Foundation

// Purpose: 비밀번호 정책 검증 서비스
// MARK: - 함수 목록
/*
 * Validation Methods
 * - validatePolicy(): 비밀번호 정책 검증 (길이, 대소문자, 숫자, 특수문자)
 *
 * Private Helper Methods
 * - hasUppercase(): 대문자 포함 여부 확인
 * - hasLowercase(): 소문자 포함 여부 확인
 * - hasNumbers(): 숫자 포함 여부 확인
 * - hasSpecialCharacters(): 특수문자 포함 여부 확인
 */
struct PasswordValidator {

    // MARK: - Password Policy

    // 비밀번호 정책 4가지 필수 요구사항
    static let minPasswordLength = 10
    static let requiresUppercase = true
    static let requiresLowercase = true
    static let requiresNumbers = true
    static let requiresSpecialCharacters = true

    // MARK: - Public Methods

    // 1차 비밀번호만 정책 검증
    static func validatePolicy(_ password: String) -> (isValid: Bool, errorMessage: String) {
        // 공백 포함 여부 확인
        if password.contains(" ") {
            return (false, "비밀번호에 공백을 포함할 수 없습니다")
        }

        var failedRequirements: [String] = []

        // 최소 길이 확인
        if password.count < minPasswordLength {
            failedRequirements.append("최소 \(minPasswordLength)자")
        }

        // 대문자 확인
        if requiresUppercase && !hasUppercase(password) {
            failedRequirements.append("대문자 포함")
        }

        // 소문자 확인
        if requiresLowercase && !hasLowercase(password) {
            failedRequirements.append("소문자 포함")
        }

        // 숫자 확인
        if requiresNumbers && !hasNumbers(password) {
            failedRequirements.append("숫자 포함")
        }

        // 특수문자 확인
        if requiresSpecialCharacters && !hasSpecialCharacters(password) {
            failedRequirements.append("특수문자 포함")
        }

        if failedRequirements.isEmpty {
            return (true, "")
        } else {
            let message = "비밀번호 요구사항: " + failedRequirements.joined(separator: ", ")
            return (false, message)
        }
    }

    // MARK: - Private Methods

    // 대문자 포함 여부
    private static func hasUppercase(_ password: String) -> Bool {
        return password.range(of: "[A-Z]", options: .regularExpression) != nil
    }

    // 소문자 포함 여부
    private static func hasLowercase(_ password: String) -> Bool {
        return password.range(of: "[a-z]", options: .regularExpression) != nil
    }

    // 숫자 포함 여부
    private static func hasNumbers(_ password: String) -> Bool {
        return password.range(of: "[0-9]", options: .regularExpression) != nil
    }

    // 특수문자 포함 여부
    private static func hasSpecialCharacters(_ password: String) -> Bool {
        return password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }
}
