import Foundation

actor ScanEngine {
    private let fileManager = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    // MARK: - Public API

    func scanCategory(_ category: CleaningCategory) async -> CategoryResult {
        switch category {
        case .smartScan:
            return CategoryResult(category: category, items: [], totalSize: 0)
        case .systemJunk:
            return await scanSystemJunk()
        case .userCache:
            return await scanUserCache()
        case .mailAttachments:
            return await scanMailAttachments()
        case .trashBins:
            return await scanTrash()
        case .largeFiles:
            return await scanLargeFiles()
        case .purgeableSpace:
            return await scanPurgeableSpace()
        case .xcodeJunk:
            return await scanXcodeJunk()
        case .brewCache:
            return await scanBrewCache()
        }
    }

    func getDiskInfo() -> DiskInfo {
        var info = DiskInfo()
        do {
            let attrs = try fileManager.attributesOfFileSystem(forPath: "/")
            if let total = attrs[.systemSize] as? Int64 {
                info.totalSpace = total
            }
            if let free = attrs[.systemFreeSize] as? Int64 {
                info.freeSpace = free
            }
            info.usedSpace = info.totalSpace - info.freeSpace

            // Get purgeable space via diskutil
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            task.arguments = ["info", "/"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    if line.contains("Purgeable") || line.contains("Container Free Space") {
                        let parts = line.components(separatedBy: "(")
                        if parts.count > 1 {
                            let bytesStr = parts[1]
                                .components(separatedBy: " Bytes")[0]
                                .trimmingCharacters(in: .whitespaces)
                            if let bytes = Int64(bytesStr) {
                                info.purgeableSpace = bytes
                            }
                        }
                    }
                }
            }
        } catch {
            // Silently fail - disk info is supplementary
        }
        return info
    }

    // MARK: - Scanners

    private func scanSystemJunk() async -> CategoryResult {
        var items: [CleanableItem] = []
        var totalSize: Int64 = 0

        let systemPaths = [
            "/Library/Caches",
            "/Library/Logs",
            "/private/var/log",
            "\(home)/Library/Logs",
            "/tmp",
            "/private/var/tmp",
        ]

        for path in systemPaths {
            let scanned = scanDirectory(path: path, category: .systemJunk, recursive: true, maxDepth: 3)
            items.append(contentsOf: scanned)
        }

        totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .systemJunk, items: items, totalSize: totalSize)
    }

    private func scanUserCache() async -> CategoryResult {
        var items: [CleanableItem] = []

        let cachePaths = [
            "\(home)/Library/Caches",
            "\(home)/Library/Caches/com.apple.Safari",
            "\(home)/Library/Caches/Google/Chrome",
            "\(home)/Library/Caches/Firefox",
            "\(home)/Library/Caches/com.spotify.client",
            "\(home)/Library/Caches/com.microsoft.VSCode",
            "\(home)/Library/Caches/Slack",
        ]

        for path in cachePaths {
            let scanned = scanDirectory(path: path, category: .userCache, recursive: false, maxDepth: 1)
            items.append(contentsOf: scanned)
        }

        // Also scan for npm/pip/yarn caches
        let devCaches = [
            "\(home)/.npm/_cacache",
            "\(home)/.cache/pip",
            "\(home)/.cache/yarn",
            "\(home)/.cache/pnpm",
            "\(home)/Library/Caches/pip",
        ]

        for path in devCaches {
            if fileManager.fileExists(atPath: path) {
                let size = directorySize(path: path)
                if size > 0 {
                    items.append(CleanableItem(
                        name: URL(fileURLWithPath: path).lastPathComponent,
                        path: path,
                        size: size,
                        category: .userCache,
                        isSelected: true,
                        lastModified: nil
                    ))
                }
            }
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .userCache, items: items, totalSize: totalSize)
    }

    private func scanMailAttachments() async -> CategoryResult {
        var items: [CleanableItem] = []

        let mailPaths = [
            "\(home)/Library/Mail Downloads",
            "\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
        ]

        for path in mailPaths {
            let scanned = scanDirectory(path: path, category: .mailAttachments, recursive: true, maxDepth: 3)
            items.append(contentsOf: scanned)
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .mailAttachments, items: items, totalSize: totalSize)
    }

    private func scanTrash() async -> CategoryResult {
        var items: [CleanableItem] = []

        let trashPath = "\(home)/.Trash"
        let scanned = scanDirectory(path: trashPath, category: .trashBins, recursive: false, maxDepth: 1)
        items.append(contentsOf: scanned)

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .trashBins, items: items, totalSize: totalSize)
    }

    private func scanLargeFiles() async -> CategoryResult {
        var items: [CleanableItem] = []
        let minSize: Int64 = 100 * 1024 * 1024 // 100 MB
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!

        let searchPaths = [
            "\(home)/Downloads",
            "\(home)/Documents",
            "\(home)/Desktop",
        ]

        for basePath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: basePath),
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            var depth = 0
            for case let fileURL as URL in enumerator {
                depth += 1
                if depth > 5000 { break } // Safety limit

                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                      let isFile = resourceValues.isRegularFile, isFile,
                      let fileSize = resourceValues.fileSize
                else { continue }

                let size = Int64(fileSize)
                let modDate = resourceValues.contentModificationDate

                if size > minSize || (modDate != nil && modDate! < oneYearAgo && size > 10 * 1024 * 1024) {
                    items.append(CleanableItem(
                        name: fileURL.lastPathComponent,
                        path: fileURL.path,
                        size: size,
                        category: .largeFiles,
                        isSelected: false, // Don't auto-select large files
                        lastModified: modDate
                    ))
                }
            }
        }

        items.sort { $0.size > $1.size }
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .largeFiles, items: items, totalSize: totalSize)
    }

    private func scanPurgeableSpace() async -> CategoryResult {
        let diskInfo = getDiskInfo()
        var items: [CleanableItem] = []

        if diskInfo.purgeableSpace > 0 {
            items.append(CleanableItem(
                name: "APFS Purgeable Space",
                path: "/",
                size: diskInfo.purgeableSpace,
                category: .purgeableSpace,
                isSelected: true,
                lastModified: nil
            ))
        }

        return CategoryResult(category: .purgeableSpace, items: items, totalSize: diskInfo.purgeableSpace)
    }

    private func scanXcodeJunk() async -> CategoryResult {
        var items: [CleanableItem] = []

        let xcodePaths = [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/Archives",
            "\(home)/Library/Developer/CoreSimulator/Caches",
            "\(home)/Library/Caches/com.apple.dt.Xcode",
        ]

        for path in xcodePaths {
            if fileManager.fileExists(atPath: path) {
                let size = directorySize(path: path)
                if size > 0 {
                    items.append(CleanableItem(
                        name: URL(fileURLWithPath: path).lastPathComponent,
                        path: path,
                        size: size,
                        category: .xcodeJunk,
                        isSelected: true,
                        lastModified: nil
                    ))
                }
            }
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .xcodeJunk, items: items, totalSize: totalSize)
    }

    private func scanBrewCache() async -> CategoryResult {
        var items: [CleanableItem] = []

        // Homebrew cache location
        let brewCachePaths = [
            "\(home)/Library/Caches/Homebrew",
            "/opt/homebrew/Caskroom/.metadata",
        ]

        for path in brewCachePaths {
            if fileManager.fileExists(atPath: path) {
                let size = directorySize(path: path)
                if size > 0 {
                    items.append(CleanableItem(
                        name: URL(fileURLWithPath: path).lastPathComponent,
                        path: path,
                        size: size,
                        category: .brewCache,
                        isSelected: true,
                        lastModified: nil
                    ))
                }
            }
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .brewCache, items: items, totalSize: totalSize)
    }

    // MARK: - Helpers

    private func scanDirectory(path: String, category: CleaningCategory, recursive: Bool, maxDepth: Int) -> [CleanableItem] {
        var items: [CleanableItem] = []

        guard fileManager.fileExists(atPath: path),
              fileManager.isReadableFile(atPath: path) else { return [] }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for item in contents {
                let fullPath = (path as NSString).appendingPathComponent(item)

                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

                if isDir.boolValue {
                    let size = directorySize(path: fullPath)
                    if size > 1024 { // Skip tiny entries
                        items.append(CleanableItem(
                            name: item,
                            path: fullPath,
                            size: size,
                            category: category,
                            isSelected: true,
                            lastModified: fileModDate(path: fullPath)
                        ))
                    }
                } else {
                    if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64, size > 1024 {
                        items.append(CleanableItem(
                            name: item,
                            path: fullPath,
                            size: size,
                            category: category,
                            isSelected: true,
                            lastModified: attrs[.modificationDate] as? Date
                        ))
                    }
                }
            }
        } catch {
            // Permission denied or other error - skip silently
        }

        return items
    }

    private func directorySize(path: String) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var count = 0
        for case let fileURL as URL in enumerator {
            count += 1
            if count > 10000 { break } // Safety limit for very large directories

            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  let isFile = values.isRegularFile, isFile,
                  let size = values.fileSize else { continue }
            totalSize += Int64(size)
        }

        return totalSize
    }

    private func fileModDate(path: String) -> Date? {
        try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }
}
