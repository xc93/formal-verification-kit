def average(nums):
    """Return the arithmetic mean of a non-empty list of numbers."""
    total = 0
    i = 0
    n = len(nums)
    while i < n:
        total = total + nums[i]
        i = i + 1
    return total / n


if __name__ == "__main__":
    assert average([1, 2, 3]) == 2
    assert average([10]) == 10
    assert average([2, 4]) == 3
    assert average([-1, 1]) == 0
    assert average([1, 2]) == 1.5
    assert average([0, 0, 0]) == 0
    print("all tests passed")
