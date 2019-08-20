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
end
