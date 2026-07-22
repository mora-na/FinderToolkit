import Foundation
import CryptoKit
import CommonCrypto

struct SM3Hasher {
    private var state: [UInt32] = [
        0x7380166f, 0x4914b2b9, 0x172442d7, 0xda8a0600,
        0xa96f30bc, 0x163138aa, 0xe38dee4d, 0xb0fb0e4e
    ]
    private var buffer: [UInt8] = []
    private var totalByteCount: UInt64 = 0

    mutating func update(data: Data) {
        totalByteCount &+= UInt64(data.count)
        data.withUnsafeBytes { bytes in
            var offset = 0

            if !buffer.isEmpty {
                let count = min(64 - buffer.count, bytes.count)
                buffer.append(contentsOf: bytes.prefix(count))
                offset += count
                if buffer.count == 64 {
                    buffer.withUnsafeBytes { compress(block: $0, offset: 0) }
                    buffer.removeAll(keepingCapacity: true)
                }
            }

            while offset + 64 <= bytes.count {
                compress(block: bytes, offset: offset)
                offset += 64
            }

            if offset < bytes.count {
                buffer.append(contentsOf: bytes[offset...])
            }
        }
    }

    mutating func finalize() -> [UInt8] {
        var finalBlock = buffer
        finalBlock.append(0x80)
        while finalBlock.count % 64 != 56 {
            finalBlock.append(0)
        }

        let bitLength = totalByteCount &* 8
        for shift in stride(from: 56, through: 0, by: -8) {
            finalBlock.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        finalBlock.withUnsafeBytes { bytes in
            for offset in stride(from: 0, to: bytes.count, by: 64) {
                compress(block: bytes, offset: offset)
            }
        }

        return state.flatMap { value in
            [
                UInt8(truncatingIfNeeded: value >> 24),
                UInt8(truncatingIfNeeded: value >> 16),
                UInt8(truncatingIfNeeded: value >> 8),
                UInt8(truncatingIfNeeded: value)
            ]
        }
    }

    private mutating func compress(block: UnsafeRawBufferPointer, offset: Int) {
        var words = [UInt32](repeating: 0, count: 68)
        var expanded = [UInt32](repeating: 0, count: 64)

        for index in 0..<16 {
            let start = offset + index * 4
            words[index] = (UInt32(block[start]) << 24)
                | (UInt32(block[start + 1]) << 16)
                | (UInt32(block[start + 2]) << 8)
                | UInt32(block[start + 3])
        }

        for index in 16..<68 {
            words[index] = p1(words[index - 16] ^ words[index - 9] ^ rotateLeft(words[index - 3], by: 15))
                ^ rotateLeft(words[index - 13], by: 7)
                ^ words[index - 6]
        }
        for index in 0..<64 {
            expanded[index] = words[index] ^ words[index + 4]
        }

        var a = state[0]
        var b = state[1]
        var c = state[2]
        var d = state[3]
        var e = state[4]
        var f = state[5]
        var g = state[6]
        var h = state[7]

        for index in 0..<64 {
            let constant: UInt32 = index < 16 ? 0x79cc4519 : 0x7a879d8a
            let a12 = rotateLeft(a, by: 12)
            let ss1 = rotateLeft(a12 &+ e &+ rotateLeft(constant, by: index), by: 7)
            let ss2 = ss1 ^ a12
            let tt1 = ff(a, b, c, round: index) &+ d &+ ss2 &+ expanded[index]
            let tt2 = gg(e, f, g, round: index) &+ h &+ ss1 &+ words[index]
            d = c
            c = rotateLeft(b, by: 9)
            b = a
            a = tt1
            h = g
            g = rotateLeft(f, by: 19)
            f = e
            e = p0(tt2)
        }

        state[0] ^= a
        state[1] ^= b
        state[2] ^= c
        state[3] ^= d
        state[4] ^= e
        state[5] ^= f
        state[6] ^= g
        state[7] ^= h
    }

    private func rotateLeft(_ value: UInt32, by amount: Int) -> UInt32 {
        let shift = UInt32(amount % 32)
        guard shift != 0 else { return value }
        return (value << shift) | (value >> (32 - shift))
    }

    private func ff(_ x: UInt32, _ y: UInt32, _ z: UInt32, round: Int) -> UInt32 {
        round < 16 ? (x ^ y ^ z) : ((x & y) | (x & z) | (y & z))
    }

    private func gg(_ x: UInt32, _ y: UInt32, _ z: UInt32, round: Int) -> UInt32 {
        round < 16 ? (x ^ y ^ z) : ((x & y) | (~x & z))
    }

    private func p0(_ value: UInt32) -> UInt32 {
        value ^ rotateLeft(value, by: 9) ^ rotateLeft(value, by: 17)
    }

    private func p1(_ value: UInt32) -> UInt32 {
        value ^ rotateLeft(value, by: 15) ^ rotateLeft(value, by: 23)
    }
}

struct HashCalculator {

    static func calculate(
        for url: URL,
        algorithms: [String]? = nil,
        progressHandler: ((Double) -> Void)? = nil,
        cancellationToken: HashCancellationToken? = nil
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
                cancellationToken: cancellationToken
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
        cancellationToken: HashCancellationToken?
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
        var sm3Hasher = SM3Hasher()

        if enabled.contains("MD5") { CC_MD5_Init(&md5Context) }
        if enabled.contains("SHA1") { CC_SHA1_Init(&sha1Context) }
        if enabled.contains("SHA224") { CC_SHA224_Init(&sha224Context) }

        let bufferSize = 4 * 1024 * 1024
        var totalBytesRead: Int64 = 0

        while true {
            try checkCancelled(cancellationToken)
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
            if enabled.contains("SM3") {
                sm3Hasher.update(data: data)
            }

            totalBytesRead += Int64(data.count)
            if fileSize > 0 {
                progressHandler?(min(1, Double(totalBytesRead) / Double(fileSize)))
            }
        }

        try checkCancelled(cancellationToken)
        progressHandler?(1)

        return HashResult(
            crc32: enabled.contains("CRC32") ? String(format: "%08x", crc32 ^ 0xffffffff) : "-",
            crc32c: enabled.contains("CRC32C") ? String(format: "%08x", crc32c ^ 0xffffffff) : "-",
            md5: enabled.contains("MD5") ? finalizeMD5(&md5Context) : "-",
            sha1: enabled.contains("SHA1") ? finalizeSHA1(&sha1Context) : "-",
            sha224: enabled.contains("SHA224") ? finalizeSHA224(&sha224Context) : "-",
            sha256: enabled.contains("SHA256") ? hex(sha256Hasher.finalize()) : "-",
            sha384: enabled.contains("SHA384") ? hex(sha384Hasher.finalize()) : "-",
            sha512: enabled.contains("SHA512") ? hex(sha512Hasher.finalize()) : "-",
            sm3: enabled.contains("SM3") ? hex(sm3Hasher.finalize()) : "-"
        )
    }

    private static func fileSizeInBytes(url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }

    private static func checkCancelled(_ cancellationToken: HashCancellationToken?) throws {
        if cancellationToken?.isCancelled == true {
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
