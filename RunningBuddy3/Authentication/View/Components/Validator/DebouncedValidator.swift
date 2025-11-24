import Foundation
import Combine

// Purpose: 입력 검증을 위한 디바운싱 헬퍼 클래스
// MARK: - 함수 목록
/*
 * Debouncing Methods
 * - debounce(interval:action:): 지정된 시간 후 액션 실행 (이전 타이머 취소)
 * - cancel(): 대기 중인 타이머 취소
 */

/// 입력 검증 시 API 호출을 지연시키는 디바운싱 헬퍼
/// 사용자가 타이핑을 멈춘 후 일정 시간이 지나면 검증 실행
class DebouncedValidator: ObservableObject {

    // MARK: - Properties

    private var timer: Timer?

    // MARK: - Initializer

    init() {}

    // MARK: - Methods

    // ═══════════════════════════════════════
    // PURPOSE: 디바운싱 실행 (이전 타이머 자동 취소)
    // ═══════════════════════════════════════
    /// - Parameters:
    ///   - interval: 대기 시간 (초), 기본값 1.0초
    ///   - action: 타이머 완료 후 실행할 액션
    func debounce(interval: TimeInterval = 1.0, action: @escaping () -> Void) {
        // Step 1: 기존 타이머 취소
        timer?.invalidate()

        // Step 2: 새 타이머 시작
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            action()
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 대기 중인 타이머 취소
    // ═══════════════════════════════════════
    /// 컴포넌트가 사라질 때 호출하여 메모리 누수 방지
    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Deinit

    deinit {
        cancel()
    }
}
