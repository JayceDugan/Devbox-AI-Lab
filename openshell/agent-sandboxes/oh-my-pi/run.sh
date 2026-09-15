#!/bin/bash

#openshell sandbox create --from localhost/ai-lab/openshell-oh-my-pi-sandbox -- omp --allow-home

# --no-keep destroys the sandbox after you exit
openshell sandbox create --provider github --from localhost/ai-lab/openshell-oh-my-pi-sandbox --no-keep
