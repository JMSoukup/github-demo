using DiscreteEvents, Random, Distributions, GLMakie, LaTeXStrings, DataFrames

abstract type MState end

struct Idle <: MState end
struct Busy <: MState end

mutable struct Job
    no::Int64
    ts::Float64
    t1::Float64
    t2::Float64
    t3::Float64
end

mutable struct Machine
    state::MState
    job
end

Q = Job[]   # input queue
S = Job[]   # stock
M = Machine(Idle(), 0)
df = DataFrame(time = Float64[], buffer=Int[], machine=Int[], finished=Int[])
count = 1
printing = true

stats() = push!(df, (tau(), length(Q), M.state == Busy() ? 1 : 0, length(S)))

function arrive(μ, σ, c)
    @assert μ ≥ 1 "μ must be ≥ 1"
    ts = rand(Normal(μ, σ))/c
    job = Job(count, ts, tau(), 0, 0)
    global count += 1
    push!(Q, job)
    ta = rand(Erlang())*μ
    event!(𝐶, fun(arrive, μ, σ, c), after, ta)  # we schedule the next arrival
    printing ? println(tau(), ": job $(job.no) has arrived") : nothing # tau() is the current time
    if M.state == Idle()
        load()
    else
        stats()
    end
end

function load()
    M.state = Busy()
    M.job = popfirst!(Q)
    M.job.t2 = tau()
    event!(𝐶, fun(unload), after, M.job.ts)  # we schedule the unload
    printing ? println(tau(), ": job $(M.job.no) has been loaded") : nothing
    stats()
end

function unload()
    M.state = Idle()
    M.job.t3 = tau()
    push!(S, M.job)
    printing ? println(tau(), ": job $(M.job.no) has been finished") : nothing
    stats()
    M.job = 0
    if !isempty(Q)
        load()
    end
end

sample_time!(𝐶, 0.1)  # we determine the sample rate
periodic!(𝐶, fun(stats));  # we register stats() as sampling function

Random.seed!(2019)
#resetClock!(𝐶)
arrive(5, 1/5, 1)  # we schedule the first event
run!(𝐶, 30)        # and run the simulation

# FigureAxisPlot takes figure and axis keywords
fig, ax, p = lines((df.time, df.buffer),
    figure = (resolution = (1600, 600),),
    axis = (xlabel = "time (min)", ylabel = "buffer",title = "Single Server"),
    color = :blue,
    linewidth = 3)
fig

fig, ax, p = lines((df.time, df.machine),
    figure = (resolution = (1600, 600),),
    axis = (xlabel = "time (min)", ylabel = "machine",title = "Single Server"),
    color = :red,
    linewidth = 3)
fig

fig, ax, p = lines((df.time, df.finished),
    figure = (resolution = (1600, 600),),
    axis = (xlabel = "time (min)", ylabel = "stock",title = "Single Server"),
    color = :red,
    linewidth = 3)
fig