import time
import os
import gc
import json
from matplotlib import pyplot as plt
import numpy as np

os.sched_setaffinity(0, {13})

lista_n = [1000, 10000, 100000]
l = []
R = 100
results = {n: [] for n in lista_n}

for n in lista_n:
    gc.collect()
    gc.disable()
    ll = []
    try:
        for i in range(R):
            tic = time.perf_counter_ns()
            for i in range(n):
                x = 1
            tac = time.perf_counter_ns()
            results[n].append((tac - tic) / 1e9)
    finally:
        gc.enable()

with open("docs/samuca_files/times3.json", "w") as f:
    json.dump(results, f, indent=2)
