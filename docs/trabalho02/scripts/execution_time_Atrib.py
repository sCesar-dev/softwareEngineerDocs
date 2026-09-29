import time
import gc
import json
import os

try:
    os.sched_setaffinity(0, {13})
except AttributeError:
    pass

n = 100
R = 100000
results = {}

operations = [
    "var_int_cte_int",
    "var_float_cte_float",
    "var_bool_cte_bool",
    "var_int_var_int",
    "var_float_var_float"
]

for op in operations:
    results[op] = []
    
    b = 5
    c = 5.0
    
    gc.collect()
    gc.disable()
    try:
        if op == "var_int_cte_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    a = 5
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_float_cte_float":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    a = 5.0
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_bool_cte_bool":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    a = True
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    a = b
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_float_var_float":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    a = c
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
    finally:
        gc.enable()

with open("times_Atrib.json", "w") as f:
    json.dump(results, f, indent=2)
print("Execução finalizada: times_Atrib.json gerado.")
