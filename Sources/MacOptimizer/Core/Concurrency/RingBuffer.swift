import Foundation

/// Fixed-capacity FIFO buffer. Appending beyond `capacity` evicts the oldest element,
/// so memory stays constant no matter how long the app runs.
public struct RingBuffer<Element>: RandomAccessCollection {
    public let capacity: Int
    private var storage: [Element] = []
    private var head = 0 // index of the oldest element once storage is full

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    public var startIndex: Int { 0 }
    public var endIndex: Int { storage.count }

    public subscript(position: Int) -> Element {
        storage[(head + position) % storage.count]
    }

    public mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[head] = element
            head = (head + 1) % capacity
        }
    }

    public mutating func append<S: Sequence>(contentsOf elements: S) where S.Element == Element {
        for element in elements { append(element) }
    }

    public mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
        head = 0
    }

    /// Elements ordered oldest → newest.
    public var elements: [Element] { Array(self) }
}

extension RingBuffer: Sendable where Element: Sendable {}
extension RingBuffer: Equatable where Element: Equatable {
    public static func == (lhs: RingBuffer, rhs: RingBuffer) -> Bool {
        lhs.capacity == rhs.capacity && lhs.elementsEqual(rhs)
    }
}

extension Array {
    /// Inserts at the front and trims the tail so the array never exceeds `limit`.
    mutating func prependBounded(_ element: Element, limit: Int) {
        insert(element, at: 0)
        if count > limit { removeLast(count - limit) }
    }

    /// Appends and trims the head so the array never exceeds `limit`.
    mutating func appendBounded(_ element: Element, limit: Int) {
        append(element)
        if count > limit { removeFirst(count - limit) }
    }
}
