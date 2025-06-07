a: int = 5
b: int = 2
c: float = a * b + (a * (a - b)) / b
if a > 5:print("a > 5")
elif a == 5:print("a == 5")
if c > 3:
    print("c > 3")
else:
    print("c <= 3")