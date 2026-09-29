import time
import gc
import json
import os
import math

try:
    os.sched_setaffinity(0, {13})
except AttributeError:
    pass

n = 100
R = 100000
results = {}

operations = [
    "math_sqrt_var_float",
    "abs_var_int"
]

for op in operations:
    results[op] = []
    
    a_int = -15
    a_float = 15.5
    
    gc.collect()
    gc.disable()
    try:
        if op == "math_sqrt_var_float":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = math.sqrt(a_float)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "abs_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = abs(a_int)
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
    finally:
        gc.enable()

with open("times_Func.json", "w") as f:
    json.dump(results, f, indent=2)
print("Execução finalizada: times_Func.json gerado.")
