import Foundation

/// Geri çağrılardan gelen değerleri iş parçacığı güvenli biçimde toplar.
final class Collected<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [T] = []

    func add(_ item: T) { lock.withLock { items.append(item) } }
    var all: [T] { lock.withLock { items } }
}
