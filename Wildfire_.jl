# Author: Youngjun Kim, youngjun@stanford.edu
# Date: 12/02/2014

module Wildfire_

export Wildfire, BurningMatrix, FuelLevelMatrix
export wfTranProb, wfNextState
export burningProb, burningProbMatrix


using Distributions


typealias BurningMatrix     Array{Bool, 2}
typealias FuelLevelMatrix   Array{Int64, 2}


type Wildfire

    seed::Uint64

    nrow::Int64
    ncol::Int64

    B::BurningMatrix
    F::FuelLevelMatrix
    F_max::Int64

    # probability that a fire in neighbor cell ignites a fire in the cell
    p_fire::Float64


    function Wildfire(nrow::Int64, ncol::Int64; seed::Union(Uint64, Nothing) = nothing, init_loc::Union((Int64, Int64), Array{(Int64, Int64), 1}, Nothing) = nothing, p_fire::Float64 = 0.06, B_::Union(BurningMatrix, Nothing) = nothing, F_::Union(FuelLevelMatrix, Nothing) = nothing)

        self = new()

        if seed != nothing
            if seed != 0
                self.seed = uint(seed)
            else
                self.seed = uint(time())
            end

            srand(self.seed)
        end

        self.nrow = nrow
        self.ncol = ncol

        # initial fire
        if B_ == nothing
            B = zeros(Bool, nrow, ncol)
            if init_loc != nothing
                if isa(init_loc, (Int64, Int64))
                    B[init_loc[1], init_loc[2]] = true
                else
                    for (row, col) in init_loc
                        B[row, col] = true
                    end
                end
            else
                B[rand(1:nrow), rand(1:ncol)] = true
            end
            self.B = B
        else
            self.B = copy(B_)
        end

        # fuel level
        if F_ == nothing
            F = zeros(Int64, nrow, ncol)
            F_max = int(max(nrow, ncol) * 10)
            mu = F_max * 0.7
            sigma = mu * 0.2
            F = int(rand(Normal(mu, sigma), (nrow, ncol)))
            F[F .< 0] = 0
            F[F .> F_max] = F_max

            self.F = F
            self.F_max = F_max
        else
            self.F = copy(F_)
            self.F_max = maximum(F_)
        end

        self.p_fire = p_fire

        return self
    end
end


function burningProb(wm::Wildfire, B::BurningMatrix, i, j)

    if B[i, j]
        return 1.
    else
        s = 1.

        if i != 1
            s *= 1 - wm.p_fire * B[i - 1, j]
        end

        if i != wm.nrow
            s *= 1 - wm.p_fire * B[i + 1, j]
        end

        if j != 1
            s *= 1 - wm.p_fire * B[i, j - 1]
        end

        if j != wm.ncol
            s *= 1 - wm.p_fire * B[i, j + 1]
        end

        rho = 1 - s

        return rho
    end
end

function burningProb(wm::Wildfire, B::BurningMatrix, F::FuelLevelMatrix, i, j)

    if F[i, j] == 0
        return 0.
    elseif B[i, j]
        return 1.
    else
        s = 1.

        if i != 1
            s *= 1 - wm.p_fire * B[i - 1, j]
        end

        if i != wm.nrow
            s *= 1 - wm.p_fire * B[i + 1, j]
        end

        if j != 1
            s *= 1 - wm.p_fire * B[i, j - 1]
        end

        if j != wm.ncol
            s *= 1 - wm.p_fire * B[i, j + 1]
        end

        rho = 1 - s

        return rho
    end
end


function burningProbMatrix(wm::Wildfire)

    P = [burningProb(wm, wm.B, i, j) for i = 1:wm.nrow, j = 1:wm.ncol]

    return P
end

function burningProbMatrix(wm::Wildfire, B::BurningMatrix)

    P = [burningProb(wm, B, i, j) for i = 1:wm.nrow, j = 1:wm.ncol]

    return P
end

function burningProbMatrix(wm::Wildfire, B::BurningMatrix, F::FuelLevelMatrix)

    P = [burningProb(wm, B, F, i, j) for i = 1:wm.nrow, j = 1:wm.ncol]

    return P
end


function wfTranProb(wm::Wildfire, B::BurningMatrix, B_::BurningMatrix)

    P = burningProbMatrix(wm, B)
    P[B] = 0.

    D = B $ B_
    p = prod(P[D])

    return p
end

function wfTranProb(wm::Wildfire, B::BurningMatrix, B_::BurningMatrix, F::FuelLevelMatrix, F_::FuelLevelMatrix)

    Fn= copy(F)
    Fn[B] -= 1
    Fn[Fn .< 0] = 0

    if Fn == F_
        Bn = copy(B)
        Bn[Fn .== 0] = false

        P = burningProbMatrix(wm, Bn, Fn)
        P[Bn] = 0.

        D = Bn $ B_
        p = prod(P[D])
    else
        p = 0.
    end

    return p
end


function wfNextState(wm::Wildfire, B::BurningMatrix)

    P = burningProbMatrix(wm, B)
    R = rand(size(B))

    B_ = P .> R

    return B_
end

function wfNextState(wm::Wildfire, B::BurningMatrix, F::FuelLevelMatrix)

    F_ = copy(F)
    F_[B] -= 1
    F_[F_ .< 0] = 0

    P = burningProbMatrix(wm, B, F_)
    R = rand(size(B))

    B_ = P .> R

    return B_, F_
end

function wfNextState(wm::Wildfire; bFuel::Bool = false)

    if bFuel
        wm.F[wm.B] -= 1
        wm.F[wm.F .< 0] = 0

        P = burningProbMatrix(wm, wm.B, wm.F)
    else
        P = burningProbMatrix(wm, wm.B)
    end

    R = rand((wm.nrow, wm.ncol))

    wm.B = P .> R

    if bFuel
        return wm.B, wm.F
    else
        return wm.B
    end
end


end


