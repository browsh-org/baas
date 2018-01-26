#!/bin/bash

get_first_active_manager () {
  nodes=$(docker-machine ls)
  first_active_manager=$()
}

get_first_active_manager
eval $(docker-machine env $first_active_manager)

timeout 300 docker run --rm -it browsh-org/browsh
