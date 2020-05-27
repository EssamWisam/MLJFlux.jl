using Test
using Tables
using MLJBase
import MLJFlux
using CategoricalArrays
using ColorTypes
import Flux
import Random
import Random.seed!
using Statistics
import StatsBase
using MLJScientificTypes

seed!(123)

include("test_utils.jl")

@testset "core" begin
    include("core.jl")
end

@testset "regressor" begin
    include("regressor.jl")
end

@testset "classifier" begin
    include("classifier.jl")
end

@testset "image" begin
    include("image.jl")
end
