package class Ptr<T> {
    public var v: T

    init(ref: inout T) {
        self.v = ref
    }
}
