import Foundation
import Combine

// Purpose: 센서 데이터를 CSV 파일로 저장하는 서비스
// MARK: - 함수 목록
/*
 * Data Collection
 * - startRecording(): 센서 데이터 수집 시작
 * - stopRecording(): 센서 데이터 수집 중지 및 반환
 * - addSensorData(_:): 센서 데이터 추가
 *
 * CSV Export
 * - exportToCSV(data:): 센서 데이터 배열을 CSV 파일로 저장
 * - generateCSVContent(from:): CSV 문자열 생성
 * - saveToFile(_:): CSV 문자열을 파일로 저장
 */

class SensorDataExporter: ObservableObject {

    // MARK: - Published Properties

    // Purpose: 녹화 중 여부
    @Published var isRecording = false

    // Purpose: 녹화된 데이터 개수
    @Published var recordedCount = 0

    // MARK: - Private Properties

    // Purpose: 녹화 중인 센서 데이터 배열
    private var recordedData: [SensorData] = []

    // Purpose: 녹화 시작 시간
    private var recordingStartTime: Date?

    // MARK: - Data Collection

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터 수집 시작
    // ═══════════════════════════════════════
    func startRecording() {
        recordedData.removeAll()
        recordingStartTime = Date()
        isRecording = true
        recordedCount = 0
        print("📊 센서 데이터 녹화 시작")
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터 수집 중지 및 반환
    // ═══════════════════════════════════════
    func stopRecording() -> [SensorData] {
        isRecording = false
        let data = recordedData
        print("📊 센서 데이터 녹화 중지 (\(data.count)개 샘플)")
        return data
    }

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터 추가
    // ═══════════════════════════════════════
    func addSensorData(_ data: SensorData) {
        guard isRecording else { return }
        recordedData.append(data)
        recordedCount = recordedData.count
    }

    // MARK: - CSV Export

    // ═══════════════════════════════════════
    // PURPOSE: 센서 데이터 배열을 CSV 파일로 저장
    // RETURNS: 저장된 파일 URL (공유를 위해 반환)
    // ═══════════════════════════════════════
    func exportToCSV(data: [SensorData]) throws -> URL {
        // Step 1: CSV 문자열 생성
        let csvContent = generateCSVContent(from: data)

        // Step 2: 파일로 저장
        let fileURL = try saveToFile(csvContent)

        print("✅ CSV 파일 저장 완료: \(fileURL.path)")
        return fileURL
    }

    // ═══════════════════════════════════════
    // PURPOSE: CSV 문자열 생성
    // ═══════════════════════════════════════
    private func generateCSVContent(from data: [SensorData]) -> String {
        // Step 1: CSV 헤더 생성
        var csvString = "Timestamp,Heart Rate (bpm),Accelerometer X (g),Accelerometer Y (g),Accelerometer Z (g),Gyroscope X (rad/s),Gyroscope Y (rad/s),Gyroscope Z (rad/s)\n"

        // Step 2: 각 센서 데이터를 CSV 행으로 변환
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for sensorData in data {
            let timestamp = dateFormatter.string(from: sensorData.timestamp)
            let heartRate = sensorData.heartRate.map { String(format: "%.1f", $0) } ?? ""

            let row = [
                timestamp,
                heartRate,
                String(format: "%.6f", sensorData.accelerometerX),
                String(format: "%.6f", sensorData.accelerometerY),
                String(format: "%.6f", sensorData.accelerometerZ),
                String(format: "%.6f", sensorData.gyroscopeX),
                String(format: "%.6f", sensorData.gyroscopeY),
                String(format: "%.6f", sensorData.gyroscopeZ)
            ].joined(separator: ",")

            csvString += row + "\n"
        }

        return csvString
    }

    // ═══════════════════════════════════════
    // PURPOSE: CSV 문자열을 파일로 저장
    // RETURNS: 저장된 파일 URL
    // ═══════════════════════════════════════
    private func saveToFile(_ csvString: String) throws -> URL {
        // Step 1: 파일명 생성 (타임스탬프 포함)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "SensorData_\(timestamp).csv"

        // Step 2: Documents 디렉토리 경로 가져오기
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw NSError(
                domain: "SensorDataExporter",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Documents 디렉토리를 찾을 수 없습니다"]
            )
        }

        // Step 3: 파일 URL 생성
        let fileURL = documentsDirectory.appendingPathComponent(fileName)

        // Step 4: 파일 쓰기
        try csvString.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    // MARK: - Helper Methods

    // ═══════════════════════════════════════
    // PURPOSE: 녹화 시간 계산 (초 단위)
    // ═══════════════════════════════════════
    func getRecordingDuration() -> TimeInterval? {
        guard let startTime = recordingStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
}
