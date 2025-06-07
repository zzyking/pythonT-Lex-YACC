class Tensor:
    data: list
def tensor_add(a: Tensor, b: Tensor) -> Tensor:
    result: Tensor = Tensor()
    result.data = []
    for i in range(2):
        result.data.append(a.data[i] + b.data[i])
    return result
t1 :Tensor = Tensor()
t1.data = [1, 2]
t2 :Tensor = Tensor()
t2.data = [3, 4]
t3: Tensor = tensor_add(t1, t2)
print("Sum:", t3.data)