def gcd(a, b):
    """Return the greatest common divisor of two non-negative integers."""
    while b:
        a, b = b, a % b
    return a


if __name__ == "__main__":
    assert gcd(12, 8) == 4
    assert gcd(54, 24) == 6
    assert gcd(17, 5) == 1
    assert gcd(0, 5) == 5
    assert gcd(5, 0) == 5
    assert gcd(0, 0) == 0
    assert gcd(100, 100) == 100
    print("All tests passed.")
