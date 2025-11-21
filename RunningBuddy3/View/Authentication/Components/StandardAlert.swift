import SwiftUI

// Purpose: 표준 Alert 컴포넌트 - Authentication 영역 전체에서 재사용
// MARK: - 함수 목록
/*
 * View Modifiers
 * - standardAlert(): 일반 알림 (확인 버튼만)
 * - standardAlert(with action): 확인 버튼에 커스텀 액션 포함
 */

// MARK: - View Extension

extension View {

    // ═══════════════════════════════════════
    // PURPOSE: 일반 알림 (확인 버튼만)
    // ═══════════════════════════════════════
    /// - Parameters:
    ///   - title: 알림 제목
    ///   - isPresented: 알림 표시 여부 바인딩
    ///   - message: 알림 메시지
    func standardAlert(
        title: String = "알림",
        isPresented: Binding<Bool>,
        message: String
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(message)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 확인 버튼에 커스텀 액션 포함
    // ═══════════════════════════════════════
    /// - Parameters:
    ///   - title: 알림 제목
    ///   - isPresented: 알림 표시 여부 바인딩
    ///   - message: 알림 메시지
    ///   - confirmAction: 확인 버튼 클릭 시 실행할 액션
    func standardAlert(
        title: String = "알림",
        isPresented: Binding<Bool>,
        message: String,
        confirmAction: @escaping () -> Void
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            Button("확인", role: .cancel) {
                confirmAction()
            }
        } message: {
            Text(message)
        }
    }
}

// MARK: - Info Alert Variant

extension View {

    // ═══════════════════════════════════════
    // PURPOSE: 정보 제공용 Alert (도움말, 안내 등)
    // ═══════════════════════════════════════
    /// - Parameters:
    ///   - title: 알림 제목
    ///   - isPresented: 알림 표시 여부 바인딩
    ///   - message: 알림 메시지 (여러 줄 가능)
    func infoAlert(
        title: String,
        isPresented: Binding<Bool>,
        message: String
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            Button("확인") { }
        } message: {
            Text(message)
        }
    }
}
