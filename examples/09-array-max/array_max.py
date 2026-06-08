def array_max(a):
    """Return the maximum element of a non-empty list `a`.

    Scans the list with an explicit index loop, using only comparison
    operators, indexing reads, len(), while/if, and assignment.
    """
    largest = a[0]
    i = 1
    while i < len(a):
        if a[i] > largest:
            largest = a[i]
        i = i + 1
    return largest


if __name__ == "__main__":
    assert array_max([42]) == 42
    assert array_max([1, 2, 3]) == 3
    assert array_max([3, 2, 1]) == 3
    assert array_max([5, 1, 9, 4, 9, 2]) == 9
    assert array_max([-3, -1, -7, -2]) == -1
    assert array_max([0, 0, 0]) == 0
    assert array_max([2, 2, 2, 2]) == 2
    assert array_max([-10, 5, 0, 5, -10]) == 5
    print("all tests passed")
