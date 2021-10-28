#!/usr/bin/env bash

OS=linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	:
elif [[ "$OSTYPE" == "darwin"* ]]; then
	:
	hash pv
	if [[ $? -ne 0 ]]; then
		brew install pv
	fi
fi