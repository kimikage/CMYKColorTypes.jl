# Arithmetic
+(a::ColorantCMYK, b::ColorantCMYK) = mapc(+, a, b)
-(a::ColorantCMYK, b::ColorantCMYK) = mapc(-, a, b)
-(a::ColorantCMYK) = mapc(-, a)
*(k::Number, a::ColorantCMYK) = mapc(v -> k * v, a)
*(a::ColorantCMYK, k::Number) = k * a
/(a::ColorantCMYK, k::Number) = mapc(v -> v / k, a)
