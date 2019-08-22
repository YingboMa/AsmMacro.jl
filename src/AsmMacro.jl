module AsmMacro

export @asm

genlabel(arg::Expr) = string(".", string(arg.args[1])[2:end], "\${:uid}")

function genarg(args, arg::Expr)
    if arg.head === :ref
        ii = arg.args[2]
        ii′ = ii isa Number ? ii : eval(ii)
        string(ii′, "(", genarg(args, arg.args[1]), ")")
    elseif arg.head === :macrocall
        genlabel(arg)
    else
        error("?!! $arg")
    end
end
function genarg(args, arg::Symbol)
    idx = findfirst(isequal(arg), args)
    idx === nothing && return string("%", arg)
    "\$$(idx-1)"
end

# TODO add more of those
typ2llvm(::Type{Float64}) = "double"
typ2llvm(::Type{Float32}) = "float"
typ2llvm(::Type{Int32}) = "i32"
typ2llvm(::Type{Int64}) = "i64"
typ2llvm(::Type{Ptr{T}}) where {T} = typ2llvm(Int)

const DEBUG_ASM = Ref(false)

function genasm(args, xs)
    io = IOBuffer()
    argnames = Symbol[]
    typs = []
    for a in args
        isa(a,Expr) && a.head === :(::) || error("invalid arg sig $a")
        typ = eval(a.args[2])
        push!(argnames,a.args[1])
        push!(typs,typ)
    end
    println(io, "call void asm \"")
    for ex in xs
        isa(ex, LineNumberNode) && continue
        isa(ex, Expr) && ex.head === :line && continue

        if isa(ex,Expr)
            if ex.head === :call
                op = string(ex.args[1])
                opargs = join(map(a -> genarg(argnames, a), ex.args[2:end]), ", ")
                println(io, op, " ", opargs)
            elseif ex.head === :macrocall
                println(io, genlabel(ex), ":")
            else
                dump(ex)
                error("unknown expr $ex")
            end
        else
            error("??? $(typeof(ex))")
        end
    end
    llvmtypes = map(typ2llvm, typs)
    for i = 1:length(llvmtypes)
        llvmtypes[i] = string(llvmtypes[i], " %", i-1)
    end
    constr = map(_ -> "r", llvmtypes)
    println(io, "\",\"", join(constr, ","), "\"(", join(llvmtypes, ", "), ")")
    println(io, "ret void")
    asm = String(take!(io))
    DEBUG_ASM[] && println(asm)
    Expr(:call, GlobalRef(Base, :llvmcall), asm, Cvoid, Tuple{typs...}, args...)
end

macro asm(f)
    @assert f.head === :function
    sig = f.args[1]
    @assert sig.head === :call
    body = f.args[2]
    @assert body.head === :block
    body.args = Any[genasm(sig.args[2:end], body.args)]
    esc(f)
end

end # module
