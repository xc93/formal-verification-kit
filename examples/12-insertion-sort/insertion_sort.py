def insertion_sort(a):
    i = 1
    while i < len(a):
        key = a[i]
        j = i - 1
        while j >= 0 and a[j] > key:
            a[j + 1] = a[j]
            j = j - 1
        a[j + 1] = key
        i = i + 1
    return a


if __name__ == "__main__":
    assert insertion_sort([]) == []
    assert insertion_sort([1]) == [1]
    assert insertion_sort([2, 1]) == [1, 2]
    assert insertion_sort([5, 2, 4, 6, 1, 3]) == [1, 2, 3, 4, 5, 6]
    assert insertion_sort([3, 3, 1, 2, 1]) == [1, 1, 2, 3, 3]
    assert insertion_sort([5, 4, 3, 2, 1]) == [1, 2, 3, 4, 5]
    assert insertion_sort([-1, -3, 2, 0]) == [-3, -1, 0, 2]

    b = [9, 7, 8]
    assert insertion_sort(b) is b  # sorts in place, returns same object

    print("all tests passed")
