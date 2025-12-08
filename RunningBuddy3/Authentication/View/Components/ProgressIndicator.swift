import SwiftUI

// Purpose: 점진적 진행률을 시각적으로 표시하는 컴포넌트 (●--○--○--○ 형태)
struct ProgressIndicator: View {

    // MARK: - Properties

    let totalSteps: Int
    let currentStep: Int
    let stepTitles: [String]

    // MARK: - Styling Properties

    private let completedColor = DesignSystem.Colors.textPrimary
    private let currentColor = DesignSystem.Colors.textPrimary.opacity(DesignSystem.Opacity.veryStrong)
    private let incompleteColor = DesignSystem.Colors.textDisabled
    private let lineColor = DesignSystem.Colors.textPrimary.opacity(DesignSystem.Opacity.semiMedium)
    private let circleSize: CGFloat = 16
    private let lineHeight: CGFloat = 2

    // MARK: - Initializer

    init(totalSteps: Int, currentStep: Int, stepTitles: [String] = []) {
        self.totalSteps = totalSteps
        self.currentStep = currentStep
        self.stepTitles = stepTitles
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // Progress dots and lines
            progressDotsView
        }
    }

    // MARK: - Step Titles View

    @ViewBuilder
    private var stepTitlesView: some View {
        HStack {
            ForEach(0..<min(stepTitles.count, totalSteps), id: \.self) { index in
                Text(stepTitles[index])
                    .font(.caption2)
                    .foregroundColor(colorForStep(index))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Progress Dots View

    private var progressDotsView: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { index in
                // Step circle
                stepCircle(for: index)

                // Connecting line (except for last step)
                if index < totalSteps - 1 {
                    connectingLine(for: index)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step Circle

    @ViewBuilder
    private func stepCircle(for index: Int) -> some View {
        Circle()
            .fill(fillColorForStep(index))
            .frame(width: circleSize, height: circleSize)
            .overlay(
                // 미진행 단계에 테두리 표시
                Circle()
                    .stroke(strokeColorForStep(index), lineWidth: 2)
            )
            .scaleEffect(isCurrentStep(index) ? 1.2 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: currentStep)
    }

    // MARK: - Connecting Line

    @ViewBuilder
    private func connectingLine(for index: Int) -> some View {
        Rectangle()
            .fill(lineColorForConnection(index))
            .frame(height: lineHeight)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    // MARK: - Helper Methods

    // Purpose: 단계가 완료되었는지 확인
    private func isStepCompleted(_ index: Int) -> Bool {
        return index < currentStep
    }

    // Purpose: 현재 단계인지 확인
    private func isCurrentStep(_ index: Int) -> Bool {
        return index == currentStep
    }

    // Purpose: 각 단계별 채우기 색상 결정
    private func fillColorForStep(_ index: Int) -> Color {
        if isStepCompleted(index) {
            return completedColor
        } else if isCurrentStep(index) {
            return currentColor
        } else {
            return Color.clear
        }
    }

    // Purpose: 각 단계별 테두리 색상 결정
    private func strokeColorForStep(_ index: Int) -> Color {
        if isStepCompleted(index) || isCurrentStep(index) {
            return completedColor
        } else {
            return incompleteColor
        }
    }

    // Purpose: 단계 제목의 색상 결정
    private func colorForStep(_ index: Int) -> Color {
        if isStepCompleted(index) || isCurrentStep(index) {
            return completedColor
        } else {
            return incompleteColor
        }
    }

    // Purpose: 연결선의 색상 결정
    private func lineColorForConnection(_ index: Int) -> Color {
        // 현재 단계 이전의 연결선은 활성화
        if index < currentStep {
            return completedColor.opacity(0.8)
        } else {
            return incompleteColor
        }
    }
}