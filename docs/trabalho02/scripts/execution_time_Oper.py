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
    "var_int_add_cte_int",
    "var_int_add_var_int",
    "var_float_add_var_float",
    "var_int_sub_var_int",
    "var_int_mul_var_int",
    "var_float_mul_var_float",
    "var_float_div_var_float",
    "var_int_floordiv_var_int",
    "var_int_mod_var_int"
]

for op in operations:
    results[op] = []
    
    a_int = 15
    b_int = 7
    a_float = 15.5
    b_float = 7.2
    
    gc.collect()
    gc.disable()
    try:
        if op == "var_int_add_cte_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_int + 5
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_add_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_int + b_int
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_float_add_var_float":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_float + b_float
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_sub_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_int - b_int
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_mul_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_int * b_int
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_float_mul_var_float":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_float * b_float
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_float_div_var_float":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_float / b_float
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_floordiv_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_int // b_int
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
        elif op == "var_int_mod_var_int":
            for _ in range(R):
                tic = time.perf_counter_ns()
                for _ in range(n):
                    _ = a_int % b_int
                tac = time.perf_counter_ns()
                results[op].append(tac - tic)
    finally:
        gc.enable()

with open("times_Oper.json", "w") as f:
    json.dump(results, f, indent=2)
print("Execução finalizada: times_Oper.json gerado.")
