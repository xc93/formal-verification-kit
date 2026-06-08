def reverse(a):
    i = 0
    j = len(a) - 1
    while i < j:
        tmp = a[i]
        a[i] = a[j]
        a[j] = tmp
        i = i + 1
        j = j - 1
    return a


if __name__ == "__main__":
    x = [1, 2, 3, 4, 5]
    assert reverse(x) == [5, 4, 3, 2, 1]
    assert x == [5, 4, 3, 2, 1]  # reversed in place

    y = [1, 2, 3, 4]
    assert reverse(y) is y  # returns the same object
    assert y == [4, 3, 2, 1]

    assert reverse([]) == []
    assert reverse([42]) == [42]

    print("all tests passed")
