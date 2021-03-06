# Author: Youngjun Kim, youngjun@stanford.edu
# Date: 11/04/2014

using RockSample_

using QMDP_
using FIB_

using UCT_
using POMCP_

using Util
using RockSampleVisualizer_
using MCTSVisualizer_

using Iterators
using Base.Test


function sampleParticles(pm, b, nsample = 100000)

    B = RSState[]

    for n = 1:nsample
        rv = rand()

        sum_ = 0.
        for s in keys(b.belief)
            sum_ += b.belief[s]

            if rv < sum_
                push!(B, s)

                break
            end
        end
    end

    return RSBeliefParticles(B)
end


function beliefParticles2Vector(pm, B)

    count_ = Dict{RSState, Int64}()
    belief = Dict{RSState, Float64}()

    for s in pm.states
        count_[s] = 0
        belief[s] = 0.
    end

    sum_ = 0
    for s in B.particles
        count_[s] += 1
        sum_ += 1
    end
    sum_ = float(sum_)

    for s in B.particles
        belief[s] = count_[s] / sum_
    end

    return RSBeliefVector(belief)
end


function printBelief(pm, alg, b)

    if typeof(alg) == POMCP
        bv = beliefParticles2Vector(pm, b)
    else
        bv = b
    end

    for s in pm.states
        if s.Position == pm.rover_pos
            println(s, ": ", bv.belief[s])
        else
            @test bv.belief[s] == 0.
        end
    end
end


function getInitialState(pm::RockSample)

    rock_types = Array(Symbol, pm.k)

    for (rock, rock_type) in pm.rock_types
        rock_index = rock2ind(rock)
        rock_types[rock_index] = rock_type
    end

    return RSState(pm.rover_pos, rock_types)
end


function getInitialBelief(pm::RockSample; bParticles::Bool = false)

    if bParticles
        B = RSState[]

        for rock_types in product(repeated([:good, :bad], pm.k)...)
            push!(B, RSState(pm.rover_pos, [rock_types...]))
        end

        return RSBeliefParticles(B)
    else
        belief = Dict{RSState, Float64}()

        sum_ = 0
        for s in pm.states
            if s.Position == pm.rover_pos
                belief[RSState(s.Position, s.RockTypes)] = 1.
                sum_ += 1
            else
                belief[RSState(s.Position, s.RockTypes)] = 0.
            end
        end

        for s in keys(belief)
            belief[s] /= sum_
        end

        return RSBeliefVector(belief)
    end
end


function test(pm, alg)

    if typeof(alg) == POMCP
        b = getInitialBelief(pm, bParticles = true)
    else
        b = getInitialBelief(pm)
    end

    a_opt, Qv = selectAction(alg, pm, b)

    Qv__ = Float64[]
    for a in  pm.actions
        push!(Qv__, round(Qv[a], 2))
    end
    println("Qv: ", Qv__)
    println("action: ", a_opt.action)
end


function simulate(pm, alg; draw = true, wait = false)

    if draw
        rsv = RockSampleVisualizer(wait = wait)
    end

    s = getInitialState(pm)

    if typeof(alg) == POMCP
        b = getInitialBelief(pm, bParticles = true)
    else
        b = getInitialBelief(pm)
    end
    #printBelief(pm, alg, b)

    R = 0.

    println("time: 0, s: ", s.Position, " ", s.RockTypes)

    if draw
        visInit(rsv, pm)
        visUpdate(rsv, pm)
        updateAnimation(rsv)
    end

    for i = 1:50
        #println("T: ", alg.T)
        #println("N: ", alg.N)
        #println("Ns: ", alg.Ns)
        #println("Q: ", alg.Q)
        #println("B: ", alg.B)
        #println()

        a, Qv = selectAction(alg, pm, b)

        # XXX debug
        #Qv = Dict{RSAction, Float64}()
        #for a__ in  pm.actions
        #    Qv[a__] = 0.
        #end
        #if i == 1
        #    a = RSAction(:check1)
        #elseif i == 2
        #    a = RSAction(:check2)
        #elseif i == 3
        #    a = RSAction(:check3)
        #else
        #    a, Qv = selectAction(alg, pm, b)
        #end
        #if rem(i, 4) == 1
        #    a = RSAction(:check1)
        #elseif rem(i, 4) == 2
        #    a = RSAction(:check2)
        #elseif rem(i, 4) == 3
        #    a = RSAction(:check3)
        #elseif rem(i, 4) == 0
        #    a, Qv = selectAction(alg, pm, b)
        #end

        #println("T: ", alg.T)
        #println("N: ", alg.N)
        #println("Ns: ", alg.Ns)
        #println("Q: ", alg.Q)
        #println("B: ", alg.B)
        #println()

        s_ = nextState(pm, s, a)

        o = observe(pm, s_, a)

        r = reward(pm, s, a)
        R += r

        Qv__ = Float64[]
        for a__ in  pm.actions
            push!(Qv__, round(Qv[a__], 2))
        end
        println("time: ", i, ", s: ", s.Position, " ", s.RockTypes, ", Qv: ", Qv__, ", a: ", a.action, ", o: ", o.observation, ", r: ", r, ", R: ", R, ", s_: ", s_.Position, " ", s_.RockTypes)

        updateInternalStates(pm, s, a, s_)

        if draw
            visInit(rsv, pm)
            visUpdate(rsv, pm, (i, a, o, r, R))
            updateAnimation(rsv)
        end

        s = s_

        if isEnd(pm, s)
            println("reached the terminal state")
            break
        end

        if typeof(alg) == POMCP
            b = updateBelief(pm, RSBeliefParticles(getParticles(alg, a, o)))
        else
            b = updateBelief(pm, b, a, o)
        end
        #printBelief(pm, alg, b)

        if typeof(alg) == UCT || typeof(alg) == POMCP
            reinitialize(alg, a, o)
        end
    end

    if draw
        saveAnimation(rsv, repeat = true)
    end
end


function default_policy(pm::RockSample, s::RSState)

    a = pm.actions[rand(1:length(pm.actions))]

    while !isFeasible(pm, s, a)
        a = pm.actions[rand(1:length(pm.actions))]
    end

    return a
end


srand(uint(time()))

#pm = RockSample(5, 5, seed = rand(1:typemax(Int64)))
#pm = RockSample(5, 5, seed = rand(1:1024))
pm = RockSample(3, 3, seed = 263)

#alg = QMDP(pm, "rocksample_qmdp.pcy", verbose = 1)
#alg = QMDP("rocksample_qmdp.pcy")
#alg = FIB(pm, "rocksample_fib.pcy", verbose = 1)
#alg = FIB("rocksample_fib.pcy")

#alg = UCT(depth = 5, default_policy = default_policy, nloop_max = 10000, nloop_min = 10000, c = 20., gamma_ = 0.99, rgamma_ = 0.99, visualizer = MCTSVisualizer())
alg = POMCP(depth = 5, default_policy = default_policy, nloop_max = 10000, nloop_min = 10000, c = 20., gamma_ = 0.99, rgamma_ = 0.99, visualizer = MCTSVisualizer())

#test(pm, alg)
simulate(pm, alg, draw = true, wait = true)


