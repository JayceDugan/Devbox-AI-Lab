#!/bin/bash

echo "Updating installed package list registry: ./packages/installed_package_list.txt";

pacman -Qqe > ./packages/installed_package_list.txt;
