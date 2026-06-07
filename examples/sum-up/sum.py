def sum_to_n(n):
    """Return the sum of the integers from 1 to n."""
    s = 0
    i = 1
    while i <= n:
        s += i
        i += 1
    return s
