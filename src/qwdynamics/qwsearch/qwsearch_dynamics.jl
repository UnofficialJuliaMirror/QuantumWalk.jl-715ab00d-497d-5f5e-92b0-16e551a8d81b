export
   execute,
   execute_single,
   execute_single_measured,
   execute_all,
   execute_all_measured


"""
    execute(qws,[ initstate,] runtime[, all, measure])

Run proper execution  of quantum spatial search depending on given keywords.
The initial state is generated by `initial_state(qws)` if not provided.
`all` and `measure` keywords defaults to `false`. For detailed description
please see documentation of corresponding function. Note that for `all` equal
to `true` model in `qws` needs to be disrete.

"""
function execute(qws::QWSearch,
                 runtime::Real;
                 all::Bool = false,
                 measure::Bool = false)
   if !all && !measure
     execute_single(qws, runtime)
   elseif !all && measure
     execute_single_measured(qws, runtime)
   elseif all && !measure
     execute_all(qws, runtime)
   else
     execute_all_measured(qws, runtime)
   end
end

"""
    execute_single(qws, [ initstate,] runtime)

Evolve `initstate` acording to `qws` for time `runtime`. The initial state is
generated by `initial_state(qws)` if not provided. `runtime` needs to
be nonnegative. `QSearchState{typeof(initstate)}` is returned.
"""
function execute_single(qws::QWSearch{<:QWModelDiscr,<:Real},
                        initstate,
                        runtime::Int)
   @assert runtime>=0 "Parameter 'runtime' needs to be nonnegative"

   state = initstate
   for t=1:runtime
      state = evolve(qws, state)
   end

   QSearchState(qws, state, runtime)
end,

function execute_single(qws::QWSearch{<:QWModelCont,<:Real},
                        initstate,
                        runtime::Real)
   @assert runtime>=0 "Parameter 'runtime' needs to be nonnegative"

   QSearchState(qws, evolve(qws, initstate, runtime), runtime)
end,

function execute_single(qws::QWSearch, runtime::Real)
   execute_single(qws, initial_state(qws), runtime)
end

"""
    execute_single_measured(qws,[ initstate,] runtime)

Evolve `initstate` acording to `qws` for time `runtime`. The initial state is
generated by `initial_state(qws)` if not provided. `runtime` needs to
be nonnegative. Measurement probability distribution is returned.
"""
function execute_single_measured(qws::QWSearch, runtime::Real)
   execute_single_measured(qws, initial_state(qws), runtime)
end


"""
    execute_all(qws,[ initstate,] runtime)

Evolve `initstate` acording to `qws` for time `runtime`. `runtime` needs to be
nonnegative. The initial state is generated by `initial_state(qws)`
if not provided. Returns `Vector` of all `QSearchState{typeof(initstate)}`
including `initstate`.
"""
function execute_all(qws::QWSearch{<:QWModelDiscr},
                     initstate::S,
                     runtime::Int) where S
   @assert runtime>=0 "Parameter 'runtime' needs to be nonnegative"

   result = Vector{QSearchState{S,Int}}([QSearchState(qws, initstate, 0)])
   state = initstate
   for t=1:runtime
      state = evolve(qws, state)
      push!(result, QSearchState(qws, state, t))
   end

   result
end,

function execute_all(qws::QWSearch{<:QWModelDiscr}, runtime::Int)
   execute_all(qws, initial_state(qws), runtime)
end

"""
    execute_all_measured(qws,[ initstate,] runtime)

Evolve `initstate` acording to `qws` for time `runtime`.
`runtime` needs to be nonnegative. The initial state is generated by `initial_state(qws)`
 if not provided. As a result return matrix of type `Matrix{Float64}`
 for which `i`-th column is measurement probability distribution in (`i-1`)-th step.
"""
function execute_all_measured(qws::QWSearch, runtime::Real)
   execute_all_measured(qws, initial_state(qws), runtime)
end