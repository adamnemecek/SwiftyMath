//
//  SmithEliminator.swift
//  SwiftyMath
//
//  Created by Taketo Sano on 2017/11/08.
//  Copyright © 2017年 Taketo Sano. All rights reserved.
//

internal final class SmithEliminator<R: EuclideanRing>: MatrixEliminator<R> {
    var targetIndex = 0

    override var resultType: MatrixEliminationResultImpl<R>.Type {
        return DiagonalEliminationResult.self
    }

    override func prepare() {
        run(DiagonalEliminator.self)
    }

    override func isDone() -> Bool {
        return targetIndex >= target.table.count
    }

    @_specialize(where R == ComputationSpecializedRing)
    override func iteration() {
        let diagonal = targetDiagonal()
        guard let (i0, a0) = diagonal.min(by: {$0.1.degree < $1.1.degree}) else {
            fatalError()
        }

        if !a0.isInvertible {
            for (i, a) in diagonal {
                if i == i0 {
                    continue
                }

                if a % a0 != .zero {
                    diagonalGCD((i0, a0), (i, a))
                    return
                }
            }
        }

        // now `a0` divides all other elements.
        if a0.normalizeUnit != .identity {
            apply(.MulRow(at: i0, by: a0.normalizeUnit))
        }

        if i0 != targetIndex {
            swapDiagonal(i0, targetIndex)
        }

        targetIndex += 1
    }

    private func diagonalGCD(_ d1: (Int, R), _ d2: (Int, R)) {
        let (i, a) = d1
        let (j, b) = d2
        let (p, q, r) = bezout(a, b)

        // r = gcd(a, b) = pa + qb
        // m = lcm(a, b) = -a * b / r

        apply(.AddRow(at: i, to: j, mul: p))     // [a, 0; pa, b]
        apply(.AddCol(at: j, to: i, mul: q))     // [a, 0;  r, b]
        apply(.AddRow(at: j, to: i, mul: -a/r))  // [0, m; r, b]
        apply(.AddCol(at: i, to: j, mul: -b/r))  // [0, m; r, 0]
        apply(.SwapRows(i, j))                   // [r, 0; 0, m]
    }

    private func swapDiagonal(_ i0: Int, _ i1: Int) {
        apply(.SwapRows(i0, i1))
        apply(.SwapCols(i0, i1))
    }

    private func targetDiagonal() -> [(Int, R)] {
        return (targetIndex ..< target.table.keys.count).map{ target.table[$0]!.first! }
    }
}
