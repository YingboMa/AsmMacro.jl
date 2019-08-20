using AsmMacro, Test

@testset "@asm" begin
    @asm function add_loop_vec2(x::Ptr{Float64},n::Int,z::Ptr{Float64})
        movq(n, rcx)
        movapd(x[0], xmm0)
        xorpd(xmm1,xmm1)
        @loop
        addpd(xmm0,xmm1)
        dec(rcx)
        jnz(@loop)
        movapd(xmm1, z[0])
    end

    x = [1.0,2.0]
    n = 10
    z = similar(x)
    add_loop_vec2(pointer(x),n,pointer(z))
    @test z == x*n

    @asm function add(z::Ptr{Int64}, x::Int64, y::Int64)
        addq(x, y)
        movq(y, z[0])
    end
    z = Int64[100]
    add(pointer(z), Int64(1), Int64(2))
    @test z[1] === Int64(3)

    @asm function add(z::Ptr{Int32}, x::Int32, y::Int32)
        addl(x, y)
        movl(y, z[0])
    end
    z = Int32[100]
    add(pointer(z), Int32(1), Int32(2))
    @test z[1] === Int32(3)

    @asm function add(z::Ptr{Float64}, x::Float64, y::Float64)
        vaddsd(xmm0, xmm1, xmm1)
        movq(xmm1, z[0])
    end
    z = Float64[100]
    add(pointer(z), Float64(1), Float64(2))
    @test z[1] === Float64(3.0)

    @asm function add(z::Ptr{Float32}, x::Float32, y::Float32)
        vaddss(xmm0, xmm1, xmm1)
        movq(xmm1, z[0])
    end
    z = Float32[100]
    add(pointer(z), Float32(1), Float32(2))
    @test z[1] === Float32(3.0)

    @test_throws Any (@eval @asm function add(x::Float64)
        ___
    end)
end
