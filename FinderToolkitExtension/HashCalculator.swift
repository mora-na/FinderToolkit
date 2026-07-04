import Foundation
import CryptoKit
import CommonCrypto

struct HashCalculator {

    static func calculate(
        for url: URL,
        algorithms: [String]? = nil,
        progressHandler: ((Double) -> Void)? = nil,
        isCancelled: UnsafeMutablePointer<Bool>? = nil
    ) -> Result<HashResult, HashError> {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound)
        }

        let fileSize = fileSizeInBytes(url: url)
        let enabled = Set(algorithms ?? defaultHashAlgorithms)

        do {
            let result = try calculateSinglePass(
                url: url,
                fileSize: fileSize,
                enabled: enabled,
                progressHandler: progressHandler,
                isCancelled: isCancelled
            )
            return .success(result)
        } catch let error as HashError {
            return .failure(error)
        } catch {
            return .failure(.readFailed)
        }
    }

    private static func calculateSinglePass(
        url: URL,
        fileSize: Int64,
        enabled: Set<String>,
        progressHandler: ((Double) -> Void)?,
        isCancelled: UnsafeMutablePointer<Bool>?
    ) throws -> HashResult {
        guard let file = FileHandle(forReadingAtPath: url.path) else {
            throw HashError.readFailed
        }
        defer { file.closeFile() }

        var crc32 = UInt32(0xffffffff)
        var crc32c = UInt32(0xffffffff)

        var md5Context = CC_MD5_CTX()
        var sha1Context = CC_SHA1_CTX()
        var sha224Context = CC_SHA256_CTX()
        var sha256Hasher = SHA256()
        var sha384Hasher = SHA384()
        var sha512Hasher = SHA512()

        if enabled.contains("MD5") { CC_MD5_Init(&md5Context) }
        if enabled.contains("SHA1") { CC_SHA1_Init(&sha1Context) }
        if enabled.contains("SHA224") { CC_SHA224_Init(&sha224Context) }

        let bufferSize = 4 * 1024 * 1024
        var totalBytesRead: Int64 = 0

        while true {
            try checkCancelled(isCancelled)
            let data = file.readData(ofLength: bufferSize)
            guard !data.isEmpty else { break }

            if enabled.contains("CRC32") {
                updateCRC(&crc32, with: data, polynomial: 0xedb88320)
            }
            if enabled.contains("CRC32C") {
                updateCRC(&crc32c, with: data, polynomial: 0x82f63b78)
            }
            if enabled.contains("MD5") {
                data.withUnsafeBytes {
                    _ = CC_MD5_Update(&md5Context, $0.baseAddress, CC_LONG(data.count))
                }
            }
            if enabled.contains("SHA1") {
                data.withUnsafeBytes {
                    _ = CC_SHA1_Update(&sha1Context, $0.baseAddress, CC_LONG(data.count))
                }
            }
            if enabled.contains("SHA224") {
                data.withUnsafeBytes {
                    _ = CC_SHA224_Update(&sha224Context, $0.baseAddress, CC_LONG(data.count))
                }
            }
            if enabled.contains("SHA256") {
                sha256Hasher.update(data: data)
            }
            if enabled.contains("SHA384") {
                sha384Hasher.update(data: data)
            }
            if enabled.contains("SHA512") {
                sha512Hasher.update(data: data)
            }

            totalBytesRead += Int64(data.count)
            if fileSize > 0 {
                progressHandler?(min(1, Double(totalBytesRead) / Double(fileSize)))
            }
        }

        try checkCancelled(isCancelled)
        progressHandler?(1)

        return HashResult(
            crc32: enabled.contains("CRC32") ? String(format: "%08x", crc32 ^ 0xffffffff) : "-",
            crc32c: enabled.contains("CRC32C") ? String(format: "%08x", crc32c ^ 0xffffffff) : "-",
            md5: enabled.contains("MD5") ? finalizeMD5(&md5Context) : "-",
            sha1: enabled.contains("SHA1") ? finalizeSHA1(&sha1Context) : "-",
            sha224: enabled.contains("SHA224") ? finalizeSHA224(&sha224Context) : "-",
            sha256: enabled.contains("SHA256") ? hex(sha256Hasher.finalize()) : "-",
            sha384: enabled.contains("SHA384") ? hex(sha384Hasher.finalize()) : "-",
            sha512: enabled.contains("SHA512") ? hex(sha512Hasher.finalize()) : "-"
        )
    }

    private static func fileSizeInBytes(url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private static func checkCancelled(_ isCancelled: UnsafeMutablePointer<Bool>?) throws {
        if let ptr = isCancelled, ptr.pointee {
            throw HashError.cancelled
        }
    }

    private static func updateCRC(_ crc: inout UInt32, with data: Data, polynomial: UInt32) {
        for byte in data {
            var value = (crc ^ UInt32(byte)) & 0xff
            for _ in 0..<8 {
                value = (value & 1) == 1 ? (polynomial ^ (value >> 1)) : (value >> 1)
            }
            crc = (crc >> 8) ^ value
        }
    }

    private static func finalizeMD5(_ context: inout CC_MD5_CTX) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5_Final(&digest, &context)
        return hex(digest)
    }

    private static func finalizeSHA1(_ context: inout CC_SHA1_CTX) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        CC_SHA1_Final(&digest, &context)
        return hex(digest)
    }

    private static func finalizeSHA224(_ context: inout CC_SHA256_CTX) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA224_DIGEST_LENGTH))
        CC_SHA224_Final(&digest, &context)
        return hex(digest)
    }

    private static func hex<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
