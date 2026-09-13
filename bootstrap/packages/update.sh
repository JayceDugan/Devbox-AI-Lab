#!/bin/bash

echo "Updating installed package list registry: ./packages/installed_package_list.txt";

pacman -Qqe > ./installed_package_list.txt;
