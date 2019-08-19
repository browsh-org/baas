#!/bin/bash
kubectl delete pods --context=do-sfo2-browsh $(kubectl get pods --context=do-sfo2-browsh -o=custom-columns=NAME:metadata.name|rg ^browsh-http-server)
