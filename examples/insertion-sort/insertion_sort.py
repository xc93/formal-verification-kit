def insertion_sort(array):
    """Sort an array of elements using the insertion sort algorithm.

    Returns a new sorted list; the input array is left unchanged.
    """
    result = list(array)  # work on a copy so the input is not modified

    i = 1
    while i < len(result):
        key = result[i]
        j = i - 1
        # shift elements greater than key one position to the right
        while j >= 0 and result[j] > key:
            result[j + 1] = result[j]
            j = j - 1
        result[j + 1] = key
        i = i + 1

    return result
