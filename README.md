# Simple Container Development Environment Management

## Installation
add `source scdev.sh` to your `.bashrc` file

## Usage
1. go to your workspace
2. `scdev-create <env-name> [base-image]` to create an env
3. `scdev-use <env-name> ` to use an exist env
4. when you navigate to your workspace, scdev will auto login to your contianer 
5. when you leave your workspace in your container, scdev will auto logout your contianer
6. you can modify `.scdev.conf` in your workspace to add more container settings