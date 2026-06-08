def sum_to_n(n):
    total = 0
    i = n
    while i >= 1:
        total += i
        i -= 1
    return total


if __name__ == "__main__":
    n = int(input("Enter an integer n: "))
    print(sum_to_n(n))
