#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

typedef struct{
    int data[512];
    int data_size;
}Tensor;

Tensor tensor_add(Tensor a, Tensor b){
    Tensor result;
    int arr_result[] = {};
    result.data_size = sizeof(arr_result) / sizeof(arr_result[0]);
    for (int i = 0; i < result.data_size; i++) {
        result.data[i] = arr_result[i];
    }
    for (int i = 0; i < 2; i++){
        result.data[result.data_size++] = (a.data[i] + b.data[i]);
    }
    return result;
}
int main() {
    Tensor t1;
    int arr_t1[] = {1, 2};
    t1.data_size = sizeof(arr_t1) / sizeof(arr_t1[0]);
    for (int i = 0; i < t1.data_size; i++) {
        t1.data[i] = arr_t1[i];
    }
    Tensor t2;
    int arr_t2[] = {3, 4};
    t2.data_size = sizeof(arr_t2) / sizeof(arr_t2[0]);
    for (int i = 0; i < t2.data_size; i++) {
        t2.data[i] = arr_t2[i];
    }
    Tensor t3 = tensor_add(t1, t2);
    printf("Sum:");
    printf(" ");
    printf("[");
    for (int i = 0; i < t3.data_size; i++) {
        if (i > 0) printf(", ");
        printf("%d", t3.data[i]);
    }
    printf("]");
    printf("\n");
    return 0;
}
