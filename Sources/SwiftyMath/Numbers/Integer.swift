import Foundation

public typealias 𝐙 = Int

fileprivate var _primes: [𝐙] = []

extension 𝐙: EuclideanRing {
    public init(from n: 𝐙) {
        self.init(n)
    }

    public var inverse: 𝐙? {
        return (self.abs == 1) ? self : nil
    }

    public var normalizeUnit: 𝐙 {
        return (self > 0) ? 1 : -1
    }

    public var degree: Int {
        return Swift.abs(self)
    }

    public var sign: 𝐙 {
        return (self >  0) ? 1 :
               (self == 0) ? 0 :
                            -1
    }

    public var abs: 𝐙 {
        return (self >= 0) ? self : -self
    }

    public var isEven: Bool {
        return (self % 2 == 0)
    }

    public func pow(_ n: 𝐙) -> 𝐙 {
        switch  self {
        case 1:
            return 1
        case -1:
            return n.isEven ? 1 : -1
        default:
            assert(n >= 0)
            return (0 ..< n).reduce(1){ (res, _) in self * res }
        }
    }

    public var factorial: 𝐙 {
        if self < 0 {
            fatalError("factorial of negative number.")
        }
        return (self == 0) ? 1 : self * (self - 1).factorial
    }

    public func eucDiv(by b: 𝐙) -> (q: 𝐙, r: 𝐙) {
        let a = self
        let q = a / b
        return (q: q, r: a - q * b)
    }

    public static func primes(upto n: 𝐙) -> [𝐙] {
        if let last = _primes.last, n <= last {
            return _primes.filter{ $0 <= n }
        }

        var result: [𝐙] = []
        var seive = _primes + Array( (_primes.last ?? 1) + 1 ... n.abs )

        while let a = seive.first {
            seive = seive.filter{ $0 % a > 0 }
            result.append(a)
        }

        _primes = result
        return result
    }

    public var divisors: [𝐙] {
        if self == 0 {
            return []
        }

        var result: [𝐙] = []

        let a = self.abs
        let m = Int(sqrt(Double(a)))

        for d in 1...m {
            if a % d == 0 {
                result.append(d)
                result.append(a/d)
            }
        }

        return result.sorted()
    }

    public var primeFactors: [𝐙] {
        var result: [𝐙] = []
        var q = self

        let ps = 𝐙.primes(upto: self)
        for p in ps {
            while q % p == 0 {
                q /= p
                result.append(p)
            }
        }

        return result
    }

    public static var symbol: String {
        return "𝐙"
    }
}
