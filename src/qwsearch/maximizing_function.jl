export
   maximize_quantum_search

"""
    maximize_quantum_search(qss::QWSearch{<:QWModelCont} [, maxtime, tstep])

Determines optimal runtime for continuous quantum walk models. The time is
searched in [0, maxtime] interval, with penalty `penalty(qss)`, which is added.
It is recommended for penalty to be nonzero, otherwise time close to 0 is usually
returned. Typically small `penalty` approximately equal to log(n) is enough, but
optimal value may depend on the model or graph chosen.

The optimal time is chosen according to expected runtime, which equals to
runtime over probability, which simulates the Bernoulli process based on
`QWModelCont`.

`tstep` is used for primary grid search to search for determine intervale which
is supsected to have small expected runtime. To large value may miss the optimal value,
while to small may greatly increase runtime of the algorithm.

`maxtime` defaults to graph order n, `tstep` defaults to `sqrt(n)/5`. `QSearchState`
is returned by deafult without `penalty`. Note that in general the probability is not maximal


```@doc
julia> using QuantumWalk,LightGraphs

julia> qss = QWSearch(CTQW(CompleteGraph(100)), [1], 0.01, 1.);

julia> result = maximize_quantum_search(qss)
QuantumWalk.QSearchState{Array{Complex{Float64},1},Float64}(Complex{Float64}[0.621142+0.695665im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im  …  0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im, 0.0279736-0.023086im], [0.869767], 12.99636940469214)

julia> expected_runtime(result)
14.94235723559316

julia> probability(result)
1-element Array{Float64,1}:
 0.869767

julia> probability(execute_single(qss, pi*sqrt(100)/2))
1-element Array{Float64,1}:
 1.0
```
"""
function maximize_quantum_search(qss::QWSearch{<:QWModelCont},
                                 maxtime::T = Float64(nv(graph(qss))),
                                 tstep::T = Float64(0.2*sqrt(nv(graph(qss))))) where T<:Real
   @assert maxtime >= 0. "Time needs to be nonnegative"
   if penalty(qss) == 0
      warn("It is recommended for penalty to be nonzero, otherwise time close is returned. Typically small penalty approximately equal to log(n) is enough, but optimal value may depend on the model or graph chosen.")
   end

   state = initial_state(qss)
   function efficiency_opt(runtime::Number)
      expected_runtime(runtime+penalty(qss), sum(measure(qss, evolve(qss, state, runtime), marked(qss))))
   end

   t = zero(T)
   data_t = T[t]
   data_y = [efficiency_opt(t)]
   max_efficiency = data_y[end]
   for t=tstep:tstep:maxtime
      push!(data_t, t)
      push!(data_y, efficiency_opt(t))

      max_efficiency = min(max_efficiency, data_y[end])
      if max_efficiency <= t
         break
      end
   end

   if t > maxtime
      push!(data_t, maxtime)
      push!(data_y, efficiency_opt(maxtime))
   end


   minindex = findmin(data_y)[2]
   mint = max(zero(T), data_t[max(1, minindex-1)])
   maxt = min(maxtime, data_t[min(length(data_t), minindex+1)])
   optresult = optimize(efficiency_opt, mint, maxt)

   result = execute_single(qss, Optim.minimizer(optresult))
   QSearchState(result.state, result.probability, result.runtime+qss.penalty)
end

"""
   maximize_quantum_search(qss::QWSearch{<:QWModelDiscr} [, runtime, mode])

Determines optimal runtime for continuous quantum walk models. The time is
searched in [0, runtime] interval, with penalty `penalty(qss)`, which is added.
It is recommended for penalty to be nonzero, otherwise time close 0 is returned.
Typically small `penalty` approximately equal to log(n) is enough, but
optimal value may depend on the model or graph chosen.

The optimal time depende on chosen `mode`:
* `:firstmaxprob` stops when probability start to decrease,
* `:firstmaxeff` stops whene expected runtime start to increase,
* `:maxtimeeff` chooses exhaustively the time from [0, runtime] with smallest expected time,
* `:maxtimeprob` chooses exhaustively the time from [0, runtime] with maximal success probability,
* `:maxeff` (default) finds optimal time with smallest expected time, usually faster
than `:maxtimefff`.

Note last three modes always returns optimal time within the interval.

`maxtime` defaults to graph order n, `mode` defaults to `:maxeff`. `QSearchState`
is returned by deafult without `penalty`.

```jldoctest
julia> qss = QWSearch(Szegedy(CompleteGraph(200)), [1], 1);

julia> result = maximize_quantum_search(qss);

julia> runtime(result)
7

julia> probability(result)
1-element Array{Float64,1}:
 0.500016

julia> result = maximize_quantum_search(qss, 100, :maxtimeprob);

julia> runtime(result)
40

julia> probability(result)
1-element Array{Float64,1}:
 0.550938
```
"""
function maximize_quantum_search(qss::QWSearch{<:QWModelDiscr},
                                 runtime::Int = nv(graph(qss)),
                                 mode::Symbol = :maxeff)
   @assert runtime>=0 "Parameter 'runtime' needs to be nonnegative"
   @assert mode ∈ [:firstmaxprob, :firstmaxeff, :maxtimeeff, :maxeff, :maxtimeprob] "Specified stop condition is not implemented"
   if penalty(qss) == 0
      warn("It is recommended for penalty to be nonzero, otherwise time close is returned. Typically small penalty approximately equal to log(n) is enough, but optimal value may depend on the model or graph chosen.")
   end


   best_result = QSearchState(qss, initial_state(qss), qss.penalty)
   state = QSearchState(qss, initial_state(qss), qss.penalty)
   for t=1:runtime
      state = QSearchState(qss, evolve(qss, state), t+qss.penalty)
      stopsearchflag = stopsearch(best_result, state, mode)
      best_result = best(best_result, state, mode)

      if stopsearchflag
         break
      end
   end

   best_result
end

"""
    stopsearch(previous_state, state, mode)

For given combination of argument decides whetver maximizing search function
should be stopped:
The optimal time depende on chosen `mode`:
* `:firstmaxprob` stops when probability start to decrease,
* `:firstmaxeff` stops whene expected runtime start to increase,
* `:maxtimeeff` always return `false` (should be decided by external function),
* `:maxtimeprob`  always return `false` (should be decided by external function),
* `:maxeff` checks whetver expected_runtime of older state is smaller than current time,

`false` means maximizing should continue unless other constraints, `true` otherwise.
"""

function stopsearch(previous_state::QSearchState,
                    state::QSearchState,
                    mode::Symbol)
   if mode == :maxeff
      return expected_runtime(previous_state) < state.runtime+1 #check whetver needs to analyze next step
   elseif mode == :firstmaxprob
      return sum(previous_state.probability) > sum(state.probability)
   elseif mode == :firstmaxeff
      return expected_runtime(previous_state) < expected_runtime(state)
   else # include :maxtime case, should be considered by outside loop (hack?)
      return false
   end
end

"""
    best(state1, state2, mode)

Choose better state depending on mode. If success probability is maximized, then
the success probability is compared. If expected runtime is minimized,
then expected runtime is compared.
"""
function best(state1::QSearchState,
              state2::QSearchState,
              mode::Symbol)
   if mode ∈ [:firstmaxprob,:maxtimeprob]
      sum(state1.probability) > sum(state2.probability) ? state1 : state2
   else
      expected_runtime(state1) < expected_runtime(state2) ? state1 : state2
   end
end
