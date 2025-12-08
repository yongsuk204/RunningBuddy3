import SwiftUI

// Purpose: 캘리브레이션 측정 기록 관리 화면
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
            // Background gradient
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
                // Top: Measurement button (fixed)
                measurementButtonSection
                    .padding(.horizontal)
                    .padding(.top, 16)

                // Bottom: Scrollable record list
                if isLoading {
                    loadingSection
                } else if calibrator.calibrationRecords.isEmpty {
                    emptyStateSection
                } else {
                    recordsListSection
                }
            }
        }
        .navigationTitle("캘리브레이션")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showingNewCalibration) {
            CalibrationView(calibrationData: $newCalibrationData) {}
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

    // MARK: - Measurement Button Section
    // ═══════════════════════════════════════
    // PURPOSE: 상단 고정 측정 버튼
    // ═══════════════════════════════════════
    private var measurementButtonSection: some View {
        Button(action: { showingNewCalibration = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("측정하기")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        themeManager.gradientStart,
                        themeManager.gradientEnd
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Empty State Section
    // ═══════════════════════════════════════
    // PURPOSE: 기록 없음 상태 표시
    // ═══════════════════════════════════════
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

                Text("측정하기 버튼을 눌러 100m 측정을 시작하세요")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading Section
    // ═══════════════════════════════════════
    // PURPOSE: 로딩 중 상태 표시
    // ═══════════════════════════════════════
    private var loadingSection: some View {
        VStack {
            Spacer()
            ProgressView("로딩 중...")
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .foregroundColor(.white)
            Spacer()
        }
    }

    // MARK: - Records List Section
    // ═══════════════════════════════════════
    // PURPOSE: 기록 리스트 (스크롤 가능)
    // ═══════════════════════════════════════
    private var recordsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(calibrator.calibrationRecords.enumerated()),
                       id: \.element.measuredAt) { index, record in
                    calibrationRecordCard(record: record, index: index)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Calibration Record Card
    // ═══════════════════════════════════════
    // PURPOSE: 개별 기록 카드
    // ═══════════════════════════════════════
    private func calibrationRecordCard(record: CalibrationData, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Record number + Date + Delete button
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

            // Metrics: Stride + Steps + Cadence
            HStack(spacing: 20) {
                // Stride
                metricColumn(
                    title: "평균 보폭",
                    value: String(format: "%.2f m", record.averageStepLength)
                )

                // Steps
                metricColumn(
                    title: "걸음 수",
                    value: "\(record.totalSteps)걸음"
                )

                // Cadence
                metricColumn(
                    title: "케이던스",
                    value: String(format: "%.1f SPM", record.averageCadence)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Metric Column
    // ═══════════════════════════════════════
    // PURPOSE: 메트릭 컬럼 (보폭/걸음/케이던스)
    // ═══════════════════════════════════════
    private func metricColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 기록 삭제
    // ═══════════════════════════════════════
    private func deleteRecord(_ record: CalibrationData) async {
        if let index = calibrator.calibrationRecords.firstIndex(where: { $0.measuredAt == record.measuredAt }) {
            await calibrator.removeCalibrationRecord(at: index)
        }
    }

    // ═══════════════════════════════════════
    // PURPOSE: 날짜 포맷 (yyyy년 MM월 dd일 HH:mm)
    // ═══════════════════════════════════════
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
        return formatter.string(from: date)
    }
}
