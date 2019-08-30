module AsmMacro
using MLStyle
export @asm

genlabel(sym::Symbol) = string(".", string(sym)[2:end], "\${:uid}")

genarg(args, arg) = @match arg begin
    :($value[$ii]) => begin
            ii′ = ii isa Number ? ii : eval(ii)
            string(ii′, "(", genarg(args, value), ")")
        end
    ::Symbol => begin
            idx = findfirst(isequal(arg), args)
            idx === nothing && return string("%", arg)
            "\$$(idx-1)"
        end
    Expr(:macrocall, sym, ::LineNumberNode) => genlabel(sym)
    _ => error("?!! $arg")
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
    for arg in args; @match arg begin
        :($(argname :: Symbol) :: $typ) => begin
                push!(argnames, argname)
                push!(typs, eval(typ))
            end
        a => error("invalid arg sig $a")
    end end
    println(io, "call void asm \"")
    for ex in xs; @match ex begin
        ::LineNumberNode || Expr(:line, _...) => nothing
        :($op($(opargs...))) => begin
                str_opargs = join(map(a -> genarg(argnames, a), opargs), ", ")
                println(io, op, " ", str_opargs)
            end
        Expr(:macrocall, sym, ::LineNumberNode) =>
            println(io, genlabel(sym), ":")
        ::Expr => begin
            dump(ex)
            error("unknown expr $ex")
        end
        _ => error("??? $(typeof(ex))")
    end end
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
    @match f begin
        :(function $f($(args...)) $(body...) end) =>
            :(function $f($(args...))
                $(genasm(args, body))
              end) |> esc
        _ => error("invalid function form $f")
    end
end

end # module
