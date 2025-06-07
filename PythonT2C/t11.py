class Tensor:
    data: list
t :Tensor = Tensor()
t.data = [1, 2, 3]
t.data.append(4)
print(t.data)