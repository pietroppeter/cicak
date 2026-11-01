# Exploring arraymancer
# A heavy library: cell 1 imports and re-exports arraymancer, then each cell tries
# one thing on small tensors. Needs bench/deps.sh.
# paths: deps/Arraymancer/src deps/nimblas deps/nimlapack deps/nimcuda/src deps/nim-clblast/src deps/zip deps/untar/src deps/stb_image

# %% import arraymancer
import arraymancer
export arraymancer

# %% a 2x2 tensor
let a* = [[1.0, 2.0], [3.0, 4.0]].toTensor
echo a

# %% shape and rank
echo a.shape, " ", a.rank

# %% matrix product
echo a * a

# %% broadcast a scalar
echo a +. 1.0

# %% transpose
echo a.transpose

# %% a column
echo a[_, 0]

# %% zeros
let z* = zeros[float](3, 3)
echo z.sum

# %% linspace
echo linspace(0.0, 1.0, 5)

# %% map inline
echo a.map_inline(x * x)

# %% max and argmax
echo a.max, " ", a.argmax(axis = 1)

# %% reshape
echo a.reshape(1, 4)

# %% concat
echo concat(a, a, axis = 0).shape

# %% sum along an axis
echo a.sum(axis = 0)

# %% elementwise sqrt
echo sqrt(a)

# %% matrix times a column vector
let v* = [1.0, 2.0].toTensor.reshape(2, 1)
echo a * v

# %% a bigger tensor
let big* = ones[float](200, 200)
echo big.shape

# %% its product
echo (big * big)[0, 0]

# %% mean
echo big.mean

# %% elementwise with zip
echo map2_inline(a, a.transpose, x - y)
