#!/bin/bash
# Rebuild MBench if the shipped binary does not run here.
# Host is C++ only -- kernel.cu is #included for its struct and never compiled.
g++ -O2 -std=c++17 -I. -I/usr/local/cuda/include \
    -o mbench main.cpp CallCubin.cpp Ec.cpp utils.cpp \
    -L/usr/local/cuda/lib64 -L/usr/local/cuda/lib64/stubs \
    -lcudart -lcuda -lpthread