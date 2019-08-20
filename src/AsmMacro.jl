module AsmMacro

export @asm

function gen_arg(args, arg::Expr)
    if arg.head === :ref
        string(arg.args[2], "(", gen_arg(args, arg.args[1]), ")")
    elseif arg.head === :macrocall
        string(".", string(arg.args[1])[2:end])
    else
        error("?!! $arg")
    end
end
function gen_arg(args, arg::Symbol)
    idx = findfirst(isequal(arg), args)
    idx === nothing && return string("%", arg)
    "\$$(idx-1)"
end

# TODO add more of those
typ_to_llvm(::Type{Float64}) = "double"
typ_to_llvm(::Type{Float32}) = "float"
typ_to_llvm(::Type{Int32}) = "i32"
typ_to_llvm(::Type{Int64}) = "i64"
typ_to_llvm(::Type{Ptr{T}}) where {T} = typ_to_llvm(Int)

const DEBUG_ASM = Ref(false)

function gen_asm(args, xs)
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
                opargs = join(map(a -> gen_arg(argnames, a), ex.args[2:end]), ", ")
                println(io, op, " ", opargs)
            elseif ex.head === :macrocall
                println(io, ".", string(ex.args[1])[2:end], ":")
            else
                dump(ex)
                error("unknown expr $ex")
            end
        else
            error("??? $(typeof(ex))")
        end
    end
    llvmtypes = map(typ_to_llvm, typs)
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
    body.args = Any[gen_asm(sig.args[2:end], body.args)]
    esc(f)
end

end # module
