def max2(x, y):
    if x > y:
        return x
    else:
        return y


def tree_height(t):
    if t is None:
        return 0
    left = t[1]
    right = t[2]
    return 1 + max2(tree_height(left), tree_height(right))


if __name__ == "__main__":
    # Empty tree has height 0.
    assert tree_height(None) == 0

    # Single node has height 1.
    assert tree_height((5, None, None)) == 1

    # Left-leaning chain of three nodes.
    left_chain = (1, (2, (3, None, None), None), None)
    assert tree_height(left_chain) == 3

    # Right-leaning chain of three nodes.
    right_chain = (1, None, (2, None, (3, None, None)))
    assert tree_height(right_chain) == 3

    # Balanced tree: root with two leaf children.
    balanced = (1, (2, None, None), (3, None, None))
    assert tree_height(balanced) == 2

    # Unbalanced: height taken from the deeper (right) subtree.
    unbalanced = (1, (2, None, None), (3, None, (4, None, None)))
    assert tree_height(unbalanced) == 3

    # max2 helper sanity checks.
    assert max2(2, 5) == 5
    assert max2(7, 3) == 7
    assert max2(4, 4) == 4

    print("All tests passed.")
