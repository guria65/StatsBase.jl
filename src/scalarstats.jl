# Statistics for an array of scalars


#############################
#
#   Moments
#
#############################

# Skewness
# This is Type 1 definition according to Joanes and Gill (1998)
function skewness(v::RealArray, m::Real)
    n = length(v)
    cm2 = 0.0   # empirical 2nd centered moment (variance)
    cm3 = 0.0   # empirical 3rd centered moment
    for x_i in v
        z = x_i - m
        z2 = z * z

        cm2 += z2
        cm3 += z2 * z
    end
    cm3 /= n
    cm2 /= n
    return cm3 / sqrt(cm2 * cm2 * cm2)  # this is much faster than cm2^1.5
end

function skewness(v::RealArray, wv::WeightVec, m::Real)
    n = length(v)
    length(wv) == n || raise_dimerror()
    cm2 = 0.0   # empirical 2nd centered moment (variance)
    cm3 = 0.0   # empirical 3rd centered moment    
    w = values(wv)

    @inbounds for i = 1 : n
        x_i = v[i]
        w_i = w[i]
        z = x_i - m
        z2w = z * z * w_i
        cm2 += z2w
        cm3 += z2w * z
    end
    sw = sum(wv)
    cm3 /= sw
    cm2 /= sw
    return cm3 / sqrt(cm2 * cm2 * cm2)  # this is much faster than cm2^1.5
end

skewness(v::RealArray) = skewness(v, mean(v))
skewness(v::RealArray, wv::WeightVec) = skewness(v, wv, mean(v, wv))

# (excessive) Kurtosis
# This is Type 1 definition according to Joanes and Gill (1998)
function kurtosis(v::RealArray, m::Real)
    n = length(v)
    cm2 = 0.0  # empirical 2nd centered moment (variance)
    cm4 = 0.0  # empirical 4th centered moment
    for x_i in v
        z = x_i - m
        z2 = z * z
        cm2 += z2
        cm4 += z2 * z2
    end
    cm4 /= n
    cm2 /= n
    return (cm4 / (cm2 * cm2)) - 3.0
end

function kurtosis(v::RealArray, wv::WeightVec, m::Real)
    n = length(v)
    length(wv) == n || raise_dimerror()
    cm2 = 0.0  # empirical 2nd centered moment (variance)
    cm4 = 0.0  # empirical 4th centered moment
    w = values(wv)

    @inbounds for i = 1 : n
        x_i = v[i]
        w_i = w[i]
        z = x_i - m
        z2 = z * z
        z2w = z2 * w_i
        cm2 += z2w
        cm4 += z2w * z2
    end
    sw = sum(wv)
    cm4 /= sw
    cm2 /= sw
    return (cm4 / (cm2 * cm2)) - 3.0
end

kurtosis(v::RealArray) = kurtosis(v, mean(v))
kurtosis(v::RealArray, wv::WeightVec) = kurtosis(v, wv, mean(v, wv))

#############################
#
#   Variability measurements
#
#############################

# Variation: std / mean
variation{T<:Real}(x::AbstractArray{T}, m::Real) = stdm(x, m) / m
variation{T<:Real}(x::AbstractArray{T}) = variation(x, mean(x))

# Standard error of the mean: std(a)
sem{T<:Real}(a::AbstractArray{T}) = sqrt(var(a) / length(a))

# Median absolute deviation
mad{T<:Real}(v::AbstractArray{T}, center::Real) = 1.4826 * median!(abs(v .- center))

function mad!{T<:Real}(v::AbstractArray{T}, center::Real)
    for i in 1:length(v)
        v[i] = abs(v[i]-center)
    end
    1.4826 * median!(v, checknan=false)
end

mad!{T<:Real}(v::AbstractArray{T}) = mad!(v, median!(v))

mad{T<:Real}(v::AbstractArray{T}) = mad!(copy(v))
mad{T<:Real}(v::Range1{T}) = mad!([v])


#############################
#
#   min/max related
#
#############################

# middle
middle{T<:FloatingPoint}(a1::T, a2::T) = (a1 + a2) / convert(T, 2)
middle{T<:Integer}(a1::T, a2::T) = (a1 + a2) / 2

# Mid-range
midrange{T<:Real}(a::AbstractArray{T}) = middle(extrema(a)...)

# Range: xmax - xmin
range{T<:Real}(a::AbstractArray{T}) = ((m0, m1) = extrema(a); m1 - m0)


#############################
#
#   quantile and friends
#
#############################

percentile{T<:Real}(v::AbstractArray{T}, p) = quantile(v, p * 0.01)
iqr{T<:Real}(v::AbstractArray{T}) = (q = quantile(v, [.25, .75]); q[2] - q[1])

quantile{T<:Real}(v::AbstractArray{T}) = quantile(v, [.0, .25, .5, .75, 1.0])
nquantile{T<:Real}(v::AbstractArray{T}, n::Integer) = quantile(v, (0:n)/n)


#############################
#
#   mode & modes
#
#############################

# compute mode, given the range of integer values
function mode{T<:Integer}(a::AbstractArray{T}, rgn::Range1{T})
    isempty(a) && error("mode: input array cannot be empty.")

    r0 = rgn[1]  
    r1 = rgn[end]
    cnts = zeros(Int, length(rgn))

    mc = 0    # maximum count
    mv = r0   # a value corresponding to maximum count

    for x in a
        if r0 <= x <= r1
            @inbounds c = (cnts[x - r0 + 1] += 1)
            if c > mc
                mc = c
                mv = x
            end
        end
    end

    return mv
end

function modes{T<:Integer}(a::AbstractArray{T}, rgn::Range1{T})
    r0 = rgn[1]  
    r1 = rgn[end]
    n = length(rgn)
    cnts = zeros(Int, n)

    # find the maximum count
    mc = 0 
    for x in a
        if r0 <= x <= r1
            @inbounds c = (cnts[x - r0 + 1] += 1)
            if c > mc
                mc = c
            end
        end
    end

    # find all values corresponding to maximum count
    ms = T[]
    for i = 1 : n
        @inbounds if cnts[i] == mc
            push!(ms, rgn[i])
        end
    end

    return ms
end

function mode{T}(a::AbstractArray{T})
    isempty(a) && error("mode: input array cannot be empty.")

    cnts = (T=>Int)[]

    # first element
    mc = 1
    mv = a[1]
    cnts[mv] = 1

    # find the mode along with table construction
    for i = 2 : length(a)
        @inbounds x = a[i]
        if haskey(cnts, x)
            c = (cnts[x] += 1)
            if c > mc
                mc = c
                mv = x
            end
        else
            cnts[x] = 1
            # in this case: c = 1, and thus c > mc won't happen
        end
    end

    return mv
end

function modes{T}(a::AbstractArray{T})
    isempty(a) && error("modes: input array cannot be empty.")

    cnts = (T=>Int)[]

    # first element
    mc = 1
    cnts[a[1]] = 1

    # find the mode along with table construction
    for i = 2 : length(a)
        @inbounds x = a[i]
        if haskey(cnts, x)
            c = (cnts[x] += 1)
            if c > mc
                mc = c
            end
        else
            cnts[x] = 1
            # in this case: c = 1, and thus c > mc won't happen
        end
    end

    # find values corresponding to maximum counts
    ms = T[]
    for (x, c) in cnts
        if c == mc
            push!(ms, x)
        end
    end

    return ms
end



#############################
#
#   summary
#
#############################

immutable SummaryStats{T<:FloatingPoint}
    mean::T
    min::T
    q25::T    
    median::T    
    q75::T
    max::T
end

function summarystats{T<:Real}(a::AbstractArray{T})
    m = mean(a)
    qs = quantile(a, [0.00, 0.25, 0.50, 0.75, 1.00])    
    R = typeof(convert(FloatingPoint, zero(T)))
    SummaryStats{R}(
        convert(R, m), 
        convert(R, qs[1]),
        convert(R, qs[2]),
        convert(R, qs[3]),
        convert(R, qs[4]),
        convert(R, qs[5]))
end

function Base.show(io::IO, ss::SummaryStats)
    println(io, "Summary Stats:")
    @printf(io, "Mean:         %.6f\n", ss.mean)
    @printf(io, "Minimum:      %.6f\n", ss.min)
    @printf(io, "1st Quartile: %.6f\n", ss.q25)
    @printf(io, "Median:       %.6f\n", ss.median)
    @printf(io, "3rd Quartile: %.6f\n", ss.q75)
    @printf(io, "Maximum:      %.6f\n", ss.max)
end

describe{T<:Real}(a::AbstractArray{T}) = show(summarystats(a))

