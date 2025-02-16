// Ptr acts as a shared pointer to a value.
// It takes ownership of the provided value,
// and then copies of the Ptr will reference the
// same owned copy.
package final class Ptr<T> {
    public var v: T

    init(toCopyOf v: T) {
        self.v = v
    }
}
