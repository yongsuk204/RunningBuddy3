import SwiftUI

// Purpose: 캘리브레이션 기록 관리 및 선형 회귀 모델 표시 화면
struct CalibrationHistoryView: View {

    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss
    @StateObject private var calibrator = StrideCalibratorService.shared
    @StateObject private var themeManager = ThemeManager.shared

    @State private var showingNewCalibration = false
    @State private var showingDeleteAlert = false
    @State private var recordToDelete: CalibrationData?
    @State private var isLoading = false
    @State private var newCalibrationData: CalibrationData?

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: [
                    themeManager.gradientStart.opacity(0.6),
                    themeManager.gradientEnd.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 헤더
                headerSection

                if isLoading {
                    Spacer()
                    ProgressView("로딩 중...")
                        .foregroundColor(.white)
                    Spacer()
                } else if calibrator.calibrationRecords.isEmpty {
                    emptyStateSection
                } else {
                    // 기록 수 부족 경고 (5개 미만)
                    if calibrator.calibrationRecords.count < 5 {
                        insufficientRecordsWarning
                            .padding(.horizontal)
                            .padding(.top, 16)
                    }

                    // 모델 정보 카드 (5개 이상일 때만 표시)
                    if let model = calibrator.strideModel {
                        modelInfoCard(model: model)
                            .padding(.horizontal)
                            .padding(.top, calibrator.calibrationRecords.count < 5 ? 12 : 16)
                    }

                    // 캘리브레이션 기록 리스트
                    recordsListSection
                }

                // 새 캘리브레이션 추가 버튼
                addButtonSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCalibrationHistory()
        }
        .sheet(isPresented: $showingNewCalibration) {
            CalibrationView(
                calibrationData: $newCalibrationData
            ) {
                // 저장 완료 후 콜백 (히스토리 새로고침)
                loadCalibrationHistory()
            }
        }
        .alert("기록 삭제", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                if let record = recordToDelete {
                    Task {
                        await deleteRecord(record)
                    }
                }
            }
        } message: {
            Text("이 캘리브레이션 기록을 삭제하시겠습니까?")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.white)
                }

                Spacer()

                Text("캘리브레이션 히스토리")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                // 균형을 위한 투명 버튼
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .opacity(0)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            if !calibrator.calibrationRecords.isEmpty {
                Text("\(calibrator.calibrationRecords.count)개의 기록")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Empty State Section

    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.walk")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.5))

            VStack(spacing: 12) {
                Text("캘리브레이션 기록이 없습니다")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("정확한 동적 보폭 모델을 위해\n다양한 속도로 5회 이상 측정하세요")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 8) {
                    Text("권장 측정 방법:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.9))

                    HStack(spacing: 4) {
                        Image(systemName: "1.circle.fill")
                        Text("천천히 조깅")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Image(systemName: "2.circle.fill")
                        Text("편안한 페이스")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Image(systemName: "3.circle.fill")
                        Text("빠른 페이스")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Image(systemName: "4.circle.fill")
                        Text("스피드 러닝")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 4) {
                        Image(systemName: "5.circle.fill")
                        Text("전력 질주")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Insufficient Records Warning

    private var insufficientRecordsWarning: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("기록 수 부족")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Divider()
                .background(Color.white.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                Text("현재 \(calibrator.calibrationRecords.count)개의 기록이 있습니다")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text("정확한 동적 보폭 모델을 위해 최소 5회 이상의 캘리브레이션이 필요합니다. 다양한 속도(천천히, 보통, 빠르게)로 측정하세요.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("진행률:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    ProgressView(value: Double(calibrator.calibrationRecords.count), total: 5.0)
                        .tint(.green)

                    Text("\(calibrator.calibrationRecords.count)/5")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Model Info Card

    private func modelInfoCard(model: StrideModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("선형 회귀 모델")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Divider()
                .background(Color.white.opacity(0.3))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("보폭 공식:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }

                Text("stride = \(formatNumber(model.alpha)) × cadence + \(formatNumber(model.beta))")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 4)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("R² (적합도)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(formatNumber(model.rSquared))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("샘플 수")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(model.sampleCount)개")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Records List Section

    private var recordsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(calibrator.calibrationRecords.enumerated()), id: \.element.measuredAt) { index, record in
                    calibrationRecordCard(record: record, index: index)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Calibration Record Card

    private func calibrationRecordCard(record: CalibrationData, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("기록 #\(calibrator.calibrationRecords.count - index)")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(formatDate(record.measuredAt))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Button(action: {
                    recordToDelete = record
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red.opacity(0.8))
                }
            }

            Divider()
                .background(Color.white.opacity(0.3))

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("걸음 수")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(record.totalSteps)걸음")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("케이던스")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.1f SPM", record.averageCadence))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("평균 보폭")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.2f m", record.averageStepLength))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Add Button Section

    private var addButtonSection: some View {
        VStack {
            Button(action: {
                showingNewCalibration = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("새 캘리브레이션 추가")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.clear,
                    themeManager.gradientStart.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 캘리브레이션 히스토리 로드
    // ═══════════════════════════════════════
    private func loadCalibrationHistory() {
        isLoading = true
        Task {
            await calibrator.loadCalibrationHistory()
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func deleteRecord(_ record: CalibrationData) async {
        if let index = calibrator.calibrationRecords.firstIndex(where: { $0.measuredAt == record.measuredAt }) {
            await calibrator.removeCalibrationRecord(at: index)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
        return formatter.string(from: date)
    }

    private func formatNumber(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}

#Preview {
    NavigationStack {
        CalibrationHistoryView()
    }
}
