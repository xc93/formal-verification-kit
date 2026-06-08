def fib(n):
    """Return the n-th Fibonacci number (fib(0) = 0, fib(1) = 1)."""
    prev = 0
    curr = 1
    i = 0
    while i < n:
        prev, curr = curr, prev + curr
        i = i + 1
    return prev


if __name__ == "__main__":
    assert fib(0) == 0
    assert fib(1) == 1
    assert fib(2) == 1
    assert fib(3) == 2
    assert fib(4) == 3
    assert fib(5) == 5
    assert fib(6) == 8
    assert fib(7) == 13
    assert fib(10) == 55
    assert fib(20) == 6765
    print("All tests passed.")
