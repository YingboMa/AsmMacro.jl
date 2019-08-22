# AsmMacro.jl

[![Build Status](https://travis-ci.org/YingboMa/AsmMacro.jl.svg?branch=master)](https://travis-ci.org/YingboMa/AsmMacro.jl)
[![codecov](https://codecov.io/gh/YingboMa/AsmMacro.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/YingboMa/AsmMacro.jl)

`AsmMacro.jl` provides a relatively simple way to write assembly code in Julia.

## Examples

```julia
using AsmMacro

# z[1:4] <- x[1:4]*n (with a loop)
@asm function add_loop_sse(x::Ptr{Float64},n::Int,z::Ptr{Float64})
    movq(n, rcx)
    movapd(x[0*16], xmm0)
    movapd(x[1*16], xmm1)
    xorpd(xmm2,xmm2)
    xorpd(xmm3,xmm3)
    @loop
    addpd(xmm0,xmm2)
    addpd(xmm1,xmm3)
    dec(rcx)
    jnz(@loop)
    movapd(xmm2, z[0*16])
    movapd(xmm3, z[1*16])
end

x = [1.0,2.0,4.0,5.0]
n = 10
z = similar(x)
add_loop_sse(pointer(x),n,pointer(z))

julia> z
4-element Array{Float64,1}:
 10.0
 20.0
 40.0
 50.0
```

```julia
using AsmMacro

# z[1:4] <- x[1:4] + y[1:4]
@asm function add_avx256(x::Ptr{Float64},y::Ptr{Float64},z::Ptr{Float64})
    vmovupd(x[0], ymm0)
    vmovupd(y[0], ymm1)
    vaddpd(ymm0, ymm1, ymm1)
    vmovupd(ymm1, z[0])
end

x = [1.0,2.0,3.0,4.0]
y = [4.0,3.0,2.0,1.0]
z = similar(x)
add_avx256(pointer(x),pointer(y),pointer(z))

julia> z
4-element Array{Float64,1}:
 5.0
 5.0
 5.0
 5.0
```

## Acknowledgement

This package is based on the original code by [Oscar Blumberg](https://github.com/carnaval).
