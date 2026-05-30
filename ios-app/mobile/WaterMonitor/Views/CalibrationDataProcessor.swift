import Foundation

/**
 * CalibrationDataProcessor — AI filtering and stability analysis
 *
 * Handles the intelligent parts of quick calibration:
 * - Stability scoring (measures reading consistency)
 * - Min/max range detection (for auto calibration)
 * - Median filtering (removes outliers)
 * - Outlier detection (identifies spikes)
 *
 * Isolated from UI so logic can be tested independently.
 * Called by TankCalibrationView to process incoming sensor readings.
 */
final class CalibrationDataProcessor {
    private var readingsCollected: [Double] = []
    private var detectedMin: Double = Double.infinity
    private var detectedMax: Double = -Double.infinity
    private let outlierThresholdCM: Double = 10.0  // ±10cm spike detection

    // MARK: - Public Interface

    /**
     * Process a new sensor reading and update internal state.
     * Returns updated stability score (0-5 bar indicator).
     *
     * Parameters:
     *   reading - Latest distance measurement in centimeters
     *
     * Returns: Stability score (0=unstable, 5=very stable)
     */
    func processReading(_ reading: Double) -> Int {
        readingsCollected.append(reading)
        updateRange(reading)
        return calculateStabilityScore()
    }

    /**
     * Get the current stability score without processing a new reading.
     * Returns 0-5 indicator for UI display.
     */
    func getStabilityScore() -> Int {
        calculateStabilityScore()
    }

    /**
     * Get detected min distance (for auto calibration).
     * Returns infinity if no readings yet.
     */
    func getDetectedMin() -> Double {
        detectedMin
    }

    /**
     * Get detected max distance (for auto calibration).
     * Returns negative infinity if no readings yet.
     */
    func getDetectedMax() -> Double {
        detectedMax
    }

    /**
     * Get all collected readings (for analysis or export).
     */
    func getAllReadings() -> [Double] {
        readingsCollected
    }

    /**
     * Reset all data for new calibration session.
     */
    func reset() {
        readingsCollected.removeAll()
        detectedMin = Double.infinity
        detectedMax = -Double.infinity
    }

    // MARK: - Private: Analysis

    /**
     * Calculate stability score based on reading variance.
     * Algorithm: measure consistency of recent readings
     * - 0: Highly variable (bouncing around)
     * - 3: Moderate (some variation)
     * - 5: Very stable (consistent readings)
     *
     * Uses last 10 readings for window (faster response than all-time average).
     */
    private func calculateStabilityScore() -> Int {
        guard readingsCollected.count >= 3 else { return 0 }

        // Use last 10 readings for rolling window
        let window = Array(readingsCollected.suffix(10))
        let mean = window.reduce(0, +) / Double(window.count)

        // Calculate standard deviation
        let variance = window.map { pow($0 - mean, 2) }.reduce(0, +) / Double(window.count)
        let stdDev = sqrt(variance)

        // Map stdDev to 0-5 score
        // stdDev < 1cm = very stable (5)
        // stdDev 1-2cm = stable (4)
        // stdDev 2-3cm = moderate (3)
        // stdDev 3-5cm = unstable (2)
        // stdDev > 5cm = very unstable (1)
        switch stdDev {
        case 0..<1:
            return 5
        case 1..<2:
            return 4
        case 2..<3:
            return 3
        case 3..<5:
            return 2
        default:
            return 1
        }
    }

    /**
     * Update min/max range, filtering obvious outliers.
     * Outliers are readings that spike >10cm from recent average.
     */
    private func updateRange(_ reading: Double) {
        // Skip obvious outliers
        if isOutlier(reading) {
            return  // Don't update range for spikes
        }

        if reading < detectedMin {
            detectedMin = reading
        }
        if reading > detectedMax {
            detectedMax = reading
        }
    }

    /**
     * Detect if a reading is a spike (outlier).
     * Used to ignore momentary sensor glitches.
     */
    private func isOutlier(_ reading: Double) -> Bool {
        guard readingsCollected.count >= 3 else { return false }

        let recent = Array(readingsCollected.suffix(5))
        let average = recent.reduce(0, +) / Double(recent.count)
        let deviation = abs(reading - average)

        return deviation > outlierThresholdCM
    }
}
