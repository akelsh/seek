import Foundation

/// Tracks and reports statistics during indexing operations
class IndexingStatistics {
    private(set) var symlinkCount = 0
    private(set) var totalProcessed = 0
    private(set) var excludedPathCount = 0
    private(set) var rebuiltCount = 0
    private let startTime: Date

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
        print("✅ Full indexing completed in \(String(format: "%.2f", elapsed)) seconds")
        print("📊 Rate: \(Int(Double(totalCount) / elapsed)) files/second")
        print("📈 Statistics:")
        print("  • Total processed: \(totalProcessed)")
        print("  • Actually stored in DB: \(dbCount)")
        print("  • Excluded paths: \(excludedPathCount)")
        print("  • Symlinks skipped: \(symlinkCount)")
    }

    /// Print statistics for smart reindexing
    func printSmartReindexingStats(changedDirs: Int, dbCount: Int) {
        let elapsed = Date().timeIntervalSince(startTime)
        print("✅ Smart reindexing completed in \(String(format: "%.2f", elapsed)) seconds")
        print("📈 Statistics:")
        print("  • Changed directories rebuilt: \(changedDirs)")
        print("  • Total entries rebuilt: \(rebuiltCount)")
        print("  • Final DB count: \(dbCount)")
        if rebuiltCount > 0 {
            print("📊 Rate: \(Int(Double(rebuiltCount) / elapsed)) files/second")
        }
    }

}