from time import time

lista_n = [1000, 10000, 100000]
l = []

for n in lista_n:
    tic = time()

    for i in range(n):
        x = 1
    tac = time()
    l.append(tac - tic)
    print(f'n: {n} tempo: {l[-1]}')