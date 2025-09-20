import Foundation

/// Tracks and reports statistics during indexing operations
class IndexingStatistics {
    private(set) var symlinkCount = 0
    private(set) var totalProcessed = 0
    private(set) var excludedPathCount = 0
    private(set) var rebuiltCount = 0
    private let startTime: Date
    private let logger = LoggingService.shared

    init() {
        self.startTime = Date()
    }

    func incrementSymlinkCount() {
        symlinkCount += 1
    }

    func incrementExcludedCount() {
        excludedPathCount += 1
    }

    func incrementProcessedCount() {
        totalProcessed += 1
    }


    func addProcessedCount(_ count: Int) {
        totalProcessed += count
    }

    func addRebuiltCount(_ count: Int) {
        rebuiltCount += count
    }


    /// Print statistics for full indexing
    func printFullIndexingStats(totalCount: Int, dbCount: Int) {
        let elapsed = Date().timeIntervalSince(startTime)
        logger.performanceInfo("Full indexing completed in \(String(format: "%.2f", elapsed)) seconds")
        logger.performanceInfo("Rate: \(Int(Double(totalCount) / elapsed)) files/second")
        logger.performanceInfo("Statistics:")
        logger.performanceInfo("  • Total processed: \(totalProcessed)")
        logger.performanceInfo("  • Actually stored in DB: \(dbCount)")
        logger.performanceInfo("  • Excluded paths: \(excludedPathCount)")
        logger.performanceInfo("  • Symlinks skipped: \(symlinkCount)")
    }

    /// Print statistics for smart reindexing
    func printSmartReindexingStats(changedDirs: Int, dbCount: Int) {
        let elapsed = Date().timeIntervalSince(startTime)
        logger.performanceInfo("Smart reindexing completed in \(String(format: "%.2f", elapsed)) seconds")
        logger.performanceInfo("Statistics:")
        logger.performanceInfo("  • Changed directories rebuilt: \(changedDirs)")
        logger.performanceInfo("  • Total entries rebuilt: \(rebuiltCount)")
        logger.performanceInfo("  • Final DB count: \(dbCount)")
        if rebuiltCount > 0 {
            logger.performanceInfo("Rate: \(Int(Double(rebuiltCount) / elapsed)) files/second")
        }
    }

}