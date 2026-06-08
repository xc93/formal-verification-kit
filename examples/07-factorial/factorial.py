def factorial(n):
    """Return n! (n factorial) for a non-negative integer n.

    n! = 1 * 2 * ... * n, with 0! = 1.
    """
    if n < 0:
        raise ValueError("n must be a non-negative integer")
    if n == 0:
        return 1
    return n * factorial(n - 1)
