"""Mutually recursive parity checks for non-negative integers."""


def is_even(n):
    """Return True iff n is even, for non-negative integer n."""
    if n == 0:
        return True
    return is_odd(n - 1)


def is_odd(n):
    """Return True iff n is odd, for non-negative integer n."""
    if n == 0:
        return False
    return is_even(n - 1)


if __name__ == "__main__":
    assert is_even(0) is True
    assert is_odd(0) is False
    assert is_even(1) is False
    assert is_odd(1) is True
    assert is_even(2) is True
    assert is_odd(3) is True
    assert is_even(10) is True
    assert is_odd(7) is True

    for n in range(50):
        assert is_even(n) == (n % 2 == 0)
        assert is_odd(n) == (n % 2 == 1)
        assert is_even(n) != is_odd(n)

    print("All tests passed.")
